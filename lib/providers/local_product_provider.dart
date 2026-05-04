import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/get_product.dart';
import '../models/local_models.dart';
import '../resources/app_url.dart';
import '../providers/app_settings_provider.dart';
import '../providers/shared_preferences.dart' as prefs_provider;

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

  /// Optional sale-unit metadata used when a cart line originates from an
  /// alternate sale unit barcode such as CASE / PACK / BOX.
  final int? saleUnitId;
  final String? saleUnitName;
  final double? saleUnitConversionRate;

  LocalCartItem({
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
    this.saleUnitId,
    this.saleUnitName,
    this.saleUnitConversionRate,
  })  : stockGroupIds = stockGroupIds ?? <int>[],
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
    return (reconstructedBase - baseQuantity).abs() < _saleUnitEpsilon;
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

  // Getters for pagination
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get itemsPerPage => _itemsPerPage;

  // Stock management settings - need to be injected from outside since this provider
  // doesn't have access to GeneralSettingsProvider directly
  bool? _stockEnabled;

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
    _loadProductsFromHive();
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
    if (stockTaxRate != null && stockTaxRate.isNotEmpty) {
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

  double _resolveMrp({
    required GetProduct product,
    Stock? selectedStock,
    double? fallbackMrp,
  }) {
    return _parseAmount(selectedStock?.mrp) ??
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

  double _resolveUnitPrice({
    required GetProduct product,
    required num quantity,
    Stock? selectedStock,
    double? fallbackPrice,
  }) {
    final wholesalePrice = _resolveWholesalePrice(selectedStock);
    if (wholesalePrice != null &&
        _qualifiesForWholesalePrice(
          quantity: quantity,
          selectedStock: selectedStock,
        )) {
      return wholesalePrice;
    }

    return _parseAmount(selectedStock?.price) ??
        _parseAmount(product.price?.price?.toString()) ??
        fallbackPrice ??
        0.0;
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
      );
    }

    item.mrp = _resolveMrp(
      product: item.product,
      selectedStock: effectiveStock,
      fallbackMrp: item.mrp,
    );

    final effectiveTaxRate = _resolveCartTaxRate(
      item.product,
      selectedStock: effectiveStock,
      fallbackTaxRate: item.taxRate,
    );
    item.taxRate = effectiveTaxRate;
    item.taxAmount = _calculateTaxAmount(item.price ?? 0.0, effectiveTaxRate);
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
    );
  }

  LocalCartItem _cloneLocalCartItem(LocalCartItem item) {
    return LocalCartItem(
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
      saleUnitId: item.saleUnitId,
      saleUnitName: item.saleUnitName,
      saleUnitConversionRate: item.saleUnitConversionRate,
    );
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
  }) {
    final currentProduct = getProductById(product.productId ?? -1) ?? product;
    final currentStocks = currentProduct.stock ?? const <Stock>[];
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
    );

    for (final candidate in candidates) {
      if (remaining <= 0) {
        break;
      }

      final availableQuantity = candidate.quantity ?? 0;
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
          '📦 Remaining quantity $remaining could not be reserved. Sale continues without further stock deduction.');
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
      for (final reservation in sourceReservations) {
        final actualChange = _updateStockQuantityInternal(
          Stock(id: reservation.stockId),
          -reservation.quantity,
          operation,
        );
        final reservedQuantity = actualChange.abs();
        if (reservedQuantity > 0) {
          reappliedReservations.add(
            StockReservation(
              stockId: reservation.stockId,
              quantity: reservedQuantity,
            ),
          );
        }
      }
      return reappliedReservations;
    }

    return _reserveStockForSelection(
      product: item.product,
      quantity: item.quantity,
      selectedStock: item.selectedStock,
      stockGroupIds: item.stockGroupIds,
      operation: operation,
    );
  }

  int _findCartItemIndex(
    int productId, {
    Stock? selectedStock,
    List<int>? stockGroupIds,
    int? saleUnitId,
  }) {
    final normalizedIncomingGroupIds = _normalizeStockGroupIds(stockGroupIds);

    return _cartItems.indexWhere((item) {
      if (item.product.productId != productId) {
        return false;
      }

      if (item.saleUnitId != saleUnitId) {
        return false;
      }

      if (normalizedIncomingGroupIds.isNotEmpty) {
        if (item.stockGroupIds.isNotEmpty) {
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
      num reservedQuantity = 0;

      for (final reservation in item.stockReservations) {
        if (reservation.quantity <= 0) {
          continue;
        }

        final payloadQuantity =
            item.canUseSaleUnitPayloadFor(reservation.quantity)
                ? item.toDisplayQuantity(reservation.quantity)
                : reservation.quantity;
        final payloadPrice = item.canUseSaleUnitPayloadFor(reservation.quantity)
            ? item.toDisplayAmount(item.price)
            : item.price;
        final payloadMrp = item.canUseSaleUnitPayloadFor(reservation.quantity)
            ? item.toDisplayAmount(item.mrp)
            : item.mrp;

        items.add({
          'product_id': item.product.productId,
          'quantity': payloadQuantity,
          'price': payloadPrice,
          'mrp': payloadMrp,
          'stock_id': reservation.stockId,
          if (item.canUseSaleUnitPayloadFor(reservation.quantity))
            'sale_unit_id': item.saleUnitId,
        });
        reservedQuantity += reservation.quantity;
      }

      final unreservedQuantity = item.quantity - reservedQuantity;
      if (unreservedQuantity > 0 || item.stockReservations.isEmpty) {
        final baseQuantity =
            item.stockReservations.isEmpty ? item.quantity : unreservedQuantity;
        final canUseSaleUnitPayload =
            item.canUseSaleUnitPayloadFor(baseQuantity);

        items.add({
          'product_id': item.product.productId,
          'quantity': canUseSaleUnitPayload
              ? item.toDisplayQuantity(baseQuantity)
              : baseQuantity,
          'price': canUseSaleUnitPayload
              ? item.toDisplayAmount(item.price)
              : item.price,
          'mrp':
              canUseSaleUnitPayload ? item.toDisplayAmount(item.mrp) : item.mrp,
          'stock_id':
              item.stockReservations.isEmpty ? item.selectedStock?.id : null,
          if (canUseSaleUnitPayload) 'sale_unit_id': item.saleUnitId,
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

  // Initialize the confirmed orders box safely
  Future<void> _initConfirmedOrdersBox() async {
    try {
      if (!Hive.isBoxOpen('confirmed_orders')) {
        _confirmedOrdersBox =
            await Hive.openBox<HiveSavedOrder>('confirmed_orders');
      } else {
        _confirmedOrdersBox = Hive.box<HiveSavedOrder>('confirmed_orders');
      }
      _isConfirmedBoxInitialized = true;
      _loadConfirmedOrdersFromHive();
    } catch (e) {
      debugPrint("Error initializing confirmed orders box: $e");
      _isConfirmedBoxInitialized = false;
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
        ));
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading confirmed orders: $e");
    }
  }

  // Save confirmed orders to Hive
  void _saveConfirmedOrdersToHive() {
    if (!_isConfirmedBoxInitialized) {
      _initConfirmedOrdersBox().then((_) {
        _saveConfirmedOrdersToHive();
      });
      return;
    }

    try {
      _confirmedOrdersBox.clear();
      for (var order in _confirmedOrders) {
        final hiveItems = order.items.map(_buildHiveCartItem).toList();

        final hiveSavedOrder = HiveSavedOrder(
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
        );

        _confirmedOrdersBox.add(hiveSavedOrder);
      }
    } catch (e) {
      debugPrint("Error saving confirmed orders: $e");
    }
  }

  // Load products from Hive
  void _loadProductsFromHive() {
    try {
      final boxLen = _productsBox.length;
      debugPrint(
          "📦 [Hive] Loading products from box 'products' (len=$boxLen)...");
      _products = _productsBox.values.map((hiveProduct) {
        final jsonData = json.decode(hiveProduct.serializedData.value);
        return GetProduct.fromJson(jsonData);
      }).toList();
      _filteredProducts = List.from(_products);
      _rebuildBarcodeIndex();
      debugPrint(
          "✅ [Hive] Loaded products into provider: total=${_products.length}, filtered=${_filteredProducts.length}");
      notifyListeners();
    } catch (e) {
      debugPrint("❌ [Hive] Error loading products from box: $e");
    }
  }

  // Load cart items from Hive
  void _loadCartFromHive() {
    _cartItems.clear();
    for (var hiveCartItem in _cartItemsBox.values) {
      _cartItems.add(_buildLocalCartItemFromHive(hiveCartItem));
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
      );
      _savedOrders.add(savedOrder);
      debugPrint(
          "  #$idx ↪️ Loaded SavedOrder id=${savedOrder.id}, num=${savedOrder.orderNumber}, status=${savedOrder.status}, tableId=${savedOrder.tableId}, items=${savedOrder.items.length}");
    }
    notifyListeners();
  }

  // Save products to Hive
  void _saveProductsToHive() {
    final sw = Stopwatch()..start();
    final beforeLen = _productsBox.length;
    debugPrint(
        "📝 [Hive] Saving products to box 'products' (beforeLen=$beforeLen)...");
    _productsBox.clear();
    int saved = 0;
    for (var product in _products) {
      try {
        final hiveProduct = HiveProduct(
          productId: product.productId,
          categoryId: product.categoryId,
          productName: product.productName,
          barcode: product.barcode,
          serializedData: HiveStringValue(json.encode(product.toJson())),
        );
        _productsBox.add(hiveProduct);
        saved++;
      } catch (e) {
        debugPrint(
            "❌ [Hive] Failed to serialize/save productId=${product.productId}: $e");
      }
    }
    sw.stop();
    debugPrint(
        "✅ [Hive] Saved $saved/${_products.length} products (afterLen=${_productsBox.length}) in ${sw.elapsedMilliseconds}ms");
  }

  // Save cart items to Hive
  void _saveCartToHive() {
    debugPrint(
        "💾 [Hive] Persisting ${_cartItems.length} cart items to 'cart_items' box...");
    _cartItemsBox.clear();
    int idx = 0;
    for (var cartItem in _cartItems) {
      idx++;
      final hiveCartItem = _buildHiveCartItem(cartItem);
      _cartItemsBox.add(hiveCartItem);
      debugPrint(
          "  #$idx ✅ Cart item productId=${cartItem.product.productId}, qty=${cartItem.quantity}, price=${cartItem.price}, mrp=${cartItem.mrp}, taxRate=${cartItem.taxRate}, stockId=${cartItem.selectedStock?.id}");
    }
    debugPrint(
        "✅ [Hive] Cart persistence complete. Box 'cart_items' now has ${_cartItemsBox.length} entries");
  }

  // Save orders to Hive
  void _saveSavedOrdersToHive() {
    debugPrint(
        "💾 [Hive] Persisting ${_savedOrders.length} saved orders to 'saved_orders' box...");
    _savedOrdersBox.clear();
    int idx = 0;
    for (var order in _savedOrders) {
      idx++;
      final hiveItems = order.items.map(_buildHiveCartItem).toList();

      final hiveSavedOrder = HiveSavedOrder(
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
      );

      _savedOrdersBox.add(hiveSavedOrder);
      debugPrint(
          "  #$idx ✅ Saved order id=${order.id}, num=${order.orderNumber}, status=${order.status}, tableId=${order.tableId}, items=${order.items.length}");
    }
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
    _products = products;
    // Initially, set filtered products same as the full list.
    _filteredProducts = List.from(_products);
    _rebuildBarcodeIndex();
    _saveProductsToHive();
    notifyListeners();
  }

  /// Fetch products from API with pagination
  Future<void> fetchProductsFromAPI({
    bool refresh = false,
    Function(int total, int current)? onProgress,
    bool sellableOnly = false,
  }) async {
    List<GetProduct> allProducts = [];
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
          // if (activeStoreId != null) {
          //   queryParams['store_id'] = activeStoreId.toString();
          // }
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
      _filteredProducts = List.from(_products);
      _rebuildBarcodeIndex();
      _updatePagination();
      _saveProductsToHive();
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
      result = result
          .where((p) => (p.productName ?? '')
              .toLowerCase()
              .contains(filterName.toLowerCase()))
          .toList();
    }

    if (filterBarcode != null && filterBarcode.isNotEmpty) {
      result = result
          .where((p) =>
              p.barcode != null &&
              p.barcode!.toLowerCase().contains(filterBarcode.toLowerCase()))
          .toList();
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
    return _filteredProducts
        .where((p) =>
            (p.productName ?? '').toLowerCase().contains(query.toLowerCase()))
        .toList();
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
      // If the product does not exist, add it to the first position in the list
      _products.insert(0, product);
      _rebuildBarcodeIndex();
      _saveProductsToHive();
      notifyListeners(); // Notify listeners about the change
      debugPrint("✅ Product added to local storage successfully");
    } else {
      // Optionally, you can update the existing product if needed
      _products[index] = product; // Update the existing product
      _rebuildBarcodeIndex();
      _saveProductsToHive();
      notifyListeners(); // Notify listeners about the change
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

            debugPrint(
                "📦 Updated stock in product list: ${product.productName}");

            if (persistProducts) {
              _saveProductsToHive();
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
  void addToCart({
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
      product = _products.firstWhere((p) => p.productId == productId);
    }

    if (product == null) {
      debugPrint("❌ Cannot add to cart: product is null");
      return;
    }

    final cartQuantity = quantity ?? 1;
    final normalizedStockGroupIds = _normalizeStockGroupIds(stockGroupIds);

    int index = _findCartItemIndex(
      product.productId!,
      selectedStock: selectedStock,
      stockGroupIds: normalizedStockGroupIds,
      saleUnitId: saleUnitId,
    );

    bool didMutateStock = false;

    if (index != -1) {
      debugPrint("📝 Product already in cart - updating quantity");

      final existingItem = _cartItems[index];
      if (normalizedStockGroupIds.isNotEmpty &&
          existingItem.stockGroupIds.isEmpty) {
        existingItem.stockGroupIds = List<int>.from(normalizedStockGroupIds);
      }

      // STOCK DEDUCTION: Deduct the additional quantity being added
      if (isStockEnabled && selectedStock != null) {
        final reservationDeltas = _reserveStockForSelection(
          product: product,
          quantity: cartQuantity,
          selectedStock: selectedStock,
          stockGroupIds: existingItem.stockGroupIds,
          operation: "ADD_TO_CART_INCREMENT",
        );
        _mergeReservationDeltas(existingItem, reservationDeltas);
        didMutateStock = reservationDeltas.isNotEmpty;
      }

      // If the product already exists in cart with the same stock, just update the quantity and price
      existingItem.quantity +=
          cartQuantity; // Increment by the specified quantity

      if (price != null) {
        existingItem.price = price;
        existingItem.isManualPriceOverride = markPriceAsManualOverride;
        debugPrint("💰 Using explicit price: $price");
      }

      if (mrp != null) {
        existingItem.mrp = mrp;
        debugPrint("💰 Using explicit MRP: $mrp");
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
        );
        didMutateStock = initialStockReservations.isNotEmpty;
      }

      // Safely handle null product price when adding new cart item
      final double productPrice = price ??
          _resolveUnitPrice(
            product: product,
            quantity: cartQuantity,
            selectedStock: selectedStock,
          );
      final double productMrp = mrp ??
          _resolveMrp(
            product: product,
            selectedStock: selectedStock,
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
            saleUnitId: saleUnitId,
            saleUnitName: saleUnitName,
            saleUnitConversionRate: saleUnitConversionRate,
          ));
    }

    resetSelectedProduct();
    if (didMutateStock) {
      _saveProductsToHive();
    }
    _saveCartToHive();
    notifyListeners();

    debugPrint("✅ ADD TO CART COMPLETED");
  }

  /// Removes the product with [productId] from the local cart.
  /// Also restores stock quantity when stock management is enabled.
  List<LocalCartItem> getCartItems() {
    return _cartItems;
  }

  /// Updates the comment on a specific cart item by product ID and stock.
  void updateCartItemComment(
      int productId, Stock? selectedStock, String? comment,
      {List<int>? stockGroupIds, int? saleUnitId}) {
    final index = _findCartItemIndex(
      productId,
      selectedStock: selectedStock,
      stockGroupIds: stockGroupIds,
      saleUnitId: saleUnitId,
    );
    if (index != -1) {
      _cartItems[index].comment = comment;
      _saveCartToHive();
      notifyListeners();
    }
  }

  void removeFromCart(int productId, Stock? selectedStock,
      {List<int>? stockGroupIds, int? saleUnitId}) {
    debugPrint("🗑️ REMOVE FROM CART STARTED");
    debugPrint("Product ID: $productId");
    debugPrint("Selected Stock: ${selectedStock?.id}");
    debugPrint("Stock Management Enabled: $isStockEnabled");

    final index = _findCartItemIndex(
      productId,
      selectedStock: selectedStock,
      stockGroupIds: stockGroupIds,
      saleUnitId: saleUnitId,
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
        _saveProductsToHive();
      }

      _cartItems.removeAt(index);
      _saveCartToHive();
      notifyListeners();

      debugPrint("✅ REMOVE FROM CART COMPLETED");
    } else {
      debugPrint("⚠️ Cart item not found for removal");
    }
  }

  void updateItemPrice(int productId, Stock? selectedStock, double newPrice,
      {List<int>? stockGroupIds, int? saleUnitId}) {
    final index = _findCartItemIndex(
      productId,
      selectedStock: selectedStock,
      stockGroupIds: stockGroupIds,
      saleUnitId: saleUnitId,
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
      {List<int>? stockGroupIds, int? saleUnitId}) {
    final index = _findCartItemIndex(
      productId,
      selectedStock: selectedStock,
      stockGroupIds: stockGroupIds,
      saleUnitId: saleUnitId,
    );

    if (index != -1) {
      _cartItems[index].mrp = newMrp;
      _saveCartToHive();
      notifyListeners();
    }
  }

  void updateItemTax(int productId, Stock? selectedStock, double newTaxRate,
      {List<int>? stockGroupIds, int? saleUnitId}) {
    final index = _findCartItemIndex(
      productId,
      selectedStock: selectedStock,
      stockGroupIds: stockGroupIds,
      saleUnitId: saleUnitId,
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
              );
        if (updatedProduct != null) {
          _cartItems[i] = LocalCartItem(
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
            saleUnitId: item.saleUnitId,
            saleUnitName: item.saleUnitName,
            saleUnitConversionRate: item.saleUnitConversionRate,
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
                );
          if (updatedProduct != null) {
            order.items[i] = LocalCartItem(
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
              saleUnitId: orderItem.saleUnitId,
              saleUnitName: orderItem.saleUnitName,
              saleUnitConversionRate: orderItem.saleUnitConversionRate,
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
              );
        _cartItems[i] = LocalCartItem(
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
          saleUnitId: item.saleUnitId,
          saleUnitName: item.saleUnitName,
          saleUnitConversionRate: item.saleUnitConversionRate,
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
                );
          order.items[i] = LocalCartItem(
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
            saleUnitId: orderItem.saleUnitId,
            saleUnitName: orderItem.saleUnitName,
            saleUnitConversionRate: orderItem.saleUnitConversionRate,
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
      {List<int>? stockGroupIds, int? saleUnitId}) {
    debugPrint("➖ DECREMENT CART ITEM STARTED");
    debugPrint("Product ID: $productId");
    debugPrint("Selected Stock: ${selectedStock?.id}");
    debugPrint("Stock Management Enabled: $isStockEnabled");

    final index = _findCartItemIndex(
      productId,
      selectedStock: selectedStock,
      stockGroupIds: stockGroupIds,
      saleUnitId: saleUnitId,
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
          _saveProductsToHive();
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
          _saveProductsToHive();
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

    // STOCK RESTORATION: Restore only the actually-deducted amounts
    if (isStockEnabled) {
      for (var cartItem in _cartItems) {
        if (cartItem.stockDeducted > 0) {
          _restoreStockReservations(
              cartItem, cartItem.stockDeducted, "CLEAR_CART");
        }
      }
      _saveProductsToHive();
    }

    _cartItems.clear();
    _cartItemsBox.clear();
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
    _cartItemsBox.clear();
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
    _products = [];
    _filteredProducts = [];
    _productsByBarcode.clear();
    _productsBox.clear();
    notifyListeners();
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
    _saveProductsToHive();
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
      _saveProductsToHive();

      // Update filtered products if needed
      refreshProducts();

      debugPrint("✅ MANUAL STOCK UPDATE COMPLETED");
    } else {
      debugPrint("❌ Product not found for stock update: $productId");
    }
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
          _saveProductsToHive();

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
    _saveProductsToHive();
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
    String? customerVatNumber,
    String? customerCrNumber,
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
      alternatePhone: null, // Add if needed
      address:
          address, // Pass address if available, or update if passed as param
      deliveryCharge: deliveryCharge,
      customerVatNumber: customerVatNumber,
      customerCrNumber: customerCrNumber,
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
        _saveProductsToHive();
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
        _saveProductsToHive();
      }

      // Set current order
      _currentOrder = order;

      _saveCartToHive();
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading order: $e");
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
    String? customerVatNumber,
    String? customerCrNumber,
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
        alternatePhone: _savedOrders[index].alternatePhone,
        address: address ?? _savedOrders[index].address,
        deliveryCharge: deliveryCharge ?? _savedOrders[index].deliveryCharge,
        customerVatNumber:
            customerVatNumber ?? _savedOrders[index].customerVatNumber,
        customerCrNumber:
            customerCrNumber ?? _savedOrders[index].customerCrNumber,
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

  /// Gets a list of stock options for a product with qty > 0.
  /// When stock management is enabled only positive-quantity entries are
  /// relevant for selection.  If every entry has qty <= 0 the caller
  /// should fall back to the product's base price (no stock selected).
  List<Stock> getStockOptions(GetProduct product) {
    if (product.stock == null) {
      return [];
    }
    return product.stock!
        .where((stock) => stock.quantity != null && stock.quantity! > 0)
        .toList();
  }

  List<Stock> getStockOptionsForStore(
    GetProduct product, {
    int? activeStoreId,
    String? activeStoreName,
  }) {
    final availableStocks = getStockOptions(product);
    if (availableStocks.isEmpty) {
      // No stock entries with quantity data at all — return empty so caller
      // falls back to base product pricing (non-stock mode).
      return const <Stock>[];
    }

    final normalizedActiveStoreName = activeStoreName?.trim().toLowerCase();
    final hasActiveStoreId = activeStoreId != null;
    final hasActiveStoreName = normalizedActiveStoreName != null &&
        normalizedActiveStoreName.isNotEmpty;

    if (!hasActiveStoreId && !hasActiveStoreName) {
      return availableStocks;
    }

    return availableStocks.where((stock) {
      if (hasActiveStoreId) {
        // Primary matching by store_id (API provides this reliably)
        return stock.storeId == activeStoreId;
      }

      // Fallback matching only when active store id is unavailable
      if (hasActiveStoreName) {
        final normalizedStockStoreName = stock.storeName?.trim().toLowerCase();
        return normalizedStockStoreName == normalizedActiveStoreName;
      }

      return false;
    }).toList();
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
  }) {
    final currentProduct = getProductById(product.productId ?? -1) ?? product;
    final currentStocks = currentProduct.stock ?? const <Stock>[];
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
  }) {
    final currentProduct = getProductById(product.productId ?? -1) ?? product;
    final excludedStockIds = getSelectionStockIds(
      selectedStock: selectedStock,
      stockGroupIds: stockGroupIds,
    ).toSet();

    final availableStocks = getStockOptionsForStore(
      currentProduct,
      activeStoreId: activeStoreId,
      activeStoreName: activeStoreName,
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
      {List<int>? stockGroupIds, int? saleUnitId}) {
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
    );

    if (index == -1) {
      debugPrint("⚠️ Cart item not found – cannot set quantity");
      return;
    }

    final currentQuantity = _cartItems[index].quantity;
    final num difference =
        newQuantity - currentQuantity; // positive if increasing

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

      _saveProductsToHive();
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
        _saveProductsToHive();
      }
      _cartItems.removeAt(index);
    } else {
      // Update quantity
      _cartItems[index].quantity = newQuantity;
      _refreshCartItemPricing(_cartItems[index]);
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
