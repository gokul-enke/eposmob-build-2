import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:pos_machine/services/order_submission_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/quantity_input_helper.dart';
import 'package:pos_machine/helpers/product_search_helper.dart';
import 'package:pos_machine/features/billing/domain/product_variant_selection.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/get_product.dart';
import '../models/local_models.dart';
import '../resources/app_url.dart';
import '../providers/app_settings_provider.dart';
import '../providers/master_data_provider.dart';
import '../providers/shared_preferences.dart' as prefs_provider;
import '../widgets/stock_selection_modal.dart' show buildStockGroupingKey;

/// A model representing a local cart item.
/// It holds a product and its associated quantity in the offline cart.
class StockReservation {
  final int stockId;
  num quantity;

  StockReservation({
    required this.stockId,
    required this.quantity,
  });

  StockReservation copy() => StockReservation(
        stockId: stockId,
        quantity: quantity,
      );

  Map<String, dynamic> toJson() => {
        'stockId': stockId,
        'quantity': quantity,
      };

  factory StockReservation.fromJson(Map<String, dynamic> json) {
    final rawStockId = json['stockId'] ?? json['stock_id'];
    final rawQuantity = json['quantity'];

    return StockReservation(
      stockId: rawStockId is int
          ? rawStockId
          : int.tryParse(rawStockId?.toString() ?? '') ?? 0,
      quantity: rawQuantity is num
          ? rawQuantity
          : num.tryParse(rawQuantity?.toString() ?? '') ?? 0,
    );
  }
}

class LocalCartItem {
  static const double _saleUnitEpsilon = 0.0001;
  static int _lineSequence = 0;

  static String _newLineId() {
    _lineSequence = (_lineSequence + 1) & 0x7fffffff;
    return '${DateTime.now().microsecondsSinceEpoch}-$_lineSequence';
  }

  /// Immutable local identity. Unlike product/variant/unit/stock matching,
  /// this cannot be accidentally changed or omitted by a mutation call.
  final String lineId;

  final GetProduct product;
  double? price;
  double? mrp;
  double? taxRate; // Percentage (sum of all taxes)
  double? taxAmount; // Calculated amount per unit
  num quantity;
  final Stock? selectedStock;

  /// Tracks the actual number of units deducted from the selected stock.
  /// This may be less than [quantity] when stock ran out (clamped at 0).
  /// Used for accurate stock restoration on cart removal / clear.
  num stockDeducted;

  /// Canonical raw stock ids behind a grouped pricing selection.
  /// Empty for base-price fallback or a direct single-stock selection.
  List<int> stockGroupIds;

  /// Tracks how much quantity is reserved from each raw stock row.
  /// This is the source of truth for stock restoration and payload expansion.
  List<StockReservation> stockReservations;

  /// Optional per-item comment/note (e.g. "no ice", "extra spicy")
  String? comment;

  /// When true, quantity-based wholesale recalculation must not overwrite [price].
  bool isManualPriceOverride;

  /// Customer's warranty choice for this product line.
  bool warrantyEnabled;

  /// Optional sale-unit metadata used when a cart line originates from an
  /// alternate sale unit barcode such as CASE / PACK / BOX.
  final int? saleUnitId;
  final String? saleUnitName;
  final double? saleUnitConversionRate;

  /// Selected product variant (when product has variants).
  final int? variantId;
  final Map<String, dynamic>? variantAttributes;

  LocalCartItem({
    String? lineId,
    required this.product,
    this.price,
    this.mrp,
    this.taxRate,
    this.taxAmount,
    this.quantity = 1,
    this.selectedStock,
    this.stockDeducted = 0,
    List<int>? stockGroupIds,
    List<StockReservation>? stockReservations,
    this.comment,
    this.isManualPriceOverride = false,
    this.warrantyEnabled = false,
    this.saleUnitId,
    this.saleUnitName,
    this.saleUnitConversionRate,
    this.variantId,
    this.variantAttributes,
  })  : lineId =
            lineId == null || lineId.trim().isEmpty ? _newLineId() : lineId,
        stockGroupIds = stockGroupIds ?? <int>[],
        stockReservations = stockReservations ?? <StockReservation>[];

  bool get hasGroupedStockSelection => stockGroupIds.length > 1;

  bool get hasSaleUnit =>
      saleUnitId != null &&
      saleUnitConversionRate != null &&
      saleUnitConversionRate! > 0;

  String get displayUnitName {
    final candidate = hasSaleUnit ? saleUnitName : product.unit;
    if (candidate == null || candidate.trim().isEmpty) {
      return '-';
    }
    return candidate.trim();
  }

  String get displayName => ProductVariantSelection.cartDisplayName(
        productName: product.productName,
        variantAttributes: variantAttributes,
      );

  String get variantLabel {
    final attrs = variantAttributes;
    if (attrs == null || attrs.isEmpty) return '';
    return attrs.values
        .map((value) => value?.toString() ?? '')
        .where((value) => value.trim().isNotEmpty)
        .join(' | ');
  }

  num get displayQuantity => toDisplayQuantity(quantity);

  double? get displayPrice => toDisplayAmount(price);

  double? get displayMrp => toDisplayAmount(mrp);

  num toDisplayQuantity(num baseQuantity) {
    final rate = saleUnitConversionRate;
    if (!hasSaleUnit || rate == null || rate <= 0) {
      return baseQuantity;
    }
    return _normalizeQuantity(baseQuantity / rate);
  }

  num toBaseQuantity(num displayQuantity) {
    final rate = saleUnitConversionRate;
    if (!hasSaleUnit || rate == null || rate <= 0) {
      return displayQuantity;
    }
    return _normalizeQuantity(displayQuantity * rate);
  }

  double? toDisplayAmount(double? baseAmount) {
    final rate = saleUnitConversionRate;
    if (baseAmount == null || !hasSaleUnit || rate == null || rate <= 0) {
      return baseAmount;
    }
    return baseAmount * rate;
  }

  double? toBaseAmount(double? displayAmount) {
    final rate = saleUnitConversionRate;
    if (displayAmount == null || !hasSaleUnit || rate == null || rate <= 0) {
      return displayAmount;
    }
    return displayAmount / rate;
  }

  bool canUseSaleUnitPayloadFor(num baseQuantity) {
    if (!hasSaleUnit) {
      return false;
    }
    final displayQuantity = toDisplayQuantity(baseQuantity);
    final reconstructedBase = toBaseQuantity(displayQuantity);
    if ((reconstructedBase - baseQuantity).abs() >= _saleUnitEpsilon) {
      return false;
    }

    // A stock reservation can split one pack into a reserved and an
    // unreserved part (for example, 6 available pieces out of a 25-piece
    // pack). PC/PCS products must not serialize those parts as 0.24 PACK and
    // 0.76 PACK because the order API requires whole quantities for
    // non-decimal products. Emit those lines in base units instead.
    if (!allowsDecimalQuantityUnit(product.unit)) {
      final roundedDisplayQuantity = displayQuantity.round();
      return (displayQuantity - roundedDisplayQuantity).abs() <
          _saleUnitEpsilon;
    }

    return true;
  }

  num _normalizeQuantity(num value) {
    if (value is double) {
      final roundedValue = value.roundToDouble();
      if ((value - roundedValue).abs() < _saleUnitEpsilon) {
        return roundedValue.toInt();
      }
    }
    return value;
  }
}

/// Represents a saved order stored locally
class SavedOrder {
  final String id; // Unique identifier for the order
  final String orderNumber; // Display order number (ORD-1, ORD-2, etc.)
  final List<LocalCartItem> items;
  final String? customerName;
  final String? customerPhone;
  final String? comment;
  final String createdAt;
  final double total;
  final String? deliveryMethod;

  // New fields for API compatibility
  final int? customerId;
  final String? paymentMethod;
  final String? paidAmount;
  final String? balanceAmount;
  final String? transactionId;
  final String? couponId;
  final String? deliveryMethodId;
  final String? carNumber;
  final String? status;
  final String? deliveryDate; // Added for local persistence
  final String? deliveryTime; // Added for local persistence
  final double? flatDiscount;
  final double? percentageDiscount;
  final bool? toCustomerCredit;

  final String? tableId;
  final String? alternatePhone;
  final String? address;
  final double? deliveryCharge;
  final String? customerVatNumber;
  final String? customerCrNumber;
  final String? customerType;
  final int? quotationId;
  final String? quotationNumber;

  SavedOrder({
    required this.id,
    required this.orderNumber,
    required this.items,
    this.customerName,
    this.customerPhone,
    this.comment,
    required this.createdAt,
    required this.total,
    this.deliveryMethod,
    // New API-compatible fields
    this.customerId,
    this.paymentMethod,
    this.paidAmount,
    this.balanceAmount,
    this.transactionId,
    this.couponId,
    this.deliveryMethodId,
    this.carNumber,
    this.status,
    this.deliveryDate, // Added to constructor
    this.deliveryTime, // Added to constructor
    this.flatDiscount,
    this.percentageDiscount,
    this.toCustomerCredit,
    this.tableId,
    this.alternatePhone,
    this.address,
    this.deliveryCharge,
    this.customerVatNumber,
    this.customerCrNumber,
    this.customerType,
    this.quotationId,
    this.quotationNumber,
  });
}

class PriceSummary {
  double discount;
  double netPayable;
  double subTotal;
  double totalTax;
  double netTotal;
  double flatDiscount;
  double percentageDiscount;
  double originalSubTotal;

  PriceSummary({
    required this.discount,
    required this.netPayable,
    required this.subTotal,
    required this.totalTax,
    required this.netTotal,
    this.flatDiscount = 0.0,
    this.percentageDiscount = 0.0,
    this.originalSubTotal = 0.0,
  });
}

/// The LocalProductProvider is aimed for an offline approach.
/// Upon login, all products should be loaded into this provider
/// via [initializeProducts]. It maintains a full product list along with
/// a filtered list and a selected product for details, similar to GridSelectionProvider.
/// Additionally, it manages a separate offline cart state.
class LocalProductProvider extends ChangeNotifier {
  String _cartSessionId = Hive.isBoxOpen('order_submissions')
      ? (Hive.box('order_submissions').get('_active_cart_session') as String? ??
          'legacy')
      : 'legacy';
  String get cartSessionId => _cartSessionId;

  static bool _cachedStockEnabled = false;

  static void cacheStockEnabled(bool enabled) {
    _cachedStockEnabled = enabled;
  }

  // Hive boxes
  final Box<HiveProduct> _productsBox = Hive.box<HiveProduct>('products');
  final Box<HiveLocalCartItem> _cartItemsBox =
      Hive.box<HiveLocalCartItem>('cart_items');
  final Box<HiveSavedOrder> _savedOrdersBox =
      Hive.box<HiveSavedOrder>('saved_orders');
  late Box<HiveSavedOrder> _confirmedOrdersBox;
  bool _isConfirmedBoxInitialized = false;

  /// How many products are JSON-encoded or decoded between yields to the
  /// event loop. On Windows the Dart UI isolate runs on the platform thread,
  /// so a multi-second synchronous pass over a 30k catalog stops the Win32
  /// message pump and the window is flagged "Not Responding". Keeping each
  /// slice to a few hundred rows keeps every pass well under that threshold.
  static const int _catalogChunkSize = 300;

  /// Products whose in-memory stock was mutated since the last persist. Cart
  /// and stock adjustments touch one or two products, so they are written as
  /// single keyed rows instead of rewriting the whole catalog.
  final Set<int> _dirtyProductIds = <int>{};

  /// Bumped every time [_products] is replaced wholesale. A hydration that
  /// started before the bump must not clobber the newer catalog.
  int _catalogEpoch = 0;

  late final Future<void> _hydration;

  /// Completes once the product catalog has been read from Hive. Small boxes
  /// hydrate synchronously inside the constructor; large boxes are decoded in
  /// chunks and callers that need the full baseline should await this.
  Future<void> get hydrated => _hydration;

  bool _isHydrated = false;

  /// Whether the product catalog has finished loading from Hive.
  bool get isHydrated => _isHydrated;

  /// Lets timers, platform messages and the Windows message pump run between
  /// chunks of catalog work.
  static Future<void> _yieldToEventLoop() =>
      Future<void>.delayed(Duration.zero);

  // Hive mutation methods return Futures. Keep every local rewrite in one
  // ordered queue so a later clear/add cycle cannot overtake an earlier one.
  static Future<void> _persistenceTail = Future<void>.value();
  static Object? _persistenceError;
  static StackTrace? _persistenceStackTrace;

  void _enqueuePersistence(
    String operation,
    Future<void> Function() task,
  ) {
    // Chain in the root zone: callers may sit in a guarded zone (fake-async
    // widget tests, runZonedGuarded) that stops pumping before these writes
    // finish, which would strand the tail and deadlock flushPendingPersistence.
    Zone.root.run(() {
      final next = _persistenceTail.then((_) => task());
      _persistenceTail = next.catchError((Object error, StackTrace stackTrace) {
        _persistenceError = error;
        _persistenceStackTrace = stackTrace;
        debugPrint('Hive persistence failed during $operation: $error');
        debugPrint('$stackTrace');
      });
    });
  }

  /// Waits until every queued local write is durable. Tests, logout, tenant
  /// switching and app lifecycle handlers should call this before closing boxes.
  static Future<void> flushPendingPersistence() async {
    await _persistenceTail;
    final error = _persistenceError;
    final stackTrace = _persistenceStackTrace;
    _persistenceError = null;
    _persistenceStackTrace = null;
    if (error != null) {
      Error.throwWithStackTrace(error, stackTrace ?? StackTrace.current);
    }
  }

  Future<void> flushPersistence() => flushPendingPersistence();

  // The complete list of products loaded locally.
  List<GetProduct> _products = [];
  final Map<String, List<GetProduct>> _productsByBarcode =
      <String, List<GetProduct>>{};

  // A filtered subset of _products, based on search or category.
  List<GetProduct> _filteredProducts = [];

  // Getter for the complete product list.
  List<GetProduct> get products => _products;

  // Getter for the filtered product list.
  List<GetProduct> get filteredProducts => _filteredProducts;

  /// Returns only sellable products from filtered list (for billing screens)
  /// Products with null sellable are treated as sellable (default behavior)
  List<GetProduct> get sellableFilteredProducts =>
      _filteredProducts.where((p) => p.sellable != false).toList();

  /// Returns only sellable products from complete list (for billing screens)
  /// Products with null sellable are treated as sellable (default behavior)
  List<GetProduct> get sellableProducts =>
      _products.where((p) => p.sellable != false).toList();

  // Currently selected product (for showing product details).
  GetProduct? _selectedProduct;
  GetProduct? get selectedProduct => _selectedProduct;

  // Currently selected stock (for the selected product).
  Stock? _selectedStock;
  Stock? get selectedStock => _selectedStock;

  // Local offline cart state.
  final List<LocalCartItem> _cartItems = [];
  List<LocalCartItem> get cartItems => _cartItems;
  bool isLoading = false;

  // List of saved orders
  final List<SavedOrder> _savedOrders = [];
  List<SavedOrder> get savedOrders => _savedOrders;

  // List of confirmed orders
  final List<SavedOrder> _confirmedOrders = [];
  List<SavedOrder> get confirmedOrders => _confirmedOrders;

  // Currently loaded order (for editing)
  SavedOrder? _currentOrder;
  SavedOrder? get currentOrder => _currentOrder;
  int _lastLocalOrderIdMicros = 0;

  PriceSummary? priceSummary;

  // 📊 Tax Breakdown Logic (for TAX-INCLUSIVE pricing)
  // Returns Map with "TaxName @ Rate%" as key and amount as value
  Map<String, double> get taxBreakdown {
    final breakdown = <String, double>{};

    for (var item in _cartItems) {
      final double itemTotal = (item.price ?? 0.0) * item.quantity;
      final double currentTaxRate = item.taxRate ?? 0.0;

      if (currentTaxRate <= 0 || itemTotal <= 0) continue;

      // Extract total tax from tax-inclusive price
      // Formula: Tax = Price × TaxRate / (100 + TaxRate)
      final double totalTaxAmount =
          itemTotal * currentTaxRate / (100 + currentTaxRate);

      final double productTotalTaxRate = item.product.totalTaxRate;

      // Check if the current rate matches the product's defined tax structure
      // We use a small epsilon for float comparison
      if ((currentTaxRate - productTotalTaxRate).abs() < 0.01 &&
          (item.product.taxes?.isNotEmpty ?? false)) {
        // Distribute proportional to distinct taxes
        for (var tax in (item.product.taxes ?? [])) {
          if (productTotalTaxRate > 0) {
            // Parse rate from string to double
            final double taxRateVal = double.tryParse(tax.rate ?? "0") ?? 0.0;
            // Calculate share: (Individual Rate / Total Rate) * Total Tax Amount
            final double share =
                (taxRateVal / productTotalTaxRate) * totalTaxAmount;

            // Create key with rate: "GST @ 18%"
            final String taxName = tax.name ?? "Tax";
            final String rateStr = taxRateVal % 1 == 0
                ? taxRateVal.toInt().toString()
                : taxRateVal.toStringAsFixed(1);
            final String key = "$taxName @$rateStr%";
            breakdown[key] = (breakdown[key] ?? 0.0) + share;
          }
        }
      } else {
        // Fallback: Rate doesn't match or no breakdown available
        // Assign to generic "Tax" or specific label if only 1 tax exists
        String key = "Tax @ ${currentTaxRate.toStringAsFixed(0)}%";
        if ((item.product.taxes?.isNotEmpty ?? false) &&
            item.product.taxes!.length == 1) {
          final tax = item.product.taxes!.first;
          final taxName = tax.name ?? "Tax";
          final taxRateVal = double.tryParse(tax.rate ?? "0") ?? currentTaxRate;
          final String rateStr = taxRateVal % 1 == 0
              ? taxRateVal.toInt().toString()
              : taxRateVal.toStringAsFixed(1);
          key = "$taxName @ $rateStr%";
        }

        // If it was manually edited to a custom rate, we just show it as "Tax"
        // unless it happens to match the single tax name.
        breakdown[key] = (breakdown[key] ?? 0.0) + totalTaxAmount;
      }
    }
    return breakdown;
  }

  // Add pagination properties
  int _currentPage = 1;
  int _totalPages = 1;
  int _itemsPerPage = 20;

  /// Incremented each time [listAllProducts] updates [_filteredProducts].
  /// The barcode screen uses this as a cheap memoization key to avoid
  /// re-expanding BarcodeRows on unrelated [setState] calls (e.g. selection
  /// state changes). Other screens that use [paginatedProducts] are unaffected.
  int _filteredProductsVersion = 0;

  // Getters for pagination
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get itemsPerPage => _itemsPerPage;

  /// Version counter incremented whenever the filtered product list changes.
  /// Barcode screen memoizes row expansion against this value.
  int get filteredProductsVersion => _filteredProductsVersion;

  /// The full filtered product list (all pages) used by the barcode print
  /// screen, which applies its own row-level pagination after expansion.
  /// Other screens use [paginatedProducts] instead.
  List<GetProduct> get allFilteredProducts =>
      List.unmodifiable(_filteredProducts);

  // Stock management settings - need to be injected from outside since this provider
  // doesn't have access to GeneralSettingsProvider directly
  bool? _stockEnabled;
  bool _allowOverselling = true;

  // Discount management
  double _flatDiscount = 0.0;
  double _percentageDiscount = 0.0;

  /// Sets the stock enabled status from the GeneralSettingsProvider
  void setStockEnabled(bool enabled) {
    _stockEnabled = enabled;
    _cachedStockEnabled = enabled;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('general_stock_enabled', enabled);
    });
    debugPrint("📦 Stock management setting updated: $_stockEnabled");
  }

  /// Controls whether cart quantities may exceed the currently available
  /// frontend stock. This defaults to true for backward compatibility and is
  /// synchronized from the ALLOW_OVERSELL app setting by billing entry points.
  void setAllowOverselling(bool allowed) {
    _allowOverselling = allowed;
    debugPrint('Stock overselling allowed: $_allowOverselling');
  }

  bool get allowOverselling => _allowOverselling;

  /// Active stock grouping fields, mirrored from [MasterDataProvider] so cart
  /// merge decisions use the same pricing signature as stock grouping. Defaults
  /// to price+unit until the billing flow supplies the configured fields.
  Set<String> _activeStockGroupingFields =
      MasterDataProvider.defaultStockGroupingFields;

  /// Sets the active stock grouping fields used to decide when two grouped
  /// cart lines collapse into one (see [_stockGroupingKeyForStock]).
  void setActiveStockGroupingFields(Set<String> fields) {
    _activeStockGroupingFields =
        fields.isEmpty ? MasterDataProvider.defaultStockGroupingFields : fields;
  }

  /// Builds the pricing signature for a stock using the active grouping fields.
  /// All batches inside one pricing group share identical active-field values,
  /// so this key is stable even as FEFO depletion changes which raw stock ids
  /// remain in the group.
  String? _stockGroupingKeyForStock(Stock? stock) {
    if (stock == null) {
      return null;
    }
    return buildStockGroupingKey(stock, _activeStockGroupingFields);
  }

  bool stocksAreAllocationCompatible(Stock? first, Stock? second) {
    if (first == null || second == null) {
      return false;
    }

    final sameStore = first.storeId != null && second.storeId != null
        ? first.storeId == second.storeId
        : (first.storeName ?? '').trim().toLowerCase() ==
            (second.storeName ?? '').trim().toLowerCase();
    if (!sameStore) {
      return false;
    }

    return _stockGroupingKeyForStock(first) ==
        _stockGroupingKeyForStock(second);
  }

  List<int> _expandCompatibleStockGroupIds({
    required GetProduct product,
    required Stock selectedStock,
    required int? variantId,
    List<int>? stockGroupIds,
  }) {
    final ids = <int>{..._normalizeStockGroupIds(stockGroupIds)};
    if (selectedStock.id != null) {
      ids.add(selectedStock.id!);
    }

    final currentProduct = getProductById(product.productId ?? -1) ?? product;
    final scopedStocks = filterStocksForVariant(
      currentProduct.stock ?? const <Stock>[],
      variantId,
    );
    for (final candidate in scopedStocks) {
      if (candidate.id != null &&
          (candidate.quantity ?? 0) > 0 &&
          stocksAreAllocationCompatible(selectedStock, candidate)) {
        ids.add(candidate.id!);
      }
    }

    return _normalizeStockGroupIds(ids.toList());
  }

  /// Gets the current stock enabled status
  bool get isStockEnabled => _stockEnabled ?? _cachedStockEnabled;

  Future<void> _loadStockEnabledFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getBool('general_stock_enabled');
      if (cached != null) {
        _stockEnabled = cached;
        _cachedStockEnabled = cached;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to hydrate stock setting from prefs: $e');
    }
  }

  // Constructor - Load data from Hive on initialization
  LocalProductProvider() {
    _loadStockEnabledFromPrefs();
    _hydration = _hydrateProductsFromHive();
    _loadCartFromHive();
    _loadSavedOrdersFromHive();
    _initConfirmedOrdersBox();
  }

  String _normalizeBarcode(String? barcode) {
    return (barcode ?? '').trim();
  }

  double _resolveCartTaxRate(
    GetProduct product, {
    Stock? selectedStock,
    double? fallbackTaxRate,
  }) {
    final stockTaxRate = selectedStock?.taxRate?.trim();
    if (stockTaxRate != null &&
        stockTaxRate.isNotEmpty &&
        (double.tryParse(stockTaxRate) ?? 0.0) > 0) {
      return double.tryParse(stockTaxRate) ?? 0.0;
    }
    return fallbackTaxRate ?? product.totalTaxRate;
  }

  double _calculateTaxAmount(double price, double taxRate) {
    if (taxRate <= 0) {
      return 0.0;
    }
    return (price * taxRate) / (100 + taxRate);
  }

  double? _parseAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return double.tryParse(value.trim());
  }

  ProductVariant? _findVariantById(GetProduct product, int? variantId) {
    if (variantId == null || !product.hasVariants) {
      return null;
    }
    for (final variant in product.activeVariants) {
      if (variant.id == variantId) {
        return variant;
      }
    }
    return null;
  }

  double? _resolveVariantPrice(GetProduct product, int? variantId) {
    final variant = _findVariantById(product, variantId);
    if (variant == null) {
      return null;
    }
    final productPrice = ProductVariantSelection.productBasePrice(product);
    return variant.effectivePrice(productPrice);
  }

  double? _resolveVariantMrp(GetProduct product, int? variantId) {
    final variant = _findVariantById(product, variantId);
    if (variant == null) {
      return null;
    }
    final effectivePrice = _resolveVariantPrice(product, variantId) ??
        ProductVariantSelection.productBasePrice(product);
    return ProductVariantSelection.resolveVariantMrp(
      variant: variant,
      product: product,
      effectivePrice: effectivePrice,
    );
  }

  double _resolveMrp({
    required GetProduct product,
    Stock? selectedStock,
    double? fallbackMrp,
    int? variantId,
  }) {
    return _parseAmount(selectedStock?.mrp) ??
        _resolveVariantMrp(product, variantId) ??
        _parseAmount(product.mrp?.toString()) ??
        fallbackMrp ??
        0.0;
  }

  int? _resolveWholesaleMinUnit(Stock? selectedStock) {
    final wholesaleMinUnit = selectedStock?.wholesaleMinUnit;
    if (wholesaleMinUnit == null || wholesaleMinUnit <= 0) {
      return null;
    }
    return wholesaleMinUnit;
  }

  double? _resolveWholesalePrice(Stock? selectedStock) {
    final wholesalePrice = _parseAmount(selectedStock?.wholesalePrice);
    if (wholesalePrice == null || wholesalePrice <= 0) {
      return null;
    }
    return wholesalePrice;
  }

  bool _qualifiesForWholesalePrice({
    required num quantity,
    Stock? selectedStock,
  }) {
    final wholesalePrice = _resolveWholesalePrice(selectedStock);
    final wholesaleMinUnit = _resolveWholesaleMinUnit(selectedStock);
    return wholesalePrice != null &&
        wholesaleMinUnit != null &&
        quantity >= wholesaleMinUnit;
  }

  /// Finds the [SaleUnit] on [product] matching [saleUnitId].
  SaleUnit? _findSaleUnit(GetProduct product, int? saleUnitId) {
    if (saleUnitId == null) return null;
    final saleUnits = product.saleUnits;
    if (saleUnits == null) return null;
    for (final saleUnit in saleUnits) {
      if (saleUnit.id == saleUnitId) return saleUnit;
    }
    return null;
  }

  /// Resolves the per-BASE-unit price for a chosen sale unit following the
  /// documented fallback chain: batch override -> master price ->
  /// resolved_price -> auto (base x conversion). Returns null when the sale
  /// unit carries no explicit pricing, letting the caller fall back to the
  /// normal base/wholesale resolution (which already yields a per-base price).
  ///
  /// Sale-unit prices are expressed per sale unit (e.g. per Dozen), so we
  /// divide by the conversion rate to keep the internal per-base invariant;
  /// downstream display/payload logic scales it back up by the same rate.
  double? _resolveSaleUnitBasePrice({
    required GetProduct product,
    required int? saleUnitId,
    Stock? selectedStock,
  }) {
    if (saleUnitId == null) return null;
    final saleUnit = _findSaleUnit(product, saleUnitId);
    final conversionRate = saleUnit?.conversionRateValue;
    if (saleUnit == null || conversionRate == null) return null;

    // 1. Batch-specific override wins over everything (incl. wholesale).
    final override = selectedStock?.unitPriceOverrideFor(saleUnitId);
    if (override != null && override > 0) {
      return override / conversionRate;
    }

    // 2. Master price set on the sale unit.
    final masterPrice = saleUnit.price;
    if (masterPrice != null && masterPrice > 0) {
      return masterPrice / conversionRate;
    }

    // 3. Backend-resolved price for the default batch.
    final resolved = saleUnit.resolvedPrice;
    if (resolved != null && resolved > 0) {
      return resolved / conversionRate;
    }

    // 4. Auto (base x conversion) -> handled by base resolution below.
    return null;
  }

  double _resolveUnitPrice({
    required GetProduct product,
    required num quantity,
    Stock? selectedStock,
    double? fallbackPrice,
    int? saleUnitId,
    int? variantId,
  }) {
    final saleUnitBasePrice = _resolveSaleUnitBasePrice(
      product: product,
      saleUnitId: saleUnitId,
      selectedStock: selectedStock,
    );
    if (saleUnitBasePrice != null) {
      return saleUnitBasePrice;
    }

    final variantPrice = _resolveVariantPrice(product, variantId);
    if (variantPrice != null) {
      return variantPrice;
    }

    final wholesalePrice = _resolveWholesalePrice(selectedStock);
    if (wholesalePrice != null &&
        _qualifiesForWholesalePrice(
          quantity: quantity,
          selectedStock: selectedStock,
        )) {
      return wholesalePrice;
    }

    final retailPrice = _parseAmount(selectedStock?.price) ??
        _parseAmount(product.price?.price?.toString());
    if (retailPrice != null) {
      return retailPrice;
    }

    if (fallbackPrice != null &&
        wholesalePrice != null &&
        (fallbackPrice - wholesalePrice).abs() < 0.001) {
      return 0.0;
    }

    return fallbackPrice ?? 0.0;
  }

  /// Read-only preview using the same pricing chain as [addToCart].
  double previewCartUnitPrice({
    required GetProduct product,
    required num quantity,
    Stock? selectedStock,
    double? fallbackPrice,
    int? saleUnitId,
    int? variantId,
  }) {
    return _resolveUnitPrice(
      product: product,
      quantity: quantity,
      selectedStock: selectedStock,
      fallbackPrice: fallbackPrice,
      saleUnitId: saleUnitId,
      variantId: variantId,
    );
  }

  void _refreshCartItemPricing(
    LocalCartItem item, {
    Stock? selectedStock,
    bool forcePriceRefresh = false,
  }) {
    final effectiveStock = selectedStock ?? item.selectedStock;
    if (forcePriceRefresh || !item.isManualPriceOverride) {
      item.price = _resolveUnitPrice(
        product: item.product,
        quantity: item.quantity,
        selectedStock: effectiveStock,
        fallbackPrice: item.price,
        saleUnitId: item.saleUnitId,
        variantId: item.variantId,
      );
    }

    item.mrp = _resolveMrp(
      product: item.product,
      selectedStock: effectiveStock,
      fallbackMrp: item.mrp,
      variantId: item.variantId,
    );

    final effectiveTaxRate = _resolveCartTaxRate(
      item.product,
      selectedStock: effectiveStock,
      fallbackTaxRate: item.taxRate,
    );
    item.taxRate = effectiveTaxRate;
    item.taxAmount = _calculateTaxAmount(item.price ?? 0.0, effectiveTaxRate);
    _clampManualCartItemToMinimumPrice(item);
  }

  void _clampManualCartItemToMinimumPrice(LocalCartItem item) {
    if (!item.isManualPriceOverride) return;
    final minimumPrice = minimumSalePriceForCartItem(item);
    if (minimumPrice == null || (item.price ?? 0.0) >= minimumPrice - 0.001) {
      return;
    }
    item.price = minimumPrice;
    item.taxAmount = _calculateTaxAmount(minimumPrice, item.taxRate ?? 0.0);
  }

  List<int> _normalizeStockGroupIds(List<int>? stockGroupIds) {
    if (stockGroupIds == null || stockGroupIds.isEmpty) {
      return <int>[];
    }

    final normalized = stockGroupIds.toSet().toList()..sort();
    return normalized;
  }

  bool _stockGroupIdsEqual(List<int> first, List<int> second) {
    if (first.length != second.length) {
      return false;
    }

    for (int index = 0; index < first.length; index++) {
      if (first[index] != second[index]) {
        return false;
      }
    }

    return true;
  }

  List<StockReservation> _cloneStockReservations(
      List<StockReservation> reservations) {
    return reservations.map((reservation) => reservation.copy()).toList();
  }

  num _sumStockReservations(List<StockReservation> reservations) {
    return reservations.fold<num>(
      0,
      (sum, reservation) => sum + reservation.quantity,
    );
  }

  num _normalizeCartQuantity(num value) {
    if (value is double) {
      final roundedValue = value.roundToDouble();
      if ((value - roundedValue).abs() < 0.0001) {
        return roundedValue.toInt();
      }
    }
    return value;
  }

  List<StockReservation> _legacyStockReservations(
      Stock? selectedStock, num stockDeducted) {
    if (selectedStock?.id == null || stockDeducted <= 0) {
      return <StockReservation>[];
    }

    return <StockReservation>[
      StockReservation(
        stockId: selectedStock!.id!,
        quantity: stockDeducted,
      ),
    ];
  }

  String? _serializeStockGroupIds(List<int> stockGroupIds) {
    if (stockGroupIds.isEmpty) {
      return null;
    }

    return json.encode(stockGroupIds);
  }

  List<int> _deserializeStockGroupIds(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return <int>[];
    }

    try {
      final decoded = json.decode(rawValue);
      if (decoded is List) {
        return _normalizeStockGroupIds(
          decoded
              .map((value) =>
                  value is int ? value : int.tryParse(value?.toString() ?? ''))
              .whereType<int>()
              .toList(),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to deserialize stock group ids: $e');
    }

    return <int>[];
  }

  String? _serializeStockReservations(List<StockReservation> reservations) {
    if (reservations.isEmpty) {
      return null;
    }

    return json.encode(
      reservations.map((reservation) => reservation.toJson()).toList(),
    );
  }

  List<StockReservation> _deserializeStockReservations(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return <StockReservation>[];
    }

    try {
      final decoded = json.decode(rawValue);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((entry) => StockReservation.fromJson(
                Map<String, dynamic>.from(entry.cast<dynamic, dynamic>())))
            .where((reservation) => reservation.stockId > 0)
            .toList();
      }
    } catch (e) {
      debugPrint('⚠️ Failed to deserialize stock reservations: $e');
    }

    return <StockReservation>[];
  }

  LocalCartItem _buildLocalCartItemFromHive(HiveLocalCartItem hiveCartItem) {
    final productJson = json.decode(hiveCartItem.serializedProduct.value);
    final product = GetProduct.fromJson(productJson);

    Stock? selectedStock;
    if (hiveCartItem.serializedSelectedStock != null) {
      final stockJson =
          json.decode(hiveCartItem.serializedSelectedStock!.value);
      selectedStock = Stock.fromJson(stockJson);
    }

    final stockGroupIds = _deserializeStockGroupIds(
      hiveCartItem.serializedStockGroupIds?.value,
    );

    var stockReservations = _deserializeStockReservations(
      hiveCartItem.serializedStockReservations?.value,
    );

    if (stockReservations.isEmpty &&
        selectedStock != null &&
        hiveCartItem.stockDeducted > 0) {
      stockReservations =
          _legacyStockReservations(selectedStock, hiveCartItem.stockDeducted);
    }

    final resolvedStockDeducted = stockReservations.isNotEmpty
        ? _sumStockReservations(stockReservations)
        : hiveCartItem.stockDeducted;

    return LocalCartItem(
      lineId: hiveCartItem.lineId,
      product: product,
      quantity: hiveCartItem.quantity,
      price: hiveCartItem.price,
      mrp: hiveCartItem.mrp,
      taxAmount: hiveCartItem.taxAmount,
      taxRate: hiveCartItem.taxRate,
      selectedStock: selectedStock,
      stockDeducted: resolvedStockDeducted,
      stockGroupIds: stockGroupIds,
      stockReservations: stockReservations,
      comment: hiveCartItem.comment,
      isManualPriceOverride: hiveCartItem.isManualPriceOverride,
      saleUnitId: hiveCartItem.saleUnitId,
      saleUnitName: hiveCartItem.saleUnitName,
      saleUnitConversionRate: hiveCartItem.saleUnitConversionRate,
      variantId: hiveCartItem.variantId,
      variantAttributes: _deserializeVariantAttributes(
        hiveCartItem.serializedVariantAttributes?.value,
      ),
      warrantyEnabled: hiveCartItem.warrantyEnabled,
    );
  }

  HiveLocalCartItem _buildHiveCartItem(LocalCartItem item) {
    HiveStringValue? serializedStock;
    if (item.selectedStock != null) {
      serializedStock =
          HiveStringValue(json.encode(item.selectedStock!.toJson()));
    }

    final serializedStockGroupIds = _serializeStockGroupIds(item.stockGroupIds);
    final serializedStockReservations =
        _serializeStockReservations(item.stockReservations);

    return HiveLocalCartItem(
      lineId: item.lineId,
      productId: item.product.productId!,
      quantity: item.quantity,
      price: item.price,
      mrp: item.mrp,
      taxAmount: item.taxAmount,
      taxRate: item.taxRate,
      serializedProduct: HiveStringValue(json.encode(item.product.toJson())),
      serializedSelectedStock: serializedStock,
      stockDeducted: item.stockDeducted,
      comment: item.comment,
      serializedStockGroupIds: serializedStockGroupIds == null
          ? null
          : HiveStringValue(serializedStockGroupIds),
      serializedStockReservations: serializedStockReservations == null
          ? null
          : HiveStringValue(serializedStockReservations),
      isManualPriceOverride: item.isManualPriceOverride,
      saleUnitId: item.saleUnitId,
      saleUnitName: item.saleUnitName,
      saleUnitConversionRate: item.saleUnitConversionRate,
      variantId: item.variantId,
      serializedVariantAttributes: _serializeVariantAttributes(
        item.variantAttributes,
      ),
      warrantyEnabled: item.warrantyEnabled,
    );
  }

  LocalCartItem _cloneLocalCartItem(LocalCartItem item) {
    return LocalCartItem(
      lineId: item.lineId,
      product: item.product,
      quantity: item.quantity,
      price: item.price,
      mrp: item.mrp,
      taxRate: item.taxRate,
      taxAmount: item.taxAmount,
      selectedStock: item.selectedStock,
      stockDeducted: item.stockDeducted,
      stockGroupIds: List<int>.from(item.stockGroupIds),
      stockReservations: _cloneStockReservations(item.stockReservations),
      comment: item.comment,
      isManualPriceOverride: item.isManualPriceOverride,
      warrantyEnabled: item.warrantyEnabled,
      saleUnitId: item.saleUnitId,
      saleUnitName: item.saleUnitName,
      saleUnitConversionRate: item.saleUnitConversionRate,
      variantId: item.variantId,
      variantAttributes: item.variantAttributes == null
          ? null
          : Map<String, dynamic>.from(item.variantAttributes!),
    );
  }

  Map<String, dynamic>? _deserializeVariantAttributes(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {}
    return null;
  }

  HiveStringValue? _serializeVariantAttributes(
    Map<String, dynamic>? attributes,
  ) {
    if (attributes == null || attributes.isEmpty) {
      return null;
    }
    return HiveStringValue(json.encode(attributes));
  }

  List<Stock> _sortStocksForReservation(List<Stock> stocks) {
    final sortedStocks = List<Stock>.from(stocks);
    sortedStocks.sort((first, second) {
      if (first.expiryDate != null && second.expiryDate != null) {
        try {
          final firstDate = DateTime.parse(first.expiryDate!);
          final secondDate = DateTime.parse(second.expiryDate!);
          final expiryComparison = firstDate.compareTo(secondDate);
          if (expiryComparison != 0) {
            return expiryComparison;
          }
        } catch (_) {}
      }

      if (first.date != null && second.date != null) {
        try {
          final firstDate = DateTime.parse(first.date!);
          final secondDate = DateTime.parse(second.date!);
          final dateComparison = firstDate.compareTo(secondDate);
          if (dateComparison != 0) {
            return dateComparison;
          }
        } catch (_) {}
      }

      return (first.id ?? 0).compareTo(second.id ?? 0);
    });
    return sortedStocks;
  }

  List<Stock> _resolveReservationCandidates({
    required GetProduct product,
    Stock? selectedStock,
    List<int>? stockGroupIds,
    int? variantId,
  }) {
    final currentProduct = getProductById(product.productId ?? -1) ?? product;
    final currentStocks = filterStocksForVariant(
      currentProduct.stock ?? const <Stock>[],
      variantId,
    );
    final normalizedGroupIds = _normalizeStockGroupIds(stockGroupIds);

    if (normalizedGroupIds.length > 1) {
      final resolved = currentStocks
          .where((stock) =>
              stock.id != null && normalizedGroupIds.contains(stock.id))
          .toList();
      return _sortStocksForReservation(resolved);
    }

    if (selectedStock?.id == null) {
      return const <Stock>[];
    }

    final matchingStock =
        currentStocks.where((stock) => stock.id == selectedStock!.id);
    if (matchingStock.isNotEmpty) {
      return matchingStock.toList();
    }

    return <Stock>[selectedStock!];
  }

  void _mergeReservationDeltas(
    LocalCartItem item,
    List<StockReservation> deltas,
  ) {
    if (deltas.isEmpty) {
      item.stockDeducted = _sumStockReservations(item.stockReservations);
      return;
    }

    final merged = _cloneStockReservations(item.stockReservations);

    for (final delta in deltas) {
      final existingIndex = merged
          .indexWhere((reservation) => reservation.stockId == delta.stockId);
      if (existingIndex == -1) {
        merged.add(delta.copy());
      } else {
        merged[existingIndex].quantity += delta.quantity;
      }
    }

    merged.removeWhere((reservation) => reservation.quantity <= 0);
    item.stockReservations = merged;
    item.stockDeducted = _sumStockReservations(item.stockReservations);
  }

  List<StockReservation> _reserveStockForSelection({
    required GetProduct product,
    required num quantity,
    required String operation,
    Stock? selectedStock,
    List<int>? stockGroupIds,
    int? variantId,
  }) {
    if (!isStockEnabled || selectedStock == null || quantity <= 0) {
      return <StockReservation>[];
    }

    final reservations = <StockReservation>[];
    num remaining = quantity;

    final candidates = _resolveReservationCandidates(
      product: product,
      selectedStock: selectedStock,
      stockGroupIds: stockGroupIds,
      variantId: variantId,
    );

    for (final candidate in candidates) {
      if (remaining <= 0) {
        break;
      }

      final rawAvailable = candidate.quantity ?? 0;
      // For non-decimal units (PCS/PC/...) a batch can only contribute whole
      // units, so floor its usable quantity. This prevents a fractional batch
      // (e.g. 1.3) from emitting a decimal reservation line while splitting.
      final availableQuantity =
          normalizeQuantityForUnit(rawAvailable, product.unit);
      if (availableQuantity <= 0) {
        continue;
      }

      final requestedQuantity =
          remaining > availableQuantity ? availableQuantity : remaining;
      final actualChange = _updateStockQuantityInternal(
        candidate,
        -requestedQuantity,
        operation,
      );
      final reservedQuantity = actualChange.abs();

      if (reservedQuantity > 0 && candidate.id != null) {
        reservations.add(
          StockReservation(
            stockId: candidate.id!,
            quantity: reservedQuantity,
          ),
        );
        remaining -= reservedQuantity;
      }
    }

    if (remaining > 0) {
      debugPrint(
          '📦 Incomplete stock reservation: $remaining requested units remain.');
    }

    // Mirror the reserved amount onto the cached variant quantity so the picker
    // reflects the offline sale immediately.
    final reserved = quantity - remaining;
    if (reserved > 0) {
      _adjustVariantQuantity(product.productId, variantId, -reserved);
    }

    return reservations;
  }

  num _restoreStockReservations(
    LocalCartItem item,
    num quantity,
    String operation,
  ) {
    if (!isStockEnabled || quantity <= 0) {
      return 0;
    }

    final workingReservations = item.stockReservations.isNotEmpty
        ? _cloneStockReservations(item.stockReservations)
        : _legacyStockReservations(item.selectedStock, item.stockDeducted);

    num remaining = quantity;

    for (int index = workingReservations.length - 1;
        index >= 0 && remaining > 0;
        index--) {
      final reservation = workingReservations[index];
      if (reservation.quantity <= 0) {
        continue;
      }

      final requestedRestore =
          reservation.quantity > remaining ? remaining : reservation.quantity;
      final actualRestore = _updateStockQuantityInternal(
        Stock(id: reservation.stockId),
        requestedRestore,
        operation,
      );

      if (actualRestore > 0) {
        reservation.quantity -= actualRestore;
        remaining -= actualRestore;
      }
    }

    workingReservations.removeWhere((reservation) => reservation.quantity <= 0);
    item.stockReservations = workingReservations;
    item.stockDeducted = _sumStockReservations(item.stockReservations);

    // Restore the cached variant quantity by the amount actually returned to
    // stock so the picker stays consistent with the reserve path.
    final restored = quantity - remaining;
    if (restored > 0) {
      _adjustVariantQuantity(item.product.productId, item.variantId, restored);
    }

    return quantity - remaining;
  }

  List<StockReservation> _reapplySavedReservations(
    LocalCartItem item,
    String operation,
  ) {
    if (!isStockEnabled || item.selectedStock == null) {
      return _cloneStockReservations(item.stockReservations);
    }

    final sourceReservations = item.stockReservations.isNotEmpty
        ? item.stockReservations
        : _legacyStockReservations(item.selectedStock, item.stockDeducted);

    if (sourceReservations.isNotEmpty) {
      final reappliedReservations = <StockReservation>[];
      num reappliedTotal = 0;
      for (final reservation in sourceReservations) {
        final actualChange = _updateStockQuantityInternal(
          Stock(id: reservation.stockId),
          -reservation.quantity,
          operation,
        );
        final reservedQuantity = actualChange.abs();
        if (reservedQuantity > 0) {
          reappliedTotal += reservedQuantity;
          reappliedReservations.add(
            StockReservation(
              stockId: reservation.stockId,
              quantity: reservedQuantity,
            ),
          );
        }
      }
      if (reappliedTotal > 0) {
        _adjustVariantQuantity(
            item.product.productId, item.variantId, -reappliedTotal);
      }
      return reappliedReservations;
    }

    return _reserveStockForSelection(
      product: item.product,
      quantity: item.quantity,
      selectedStock: item.selectedStock,
      stockGroupIds: item.stockGroupIds,
      operation: operation,
      variantId: item.variantId,
    );
  }

  int _findCartItemIndex(
    int productId, {
    Stock? selectedStock,
    List<int>? stockGroupIds,
    int? saleUnitId,
    int? variantId,
  }) {
    final normalizedIncomingGroupIds = _normalizeStockGroupIds(stockGroupIds);

    return _cartItems.indexWhere((item) {
      if (item.product.productId != productId) {
        return false;
      }

      if (item.saleUnitId != saleUnitId) {
        return false;
      }

      if (item.variantId != variantId) {
        return false;
      }

      if (normalizedIncomingGroupIds.isNotEmpty) {
        if (item.stockGroupIds.isNotEmpty) {
          // Collapse onto the existing line when both refer to the same pricing
          // group. Matching on the pricing signature (not the exact raw id set)
          // keeps the line intact as FEFO depletion shrinks each add's
          // stockGroupIds. Falls back to id-set equality if a key is missing.
          final incomingKey = _stockGroupingKeyForStock(selectedStock);
          final itemKey = _stockGroupingKeyForStock(item.selectedStock);
          if (incomingKey != null && itemKey != null) {
            return incomingKey == itemKey;
          }
          return _stockGroupIdsEqual(
              item.stockGroupIds, normalizedIncomingGroupIds);
        }

        return item.selectedStock?.id == selectedStock?.id;
      }

      if (item.stockGroupIds.isNotEmpty) {
        return item.selectedStock?.id == selectedStock?.id;
      }

      return item.selectedStock?.id == selectedStock?.id ||
          (item.selectedStock == null && selectedStock == null);
    });
  }

  List<Map<String, dynamic>> buildOrderItemsPayload() {
    return buildOrderItemsPayloadFrom(_cartItems);
  }

  static List<Map<String, dynamic>> buildOrderItemsPayloadFrom(
      List<LocalCartItem> cartItems) {
    final items = <Map<String, dynamic>>[];

    for (final item in cartItems) {
      final positiveReservations = item.stockReservations
          .where((reservation) => reservation.quantity > 0)
          .toList(growable: false);
      final reservedQuantity = positiveReservations.fold<num>(
        0,
        (sum, reservation) => sum + reservation.quantity,
      );
      final unreservedQuantity = item.quantity - reservedQuantity;

      for (var index = 0; index < positiveReservations.length; index++) {
        final reservation = positiveReservations[index];
        final isLastReservation = index == positiveReservations.length - 1;

        // When negative stock is supported, charge an oversold remainder to
        // the final batch used by the allocator instead of emitting a
        // stock_id:null line. Combining before unit conversion also lets a
        // partial reservation plus its overflow become a whole PACK/CASE.
        final baseQuantity = isLastReservation && unreservedQuantity > 0
            ? reservation.quantity + unreservedQuantity
            : reservation.quantity;

        final payloadQuantity = item.canUseSaleUnitPayloadFor(baseQuantity)
            ? item.toDisplayQuantity(baseQuantity)
            // Base-unit line: guard against fractional reservations on
            // non-decimal units (e.g. legacy persisted 1.3 splits).
            : normalizeQuantityForUnit(baseQuantity, item.product.unit);
        final payloadPrice = item.canUseSaleUnitPayloadFor(baseQuantity)
            ? item.toDisplayAmount(item.price)
            : item.price;
        final payloadMrp = item.canUseSaleUnitPayloadFor(baseQuantity)
            ? item.toDisplayAmount(item.mrp)
            : item.mrp;

        items.add({
          'product_id': item.product.productId,
          'quantity': payloadQuantity,
          'price': payloadPrice,
          'mrp': payloadMrp,
          'stock_id': reservation.stockId,
          if (item.canUseSaleUnitPayloadFor(baseQuantity)) ...{
            'sale_unit_id': item.saleUnitId,
            'product_sale_unit_id': item.saleUnitId,
          },
          if (item.variantId != null) 'product_variant_id': item.variantId,
          'warranty_enabled': item.warrantyEnabled,
        });
      }

      if (positiveReservations.isEmpty) {
        final baseQuantity = item.quantity;
        final canUseSaleUnitPayload =
            item.canUseSaleUnitPayloadFor(baseQuantity);

        items.add({
          'product_id': item.product.productId,
          'quantity': canUseSaleUnitPayload
              ? item.toDisplayQuantity(baseQuantity)
              : normalizeQuantityForUnit(baseQuantity, item.product.unit),
          'price': canUseSaleUnitPayload
              ? item.toDisplayAmount(item.price)
              : item.price,
          'mrp':
              canUseSaleUnitPayload ? item.toDisplayAmount(item.mrp) : item.mrp,
          'stock_id': item.selectedStock?.id,
          if (canUseSaleUnitPayload) ...{
            'sale_unit_id': item.saleUnitId,
            'product_sale_unit_id': item.saleUnitId,
          },
          if (item.variantId != null) 'product_variant_id': item.variantId,
          'warranty_enabled': item.warrantyEnabled,
        });
      }
    }

    return items.where((item) {
      final quantity = item['quantity'];
      return quantity is num ? quantity > 0 : false;
    }).toList();
  }

  void _rebuildBarcodeIndex() {
    _productsByBarcode.clear();

    for (final product in _products) {
      _indexProductBarcode(product.barcode, product);
      for (final saleUnit in product.saleUnits ?? const <SaleUnit>[]) {
        _indexProductBarcode(saleUnit.barcode, product);
      }
      for (final variant in product.variants ?? const <ProductVariant>[]) {
        if (!variant.active) continue;
        _indexProductBarcode(variant.barcode, product);
      }
    }
  }

  void _indexProductBarcode(String? rawBarcode, GetProduct product) {
    final barcode = _normalizeBarcode(rawBarcode);
    if (barcode.isEmpty) {
      return;
    }

    final existing = _productsByBarcode[barcode];
    if (existing == null) {
      _productsByBarcode[barcode] = <GetProduct>[product];
      return;
    }

    final alreadyIndexed =
        existing.any((item) => item.productId == product.productId);
    if (!alreadyIndexed) {
      existing.add(product);
    }
  }

  /// Binds [_confirmedOrdersBox] synchronously when the box is already open
  /// (the normal case: main.dart opens it before the app starts).
  bool _bindConfirmedOrdersBoxIfOpen() {
    if (_isConfirmedBoxInitialized) return true;
    if (!Hive.isBoxOpen('confirmed_orders')) return false;
    try {
      _confirmedOrdersBox = Hive.box<HiveSavedOrder>('confirmed_orders');
      _isConfirmedBoxInitialized = true;
      return true;
    } catch (e) {
      debugPrint("Error binding confirmed orders box: $e");
      return false;
    }
  }

  /// Binds [_confirmedOrdersBox], opening it if needed, without touching the
  /// in-memory list, so it is safe to call from inside a queued write.
  Future<bool> _ensureConfirmedOrdersBox() async {
    if (_bindConfirmedOrdersBoxIfOpen()) return true;
    try {
      _confirmedOrdersBox =
          await Hive.openBox<HiveSavedOrder>('confirmed_orders');
      _isConfirmedBoxInitialized = true;
      return true;
    } catch (e) {
      debugPrint("Error initializing confirmed orders box: $e");
      _isConfirmedBoxInitialized = false;
      return false;
    }
  }

  // Initialize the confirmed orders box safely and load what it holds.
  //
  // When the box is already open this completes synchronously inside the
  // constructor. That matters: an order confirmed right after construction
  // must be appended to a list that already holds the persisted orders, or a
  // late reload would drop it from memory.
  Future<void> _initConfirmedOrdersBox() async {
    if (_bindConfirmedOrdersBoxIfOpen()) {
      _loadConfirmedOrdersFromHive();
      return;
    }
    if (await _ensureConfirmedOrdersBox()) {
      _loadConfirmedOrdersFromHive();
    }
  }

  // Load confirmed orders from Hive
  void _loadConfirmedOrdersFromHive() {
    if (!_isConfirmedBoxInitialized) return;

    _confirmedOrders.clear();
    try {
      for (var hiveSavedOrder in _confirmedOrdersBox.values) {
        final orderItems =
            hiveSavedOrder.items.map(_buildLocalCartItemFromHive).toList();

        _confirmedOrders.add(SavedOrder(
          id: hiveSavedOrder.id,
          orderNumber: hiveSavedOrder.orderNumber,
          items: orderItems,
          customerName: hiveSavedOrder.customerName,
          customerPhone: hiveSavedOrder.customerPhone,
          comment: hiveSavedOrder.comment,
          createdAt: hiveSavedOrder.createdAt,
          total: hiveSavedOrder.total,
          deliveryMethod: hiveSavedOrder.deliveryMethod,
          // Load new API-compatible fields
          customerId: hiveSavedOrder.customerId,
          paymentMethod: hiveSavedOrder.paymentMethod,
          paidAmount: hiveSavedOrder.paidAmount,
          balanceAmount: hiveSavedOrder.balanceAmount,
          transactionId: hiveSavedOrder.transactionId,
          couponId: hiveSavedOrder.couponId,
          deliveryMethodId: hiveSavedOrder.deliveryMethodId,
          carNumber: hiveSavedOrder.carNumber,
          status: hiveSavedOrder.status,
          deliveryDate: hiveSavedOrder.deliveryDate, // Restore delivery date
          deliveryTime: hiveSavedOrder.deliveryTime, // Restore delivery time
          flatDiscount: hiveSavedOrder.flatDiscount,
          percentageDiscount: hiveSavedOrder.percentageDiscount,

          toCustomerCredit: hiveSavedOrder.toCustomerCredit,
          alternatePhone: hiveSavedOrder.alternatePhone,
          tableId: hiveSavedOrder.tableId,
          address: hiveSavedOrder.address,
          deliveryCharge: hiveSavedOrder.deliveryCharge,
          customerVatNumber: hiveSavedOrder.customerVatNumber,
          customerCrNumber: hiveSavedOrder.customerCrNumber,
          customerType: hiveSavedOrder.customerType,
        ));
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading confirmed orders: $e");
    }
  }

  // Save confirmed orders to Hive.
  //
  // Keyed by order id and written through the persistence queue: a confirmed
  // order is an unsynced sale, so there must never be a moment where the box
  // has been cleared but the rows are not yet back on disk.
  void _saveConfirmedOrdersToHive() {
    final snapshots = <String, HiveSavedOrder>{};
    try {
      for (var order in _confirmedOrders) {
        final hiveItems = order.items.map(_buildHiveCartItem).toList();

        snapshots[order.id] = HiveSavedOrder(
          id: order.id,
          orderNumber: order.orderNumber,
          items: hiveItems,
          customerName: order.customerName,
          customerPhone: order.customerPhone,
          comment: order.comment,
          createdAt: order.createdAt,
          total: order.total,
          deliveryMethod: order.deliveryMethod,
          // Save new API-compatible fields
          customerId: order.customerId,
          paymentMethod: order.paymentMethod,
          paidAmount: order.paidAmount,
          balanceAmount: order.balanceAmount,
          transactionId: order.transactionId,
          couponId: order.couponId,
          deliveryMethodId: order.deliveryMethodId,
          carNumber: order.carNumber,
          status: order.status,
          deliveryDate: order.deliveryDate,
          deliveryTime: order.deliveryTime,
          flatDiscount: order.flatDiscount,
          percentageDiscount: order.percentageDiscount,

          toCustomerCredit: order.toCustomerCredit,
          tableId: order.tableId,
          alternatePhone: order.alternatePhone,
          address: order.address,
          deliveryCharge: order.deliveryCharge,
          customerVatNumber: order.customerVatNumber,
          customerCrNumber: order.customerCrNumber,
          customerType: order.customerType,
        );
      }
    } catch (e) {
      debugPrint("Error serializing confirmed orders: $e");
      return;
    }

    _enqueuePersistence('save confirmed orders', () async {
      if (!await _ensureConfirmedOrdersBox()) {
        throw StateError('confirmed_orders box is not available');
      }
      if (snapshots.isNotEmpty) {
        await _confirmedOrdersBox.putAll(snapshots);
      }
      // Removes deleted orders and any legacy auto-increment rows written by
      // older builds, which are now superseded by their id-keyed copies.
      final staleKeys = _confirmedOrdersBox.keys
          .where((key) => !snapshots.containsKey(key))
          .toList(growable: false);
      if (staleKeys.isNotEmpty) {
        await _confirmedOrdersBox.deleteAll(staleKeys);
      }
    });
  }

  // Load products from Hive.
  //
  // Decodes the catalog in chunks. The first chunk runs synchronously inside
  // the constructor, so a small box (tests, tiny tenants) is fully loaded
  // before the constructor returns, exactly as before. Larger boxes yield to
  // the event loop between chunks so a 30k catalog cannot freeze the window,
  // and the finished list is swapped in atomically at the end.
  Future<void> _hydrateProductsFromHive() async {
    final startEpoch = _catalogEpoch;
    final initialList = _products;
    final decoded = <GetProduct>[];
    final seenIds = <int, int>{};
    var legacyKeyedRows = 0;
    var unreadableRows = 0;

    try {
      final boxLen = _productsBox.length;
      debugPrint(
          "📦 [Hive] Loading products from box 'products' (len=$boxLen)...");
      final keys = _productsBox.keys.toList(growable: false);

      for (var offset = 0; offset < keys.length; offset += _catalogChunkSize) {
        if (offset > 0) {
          await _yieldToEventLoop();
          if (_catalogEpoch != startEpoch) {
            debugPrint(
                '📦 [Hive] Catalog replaced during hydration; discarding stale rows');
            _isHydrated = true;
            return;
          }
        }

        final end = offset + _catalogChunkSize > keys.length
            ? keys.length
            : offset + _catalogChunkSize;
        for (final key in keys.sublist(offset, end)) {
          final hiveProduct = _productsBox.get(key);
          if (hiveProduct == null) continue;
          GetProduct product;
          try {
            product = GetProduct.fromJson(
              json.decode(hiveProduct.serializedData.value),
            );
          } catch (error) {
            // One damaged row must not take the whole catalog down.
            unreadableRows++;
            debugPrint(
                '⚠️ [Hive] Skipping unreadable product row $key: $error');
            continue;
          }

          final id = product.productId;
          if (id == null) {
            decoded.add(product);
            continue;
          }
          if (key != id) {
            legacyKeyedRows++;
          }
          final existingIndex = seenIds[id];
          if (existingIndex != null) {
            // Duplicate rows can only come from legacy auto-increment keys.
            // Prefer the latest row; the id-keyed rewrite below removes the rest.
            decoded[existingIndex] = product;
          } else {
            seenIds[id] = decoded.length;
            decoded.add(product);
          }
        }
      }
    } catch (e) {
      debugPrint("❌ [Hive] Error loading products from box: $e");
    }

    if (_catalogEpoch != startEpoch) {
      debugPrint(
          '📦 [Hive] Catalog replaced during hydration; discarding stale rows');
      _isHydrated = true;
      return;
    }

    // Anything added in place while hydration was in flight (for example a
    // product created right after launch) must survive the swap.
    if (identical(_products, initialList) && initialList.isNotEmpty) {
      for (final product in initialList) {
        final id = product.productId;
        final existingIndex = id == null ? null : seenIds[id];
        if (existingIndex != null) {
          decoded[existingIndex] = product;
        } else {
          decoded.add(product);
        }
      }
    }

    _products = decoded;
    _filteredProducts = List.from(_products);
    _rebuildBarcodeIndex();
    _updatePagination();
    _isHydrated = true;
    debugPrint(
        "✅ [Hive] Loaded products into provider: total=${_products.length}, filtered=${_filteredProducts.length}, legacyKeyed=$legacyKeyedRows, unreadable=$unreadableRows");

    if (legacyKeyedRows > 0 || unreadableRows > 0) {
      // One-time migration to product-id keys (and cleanup of rows that no
      // longer decode). Runs through the ordered queue like every other write.
      debugPrint(
          '🔁 [Hive] Rewriting products box with product-id keys (legacy rows: $legacyKeyedRows)');
      _saveProductsToHive();
    }
    notifyListeners();
  }

  // Load cart items from Hive
  void _loadCartFromHive() {
    _cartItems.clear();
    for (final entry in _cartItemsBox.toMap().entries) {
      try {
        _cartItems.add(_buildLocalCartItemFromHive(entry.value));
      } catch (error, stackTrace) {
        // One damaged offline row must not prevent every other cart line from
        // loading. Keep the row for diagnostics/recovery; a later successful
        // cart mutation will remove it as a stale key.
        debugPrint(
            'Skipping unreadable Hive cart row at key ${entry.key}: $error');
        debugPrint('$stackTrace');
      }
    }
    notifyListeners();
  }

  // Load saved orders from Hive
  void _loadSavedOrdersFromHive() {
    _savedOrders.clear();
    debugPrint(
        "📥 [Hive] Loading saved orders from 'saved_orders' box (len=${_savedOrdersBox.length})...");
    int idx = 0;
    for (var hiveSavedOrder in _savedOrdersBox.values) {
      idx++;
      final orderItems =
          hiveSavedOrder.items.map(_buildLocalCartItemFromHive).toList();

      final savedOrder = SavedOrder(
        id: hiveSavedOrder.id,
        orderNumber: hiveSavedOrder.orderNumber,
        items: orderItems,
        customerName: hiveSavedOrder.customerName,
        customerPhone: hiveSavedOrder.customerPhone,
        comment: hiveSavedOrder.comment,
        createdAt: hiveSavedOrder.createdAt,
        total: hiveSavedOrder.total,
        deliveryMethod: hiveSavedOrder.deliveryMethod,
        // Load new API-compatible fields
        customerId: hiveSavedOrder.customerId,
        paymentMethod: hiveSavedOrder.paymentMethod,
        paidAmount: hiveSavedOrder.paidAmount,
        balanceAmount: hiveSavedOrder.balanceAmount,
        transactionId: hiveSavedOrder.transactionId,
        couponId: hiveSavedOrder.couponId,
        deliveryMethodId: hiveSavedOrder.deliveryMethodId,
        carNumber: hiveSavedOrder.carNumber,
        status: hiveSavedOrder.status,
        deliveryDate: hiveSavedOrder.deliveryDate, // Restore delivery date
        deliveryTime: hiveSavedOrder.deliveryTime, // Restore delivery time
        flatDiscount: hiveSavedOrder.flatDiscount,
        percentageDiscount: hiveSavedOrder.percentageDiscount,
        toCustomerCredit: hiveSavedOrder.toCustomerCredit,

        tableId: hiveSavedOrder.tableId,
        alternatePhone: hiveSavedOrder.alternatePhone,
        address: hiveSavedOrder.address,
        deliveryCharge: hiveSavedOrder.deliveryCharge,
        customerVatNumber: hiveSavedOrder.customerVatNumber,
        customerCrNumber: hiveSavedOrder.customerCrNumber,
        customerType: hiveSavedOrder.customerType,
      );
      _savedOrders.add(savedOrder);
      debugPrint(
          "  #$idx ↪️ Loaded SavedOrder id=${savedOrder.id}, num=${savedOrder.orderNumber}, status=${savedOrder.status}, tableId=${savedOrder.tableId}, items=${savedOrder.items.length}");
    }
    notifyListeners();
  }

  // Save the whole catalog to Hive.
  //
  // Only wholesale replacements (full sync, realtime apply, key migration,
  // reset) should call this. Cart and stock adjustments touch one or two
  // products and go through [_flushDirtyProducts] / [_saveProductToHive],
  // which write single keyed rows instead of re-encoding 30k products.
  void _saveProductsToHive() {
    _persistProducts(_products, pruneOthers: true);
  }

  /// Upserts [products] into the products box keyed by product id and deletes
  /// [removedIds]. With [pruneOthers] every key not written here is deleted
  /// too, which turns the call into a full catalog replacement.
  ///
  /// The box is never truncated: rows are upserted first and stale keys are
  /// removed afterwards, so it holds a complete catalog at every instant and a
  /// process kill mid-write (Task Manager, power loss) cannot leave it empty.
  /// JSON encoding is chunked with yields so a full rewrite of a large catalog
  /// cannot block the UI thread long enough for Windows to flag the window.
  void _persistProducts(
    List<GetProduct> products, {
    Iterable<int> removedIds = const <int>[],
    bool pruneOthers = false,
  }) {
    final snapshot = List<GetProduct>.of(products);
    final removed = removedIds.toList(growable: false);
    final label = pruneOthers
        ? 'save products'
        : 'save ${snapshot.length} product(s), remove ${removed.length}';

    _enqueuePersistence(label, () async {
      final rows = <dynamic, HiveProduct>{};
      final unkeyed = <HiveProduct>[];

      for (var offset = 0;
          offset < snapshot.length;
          offset += _catalogChunkSize) {
        if (offset > 0) {
          await _yieldToEventLoop();
        }
        final end = offset + _catalogChunkSize > snapshot.length
            ? snapshot.length
            : offset + _catalogChunkSize;
        for (final product in snapshot.sublist(offset, end)) {
          try {
            final row = _buildHiveProduct(product);
            final id = product.productId;
            if (id != null) {
              rows[id] = row;
            } else if (pruneOthers) {
              unkeyed.add(row);
            } else {
              debugPrint(
                  'Skipping Hive upsert for a product without an id (${product.productName})');
            }
          } catch (e) {
            debugPrint(
                "Failed to serialize productId=${product.productId} for Hive: $e");
          }
        }
      }

      if (rows.isNotEmpty) {
        await _productsBox.putAll(rows);
      }
      final keep = <dynamic>{...rows.keys};
      if (unkeyed.isNotEmpty) {
        keep.addAll(await _productsBox.addAll(unkeyed));
      }

      final Iterable<dynamic> stale = pruneOthers
          ? _productsBox.keys.where((key) => !keep.contains(key))
          : removed.where(
              (key) => !keep.contains(key) && _productsBox.containsKey(key));
      final staleKeys = stale.toList(growable: false);
      if (staleKeys.isNotEmpty) {
        await _productsBox.deleteAll(staleKeys);
      }
    });
  }

  HiveProduct _buildHiveProduct(GetProduct product) {
    return HiveProduct(
      productId: product.productId,
      categoryId: product.categoryId,
      productName: product.productName,
      barcode: product.barcode,
      serializedData: HiveStringValue(json.encode(product.toJson())),
    );
  }

  void _saveProductToHive(GetProduct product) {
    if (product.productId == null) {
      // Cannot be keyed; fall back to a full rewrite so it is not lost.
      _saveProductsToHive();
      return;
    }
    _persistProducts(<GetProduct>[product]);
  }

  void _removeProductFromHive(int productId) {
    _persistProducts(const <GetProduct>[], removedIds: <int>[productId]);
  }

  void _markProductDirty(GetProduct? product) {
    final id = product?.productId;
    if (id != null) {
      _dirtyProductIds.add(id);
    }
  }

  /// Persists every product whose stock changed since the last flush as a
  /// single keyed row each. Replaces the old "rewrite the whole catalog after
  /// every cart tap" behaviour.
  void _flushDirtyProducts() {
    if (_dirtyProductIds.isEmpty) {
      return;
    }
    final ids = _dirtyProductIds.toList(growable: false);
    _dirtyProductIds.clear();

    final changed = <GetProduct>[];
    for (final id in ids) {
      final product = getProductById(id);
      if (product != null) {
        changed.add(product);
      }
    }
    if (changed.isNotEmpty) {
      _persistProducts(changed);
    }
  }

  // Save cart items to Hive
  void _saveCartToHive() {
    final sessionId = _cartSessionId;
    final snapshots = <String, HiveLocalCartItem>{
      for (final item in _cartItems) item.lineId: _buildHiveCartItem(item),
    };
    _enqueuePersistence('save cart', () async {
      if (snapshots.isNotEmpty) {
        await _cartItemsBox.putAll(snapshots);
      }
      final staleKeys = _cartItemsBox.keys
          .where((key) => !snapshots.containsKey(key))
          .toList(growable: false);
      if (staleKeys.isNotEmpty) {
        await _cartItemsBox.deleteAll(staleKeys);
      }
      // Persist the cart first: an interrupted handoff must never associate
      // the previous sale's items with a newly generated identity.
      await _cartItemsBox.flush();
      if (Hive.isBoxOpen('order_submissions')) {
        final recovery = Hive.box('order_submissions');
        await recovery.put('_active_cart_session', sessionId);
        await recovery.flush();
      }
    });
  }

  // Save orders to Hive
  void _saveSavedOrdersToHive() {
    final snapshots = _savedOrders.map((order) {
      return HiveSavedOrder(
        id: order.id,
        orderNumber: order.orderNumber,
        items: order.items.map(_buildHiveCartItem).toList(),
        customerName: order.customerName,
        customerPhone: order.customerPhone,
        comment: order.comment,
        createdAt: order.createdAt,
        total: order.total,
        deliveryMethod: order.deliveryMethod,
        // Save new API-compatible fields
        customerId: order.customerId,
        paymentMethod: order.paymentMethod,
        paidAmount: order.paidAmount,
        balanceAmount: order.balanceAmount,
        transactionId: order.transactionId,
        couponId: order.couponId,
        deliveryMethodId: order.deliveryMethodId,
        carNumber: order.carNumber,
        status: order.status,
        deliveryDate: order.deliveryDate,
        deliveryTime: order.deliveryTime,
        flatDiscount: order.flatDiscount,
        percentageDiscount: order.percentageDiscount,
        toCustomerCredit: order.toCustomerCredit,
        tableId: order.tableId,
        alternatePhone: order.alternatePhone,
        address: order.address,
        deliveryCharge: order.deliveryCharge,
        customerVatNumber: order.customerVatNumber,
        customerCrNumber: order.customerCrNumber,
        customerType: order.customerType,
      );
    }).toList();

    _enqueuePersistence('save orders', () async {
      await _savedOrdersBox.clear();
      if (snapshots.isNotEmpty) {
        await _savedOrdersBox.addAll(snapshots);
      }
    });
  }

  double get subTotalBeforeDiscount {
    double total = 0.0;
    for (var item in _cartItems) {
      total += (item.price ?? 0) * item.quantity;
    }
    return total;
  }

  double get cartTotal {
    double subTotal = 0.0;
    double totalTax = 0.0;

    // Calculate subtotal and extract tax from cart items
    // NOTE: Prices are TAX-INCLUSIVE, so tax is extracted for display purposes only
    for (var item in _cartItems) {
      final itemTotal = (item.price ?? 0) * item.quantity;
      subTotal += itemTotal;

      // Extract tax from the tax-inclusive price for display purposes
      // Formula: Tax = Price × TaxRate / (100 + TaxRate)
      final taxRate = item.taxRate ?? 0.0;
      if (taxRate > 0) {
        final extractedTax = itemTotal * taxRate / (100 + taxRate);
        totalTax += extractedTax;
      }
    }

    // Calculate discount amounts
    double flatDiscountAmount = _flatDiscount;
    double percentageDiscountAmount = (subTotal * _percentageDiscount / 100);
    double totalDiscount = flatDiscountAmount + percentageDiscountAmount;

    // Ensure discount doesn't exceed subtotal
    if (totalDiscount > subTotal) {
      totalDiscount = subTotal;

      // Update the stored discount values to reflect the capped amount
      // Prioritize flat discount first, then percentage
      if (flatDiscountAmount > 0) {
        _flatDiscount = subTotal;
        _percentageDiscount = 0.0;
      } else {
        // Adjust percentage to match the capped discount
        _percentageDiscount = (totalDiscount / subTotal) * 100;
      }
    }

    // Net Payable = SubTotal - Discount (tax is already included in prices)
    double netPayable = subTotal - totalDiscount;

    // For tax-inclusive pricing: Total = Net Payable (NOT adding tax again)
    double netTotal = netPayable;

    // Create a PriceSummary instance with discount details
    priceSummary = PriceSummary(
      discount: totalDiscount,
      netPayable: netPayable,
      subTotal: subTotal,
      totalTax: totalTax, // This is the extracted tax for display only
      netTotal: netTotal,
      flatDiscount: flatDiscountAmount,
      percentageDiscount: percentageDiscountAmount,
      originalSubTotal: subTotal,
    );

    return netTotal; // Return the final total (tax already included)
  }

  /// Sets the selected product and optionally the selected stock for product details.
  void callProductDetails(int productId, {Stock? selectedStock}) {
    GetProduct product = _products.firstWhere(
      (product) => product.productId == productId,
    );
    _selectedProduct = product;
    _selectedStock = selectedStock;
    notifyListeners();
  }

  /// Resets the selected product and stock.
  void resetSelectedProduct() {
    _selectedProduct = null;
    _selectedStock = null;
    notifyListeners();
  }

  /// Initializes the provider with a list of products.
  /// This should be called after a successful login and after fetching
  /// all products (possibly from a one-time API call or local cache).
  void initializeProducts(List<GetProduct> products) {
    _catalogEpoch++;
    _dirtyProductIds.clear();
    _products = products;
    // Initially, set filtered products same as the full list.
    _filteredProducts = List.from(_products);
    _rebuildBarcodeIndex();
    _saveProductsToHive();
    notifyListeners();
  }

  /// Replaces the authoritative catalog while preserving stock already
  /// reserved by this device's active cart.
  ///
  /// Server quantities do not know about local, unconfirmed reservations.
  /// Reapplying them here keeps a later cart removal from restoring stock on
  /// top of an unreduced server snapshot.
  ///
  /// When [changedProductIds] is given only those products (plus any whose
  /// stock was adjusted for cart reservations, plus deletions) are written to
  /// Hive. Without it the whole catalog is rewritten.
  Future<void> applyRealtimeCatalog(
    List<GetProduct> products, {
    required Set<int> deletedProductIds,
    Set<int>? changedProductIds,
  }) async {
    await hydrated;
    final touchedProductIds = <int>{};
    final authoritative = products
        .where((product) =>
            product.productId == null ||
            !deletedProductIds.contains(product.productId))
        .toList(growable: true);
    final productIndex = <int, int>{};
    final stockLocations = <int, ({int productIndex, int stockIndex})>{};

    for (var i = 0; i < authoritative.length; i++) {
      final product = authoritative[i];
      final id = product.productId;
      if (id != null) productIndex[id] = i;
      final stocks = product.stock ?? const <Stock>[];
      for (var j = 0; j < stocks.length; j++) {
        final stockId = stocks[j].id;
        if (stockId != null) {
          stockLocations[stockId] = (productIndex: i, stockIndex: j);
        }
      }
    }

    for (final cartItem in _cartItems) {
      final reservations = cartItem.stockReservations.isNotEmpty
          ? cartItem.stockReservations
          : _legacyStockReservations(
              cartItem.selectedStock,
              cartItem.stockDeducted,
            );
      for (final reservation in reservations) {
        final location = stockLocations[reservation.stockId];
        if (location == null || reservation.quantity <= 0) continue;
        final product = authoritative[location.productIndex];
        final stocks = List<Stock>.from(product.stock ?? const <Stock>[]);
        final stock = stocks[location.stockIndex];
        final adjusted = ((stock.quantity ?? 0) - reservation.quantity)
            .clamp(0, double.infinity);
        stocks[location.stockIndex] = stock.copyWith(quantity: adjusted);
        final variants = List<ProductVariant>.from(
          product.variants ?? const <ProductVariant>[],
        );
        final variantId = stock.productVariantId;
        if (variantId != null) {
          final variantIndex =
              variants.indexWhere((variant) => variant.id == variantId);
          if (variantIndex != -1) {
            final variant = variants[variantIndex];
            final adjustedVariant =
                ((variant.quantity ?? 0) - reservation.quantity).clamp(
              0,
              double.infinity,
            );
            variants[variantIndex] = variant.copyWith(
              quantity: adjustedVariant,
              availableQuantity: adjustedVariant,
            );
          }
        }
        authoritative[location.productIndex] = product.copyWith(
          stock: stocks,
          variants: variants,
        );
        final touchedId = product.productId;
        if (touchedId != null) touchedProductIds.add(touchedId);
      }
    }

    // Preserve reserved products in the catalog as conflict snapshots if the
    // server deleted them while they are still in the active cart.
    for (final cartItem in _cartItems) {
      final id = cartItem.product.productId;
      if (id != null &&
          deletedProductIds.contains(id) &&
          !productIndex.containsKey(id)) {
        authoritative.add(cartItem.product);
      }
    }

    _catalogEpoch++;
    _dirtyProductIds.clear();
    _products = authoritative;
    _filteredProducts = List<GetProduct>.from(_products);
    _rebuildBarcodeIndex();
    _updatePagination();

    if (changedProductIds == null) {
      _saveProductsToHive();
    } else {
      final byId = <int, GetProduct>{
        for (final product in _products)
          if (product.productId != null) product.productId!: product,
      };
      final upserts = <GetProduct>[];
      final removals = <int>[];
      for (final id in <int>{
        ...changedProductIds,
        ...touchedProductIds,
        ...deletedProductIds,
      }) {
        final product = byId[id];
        if (product != null) {
          upserts.add(product);
        } else {
          removals.add(id);
        }
      }
      if (upserts.isNotEmpty || removals.isNotEmpty) {
        _persistProducts(upserts, removedIds: removals);
      }
    }
    await flushPersistence();
    notifyListeners();
  }

  /// Merges a realtime delta into the current catalog, then delegates to the
  /// authoritative apply path so cart reservations and Hive persistence keep
  /// their existing behavior.
  Future<void> mergeRealtimeCatalog(
    List<GetProduct> changedProducts, {
    required Set<int> deletedProductIds,
  }) async {
    await hydrated;
    final merged = List<GetProduct>.from(_products);
    final indexById = <int, int>{};
    for (var i = 0; i < merged.length; i++) {
      final id = merged[i].productId;
      if (id != null) indexById[id] = i;
    }
    final changedProductIds = <int>{};
    for (final product in changedProducts) {
      final id = product.productId;
      if (id != null) changedProductIds.add(id);
      final index = id == null ? null : indexById[id];
      if (index == null) {
        merged.add(product);
        if (id != null) indexById[id] = merged.length - 1;
      } else {
        merged[index] = product;
      }
    }
    await applyRealtimeCatalog(
      merged,
      deletedProductIds: deletedProductIds,
      changedProductIds: changedProductIds,
    );
  }

  /// Fetch products from API with pagination
  Future<void> fetchProductsFromAPI({
    bool refresh = false,
    Function(int total, int current)? onProgress,
    bool sellableOnly = false,
  }) async {
    List<GetProduct> allProducts = [];
    final Set<int> deletedProductIds = {};
    int currentPage = 1;
    const int batchSize = 3; // Fetch 3 pages concurrently
    final prefsProvider = prefs_provider.SharedPreferenceProvider();
    final lastSyncRaw =
        refresh ? null : await prefsProvider.getLastProductSyncIso();
    final lastSyncIso = (lastSyncRaw == null || lastSyncRaw.isEmpty)
        ? null
        : DateHelper.normalizeToApiDateTime(lastSyncRaw);
    final syncEndIso = DateHelper.formatForApiDateTime();
    final requestedDelta = lastSyncIso != null && lastSyncIso.isNotEmpty;
    // A large box may still be decoding; the baseline decision must not be
    // taken against a half-loaded catalog.
    await hydrated;
    final hasLocalBaseline = _products.isNotEmpty;
    final useDelta = requestedDelta && hasLocalBaseline;
    int successResponses = 0;

    isLoading = true;
    notifyListeners();

    try {
      final swTotal = Stopwatch()..start();
      debugPrint(
          "🌐 [API] Starting batched product fetch (batch size: $batchSize)...");
      if (useDelta) {
        debugPrint(
            "🕒 [API] Delta sync enabled: updated_at_range=$lastSyncIso,$syncEndIso");
      } else if (requestedDelta && !hasLocalBaseline) {
        debugPrint(
            "♻️ [API] Delta sync marker exists but local product baseline is empty. Switching to full product sync.");
      }

      // Get API key from SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');
      String? accessToken = prefs.getString('access_token');
      final int? activeStoreId = prefs.getInt('active_store_id');
      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found. Please restart the app.");
      }

      if (accessToken == null || accessToken.isEmpty) {
        throw const HttpException(
            "Access token not found. Please login again.");
      }

      bool hasMorePages = true;

      while (hasMorePages) {
        // Create batch of page requests
        final batchStartPage = currentPage;
        final batchEndPage = currentPage + batchSize - 1;

        debugPrint(
            "🚀 [API] Fetching batch: pages $batchStartPage-$batchEndPage concurrently...");
        final swBatch = Stopwatch()..start();

        // Create list of futures for concurrent requests
        final futures = <Future<http.Response>>[];
        for (int page = batchStartPage; page <= batchEndPage; page++) {
          final queryParams = <String, String>{'page': page.toString()};
          if (activeStoreId != null) {
            queryParams['store_id'] = activeStoreId.toString();
          }
          if (useDelta) {
            queryParams['updated_at_range'] = "$lastSyncIso,$syncEndIso";
          }

          // Choose URL based on sellableOnly flag
          final urlString = sellableOnly
              ? '${APPUrl.getSellableProductUrl}?type=sellable'
              : APPUrl.getRawProductUrl;

          final baseUri = Uri.parse(urlString);
          final finalQueryParams =
              Map<String, dynamic>.from(baseUri.queryParameters)
                ..addAll(queryParams);

          final url = baseUri.replace(queryParameters: finalQueryParams);

          futures.add(http.get(url, headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
            'X-Tenant': apiKey,
          }));
        }

        // Wait for all requests in batch to complete
        final responses = await Future.wait(futures);
        swBatch.stop();
        debugPrint(
            "📦 [API] Batch completed in ${swBatch.elapsedMilliseconds}ms");

        // Process responses
        int emptyPageCount = 0;
        for (int i = 0; i < responses.length; i++) {
          final response = responses[i];
          final pageNum = batchStartPage + i;

          if (response.statusCode == 200) {
            successResponses++;
            dynamic jsonData;
            log(response.body);
            try {
              jsonData = json.decode(response.body);
            } catch (e) {
              debugPrint('❌ [API] JSON decode failed for page $pageNum: $e');
              continue;
            }

            GetProductModel getProductModel =
                GetProductModel.fromJson(jsonData);

            if (getProductModel.deletedProductIds != null) {
              deletedProductIds.addAll(getProductModel.deletedProductIds!);
            }

            final productsFetched = getProductModel.product?.length ?? 0;

            if (getProductModel.product == null ||
                getProductModel.product!.isEmpty) {
              emptyPageCount++;
              debugPrint('📭 [API] Page $pageNum is empty');
              continue;
            }

            allProducts.addAll(getProductModel.product!);
            debugPrint(
                '✅ [API] Page $pageNum: $productsFetched products (Total: ${allProducts.length})');

            if (onProgress != null && productsFetched > 0) {
              await onProgress(allProducts.length, productsFetched);
            }
          } else {
            debugPrint(
                '❌ [API] Page $pageNum failed: Status ${response.statusCode}');

            if (response.statusCode == 401 || response.statusCode == 403) {
              throw const HttpException("Unauthorized. Please login again.");
            }

            emptyPageCount++;
          }
        }

        // If all pages in batch were empty, stop fetching
        if (emptyPageCount == batchSize) {
          debugPrint('🛑 [API] All pages in batch were empty. Stopping fetch.');
          hasMorePages = false;
        } else {
          currentPage += batchSize;
        }
      }

      _catalogEpoch++;
      _dirtyProductIds.clear();
      if (useDelta) {
        if (allProducts.isNotEmpty) {
          final updatedProducts = List<GetProduct>.from(_products);
          final indexById = <int, int>{};
          for (int i = 0; i < updatedProducts.length; i++) {
            final id = updatedProducts[i].productId;
            if (id != null) {
              indexById[id] = i;
            }
          }

          final newProducts = <GetProduct>[];
          for (final product in allProducts) {
            final id = product.productId;
            final existingIndex = id == null ? null : indexById[id];
            if (existingIndex != null) {
              updatedProducts[existingIndex] = product;
            } else {
              newProducts.add(product);
            }
          }

          _products = [...newProducts, ...updatedProducts];
        }
      } else {
        _products = allProducts;
      }

      // Remove any products the server reported as deleted so local Hive
      // storage stays in sync (important for delta syncs).
      if (deletedProductIds.isNotEmpty) {
        final beforeCount = _products.length;
        _products = _products
            .where((p) =>
                p.productId == null || !deletedProductIds.contains(p.productId))
            .toList();
        debugPrint(
            "🗑️ [Sync] Removed ${beforeCount - _products.length} product(s) via deleted_product_ids (${deletedProductIds.length} id(s) reported)");
      }

      _filteredProducts = List.from(_products);
      _rebuildBarcodeIndex();
      _updatePagination();
      if (useDelta) {
        // Only the rows the server reported changed or deleted are written.
        _persistProducts(
          allProducts
              .where((p) =>
                  p.productId == null ||
                  !deletedProductIds.contains(p.productId))
              .toList(growable: false),
          removedIds: deletedProductIds,
        );
      } else {
        _saveProductsToHive();
      }
      if (successResponses > 0) {
        await prefsProvider.saveLastProductSyncIso(syncEndIso);
      }
      swTotal.stop();
      debugPrint(
          '✅ [API] All products loaded successfully. Total: ${_products.length} | Duration: ${swTotal.elapsedMilliseconds}ms');
      try {
        final hiveLen = _productsBox.length;
        debugPrint("📦 [Hive] Box 'products' now has $hiveLen entries");
      } catch (_) {}
    } catch (e) {
      debugPrint("❌ [API] Error fetching all products from API: $e");
    } finally {
      isLoading = false;
      notifyListeners();
      debugPrint(
          "ℹ️ [Provider] Product fetch complete. provider.products=${_products.length}, filtered=${_filteredProducts.length}");
    }
  }

  /// Delete a product via API and update local state
  Future<bool> deleteProductAPI(int productId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');
      String? accessToken = prefs.getString('access_token');

      if (apiKey == null || accessToken == null) {
        throw const HttpException(
            "Authentication details missing. Please login again.");
      }

      final url = Uri.parse(APPUrl.deleteProductUrl);
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
        body: json.encode({"product_id": productId.toString()}),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == true ||
            jsonData['status'] == 'success' ||
            jsonData['success'] == true) {
          // Remove from local list
          _products.removeWhere((p) => p.productId == productId);
          _filteredProducts.removeWhere((p) => p.productId == productId);

          // Rebuild barcode index and update pagination
          _rebuildBarcodeIndex();
          _updatePagination();

          // Drop the row from Hive
          _removeProductFromHive(productId);

          notifyListeners();
          return true;
        }
      }

      debugPrint(
          "❌ [API] Delete product failed: ${response.statusCode} - ${response.body}");
      return false;
    } catch (e) {
      debugPrint("❌ [API] Error deleting product: $e");
      return false;
    }
  }

  /// Updates pagination info based on filtered products
  void _updatePagination() {
    _totalPages = (_filteredProducts.length / _itemsPerPage).ceil();
    if (_totalPages < 1) _totalPages = 1;
    if (_currentPage > _totalPages) _currentPage = _totalPages;
  }

  /// Gets paginated products based on current page
  List<GetProduct> get paginatedProducts {
    if (_filteredProducts.isEmpty) {
      return [];
    }

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    if (startIndex >= _filteredProducts.length) {
      return [];
    }

    final endIndex = startIndex + _itemsPerPage;
    return _filteredProducts.sublist(
      startIndex,
      endIndex > _filteredProducts.length ? _filteredProducts.length : endIndex,
    );
  }

  /// Gets the starting serial number (from) for the current page
  int get paginationFrom {
    return ((_currentPage - 1) * _itemsPerPage) + 1;
  }

  /// Sets the current page
  void setPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      _currentPage = page;
      notifyListeners();
    }
  }

  /// Updates items per page
  void setItemsPerPage(int items) {
    if (items > 0) {
      _itemsPerPage = items;
      _updatePagination();
      notifyListeners();
    }
  }

  /// Modified listAllProducts to handle pagination
  void listAllProducts({
    int? categoryId,
    String? filterName,
    String? filterPrice,
    String? filterBarcode,
    String? filterHsnCode,
    String? filterCreatedBy,
    String? filterProperties,
    String? filterStore,
    String? filterSupplier,
    String? filterItemCode,
    int page = 1,
    bool sellableOnly = true, // Added but currently unused for local filtering
  }) {
    List<GetProduct> result = List.from(_products);

    if (categoryId != null && categoryId != 0) {
      result = result.where((p) => p.categoryId == categoryId).toList();
    }

    if (filterName != null && filterName.isNotEmpty) {
      result = ProductSearchHelper.search(result, filterName);
    }

    if (filterBarcode != null && filterBarcode.isNotEmpty) {
      result = ProductSearchHelper.searchBarcodes(result, filterBarcode);
    }

    // HSN Code filter - check both product level and stock level HSN codes
    if (filterHsnCode != null && filterHsnCode.isNotEmpty) {
      result = result
          .where((p) =>
              // Check product level HSN code
              (p.hsnCode != null &&
                  p.hsnCode!
                      .toLowerCase()
                      .contains(filterHsnCode.toLowerCase())) ||
              // Check stock level HSN codes
              (p.stock != null &&
                  p.stock!.any((stock) =>
                      stock.hsnCode != null &&
                      stock.hsnCode!
                          .toLowerCase()
                          .contains(filterHsnCode.toLowerCase()))))
          .toList();
    }

    if (filterPrice != null && filterPrice.isNotEmpty) {
      result = result.where((p) {
        // Convert product price to string for partial matching
        final priceString = p.price?.price?.toString() ?? '';

        // Check if the price string contains the filter text
        return priceString.contains(filterPrice);
      }).toList();
    }

    // Item Code filter
    if (filterItemCode != null && filterItemCode.isNotEmpty) {
      result = result
          .where((p) =>
              p.itemCode != null &&
              p.itemCode!.toLowerCase().contains(filterItemCode.toLowerCase()))
          .toList();
    }

    // Note: createdBy, properties, store, and supplier filters are not available in the GetProduct model
    // These filters are kept for API compatibility but won't affect the results

    _filteredProducts = result;
    _filteredProductsVersion++;
    _updatePagination();
    setPage(page);

    // Make sure UI updates by calling notifyListeners
    notifyListeners();

    // Debug info to help diagnose issues
    debugPrint(
        "Category filter applied: $categoryId - Products count: ${result.length}");
  }

  /// Searches through the filtered products using [query] on the product name.
  /// Returns the list of products matching the search criteria.
  List<GetProduct> searchProducts(String query) {
    if (query.isEmpty) {
      return _filteredProducts;
    }
    return ProductSearchHelper.search(_filteredProducts, query);
  }

  /// Adds a product to the local products list.
  void addProduct(GetProduct product) {
    debugPrint("🔍 ADDING PRODUCT TO LOCAL STORAGE:");
    debugPrint("  - Product ID: ${product.productId}");
    debugPrint("  - Product Name: ${product.productName}");
    debugPrint("  - Product Purchase Price: ${product.purchasePrice}");
    debugPrint("  - Product MRP: ${product.mrp}");
    debugPrint("  - Product Sale Price: ${product.price?.price}");
    debugPrint("  - Product Stock Count: ${product.stock?.length ?? 0}");

    if (product.stock != null && product.stock!.isNotEmpty) {
      debugPrint("  - Stock Details:");
      for (int i = 0; i < product.stock!.length; i++) {
        final stock = product.stock![i];
        debugPrint("    Stock $i:");
        debugPrint("      - Stock ID: ${stock.id}");
        debugPrint("      - Stock Purchase Price: ${stock.purchasePrice}");
        debugPrint("      - Stock Sale Price: ${stock.price}");
        debugPrint("      - Stock MRP: ${stock.mrp}");
        debugPrint("      - Stock Quantity: ${stock.quantity}");
      }
    } else {
      debugPrint("  - No stock information available");
    }

    // Check if the product already exists in the list
    int index = _products.indexWhere((p) => p.productId == product.productId);
    if (index == -1) {
      _products.insert(0, product);
      _filteredProducts.insert(0, product);
      _rebuildBarcodeIndex();
      _saveProductToHive(product);
      notifyListeners();
      debugPrint("✅ Product added to local storage successfully");
    } else {
      _products[index] = product;
      final filteredIndex =
          _filteredProducts.indexWhere((p) => p.productId == product.productId);
      if (filteredIndex == -1) {
        _filteredProducts.insert(0, product);
      } else {
        _filteredProducts[filteredIndex] = product;
      }
      _rebuildBarcodeIndex();
      _saveProductToHive(product);
      notifyListeners();
      debugPrint("✅ Product updated in local storage successfully");
    }

    debugPrint("📊 Total products in local storage: ${_products.length}");
  }

  /// Updates the filtered products with a new [filtered] list.
  void updateFilteredProducts(List<GetProduct> filtered) {
    _filteredProducts = filtered;
    notifyListeners();
  }

  /// Updates the stock quantity for a specific stock entry.
  /// Stock is clamped at 0 — it never goes negative.
  /// Returns the **actual** quantity change applied (may differ from
  /// [quantityChange] when clamping kicks in).
  num _updateStockQuantityInternal(
    Stock stock,
    num quantityChange,
    String operation, {
    bool persistProducts = false,
    bool notify = false,
  }) {
    if (!isStockEnabled) {
      debugPrint("📦 Stock management disabled - skipping stock update");
      return 0;
    }

    // Find and update the stock in the products list
    for (var product in _products) {
      if (product.stock != null) {
        for (int i = 0; i < product.stock!.length; i++) {
          if (product.stock![i].id == stock.id) {
            final currentStock = product.stock![i];
            final previousQuantity = currentStock.quantity ?? 0;
            final rawNewQuantity = previousQuantity + quantityChange;

            // Clamp: stock can never go below 0
            final num clampedQuantity = rawNewQuantity < 0 ? 0 : rawNewQuantity;
            final num actualChange = clampedQuantity - previousQuantity;

            debugPrint("📦 STOCK UPDATE:");
            debugPrint("  - Stock ID: ${stock.id}");
            debugPrint("  - Operation: $operation");
            debugPrint("  - Requested Change: $quantityChange");
            debugPrint("  - Previous Quantity: $previousQuantity");
            debugPrint("  - Raw New Quantity: $rawNewQuantity");
            debugPrint("  - Clamped Quantity: $clampedQuantity");
            debugPrint("  - Actual Change: $actualChange");

            if (rawNewQuantity < 0) {
              debugPrint(
                  "📦 Stock clamped at 0 (would have been $rawNewQuantity). Sale continues without further stock deduction.");
            }

            product.stock![i] =
                currentStock.copyWith(quantity: clampedQuantity);
            _markProductDirty(product);

            debugPrint(
                "📦 Updated stock in product list: ${product.productName}");

            if (persistProducts) {
              _flushDirtyProducts();
            }
            if (notify) {
              notifyListeners();
            }
            return actualChange;
          }
        }
      }
    }

    debugPrint("⚠️ Stock entry not found for update: ${stock.id}");
    return 0;
  }

  /// Keeps the cached [ProductVariant.quantity] in step with local stock
  /// movements so the variant picker's "Qty:" label and out-of-stock state stay
  /// fresh offline. [delta] is negative when selling and positive when
  /// restoring. No-op when [variantId] is null or the variant cannot be found.
  void _adjustVariantQuantity(int? productId, int? variantId, num delta) {
    if (!isStockEnabled || variantId == null || delta == 0) {
      return;
    }
    for (final product in _products) {
      if (product.productId != productId) {
        continue;
      }
      final variants = product.variants;
      if (variants == null) {
        return;
      }
      for (int i = 0; i < variants.length; i++) {
        if (variants[i].id == variantId) {
          final previous = variants[i].quantity ?? 0;
          final raw = previous + delta;
          final clamped = raw < 0 ? 0 : raw;
          variants[i] = variants[i].copyWith(quantity: clamped);
          _markProductDirty(product);
          return;
        }
      }
      return;
    }
  }

  /// Updates a specific stock entry within the products list
  void _updateProductStockInList(Stock updatedStock) {
    for (var product in _products) {
      if (product.stock != null) {
        for (int i = 0; i < product.stock!.length; i++) {
          if (product.stock![i].id == updatedStock.id) {
            product.stock![i] = updatedStock;
            debugPrint(
                "📦 Updated stock in product list: ${product.productName}");
            return;
          }
        }
      }
    }
  }

  /// Adds a [product] to the local cart with a specified [quantity].
  /// If the product already exists in the cart, its quantity is incremented.
  /// Optionally updates the price of the cart item if provided.
  /// Also handles stock deduction when stock management is enabled.
  bool addToCart({
    GetProduct? product,
    num? quantity = 1,
    double? price,
    double? mrp,
    int? productId,
    bool? isIncreamentUsingCompactQuantityControl = false,
    Stock? selectedStock,
    List<int>? stockGroupIds,
    bool markPriceAsManualOverride = false,
    int? saleUnitId,
    String? saleUnitName,
    double? saleUnitConversionRate,
    int? variantId,
    Map<String, dynamic>? variantAttributes,
    bool? warrantyEnabled,

    /// One-time approval from the billing flow. This does not change the
    /// tenant-level [allowOverselling] setting.
    bool allowOversellOverride = false,
  }) {
    debugPrint("🛒 ADD TO CART STARTED");
    debugPrint("Product: ${product?.productName}");
    debugPrint("Quantity: $quantity");
    debugPrint("Price: $price");
    debugPrint("MRP: $mrp");
    debugPrint("Product ID: $productId");
    debugPrint("Selected Stock: ${selectedStock?.id}");
    debugPrint("Stock Management Enabled: $isStockEnabled");

    if (productId != null) {
      product = getProductById(productId) ?? product;
    }

    if (product == null) {
      debugPrint("❌ Cannot add to cart: product is null");
      return false;
    }

    final cartQuantity = quantity ?? 1;
    final enforceStockLimit = !allowOverselling && !allowOversellOverride;
    if (cartQuantity <= 0) {
      debugPrint("❌ Cannot add to cart: quantity must be greater than zero");
      return false;
    }
    final normalizedStockGroupIds = selectedStock == null
        ? _normalizeStockGroupIds(stockGroupIds)
        : _expandCompatibleStockGroupIds(
            product: product,
            selectedStock: selectedStock,
            variantId: variantId,
            stockGroupIds: stockGroupIds,
          );

    if (isStockEnabled &&
        enforceStockLimit &&
        variantId != null &&
        selectedStock == null) {
      debugPrint(
          'Cannot add variant $variantId: no variant-scoped stock was selected');
      return false;
    }

    if (isStockEnabled && enforceStockLimit && selectedStock != null) {
      final availableQuantity = getAvailableQuantityForSelection(
        product: product,
        selectedStock: selectedStock,
        stockGroupIds: normalizedStockGroupIds,
        variantId: variantId,
      );
      if (availableQuantity < cartQuantity) {
        debugPrint(
            'Cannot add to cart: requested $cartQuantity but only $availableQuantity is available');
        return false;
      }
    }

    int index = _findCartItemIndex(
      product.productId!,
      selectedStock: selectedStock,
      stockGroupIds: normalizedStockGroupIds,
      saleUnitId: saleUnitId,
      variantId: variantId,
    );

    bool didMutateStock = false;

    if (index != -1) {
      debugPrint("📝 Product already in cart - updating quantity");

      final existingItem = _cartItems[index];
      if (normalizedStockGroupIds.isNotEmpty) {
        // Union so the line records every raw batch it has drawn from across
        // successive adds (earlier adds may have depleted some batches, leaving
        // later adds with a smaller id set for the same pricing group).
        existingItem.stockGroupIds = _normalizeStockGroupIds(
          <int>[...existingItem.stockGroupIds, ...normalizedStockGroupIds],
        );
      }

      // STOCK DEDUCTION: Deduct the additional quantity being added
      if (isStockEnabled && selectedStock != null) {
        final reservationDeltas = _reserveStockForSelection(
          product: product,
          quantity: cartQuantity,
          selectedStock: selectedStock,
          stockGroupIds: existingItem.stockGroupIds,
          operation: "ADD_TO_CART_INCREMENT",
          variantId: variantId,
        );
        _mergeReservationDeltas(existingItem, reservationDeltas);
        didMutateStock = reservationDeltas.isNotEmpty;
      }

      // If the product already exists in cart with the same stock, just update the quantity and price
      existingItem.quantity +=
          cartQuantity; // Increment by the specified quantity

      if (price != null) {
        if (markPriceAsManualOverride || !existingItem.isManualPriceOverride) {
          existingItem.price = price;
        }
        existingItem.isManualPriceOverride =
            existingItem.isManualPriceOverride || markPriceAsManualOverride;
        debugPrint("💰 Using explicit price: $price");
      }

      if (mrp != null) {
        existingItem.mrp = mrp;
        debugPrint("💰 Using explicit MRP: $mrp");
      }

      if (warrantyEnabled != null) {
        existingItem.warrantyEnabled = warrantyEnabled;
      }

      if (isIncreamentUsingCompactQuantityControl != true) {
        // Move this item to the beginning of the array
        final cartItem = _cartItems.removeAt(index);
        _cartItems.insert(0, cartItem);
      }

      final targetIndex =
          isIncreamentUsingCompactQuantityControl == true ? index : 0;
      _refreshCartItemPricing(
        _cartItems[targetIndex],
        selectedStock: selectedStock,
      );
    } else {
      debugPrint("🆕 Adding new product to cart");

      // STOCK DEDUCTION: Deduct quantity for new cart item
      List<StockReservation> initialStockReservations = <StockReservation>[];
      if (isStockEnabled && selectedStock != null) {
        initialStockReservations = _reserveStockForSelection(
          product: product,
          quantity: cartQuantity,
          selectedStock: selectedStock,
          stockGroupIds: normalizedStockGroupIds,
          operation: "ADD_TO_CART_NEW",
          variantId: variantId,
        );
        didMutateStock = initialStockReservations.isNotEmpty;
      }

      // Safely handle null product price when adding new cart item
      final double productPrice = price ??
          _resolveUnitPrice(
            product: product,
            quantity: cartQuantity,
            selectedStock: selectedStock,
            saleUnitId: saleUnitId,
            variantId: variantId,
          );
      final double productMrp = mrp ??
          _resolveMrp(
            product: product,
            selectedStock: selectedStock,
            variantId: variantId,
          );

      final double taxRate = _resolveCartTaxRate(
        product,
        selectedStock: selectedStock,
      );
      final double calculatedTax = _calculateTaxAmount(productPrice, taxRate);

      // Insert at the beginning of the array instead of appending
      _cartItems.insert(
          0,
          LocalCartItem(
            product: product,
            quantity: cartQuantity,
            price: productPrice,
            mrp: productMrp,
            taxRate: taxRate,
            taxAmount: calculatedTax,
            selectedStock: selectedStock,
            stockDeducted: _sumStockReservations(initialStockReservations),
            stockGroupIds: List<int>.from(normalizedStockGroupIds),
            stockReservations:
                _cloneStockReservations(initialStockReservations),
            isManualPriceOverride: markPriceAsManualOverride,
            warrantyEnabled: warrantyEnabled ?? false,
            saleUnitId: saleUnitId,
            saleUnitName: saleUnitName,
            saleUnitConversionRate: saleUnitConversionRate,
            variantId: variantId,
            variantAttributes: variantAttributes == null
                ? null
                : Map<String, dynamic>.from(variantAttributes),
          ));
      _clampManualCartItemToMinimumPrice(_cartItems.first);
    }

    resetSelectedProduct();
    if (didMutateStock) {
      _flushDirtyProducts();
    }
    _saveCartToHive();
    notifyListeners();

    debugPrint("✅ ADD TO CART COMPLETED");
    return true;
  }

  /// Changes the display sale unit for an existing cart line while preserving
  /// the canonical base quantity, base price, and stock reservations.
  bool changeCartItemSaleUnit(
    int productId,
    Stock? selectedStock, {
    List<int>? stockGroupIds,
    int? currentSaleUnitId,
    int? newSaleUnitId,
    String? newSaleUnitName,
    double? newSaleUnitConversionRate,
    int? variantId,
  }) {
    final currentIndex = _findCartItemIndex(
      productId,
      selectedStock: selectedStock,
      stockGroupIds: stockGroupIds,
      saleUnitId: currentSaleUnitId,
      variantId: variantId,
    );

    if (currentIndex == -1) {
      debugPrint(
          "Cart item not found; cannot change sale unit for productId=$productId");
      return false;
    }

    final targetHasSaleUnit = newSaleUnitId != null &&
        newSaleUnitConversionRate != null &&
        newSaleUnitConversionRate > 0;
    final targetSaleUnitId = targetHasSaleUnit ? newSaleUnitId : null;
    final targetSaleUnitName = targetHasSaleUnit ? newSaleUnitName : null;
    final targetSaleUnitRate =
        targetHasSaleUnit ? newSaleUnitConversionRate : null;

    final sourceItem = _cartItems[currentIndex];
    if (isStockEnabled && sourceItem.selectedStock != null) {
      sourceItem.stockGroupIds = _expandCompatibleStockGroupIds(
        product: sourceItem.product,
        selectedStock: sourceItem.selectedStock!,
        variantId: sourceItem.variantId,
        stockGroupIds: sourceItem.stockGroupIds,
      );
    }
    if (sourceItem.saleUnitId == targetSaleUnitId &&
        sourceItem.saleUnitName == targetSaleUnitName &&
        sourceItem.saleUnitConversionRate == targetSaleUnitRate) {
      return false;
    }

    final sourceDisplayQuantity = sourceItem.displayQuantity;
    final targetBaseQuantity = targetSaleUnitRate == null
        ? _normalizeCartQuantity(sourceDisplayQuantity)
        : _normalizeCartQuantity(sourceDisplayQuantity * targetSaleUnitRate);
    final quantityDifference = targetBaseQuantity - sourceItem.quantity;
    debugPrint('[UNIT_SWITCH] productId=$productId '
        'from=${sourceItem.saleUnitName ?? sourceItem.product.unit ?? 'base'} '
        'to=${targetSaleUnitName ?? sourceItem.product.unit ?? 'base'} '
        'displayQty=$sourceDisplayQuantity '
        'baseQty=${sourceItem.quantity}->$targetBaseQuantity '
        'rate=${sourceItem.saleUnitConversionRate ?? 1}->$targetSaleUnitRate');
    var didMutateStock = false;

    // A unit change can increase the base quantity, so validate the additional
    // requirement before mutating reservations.
    if (isStockEnabled &&
        sourceItem.selectedStock != null &&
        quantityDifference != 0) {
      if (quantityDifference > 0) {
        final availableQuantity = getAvailableQuantityForSelection(
          product: sourceItem.product,
          selectedStock: sourceItem.selectedStock,
          stockGroupIds: sourceItem.stockGroupIds,
          variantId: sourceItem.variantId,
        );
        if (!allowOverselling && availableQuantity < quantityDifference) {
          debugPrint(
              'Cannot change sale unit: requires $quantityDifference additional base units but only $availableQuantity is available');
          return false;
        }
        final reservationDeltas = _reserveStockForSelection(
          product: sourceItem.product,
          quantity: quantityDifference,
          selectedStock: sourceItem.selectedStock,
          stockGroupIds: sourceItem.stockGroupIds,
          operation: "CHANGE_CART_ITEM_SALE_UNIT_INCREASE",
          variantId: sourceItem.variantId,
        );
        _mergeReservationDeltas(sourceItem, reservationDeltas);
      } else {
        _restoreStockReservations(
          sourceItem,
          quantityDifference.abs(),
          "CHANGE_CART_ITEM_SALE_UNIT_DECREASE",
        );
      }
      didMutateStock = true;
    }

    sourceItem.quantity = targetBaseQuantity;

    final targetIndex = _findCartItemIndex(
      productId,
      selectedStock: selectedStock,
      stockGroupIds: sourceItem.stockGroupIds,
      saleUnitId: targetSaleUnitId,
      variantId: sourceItem.variantId,
    );

    if (targetIndex != -1 && targetIndex != currentIndex) {
      final targetItem = _cartItems[targetIndex];
      targetItem.quantity += sourceItem.quantity;
      _mergeReservationDeltas(targetItem, sourceItem.stockReservations);
      targetItem.comment ??= sourceItem.comment;
      _refreshCartItemPricing(targetItem);

      _cartItems.removeAt(currentIndex);
    } else {
      _cartItems[currentIndex] = LocalCartItem(
        lineId: sourceItem.lineId,
        product: sourceItem.product,
        quantity: sourceItem.quantity,
        price: sourceItem.price,
        mrp: sourceItem.mrp,
        taxRate: sourceItem.taxRate,
        taxAmount: sourceItem.taxAmount,
        selectedStock: sourceItem.selectedStock,
        stockDeducted: sourceItem.stockDeducted,
        stockGroupIds: List<int>.from(sourceItem.stockGroupIds),
        stockReservations:
            _cloneStockReservations(sourceItem.stockReservations),
        comment: sourceItem.comment,
        isManualPriceOverride: sourceItem.isManualPriceOverride,
        warrantyEnabled: sourceItem.warrantyEnabled,
        saleUnitId: targetSaleUnitId,
        saleUnitName: targetSaleUnitName,
        saleUnitConversionRate: targetSaleUnitRate,
        variantId: sourceItem.variantId,
        variantAttributes: sourceItem.variantAttributes == null
            ? null
            : Map<String, dynamic>.from(sourceItem.variantAttributes!),
      );
      _refreshCartItemPricing(_cartItems[currentIndex]);
      debugPrint('[UNIT_SWITCH] applied productId=$productId '
          'unit=${_cartItems[currentIndex].displayUnitName} '
          'baseQty=${_cartItems[currentIndex].quantity} '
          'basePrice=${_cartItems[currentIndex].price}');
    }

    if (didMutateStock) {
      _flushDirtyProducts();
    }
    _saveCartToHive();
    notifyListeners();
    return true;
  }

  /// Removes the product with [productId] from the local cart.
  /// Also restores stock quantity when stock management is enabled.
  List<LocalCartItem> getCartItems() {
    return _cartItems;
  }

  /// Updates the comment on a specific cart item by product ID and stock.
  void updateCartItemComment(
      int productId, Stock? selectedStock, String? comment,
      {List<int>? stockGroupIds, int? saleUnitId, int? variantId}) {
    final index = _findCartItemIndex(
      productId,
      selectedStock: selectedStock,
      stockGroupIds: stockGroupIds,
      saleUnitId: saleUnitId,
      variantId: variantId,
    );
    if (index != -1) {
      _cartItems[index].comment = comment;
      _saveCartToHive();
      notifyListeners();
    }
  }

  void removeFromCart(int productId, Stock? selectedStock,
      {List<int>? stockGroupIds, int? saleUnitId, int? variantId}) {
    debugPrint("🗑️ REMOVE FROM CART STARTED");
    debugPrint("Product ID: $productId");
    debugPrint("Selected Stock: ${selectedStock?.id}");
    debugPrint("Stock Management Enabled: $isStockEnabled");

    final index = _findCartItemIndex(
      productId,
      selectedStock: selectedStock,
      stockGroupIds: stockGroupIds,
      saleUnitId: saleUnitId,
      variantId: variantId,
    );

    if (index != -1) {
      final cartItem = _cartItems[index];
      final quantityToRestore = cartItem.stockDeducted;

      debugPrint(
          "📝 Found cart item - cart qty: ${cartItem.quantity}, stockDeducted: $quantityToRestore");

      // STOCK RESTORATION: Add back only what was actually deducted
      if (isStockEnabled && quantityToRestore > 0) {
        _restoreStockReservations(
            cartItem, quantityToRestore, "REMOVE_FROM_CART");
        _flushDirtyProducts();
      }

      _cartItems.removeAt(index);
      _saveCartToHive();
      notifyListeners();

      debugPrint("✅ REMOVE FROM CART COMPLETED");
    } else {
      debugPrint("⚠️ Cart item not found for removal");
    }
  }

  /// Minimum allowed sale price (in base units) for a pricing selection. Acts
  /// as a discount floor off the effective selling price, derived from two optional
  /// configurations:
  ///
  ///   • `min_margin_percentage` → percentage discount floor:
  ///       floor = sellingPrice × (1 − minMarginPercentage / 100)
  ///   • `min_margin_price`      → absolute discount floor (max reduction):
  ///       floor = sellingPrice − minMarginPrice
  ///
  /// When both are configured, the most restrictive (higher) floor wins.
  ///
  /// [referencePrice] can be supplied for open/manual-price products which have
  /// no configured selling price. Configured sale-unit, variant, wholesale,
  /// stock, and product prices still take precedence in that order.
  ///
  /// Returns `null` when no floor is configured (no/zero margins or no effective
  /// selling price), meaning the price may be lowered freely.
  double? minimumSalePriceForProduct(
    GetProduct product, {
    num quantity = 1,
    Stock? selectedStock,
    int? saleUnitId,
    int? variantId,
    double? referencePrice,
  }) {
    final sellingPrice = _resolveUnitPrice(
      product: product,
      quantity: quantity,
      selectedStock: selectedStock,
      fallbackPrice: referencePrice,
      saleUnitId: saleUnitId,
      variantId: variantId,
    );
    if (sellingPrice == null || sellingPrice <= 0) {
      return null;
    }

    final pct = _parseAmount(product.minMarginPercentage?.toString());
    final maxReduction = _parseAmount(product.minMarginPrice?.toString());

    double? floor;

    if (pct != null && pct > 0) {
      final pctFloor = sellingPrice * (1 - (pct / 100));
      floor = pctFloor;
    }

    if (maxReduction != null && maxReduction > 0) {
      final priceFloor = sellingPrice - maxReduction;
      // Most restrictive floor wins.
      floor = (floor == null)
          ? priceFloor
          : (priceFloor > floor ? priceFloor : floor);
    }

    if (floor == null) {
      return null;
    }

    return floor < 0 ? 0.0 : floor;
  }

  /// Minimum allowed base-unit price for the exact pricing context represented
  /// by a cart line.
  double? minimumSalePriceForCartItem(LocalCartItem item) {
    return minimumSalePriceForProduct(
      item.product,
      quantity: item.quantity,
      selectedStock: item.selectedStock,
      saleUnitId: item.saleUnitId,
      variantId: item.variantId,
      referencePrice: item.price,
    );
  }

  void updateItemPrice(int productId, Stock? selectedStock, double newPrice,
      {List<int>? stockGroupIds, int? saleUnitId, int? variantId}) {
    final index = _findCartItemIndex(
      productId,
      selectedStock: selectedStock,
      stockGroupIds: stockGroupIds,
      saleUnitId: saleUnitId,
      variantId: variantId,
    );

    if (index != -1) {
      _cartItems[index].price = newPrice;
      _cartItems[index].isManualPriceOverride = true;

      final double taxRate = _cartItems[index].taxRate ?? 0.0;
      _cartItems[index].taxAmount = (newPrice * taxRate) / (100 + taxRate);

      _saveCartToHive();
      notifyListeners();
    }
  }

  void updateItemMrp(int productId, Stock? selectedStock, double newMrp,
      {List<int>? stockGroupIds, int? saleUnitId, int? variantId}) {
    final index = _findCartItemIndex(
      productId,
      selectedStock: selectedStock,
      stockGroupIds: stockGroupIds,
      saleUnitId: saleUnitId,
      variantId: variantId,
    );

    if (index != -1) {
      _cartItems[index].mrp = newMrp;
      _saveCartToHive();
      notifyListeners();
    }
  }

  void updateItemTax(int productId, Stock? selectedStock, double newTaxRate,
      {List<int>? stockGroupIds, int? saleUnitId, int? variantId}) {
    final index = _findCartItemIndex(
      productId,
      selectedStock: selectedStock,
      stockGroupIds: stockGroupIds,
      saleUnitId: saleUnitId,
      variantId: variantId,
    );

    if (index != -1) {
      _cartItems[index].taxRate = newTaxRate;
      _cartItems[index].taxAmount =
          ((_cartItems[index].price ?? 0.0) * newTaxRate) / (100 + newTaxRate);
      _saveCartToHive();
      notifyListeners();
    }
  }

  void updateProductPricingInCart(
    int productId,
    double newPrice,
    double newMrp,
    double newTax, {
    GetProduct? updatedProduct,
  }) {
    debugPrint(
        "🔁 [CartUpdate] Start productId=$productId, newPrice=$newPrice, newMrp=$newMrp, newTax=$newTax, withSnapshot=${updatedProduct != null}");
    bool cartUpdated = false;
    int cartUpdatedCount = 0;
    for (int i = 0; i < _cartItems.length; i++) {
      final item = _cartItems[i];
      if (item.product.productId == productId) {
        final effectiveTax = _resolveCartTaxRate(
          updatedProduct ?? item.product,
          selectedStock: item.selectedStock,
          fallbackTaxRate: newTax,
        );
        final resolvedPrice = item.isManualPriceOverride
            ? (item.price ?? newPrice)
            : _resolveUnitPrice(
                product: updatedProduct ?? item.product,
                quantity: item.quantity,
                selectedStock: item.selectedStock,
                fallbackPrice: newPrice,
                saleUnitId: item.saleUnitId,
                variantId: item.variantId,
              );
        if (updatedProduct != null) {
          _cartItems[i] = LocalCartItem(
            lineId: item.lineId,
            product: updatedProduct,
            price: resolvedPrice,
            mrp: newMrp,
            taxRate: effectiveTax,
            taxAmount: _calculateTaxAmount(resolvedPrice, effectiveTax),
            quantity: item.quantity,
            selectedStock: item.selectedStock,
            stockDeducted: item.stockDeducted,
            stockGroupIds: List<int>.from(item.stockGroupIds),
            stockReservations: _cloneStockReservations(item.stockReservations),
            comment: item.comment,
            isManualPriceOverride: item.isManualPriceOverride,
            warrantyEnabled: item.warrantyEnabled,
            saleUnitId: item.saleUnitId,
            saleUnitName: item.saleUnitName,
            saleUnitConversionRate: item.saleUnitConversionRate,
            variantId: item.variantId,
            variantAttributes: item.variantAttributes == null
                ? null
                : Map<String, dynamic>.from(item.variantAttributes!),
          );
        } else {
          if (!item.isManualPriceOverride) {
            item.price = newPrice;
          }
          item.mrp = newMrp;
          item.taxRate = effectiveTax;
          item.taxAmount =
              _calculateTaxAmount(item.price ?? newPrice, effectiveTax);
        }
        cartUpdated = true;
        cartUpdatedCount++;
      }
    }

    bool savedOrdersUpdated = false;
    int savedOrderItemUpdatedCount = 0;
    for (var order in _savedOrders) {
      for (int i = 0; i < order.items.length; i++) {
        final orderItem = order.items[i];
        if (orderItem.product.productId == productId) {
          final effectiveTax = _resolveCartTaxRate(
            updatedProduct ?? orderItem.product,
            selectedStock: orderItem.selectedStock,
            fallbackTaxRate: newTax,
          );
          final resolvedPrice = orderItem.isManualPriceOverride
              ? (orderItem.price ?? newPrice)
              : _resolveUnitPrice(
                  product: updatedProduct ?? orderItem.product,
                  quantity: orderItem.quantity,
                  selectedStock: orderItem.selectedStock,
                  fallbackPrice: newPrice,
                  saleUnitId: orderItem.saleUnitId,
                );
          if (updatedProduct != null) {
            order.items[i] = LocalCartItem(
              lineId: orderItem.lineId,
              product: updatedProduct,
              price: resolvedPrice,
              mrp: newMrp,
              taxRate: effectiveTax,
              taxAmount: _calculateTaxAmount(resolvedPrice, effectiveTax),
              quantity: orderItem.quantity,
              selectedStock: orderItem.selectedStock,
              stockDeducted: orderItem.stockDeducted,
              stockGroupIds: List<int>.from(orderItem.stockGroupIds),
              stockReservations:
                  _cloneStockReservations(orderItem.stockReservations),
              comment: orderItem.comment,
              isManualPriceOverride: orderItem.isManualPriceOverride,
              warrantyEnabled: orderItem.warrantyEnabled,
              saleUnitId: orderItem.saleUnitId,
              saleUnitName: orderItem.saleUnitName,
              saleUnitConversionRate: orderItem.saleUnitConversionRate,
              variantId: orderItem.variantId,
              variantAttributes: orderItem.variantAttributes == null
                  ? null
                  : Map<String, dynamic>.from(orderItem.variantAttributes!),
            );
          } else {
            if (!orderItem.isManualPriceOverride) {
              orderItem.price = newPrice;
            }
            orderItem.mrp = newMrp;
            orderItem.taxRate = effectiveTax;
            orderItem.taxAmount =
                _calculateTaxAmount(orderItem.price ?? newPrice, effectiveTax);
          }
          savedOrdersUpdated = true;
          savedOrderItemUpdatedCount++;
        }
      }
    }

    debugPrint(
        "📊 [CartUpdate] Matched cartItems=$cartUpdatedCount, savedOrderItems=$savedOrderItemUpdatedCount");

    if (cartUpdated) {
      _saveCartToHive();
      debugPrint(
          "💾 [CartUpdate] Cart Hive sync complete for productId=$productId");
    }
    if (savedOrdersUpdated) {
      _saveSavedOrdersToHive();
      debugPrint(
          "💾 [CartUpdate] Saved orders Hive sync complete for productId=$productId");
    }
    if (cartUpdated || savedOrdersUpdated) {
      notifyListeners();
      debugPrint(
          "✅ [CartUpdate] notifyListeners() called for productId=$productId");
    } else {
      debugPrint(
          "ℹ️ [CartUpdate] No matching cart/saved-order items found for productId=$productId");
    }
  }

  void updateStockPricingInCartByStockId({
    required int stockId,
    required double newPrice,
    required double newMrp,
    GetProduct? updatedProduct,
    Stock? updatedStock,
  }) {
    debugPrint(
        "🔁 [StockCartUpdate] Start stockId=$stockId, newPrice=$newPrice, newMrp=$newMrp, withProductSnapshot=${updatedProduct != null}, withStockSnapshot=${updatedStock != null}");

    bool cartUpdated = false;
    int cartUpdatedCount = 0;
    for (int i = 0; i < _cartItems.length; i++) {
      final item = _cartItems[i];
      if (item.selectedStock?.id == stockId) {
        final resolvedStock = updatedStock ?? item.selectedStock;
        final effectiveTax = _resolveCartTaxRate(
          updatedProduct ?? item.product,
          selectedStock: resolvedStock,
          fallbackTaxRate: item.taxRate,
        );
        final resolvedPrice = item.isManualPriceOverride
            ? (item.price ?? newPrice)
            : _resolveUnitPrice(
                product: updatedProduct ?? item.product,
                quantity: item.quantity,
                selectedStock: resolvedStock,
                fallbackPrice: newPrice,
                saleUnitId: item.saleUnitId,
                variantId: item.variantId,
              );
        _cartItems[i] = LocalCartItem(
          lineId: item.lineId,
          product: updatedProduct ?? item.product,
          price: resolvedPrice,
          mrp: newMrp,
          taxRate: effectiveTax,
          taxAmount: _calculateTaxAmount(resolvedPrice, effectiveTax),
          quantity: item.quantity,
          selectedStock: resolvedStock,
          stockDeducted: item.stockDeducted,
          stockGroupIds: List<int>.from(item.stockGroupIds),
          stockReservations: _cloneStockReservations(item.stockReservations),
          comment: item.comment,
          isManualPriceOverride: item.isManualPriceOverride,
          warrantyEnabled: item.warrantyEnabled,
          saleUnitId: item.saleUnitId,
          saleUnitName: item.saleUnitName,
          saleUnitConversionRate: item.saleUnitConversionRate,
          variantId: item.variantId,
          variantAttributes: item.variantAttributes == null
              ? null
              : Map<String, dynamic>.from(item.variantAttributes!),
        );
        cartUpdated = true;
        cartUpdatedCount++;
      }
    }

    bool savedOrdersUpdated = false;
    int savedOrderItemUpdatedCount = 0;
    for (var order in _savedOrders) {
      for (int i = 0; i < order.items.length; i++) {
        final orderItem = order.items[i];
        if (orderItem.selectedStock?.id == stockId) {
          final resolvedStock = updatedStock ?? orderItem.selectedStock;
          final effectiveTax = _resolveCartTaxRate(
            updatedProduct ?? orderItem.product,
            selectedStock: resolvedStock,
            fallbackTaxRate: orderItem.taxRate,
          );
          final resolvedPrice = orderItem.isManualPriceOverride
              ? (orderItem.price ?? newPrice)
              : _resolveUnitPrice(
                  product: updatedProduct ?? orderItem.product,
                  quantity: orderItem.quantity,
                  selectedStock: resolvedStock,
                  fallbackPrice: newPrice,
                  saleUnitId: orderItem.saleUnitId,
                  variantId: orderItem.variantId,
                );
          order.items[i] = LocalCartItem(
            lineId: orderItem.lineId,
            product: updatedProduct ?? orderItem.product,
            price: resolvedPrice,
            mrp: newMrp,
            taxRate: effectiveTax,
            taxAmount: _calculateTaxAmount(resolvedPrice, effectiveTax),
            quantity: orderItem.quantity,
            selectedStock: resolvedStock,
            stockDeducted: orderItem.stockDeducted,
            stockGroupIds: List<int>.from(orderItem.stockGroupIds),
            stockReservations:
                _cloneStockReservations(orderItem.stockReservations),
            comment: orderItem.comment,
            isManualPriceOverride: orderItem.isManualPriceOverride,
            warrantyEnabled: orderItem.warrantyEnabled,
            saleUnitId: orderItem.saleUnitId,
            saleUnitName: orderItem.saleUnitName,
            saleUnitConversionRate: orderItem.saleUnitConversionRate,
            variantId: orderItem.variantId,
            variantAttributes: orderItem.variantAttributes == null
                ? null
                : Map<String, dynamic>.from(orderItem.variantAttributes!),
          );
          savedOrdersUpdated = true;
          savedOrderItemUpdatedCount++;
        }
      }
    }

    debugPrint(
        "📊 [StockCartUpdate] Matched cartItems=$cartUpdatedCount, savedOrderItems=$savedOrderItemUpdatedCount");

    if (cartUpdated) {
      _saveCartToHive();
      debugPrint(
          "💾 [StockCartUpdate] Cart Hive sync complete for stockId=$stockId");
    }
    if (savedOrdersUpdated) {
      _saveSavedOrdersToHive();
      debugPrint(
          "💾 [StockCartUpdate] Saved orders Hive sync complete for stockId=$stockId");
    }
    if (cartUpdated || savedOrdersUpdated) {
      notifyListeners();
      debugPrint(
          "✅ [StockCartUpdate] notifyListeners() called for stockId=$stockId");
    } else {
      debugPrint(
          "ℹ️ [StockCartUpdate] No matching cart/saved-order items found for stockId=$stockId");
    }
  }

  /// Decrements the quantity of the product in the cart.
  /// If the quantity becomes less than 1, the product is removed from the cart.
  /// Also handles stock restoration when stock management is enabled.
  void decrementCartItem(int productId, Stock? selectedStock,
      {List<int>? stockGroupIds, int? saleUnitId, int? variantId}) {
    debugPrint("➖ DECREMENT CART ITEM STARTED");
    debugPrint("Product ID: $productId");
    debugPrint("Selected Stock: ${selectedStock?.id}");
    debugPrint("Stock Management Enabled: $isStockEnabled");

    final index = _findCartItemIndex(
      productId,
      selectedStock: selectedStock,
      stockGroupIds: stockGroupIds,
      saleUnitId: saleUnitId,
      variantId: variantId,
    );

    if (index != -1) {
      final decrementAmount = _cartItems[index].hasSaleUnit
          ? _cartItems[index].toBaseQuantity(1)
          : 1;
      debugPrint(
          "📝 Found cart item - current quantity: ${_cartItems[index].quantity}, stockDeducted: ${_cartItems[index].stockDeducted}");

      if (_cartItems[index].quantity > decrementAmount) {
        // STOCK RESTORATION: Only restore the quantity reduced from the cart line.
        if (isStockEnabled && _cartItems[index].stockDeducted > 0) {
          _restoreStockReservations(
            _cartItems[index],
            decrementAmount,
            "DECREMENT_CART_ITEM",
          );
          _flushDirtyProducts();
        }

        _cartItems[index].quantity -= decrementAmount;
        _refreshCartItemPricing(_cartItems[index]);
        debugPrint("📝 Decremented quantity to: ${_cartItems[index].quantity}");
      } else {
        // STOCK RESTORATION: Add back the last unit if we have stock to restore
        if (isStockEnabled && _cartItems[index].stockDeducted > 0) {
          _restoreStockReservations(
            _cartItems[index],
            _cartItems[index].stockDeducted,
            "DECREMENT_CART_ITEM_REMOVE",
          );
          _flushDirtyProducts();
        }

        _cartItems.removeAt(index);
        debugPrint("📝 Removed item from cart (quantity was 1)");
      }

      _saveCartToHive();
      notifyListeners();

      debugPrint("✅ DECREMENT CART ITEM COMPLETED");
    } else {
      debugPrint("⚠️ Cart item not found for decrement");
    }
  }

  /// Clears all items from the local cart.
  /// Also restores all stock quantities when stock management is enabled.
  void clearCart() {
    debugPrint("🧹 CLEAR CART STARTED");
    debugPrint("Cart items count: ${_cartItems.length}");
    debugPrint("Stock Management Enabled: $isStockEnabled");

    // An unresolved sale may already have committed. Keep its reservation
    // while moving to a new cart instead of making that stock sellable twice.
    if (isStockEnabled &&
        !OrderSubmissionCoordinator.instance
            .isCartAwaitingReview(_cartSessionId)) {
      for (var cartItem in _cartItems) {
        if (cartItem.stockDeducted > 0) {
          _restoreStockReservations(
              cartItem, cartItem.stockDeducted, "CLEAR_CART");
        }
      }
      _flushDirtyProducts();
    }

    _cartItems.clear();
    _cartSessionId = const Uuid().v4();
    _saveCartToHive();
    clearDiscount(); // Also clear discounts when cart is cleared
    notifyListeners();

    debugPrint("✅ CLEAR CART COMPLETED");
  }

  /// Clears cart after order confirmation WITHOUT restoring stock.
  /// This maintains the stock reduction from the cart so the sale is recorded.
  /// Use this method when confirming/saving orders.
  void clearCartAfterOrder() {
    debugPrint("🧹 CLEAR CART AFTER ORDER STARTED");
    debugPrint("Cart items count: ${_cartItems.length}");
    debugPrint("📦 Stock quantities will NOT be restored (order confirmed)");

    // Do NOT restore stock - the items are sold
    _cartItems.clear();
    _cartSessionId = const Uuid().v4();
    _saveCartToHive();
    clearDiscount(); // Also clear discounts when cart is cleared
    notifyListeners();

    debugPrint("✅ CLEAR CART AFTER ORDER COMPLETED");
  }

  /// Clears the current order being edited
  void clearCurrentOrder() {
    debugPrint("🧹 CLEARING CURRENT ORDER REFERENCE");
    _currentOrder = null;
    notifyListeners();
  }

  /// Resets the local product list and filtered list.
  void resetProducts() {
    _catalogEpoch++;
    _dirtyProductIds.clear();
    _products = [];
    _filteredProducts = [];
    _productsByBarcode.clear();
    _enqueuePersistence('clear products', () async {
      await _productsBox.clear();
    });
    notifyListeners();
  }

  /// Clears saved draft orders from memory and Hive.
  Future<void> clearSavedOrdersCache() async {
    _savedOrders.clear();
    _saveSavedOrdersToHive();
    await flushPersistence();
    notifyListeners();
    debugPrint('Cleared saved orders cache');
  }

  /// Clears locally confirmed orders from memory and Hive.
  Future<void> clearConfirmedOrdersCache() async {
    _confirmedOrders.clear();
    if (_isConfirmedBoxInitialized) {
      await _confirmedOrdersBox.clear();
    }
    notifyListeners();
    debugPrint('Cleared confirmed orders cache');
  }

  /// Refreshes products by reinitializing the filtered list to the full product list.
  void refreshProducts() {
    _filteredProducts = List.from(_products);
    _rebuildBarcodeIndex();
    notifyListeners();
  }

  /// Updates a single product in the local list.
  /// If the product exists, it gets updated; otherwise, it is added.
  void updateProduct(GetProduct product) {
    int index = _products.indexWhere((p) => p.productId == product.productId);
    if (index != -1) {
      _products[index] = product;
    } else {
      _products.add(product);
    }
    _saveProductToHive(product);
    refreshProducts();
  }

  /// Manually adds new stock entry to an existing product
  /// This is much faster than fetching all products from API
  void addStockToProduct({
    required int productId,
    required int stockId,
    required num quantity,
    required String price,
    required String mrp,
    required String purchasePrice,
  }) {
    debugPrint("📦 MANUAL STOCK UPDATE STARTED");
    debugPrint("Product ID: $productId");
    debugPrint("Stock ID: $stockId");
    debugPrint("Quantity: $quantity");
    debugPrint("Price: $price");

    // Find the product in the local list
    int productIndex = _products.indexWhere((p) => p.productId == productId);

    if (productIndex != -1) {
      GetProduct oldProduct = _products[productIndex];

      // Create a copy of existing stock list
      List<Stock> updatedStock =
          oldProduct.stock != null ? List<Stock>.from(oldProduct.stock!) : [];

      // Check if stock entry already exists
      int stockIndex = updatedStock.indexWhere((s) => s.id == stockId);

      if (stockIndex != -1) {
        // Update existing stock entry
        Stock existingStock = updatedStock[stockIndex];
        // 🔧 FIX: Preserve ALL stock fields including supplier, sku, unit, date, etc.
        updatedStock[stockIndex] = existingStock.copyWith(
          quantity: (existingStock.quantity ?? 0) + quantity,
          price: price,
          mrp: mrp,
          purchasePrice: purchasePrice,
        );
      } else {
        // Add new stock entry
        Stock newStock = Stock(
          id: stockId,
          productId: productId,
          quantity: quantity,
          price: price,
          mrp: mrp,
          unit: oldProduct.unit,
          purchasePrice: purchasePrice,
          hsnCode: oldProduct.hsnCode,
        );

        updatedStock.add(newStock);
        debugPrint("📦 Added new stock entry to product");
      }

      // Create new product instance with updated stock
      GetProduct updatedProduct = oldProduct.copyWith(stock: updatedStock);

      // Update the product in the list
      _products[productIndex] = updatedProduct;

      // Save to Hive
      _saveProductToHive(updatedProduct);

      // Update filtered products if needed
      refreshProducts();

      debugPrint("✅ MANUAL STOCK UPDATE COMPLETED");
    } else {
      debugPrint("❌ Product not found for stock update: $productId");
    }
  }

  GetProduct? updateStockDetailsLocallyByStockId({
    required int stockId,
    required String retailPrice,
    required String mrp,
    required String purchasePrice,
    required String quantity,
    required String rack,
  }) {
    final productIndex = _products.indexWhere(
      (product) => product.stock?.any((stock) => stock.id == stockId) ?? false,
    );

    if (productIndex == -1) {
      debugPrint(
          "âš ï¸ [LocalStockUpdate] Product not found for stockId=$stockId");
      return null;
    }

    final oldProduct = _products[productIndex];
    final updatedStock = List<Stock>.from(oldProduct.stock ?? const <Stock>[]);
    final stockIndex = updatedStock.indexWhere((stock) => stock.id == stockId);
    if (stockIndex == -1) {
      return null;
    }

    final existingStock = updatedStock[stockIndex];
    updatedStock[stockIndex] = existingStock.copyWith(
      quantity: num.tryParse(quantity) ?? existingStock.quantity,
      price: retailPrice,
      mrp: mrp,
      purchasePrice: purchasePrice,
      rack: rack,
    );

    final updatedProduct = oldProduct.copyWith(stock: updatedStock);
    _products[productIndex] = updatedProduct;

    final filteredIndex = _filteredProducts.indexWhere(
      (product) => product.productId == updatedProduct.productId,
    );
    if (filteredIndex != -1) {
      _filteredProducts[filteredIndex] = updatedProduct;
    }

    _rebuildBarcodeIndex();
    _saveProductToHive(updatedProduct);
    notifyListeners();

    debugPrint(
        "âœ… [LocalStockUpdate] Updated local product stock for stockId=$stockId");
    return updatedProduct;
  }

  /// Updates stock quantity for a specific stock entry
  /// Used when stock quantities change (e.g., after sales, returns, etc.)
  void updateStockQuantity({
    required int productId,
    required int stockId,
    required num newQuantity,
  }) {
    debugPrint("📦 MANUAL STOCK QUANTITY UPDATE");
    debugPrint(
        "Product ID: $productId, Stock ID: $stockId, New Quantity: $newQuantity");

    int productIndex = _products.indexWhere((p) => p.productId == productId);

    if (productIndex != -1) {
      GetProduct oldProduct = _products[productIndex];

      if (oldProduct.stock != null) {
        // Create a copy of existing stock list
        List<Stock> updatedStock = List<Stock>.from(oldProduct.stock!);

        int stockIndex = updatedStock.indexWhere((s) => s.id == stockId);

        if (stockIndex != -1) {
          Stock existingStock = updatedStock[stockIndex];
          // 🔧 FIX: Preserve ALL stock fields including supplier, sku, unit, date, etc.
          updatedStock[stockIndex] =
              existingStock.copyWith(quantity: newQuantity);

          // Create new product instance with updated stock
          GetProduct updatedProduct = oldProduct.copyWith(stock: updatedStock);

          // Update the product in the list
          _products[productIndex] = updatedProduct;

          // Save to Hive
          _saveProductToHive(updatedProduct);

          // Refresh products
          refreshProducts();

          debugPrint("✅ Stock quantity updated successfully");
        } else {
          debugPrint("❌ Stock entry not found: $stockId");
        }
      }
    } else {
      debugPrint("❌ Product not found: $productId");
    }
  }

  /// Removes a product from the local product list.
  void deleteProduct(int productId) {
    _products.removeWhere((p) => p.productId == productId);
    _dirtyProductIds.remove(productId);
    _removeProductFromHive(productId);
    refreshProducts();
  }

  /// Retrieves a product by its ID.
  GetProduct? getProductById(int productId) {
    try {
      return _products.firstWhere((p) => p.productId == productId);
    } catch (e) {
      return null;
    }
  }

  List<GetProduct> filterProductByBarcode({required String barCode}) {
    final normalizedBarcode = _normalizeBarcode(barCode);
    debugPrint("filterProductByBarcode $normalizedBarcode");
    final filteredProducts = List<GetProduct>.from(
        _productsByBarcode[normalizedBarcode] ?? const []);

    // Check if any product was found before accessing .first
    if (filteredProducts.isNotEmpty) {
      debugPrint(filteredProducts.first.productName);
    } else {
      debugPrint("No product found for barcode: $normalizedBarcode");
    }
    return filteredProducts;
  }

  /// Saves the current cart as a confirmed order
  String _generateLocalOrderId() {
    final nowMicros = DateHelper.now().microsecondsSinceEpoch;
    final nextMicros = nowMicros <= _lastLocalOrderIdMicros
        ? _lastLocalOrderIdMicros + 1
        : nowMicros;
    _lastLocalOrderIdMicros = nextMicros;
    return nextMicros.toString();
  }

  SavedOrder saveCurrentCartAsConfirmedOrder({
    String? customerName,
    String? customerPhone,
    String? comment,
    String? deliveryMethod,
    // New API-compatible parameters
    int? customerId,
    String? paymentMethod,
    String? paidAmount,
    String? balanceAmount,
    String? transactionId,
    String? couponId,
    String? deliveryMethodId,
    String? carNumber,
    String? status,
    String? deliveryDate, // Add deliveryDate
    String? deliveryTime, // Add deliveryTime
    bool? toCustomerCredit,
    BuildContext? context, // Add context parameter
    String? tableId,
    String? alternatePhone,
    String? address,
    double? deliveryCharge,
    String? customerVatNumber,
    String? customerCrNumber,
    String? customerType,
  }) {
    if (_cartItems.isEmpty) {
      throw Exception("Cannot save an empty cart as confirmed order");
    }

    final String orderId = _generateLocalOrderId();

    // Calculate total with rounding if enabled
    final baseTotal = context != null ? getRoundedTotal(context) : cartTotal;
    double total = baseTotal + (deliveryCharge ?? 0.0);

    // Create a deep copy of cart items to prevent modification
    final orderItems = _cartItems.map(_cloneLocalCartItem).toList();

    // Generate sequential order number - use "CONF-" prefix for confirmed orders
    String orderNumber = generateConfirmedOrderNumber();

    // Create the confirmed order
    final SavedOrder order = SavedOrder(
      id: orderId,
      orderNumber: orderNumber,
      items: orderItems,
      customerName: customerName,
      customerPhone: customerPhone,
      comment: comment,
      createdAt: DateHelper.now().toIso8601String(),
      total: total,
      deliveryMethod: deliveryMethod,
      // Include new API-compatible fields
      customerId: customerId,
      paymentMethod: paymentMethod,
      paidAmount: paidAmount,
      balanceAmount: balanceAmount,
      transactionId: transactionId,
      couponId: couponId,
      deliveryMethodId: deliveryMethodId,
      carNumber: carNumber,
      status: status ?? "confirmed", // Default to "confirmed" if not provided
      deliveryDate: deliveryDate, // Pass deliveryDate
      deliveryTime: deliveryTime, // Pass deliveryTime
      flatDiscount: _flatDiscount,
      percentageDiscount: _percentageDiscount,
      toCustomerCredit: toCustomerCredit,
      tableId: tableId,
      alternatePhone: alternatePhone,
      address: address,
      deliveryCharge: deliveryCharge,
      customerVatNumber: customerVatNumber,
      customerCrNumber: customerCrNumber,
      customerType: customerType,
    );

    // Add to confirmed orders list
    _confirmedOrders.add(order);
    _saveConfirmedOrdersToHive();
    notifyListeners();

    return order;
  }

  /// Moves an existing saved order to confirmed orders
  SavedOrder? moveToConfirmedOrders(String orderId) {
    try {
      // Find the order in saved orders
      int index = _savedOrders.indexWhere((o) => o.id == orderId);

      if (index != -1) {
        // Get the order
        SavedOrder order = _savedOrders[index];

        // Create a new order with "CONF-" prefix for order number
        SavedOrder confirmedOrder = SavedOrder(
          id: order.id,
          orderNumber: "CONF-${order.orderNumber.split('-')[1]}",
          items: order.items,
          customerName: order.customerName,
          customerPhone: order.customerPhone,
          comment: order.comment,
          createdAt: order.createdAt,
          total: order.total,
          deliveryMethod: order.deliveryMethod,
          // Preserve API-compatible fields
          customerId: order.customerId,
          paymentMethod: order.paymentMethod,
          paidAmount: order.paidAmount,
          balanceAmount: order.balanceAmount,
          transactionId: order.transactionId,
          couponId: order.couponId,
          deliveryMethodId: order.deliveryMethodId,
          carNumber: order.carNumber,
          status: "confirmed",
          deliveryDate: order.deliveryDate, // Store deliveryDate in Hive
          deliveryTime: order.deliveryTime, // Store deliveryTime in Hive
          flatDiscount: order.flatDiscount,
          percentageDiscount: order.percentageDiscount,
          toCustomerCredit: order.toCustomerCredit,
          tableId: order.tableId,
          alternatePhone: order.alternatePhone,
          address: order.address,
          deliveryCharge: order.deliveryCharge,
          customerVatNumber: order.customerVatNumber,
          customerCrNumber: order.customerCrNumber,
          customerType: order.customerType,
        );

        // Add to confirmed orders
        _confirmedOrders.add(confirmedOrder);

        // Remove from saved orders
        _savedOrders.removeAt(index);

        // Save both lists
        _saveSavedOrdersToHive();
        _saveConfirmedOrdersToHive();

        notifyListeners();

        return confirmedOrder;
      }
      return null;
    } catch (e) {
      debugPrint("Error moving order to confirmed orders: $e");
      return null;
    }
  }

  /// Generates sequential order numbers in format CONF-1, CONF-2, etc. for confirmed orders
  String generateConfirmedOrderNumber() {
    // Find the highest existing order number
    int highestNumber = 0;

    for (var order in _confirmedOrders) {
      // Extract the number part from the orderNumber (e.g., "CONF-5" -> 5)
      String numPart = order.orderNumber.split('-')[1];
      int orderNum = int.tryParse(numPart) ?? 0;

      if (orderNum > highestNumber) {
        highestNumber = orderNum;
      }
    }

    // Return next number in sequence
    return 'CONF-${highestNumber + 1}';
  }

  /// Finds a confirmed order by its ID
  SavedOrder? findConfirmedOrderById(String orderId) {
    try {
      return _confirmedOrders.firstWhere((order) => order.id == orderId);
    } catch (e) {
      return null;
    }
  }

  /// Deletes a confirmed order
  void deleteConfirmedOrder(String orderId) {
    _confirmedOrders.removeWhere((o) => o.id == orderId);
    _saveConfirmedOrdersToHive();
    notifyListeners();
  }

  /// Saves the current cart as an order
  SavedOrder saveCurrentCartAsOrder({
    String? customerName,
    String? customerPhone,
    String? comment,
    String? deliveryMethod,
    // New API-compatible parameters
    int? customerId,
    String? paymentMethod,
    String? paidAmount,
    String? balanceAmount,
    String? transactionId,
    String? couponId,
    String? deliveryMethodId,
    String? carNumber,
    String? status,
    String? deliveryDate, // Add deliveryDate
    String? deliveryTime, // Add deliveryTime
    bool? toCustomerCredit,
    BuildContext? context, // Add context parameter
    String? tableId,
    String? address,
    double? deliveryCharge,
    String? alternatePhone,
    String? customerVatNumber,
    String? customerCrNumber,
    String? customerType,
  }) {
    debugPrint("💾 LOCAL PROVIDER - saveCurrentCartAsOrder called");
    debugPrint("  - Customer Phone parameter: '$customerPhone'");
    debugPrint("  - Customer Name parameter: '$customerName'");
    debugPrint("  - Customer ID parameter: $customerId");
    debugPrint("  - Requested status: ${status ?? 'saved'}");
    debugPrint("  - TableId: $tableId");
    debugPrint("  - Delivery Charge: ${deliveryCharge ?? 0.0}");

    if (_cartItems.isEmpty) {
      throw Exception("Cannot save an empty cart as order");
    }

    final String orderId = _generateLocalOrderId();

    // Calculate total with rounding if enabled
    final baseTotal = context != null ? getRoundedTotal(context) : cartTotal;
    double total = baseTotal + (deliveryCharge ?? 0.0);

    // Create a deep copy of cart items to prevent modification
    final orderItems = _cartItems.map(_cloneLocalCartItem).toList();

    // Generate sequential order number
    String orderNumber = generateOrderNumber();

    // Create the saved order
    final SavedOrder order = SavedOrder(
      id: orderId,
      orderNumber: orderNumber,
      items: orderItems,
      customerName: customerName,
      customerPhone: customerPhone,
      comment: comment,
      createdAt: DateHelper.now().toIso8601String(),
      total: total,
      deliveryMethod: deliveryMethod,
      // Include new API-compatible fields
      customerId: customerId,
      paymentMethod: paymentMethod,
      paidAmount: paidAmount,
      balanceAmount: balanceAmount,
      transactionId: transactionId,
      couponId: couponId,
      deliveryMethodId: deliveryMethodId,
      carNumber: carNumber,
      status: status ?? "saved", // Default to "saved" for regular orders
      deliveryDate: deliveryDate, // Pass deliveryDate
      deliveryTime: deliveryTime, // Pass deliveryTime
      flatDiscount: _flatDiscount,
      percentageDiscount: _percentageDiscount,
      toCustomerCredit: toCustomerCredit,
      tableId: tableId,
      alternatePhone: alternatePhone,
      address:
          address, // Pass address if available, or update if passed as param
      deliveryCharge: deliveryCharge,
      customerVatNumber: customerVatNumber,
      customerCrNumber: customerCrNumber,
      customerType: customerType,
    );

    // Add to saved orders list
    _savedOrders.add(order);
    _saveSavedOrdersToHive();
    notifyListeners();

    debugPrint("  - New order created: ${order.orderNumber}");
    debugPrint("  - Saved order phone: '${order.customerPhone}'");
    debugPrint("  - Saved order name: '${order.customerName}'");
    debugPrint("  - Saved order customer ID: ${order.customerId}");
    debugPrint("  - Saved order status: ${order.status}");
    debugPrint("  - Saved order tableId: ${order.tableId}");
    debugPrint("💾 LOCAL PROVIDER - saveCurrentCartAsOrder completed");

    return order;
  }

  /// Generates sequential order numbers in format ORD-1, ORD-2, etc.
  String generateOrderNumber() {
    // Find the highest existing order number
    int highestNumber = 0;

    for (var order in _savedOrders) {
      // Extract the number part from the orderNumber (e.g., "ORD-5" -> 5)
      String numPart = order.orderNumber.split('-')[1];
      int orderNum = int.tryParse(numPart) ?? 0;

      if (orderNum > highestNumber) {
        highestNumber = orderNum;
      }
    }

    // Return next number in sequence
    return 'ORD-${highestNumber + 1}';
  }

  /// Finds a saved order by its ID
  SavedOrder? findOrderById(String orderId) {
    try {
      return _savedOrders.firstWhere((order) => order.id == orderId);
    } catch (e) {
      return null;
    }
  }

  /// Loads a saved order into the current cart for editing
  void loadOrderForEditing(String orderId) {
    try {
      // Find the order
      final SavedOrder order = _savedOrders.firstWhere((o) => o.id == orderId);

      // Restore discounts
      _flatDiscount = order.flatDiscount ?? 0.0;
      _percentageDiscount = order.percentageDiscount ?? 0.0;

      // Release any stock reserved by the current cart before switching drafts.
      if (isStockEnabled) {
        for (final cartItem in _cartItems) {
          if (cartItem.stockDeducted > 0) {
            _restoreStockReservations(
              cartItem,
              cartItem.stockDeducted,
              "LOAD_ORDER_RELEASE",
            );
          }
        }
        _flushDirtyProducts();
      }

      // Clear current cart
      _cartItems.clear();

      // Add items from the saved order to the cart
      for (var item in order.items) {
        final reloadedItem = _cloneLocalCartItem(item);
        if (isStockEnabled && item.selectedStock != null) {
          reloadedItem.stockReservations =
              _reapplySavedReservations(item, "LOAD_ORDER_RESERVE");
          reloadedItem.stockDeducted =
              _sumStockReservations(reloadedItem.stockReservations);
        }

        _cartItems.add(reloadedItem);
      }

      if (isStockEnabled) {
        _flushDirtyProducts();
      }

      // Set current order
      _currentOrder = order;
      _cartSessionId = 'draft:${order.id}';

      _saveCartToHive();
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading order: $e");
    }
  }

  /// Loads a quotation as an editable billing draft without saving it as a
  /// normal local order. The final order API will receive quotationId later.
  void loadQuotationDraftForEditing(SavedOrder draft) {
    try {
      debugPrint(
          "🧾 [LocalProductProvider] Loading quotation draft id=${draft.quotationId}, number=${draft.quotationNumber}, customerId=${draft.customerId}, customerName=${draft.customerName}, customerPhone=${draft.customerPhone}, items=${draft.items.length}");
      _flatDiscount = draft.flatDiscount ?? 0.0;
      _percentageDiscount = draft.percentageDiscount ?? 0.0;

      if (isStockEnabled) {
        for (final cartItem in _cartItems) {
          if (cartItem.stockDeducted > 0) {
            _restoreStockReservations(
              cartItem,
              cartItem.stockDeducted,
              "LOAD_QUOTATION_RELEASE",
            );
          }
        }
        _flushDirtyProducts();
      }

      _cartItems.clear();
      _cartItems.addAll(draft.items.map(_cloneLocalCartItem));
      _currentOrder = draft;
      _cartSessionId = 'draft:${draft.id}';

      cartTotal;
      _saveCartToHive();
      notifyListeners();
      debugPrint(
          "✅ [LocalProductProvider] Quotation draft ready. cartItems=${_cartItems.length}, currentOrder=${_currentOrder?.id}, quotationId=${_currentOrder?.quotationId}");
    } catch (e) {
      debugPrint("Error loading quotation draft: $e");
      rethrow;
    }
  }

  /// Updates an existing saved order
  void updateSavedOrder(
    String orderId, {
    String? customerName,
    String? customerPhone,
    String? comment,
    String? deliveryMethod,
    // New API-compatible parameters
    int? customerId,
    String? paymentMethod,
    String? paidAmount,
    String? balanceAmount,
    String? transactionId,
    String? couponId,
    String? deliveryMethodId,
    String? carNumber,
    String? status,
    String? deliveryDate, // Add deliveryDate
    String? deliveryTime, // Add deliveryTime
    bool? toCustomerCredit,
    BuildContext? context,
    String? tableId,
    String? address,
    double? deliveryCharge,
    String? alternatePhone,
    String? customerVatNumber,
    String? customerCrNumber,
    String? customerType,
  }) {
    debugPrint("💾 LOCAL PROVIDER - updateSavedOrder called");
    debugPrint("  - Order ID: $orderId");
    debugPrint("  - Customer Phone parameter: '$customerPhone'");
    debugPrint("  - Customer Name parameter: '$customerName'");
    debugPrint("  - Customer ID parameter: $customerId");
    debugPrint("  - TableId parameter: $tableId");
    debugPrint("  - Status parameter: $status");

    int index = _savedOrders.indexWhere((o) => o.id == orderId);

    if (index != -1) {
      debugPrint("  - Found order at index: $index");
      debugPrint(
          "  - Original order phone: '${_savedOrders[index].customerPhone}'");
      // Keep total calculation aligned with new draft saves, including optional round-off.
      final baseTotal = context != null ? getRoundedTotal(context) : cartTotal;
      double total = baseTotal +
          (deliveryCharge ?? _savedOrders[index].deliveryCharge ?? 0.0);

      // Create a copy of current cart items
      final orderItems = _cartItems.map(_cloneLocalCartItem).toList();

      // Create updated order
      SavedOrder updatedOrder = SavedOrder(
        id: orderId,
        orderNumber: _savedOrders[index].orderNumber,
        items: orderItems,
        customerName: customerName ?? _savedOrders[index].customerName,
        customerPhone: customerPhone ?? _savedOrders[index].customerPhone,
        comment: comment ?? _savedOrders[index].comment,
        createdAt: _savedOrders[index].createdAt,
        total: total,
        deliveryMethod: deliveryMethod ?? _savedOrders[index].deliveryMethod,
        // Update or preserve API-compatible fields
        customerId: customerId ?? _savedOrders[index].customerId,
        paymentMethod: paymentMethod ?? _savedOrders[index].paymentMethod,
        paidAmount: paidAmount ?? _savedOrders[index].paidAmount,
        balanceAmount: balanceAmount ?? _savedOrders[index].balanceAmount,
        transactionId: transactionId ?? _savedOrders[index].transactionId,
        couponId: couponId ?? _savedOrders[index].couponId,
        deliveryMethodId:
            deliveryMethodId ?? _savedOrders[index].deliveryMethodId,
        carNumber: carNumber ?? _savedOrders[index].carNumber,
        status: status ?? _savedOrders[index].status,
        deliveryDate: deliveryDate ??
            _savedOrders[index].deliveryDate, // Update deliveryDate
        deliveryTime: deliveryTime ??
            _savedOrders[index].deliveryTime, // Update deliveryTime
        flatDiscount: _flatDiscount,
        percentageDiscount: _percentageDiscount,
        toCustomerCredit:
            toCustomerCredit ?? _savedOrders[index].toCustomerCredit,
        tableId: tableId ?? _savedOrders[index].tableId,
        alternatePhone: alternatePhone ?? _savedOrders[index].alternatePhone,
        address: address ?? _savedOrders[index].address,
        deliveryCharge: deliveryCharge ?? _savedOrders[index].deliveryCharge,
        customerVatNumber:
            customerVatNumber ?? _savedOrders[index].customerVatNumber,
        customerCrNumber:
            customerCrNumber ?? _savedOrders[index].customerCrNumber,
        customerType: customerType ?? _savedOrders[index].customerType,
      );

      // Update in list
      _savedOrders[index] = updatedOrder;

      debugPrint("  - Updated order phone: '${updatedOrder.customerPhone}'");
      debugPrint("  - Updated order name: '${updatedOrder.customerName}'");
      debugPrint("  - Updated order customer ID: ${updatedOrder.customerId}");
      debugPrint("  - Updated order status: ${updatedOrder.status}");
      debugPrint("  - Updated order tableId: ${updatedOrder.tableId}");

      // Clear current order reference
      _currentOrder = null;

      _saveSavedOrdersToHive();
      notifyListeners();

      debugPrint("💾 LOCAL PROVIDER - updateSavedOrder completed");
    } else {
      debugPrint("⚠️ LOCAL PROVIDER - Order not found: $orderId");
    }
  }

  /// Deletes a saved order
  void deleteSavedOrder(String orderId) {
    final before = _savedOrders.length;
    _savedOrders.removeWhere((o) => o.id == orderId);
    final after = _savedOrders.length;
    debugPrint(
        "🗑️ LOCAL PROVIDER - deleteSavedOrder id=$orderId (before=$before, after=$after)");

    // If current order is deleted, clear reference
    if (_currentOrder != null && _currentOrder!.id == orderId) {
      _currentOrder = null;
    }

    _saveSavedOrdersToHive();
    notifyListeners();
  }

  /// Checks if a product has available stock
  bool hasAvailableStock(GetProduct product, {num quantity = 1}) {
    if (product.stock == null || product.stock!.isEmpty) {
      // If stock isn't tracked, assume it's available
      return true;
    }

    // Check if at least one stock entry has enough quantity
    return product.stock!
        .any((stock) => stock.quantity != null && stock.quantity! >= quantity);
  }

  /// Gets the available stock quantity for a product
  num getAvailableStockQuantity(GetProduct product) {
    if (product.stock == null || product.stock!.isEmpty) {
      // If stock isn't tracked, return a large number
      return 9999;
    }

    // Sum all stock quantities
    return product.stock!.fold(0, (sum, stock) => sum + (stock.quantity ?? 0));
  }

  /// Filters [stocks] to the rows relevant for [variantId]. Variant sales are
  /// strict: they may only consume stock assigned to that variant. Plain
  /// product sales may only consume general (non-variant) stock.
  static List<Stock> filterStocksForVariant(
    List<Stock> stocks,
    int? variantId,
  ) {
    if (variantId == null) {
      return stocks.where((stock) => stock.productVariantId == null).toList();
    }
    return stocks
        .where((stock) => stock.productVariantId == variantId)
        .toList();
  }

  /// Gets selectable stock rows. Normal flows expose only positive quantity;
  /// oversell flows can retain zero/negative rows so the cart still carries
  /// the correct stock and variant identity.
  List<Stock> getStockOptions(
    GetProduct product, {
    bool includeNonPositive = false,
  }) {
    if (product.stock == null) {
      return [];
    }
    return product.stock!
        .where((stock) =>
            stock.quantity != null &&
            (includeNonPositive || stock.quantity! > 0))
        .toList();
  }

  List<Stock> getStockOptionsForStore(
    GetProduct product, {
    int? activeStoreId,
    String? activeStoreName,
    bool includeNonPositive = false,
  }) {
    final availableStocks = getStockOptions(
      product,
      includeNonPositive: includeNonPositive,
    );
    if (availableStocks.isEmpty) {
      // No stock entries with quantity data at all — return empty so caller
      // falls back to base product pricing (non-stock mode).
      return const <Stock>[];
    }

    return filterStocksForStore(
      availableStocks,
      activeStoreId: activeStoreId,
      activeStoreName: activeStoreName,
    );
  }

  /// Store filter shared by billing and product-details views. `store_id` is
  /// authoritative; store name is only a compatibility fallback.
  static List<Stock> filterStocksForStore(
    List<Stock> stocks, {
    int? activeStoreId,
    String? activeStoreName,
  }) {
    final normalizedActiveStoreName = activeStoreName?.trim().toLowerCase();
    final hasActiveStoreName = normalizedActiveStoreName != null &&
        normalizedActiveStoreName.isNotEmpty;

    if (activeStoreId == null && !hasActiveStoreName) {
      return List<Stock>.from(stocks);
    }

    return stocks.where((stock) {
      if (activeStoreId != null) {
        return stock.storeId == activeStoreId;
      }
      return stock.storeName?.trim().toLowerCase() == normalizedActiveStoreName;
    }).toList(growable: false);
  }

  List<int> getSelectionStockIds({
    Stock? selectedStock,
    List<int>? stockGroupIds,
  }) {
    final normalizedGroupIds = _normalizeStockGroupIds(stockGroupIds);
    if (normalizedGroupIds.isNotEmpty) {
      return normalizedGroupIds;
    }

    if (selectedStock?.id == null) {
      return const <int>[];
    }

    return <int>[selectedStock!.id!];
  }

  num getAvailableQuantityForSelection({
    required GetProduct product,
    Stock? selectedStock,
    List<int>? stockGroupIds,
    int? variantId,
  }) {
    final currentProduct = getProductById(product.productId ?? -1) ?? product;
    final currentStocks = filterStocksForVariant(
      currentProduct.stock ?? const <Stock>[],
      variantId,
    );
    final selectionStockIds = getSelectionStockIds(
      selectedStock: selectedStock,
      stockGroupIds: stockGroupIds,
    ).toSet();

    if (selectionStockIds.isEmpty) {
      return 0;
    }

    return currentStocks
        .where((stock) =>
            stock.id != null &&
            selectionStockIds.contains(stock.id) &&
            stock.quantity != null &&
            stock.quantity! > 0)
        .fold<num>(0, (sum, stock) => sum + (stock.quantity ?? 0));
  }

  List<Stock> getAlternativeStockOptions({
    required GetProduct product,
    Stock? selectedStock,
    List<int>? stockGroupIds,
    int? activeStoreId,
    String? activeStoreName,
    int? variantId,
  }) {
    final currentProduct = getProductById(product.productId ?? -1) ?? product;
    final excludedStockIds = getSelectionStockIds(
      selectedStock: selectedStock,
      stockGroupIds: stockGroupIds,
    ).toSet();

    final availableStocks = filterStocksForVariant(
      getStockOptionsForStore(
        currentProduct,
        activeStoreId: activeStoreId,
        activeStoreName: activeStoreName,
      ),
      variantId,
    );

    final filteredStocks = availableStocks.where((stock) {
      final stockId = stock.id;
      if (stockId == null) {
        return true;
      }
      return !excludedStockIds.contains(stockId);
    }).toList();

    return _sortStocksForReservation(filteredStocks);
  }

  /// Selects the optimal stock entry based on quantity needed
  Stock? selectStockForQuantity(GetProduct product, num quantity) {
    if (product.stock == null || product.stock!.isEmpty) {
      return null;
    }

    // First try to find a stock entry with exact or more quantity
    var availableStocks = product.stock!
        .where((stock) => stock.quantity != null && stock.quantity! >= quantity)
        .toList();

    if (availableStocks.isNotEmpty) {
      // Sort by price if available, otherwise return the first one
      availableStocks.sort((a, b) {
        if (a.price == null || b.price == null) return 0;
        return (double.tryParse(a.price!) ?? 0)
            .compareTo(double.tryParse(b.price!) ?? 0);
      });
      return availableStocks.first;
    }

    // If no single stock entry has enough quantity, return the one with most quantity
    var sortedStocks = List<Stock>.from(product.stock!);
    sortedStocks.sort((a, b) => (b.quantity ?? 0).compareTo(a.quantity ?? 0));

    return sortedStocks.isNotEmpty ? sortedStocks.first : null;
  }

  /// Gets current stock information for a product (for debugging/monitoring)
  Map<String, dynamic> getStockInfo(int productId) {
    final product = _products.firstWhere((p) => p.productId == productId,
        orElse: () => throw Exception("Product not found"));

    if (product.stock == null || product.stock!.isEmpty) {
      return {
        'productName': product.productName,
        'stockManagementEnabled': isStockEnabled,
        'hasStockEntries': false,
        'stockEntries': []
      };
    }

    List<Map<String, dynamic>> stockEntries = product.stock!
        .map((stock) => {
              'stockId': stock.id,
              'quantity': stock.quantity,
              'price': stock.price,
              'mrp': stock.mrp,
              'status':
                  (stock.quantity ?? 0) <= 0 ? 'OUT_OF_STOCK' : 'AVAILABLE'
            })
        .toList();

    return {
      'productName': product.productName,
      'stockManagementEnabled': isStockEnabled,
      'hasStockEntries': true,
      'stockEntries': stockEntries,
      'totalAvailableQuantity': product.stock!
          .fold<num>(0, (sum, stock) => sum + (stock.quantity ?? 0))
    };
  }

  /// Sets the exact quantity of a cart item. Supports fractional quantities.
  /// If [newQuantity] is 0 or less, the item is removed from the cart.
  /// Stock levels are adjusted based on the difference between old and new quantities.
  void setCartItemQuantity(int productId, Stock? selectedStock, num newQuantity,
      {List<int>? stockGroupIds, int? saleUnitId, int? variantId}) {
    debugPrint("🔄 SET CART ITEM QUANTITY STARTED");
    debugPrint("Product ID: $productId");
    debugPrint("Selected Stock: ${selectedStock?.id}");
    debugPrint("Requested Quantity: $newQuantity");
    debugPrint("Stock Management Enabled: $isStockEnabled");

    final index = _findCartItemIndex(
      productId,
      selectedStock: selectedStock,
      stockGroupIds: stockGroupIds,
      saleUnitId: saleUnitId,
      variantId: variantId,
    );

    if (index == -1) {
      debugPrint("⚠️ Cart item not found – cannot set quantity");
      return;
    }

    final cartItem = _cartItems[index];
    if (isStockEnabled && cartItem.selectedStock != null) {
      cartItem.stockGroupIds = _expandCompatibleStockGroupIds(
        product: cartItem.product,
        selectedStock: cartItem.selectedStock!,
        variantId: cartItem.variantId,
        stockGroupIds: cartItem.stockGroupIds,
      );
    }

    final currentQuantity = cartItem.quantity;
    final num difference =
        newQuantity - currentQuantity; // positive if increasing

    if (isStockEnabled &&
        !allowOverselling &&
        selectedStock != null &&
        difference > 0) {
      final availableQuantity = getAvailableQuantityForSelection(
        product: _cartItems[index].product,
        selectedStock: selectedStock,
        stockGroupIds: _cartItems[index].stockGroupIds,
        variantId: _cartItems[index].variantId,
      );
      if (availableQuantity < difference) {
        debugPrint(
            'Cannot set cart quantity: requires $difference additional units but only $availableQuantity is available');
        return;
      }
    }

    // Handle stock adjustment if enabled
    if (isStockEnabled && selectedStock != null && difference != 0) {
      // If difference is positive we are selling more → deduct stock (-difference)
      // If difference is negative we are reducing sale → restore stock (+abs(difference))
      if (difference > 0) {
        // Increasing quantity → deduct from stock
        final reservationDeltas = _reserveStockForSelection(
          product: _cartItems[index].product,
          quantity: difference,
          selectedStock: selectedStock,
          stockGroupIds: _cartItems[index].stockGroupIds,
          operation: "SET_CART_ITEM_QUANTITY_INCREASE",
          variantId: _cartItems[index].variantId,
        );
        _mergeReservationDeltas(_cartItems[index], reservationDeltas);
      } else {
        // Decreasing quantity → restore to stock (only up to what was deducted)
        final restoreAmount = difference.abs();
        if (restoreAmount > 0) {
          _restoreStockReservations(
            _cartItems[index],
            restoreAmount,
            "SET_CART_ITEM_QUANTITY_DECREASE",
          );
        }
      }

      _flushDirtyProducts();
    }

    if (newQuantity <= 0) {
      // Remove item — restore any remaining stock that was deducted
      debugPrint("🗑️ New quantity <= 0 – removing item from cart");
      if (isStockEnabled && _cartItems[index].stockDeducted > 0) {
        _restoreStockReservations(
          _cartItems[index],
          _cartItems[index].stockDeducted,
          "SET_CART_ITEM_QUANTITY_REMOVE",
        );
        _flushDirtyProducts();
      }
      _cartItems.removeAt(index);
    } else {
      // Update quantity
      _cartItems[index].quantity = newQuantity;
      final item = _cartItems[index];
      final effectiveStock = selectedStock ?? item.selectedStock;
      final wasWholesale = _qualifiesForWholesalePrice(
        quantity: currentQuantity,
        selectedStock: effectiveStock,
      );
      final isWholesale = _qualifiesForWholesalePrice(
        quantity: newQuantity,
        selectedStock: effectiveStock,
      );
      if (wasWholesale && !isWholesale && item.isManualPriceOverride) {
        final wholesalePrice = _resolveWholesalePrice(effectiveStock);
        if (wholesalePrice != null &&
            item.price != null &&
            (item.price! - wholesalePrice).abs() < 0.001) {
          item.isManualPriceOverride = false;
        }
      }
      _refreshCartItemPricing(item);
      debugPrint("✅ Quantity updated: $currentQuantity → $newQuantity");
    }

    _saveCartToHive();
    notifyListeners();
    debugPrint("🔄 SET CART ITEM QUANTITY COMPLETED");
  }

  // Add method to get rounded total
  double getRoundedTotal(BuildContext context) {
    double originalTotal = cartTotal;

    // Check if rounding is enabled
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    if (appSettingsProvider.appSettings?.priceRoundOff == true) {
      return AmountHelper.roundOffAmount(originalTotal);
    }

    return originalTotal;
  }

  /// Applies discount to the cart
  void applyDiscount({
    required double flatDiscount,
    required double percentageDiscount,
  }) {
    debugPrint("🏷️ APPLYING DISCOUNT");
    debugPrint("  - Flat Discount: $flatDiscount");
    debugPrint("  - Percentage Discount: $percentageDiscount%");

    _flatDiscount = flatDiscount;
    _percentageDiscount = percentageDiscount;

    // Recalculate totals by calling cartTotal getter
    cartTotal;

    notifyListeners();

    debugPrint("✅ DISCOUNT APPLIED SUCCESSFULLY");
  }

  /// Clears all applied discounts
  void clearDiscount() {
    debugPrint("🧹 CLEARING DISCOUNT");

    _flatDiscount = 0.0;
    _percentageDiscount = 0.0;

    // Recalculate totals by calling cartTotal getter
    cartTotal;

    notifyListeners();

    debugPrint("✅ DISCOUNT CLEARED SUCCESSFULLY");
  }

  /// Gets current discount values
  Map<String, double> getCurrentDiscount() {
    return {
      'flatDiscount': _flatDiscount,
      'percentageDiscount': _percentageDiscount,
    };
  }

  /// Clears ALL local data for multi-tenant isolation.
  /// Call this during logout or when switching API keys (tenants)
  /// to prevent data leakage between different tenants.
  Future<void> clearAllLocalData() async {
    debugPrint("🧹 CLEARING ALL LOCAL DATA FOR TENANT ISOLATION");

    try {
      // Prevent an older tenant's queued rewrite from running after the boxes
      // have been cleared for the new tenant.
      await flushPersistence();
      _catalogEpoch++;
      _dirtyProductIds.clear();
      // Clear Hive boxes
      await _productsBox.clear();
      debugPrint("  ✅ Cleared products box");

      await _cartItemsBox.clear();
      debugPrint("  ✅ Cleared cart_items box");

      await _savedOrdersBox.clear();
      debugPrint("  ✅ Cleared saved_orders box");

      if (_isConfirmedBoxInitialized) {
        await _confirmedOrdersBox.clear();
        debugPrint("  ✅ Cleared confirmed_orders box");
      }

      final prefsProvider = prefs_provider.SharedPreferenceProvider();
      await prefsProvider.clearLastProductSyncIso();
      debugPrint("  ✅ Cleared product delta sync marker");

      // Clear in-memory lists
      _products.clear();
      _filteredProducts.clear();
      _cartItems.clear();
      _cartSessionId = const Uuid().v4();
      _saveCartToHive();
      await flushPersistence();
      _savedOrders.clear();
      _confirmedOrders.clear();

      // Reset state
      _selectedProduct = null;
      _selectedStock = null;
      _currentOrder = null;
      _flatDiscount = 0.0;
      _percentageDiscount = 0.0;
      priceSummary = null;
      _currentPage = 1;
      _totalPages = 1;

      notifyListeners();
      debugPrint("✅ ALL LOCAL DATA CLEARED SUCCESSFULLY");
    } catch (e) {
      debugPrint("❌ Error clearing local data: $e");
      rethrow;
    }
  }

  // End of LocalProductProvider
}

// End of file.
