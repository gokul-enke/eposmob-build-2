import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/quantity_input_helper.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_title.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/supplier.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/category_list_scope.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/stock_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/sync_provider.dart';
import 'package:pos_machine/providers/supplier_provider.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'stock_responsive.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // Added for Timer
import 'dart:convert';
import 'package:pos_machine/widgets/add_product_modal.dart';
import 'package:pos_machine/components/build_dynamic_payment_selector.dart';
import 'package:pos_machine/components/build_stock_confirmation_dialog.dart';
import 'package:pos_machine/screens/suppliers/add_supplier_modal.dart';
import 'package:pos_machine/widgets/product_details_dialog.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:websafe_svg/websafe_svg.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';

/// Hive box name for draft stock items persistence
const String _kDraftStockBoxName = 'draft_stock_items';

class StockItem {
  String barcode;
  String category;
  String product;
  String quantity;
  String purchaseQty;
  String salePrice;
  String mrp;
  String wholesale;
  String purchaseRate;
  String unit;
  String rack;
  DateTime expDate;

  String batchNumber;
  String supplier;
  int supplierId;
  GetProduct? productData;
  int? productVariantId;
  String? variantName;
  Category? categoryData;
  Supplier? supplierData;
  bool isExpanded; // Add this field for expandable functionality
  bool isEditing; // Add this field to toggle edit mode for already-added rows
  String? selectedUnit; // Add selected unit for dropdown
  String? selectedPurchaseUnit;
  String? purchaseUnitName;
  String? purchaseConversionRate;
  String? selectedRack; // Add selected rack for dropdown
  bool isSuccessfullyAdded; // Add this field to track successful addition
  Map<String, dynamic>? apiResponse; // Add this field to store API response
  bool taxInclude; // Add this field for tax inclusion toggle

  String retailPriceTax; // Add this for retail price with tax
  String wholesalePriceTax; // Add this for wholesale price with tax
  Map<String, dynamic>? calculatedTaxData; // Store calculated tax data
  bool isHidden; // Add this field to track if item is hidden (soft delete)

  StockItem({
    this.barcode = '',
    this.category = '',
    this.product = '',
    this.quantity = '1',
    this.purchaseQty = '1',
    this.salePrice = '0',
    this.mrp = '0',
    this.wholesale = '',
    this.purchaseRate = '0',
    this.unit = '',
    this.rack = '',
    DateTime? expDate,
    this.batchNumber = '',
    this.supplier = '',
    this.supplierId = 1,
    this.productData,
    this.productVariantId,
    this.variantName,
    this.categoryData,
    this.supplierData,
    this.isExpanded = false,
    this.isEditing = false,
    this.selectedUnit,
    this.selectedPurchaseUnit,
    this.purchaseUnitName,
    this.purchaseConversionRate,
    this.selectedRack,
    this.isSuccessfullyAdded = false,
    this.apiResponse,
    this.taxInclude = true,
    this.retailPriceTax = '0.00',
    this.wholesalePriceTax = '0.00',
    this.calculatedTaxData,
    this.isHidden = false,
  }) : expDate = expDate ?? DateTime.now().add(const Duration(days: 365));
}

class AddProductStockScreen extends StatefulWidget {
  const AddProductStockScreen({super.key});

  @override
  State<AddProductStockScreen> createState() => _AddProductStockScreenState();
}

class _AddProductStockScreenState extends State<AddProductStockScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final SideBarController sideBarController = Get.put(SideBarController());

  // Hive box for draft persistence
  Box? _draftBox;
  Timer? _draftSaveDebouncer;
  static const Duration _draftSaveDelay = Duration(milliseconds: 500);

  // Header form controllers
  final TextEditingController supplierSearchController =
      TextEditingController();

  // Search controllers for each row
  final Map<int, TextEditingController> categorySearchControllers = {};
  final Map<int, TextEditingController> productSearchControllers = {};
  final Map<int, TextEditingController> barcodeControllers = {};
  final Map<int, TextEditingController> quantityControllers = {};
  final Map<int, TextEditingController> purchaseQtyControllers = {};

  // Expanded field controllers for each row
  final Map<int, TextEditingController> purchaseRateControllers = {};
  final Map<int, TextEditingController> retailPriceControllers = {};
  final Map<int, TextEditingController> mrpControllers = {};
  final Map<int, TextEditingController> wholesaleControllers = {};
  final Map<int, TextEditingController> batchNumberControllers = {};
  // Search controllers for expanded dropdowns
  final Map<int, TextEditingController> unitSearchControllers = {};
  final Map<int, TextEditingController> purchaseUnitSearchControllers = {};
  final Map<int, TextEditingController> rackSearchControllers = {};

  // Focus nodes for barcode and quantity fields
  final Map<int, FocusNode> barcodeFocusNodes = {};
  final Map<int, FocusNode> quantityFocusNodes = {};

  // Selected header values
  GetStoreModelData? selectedStore;
  DateTime selectedDate = DateTime.now();
  DateTime selectedPurchaseDate = DateTime.now();
  Supplier? selectedSupplier;

  // Stock items list
  List<StockItem> stockItems = [StockItem()]; // Start with one empty row

  bool _isLoading = false;

  // Payment method state - using dynamic payment methods from API
  DynamicPaymentData paymentData = DynamicPaymentData();
  List<MasterDataValue> _paymentMethods = [];
  bool _isLoadingPaymentMethods = false;
  double totalStockValue = 0.0;
  bool _needsRecalculation =
      false; // Flag to track if total needs recalculation

  // Debounce timer for quantity input
  Timer? _quantityDebounceTimer;
  Timer? _inlineEditDebounceTimer;
  // Cache for filtered products per category
  final Map<int?, List<GetProduct>> _filteredProductsCache = {};

  // Performance optimization: Cache visible items and index mapping
  final List<StockItem> _cachedVisibleItems = [];
  final Map<int, int> _visibleToOriginalIndexMap = {};
  bool _needsIndexRebuild = true;
  // Track which item index is being edited (null if adding new)
  int? _editingItemIndex;

  bool _variantFeatureEnabled({bool listen = false}) =>
      Provider.of<AppSettingsProvider>(context, listen: listen)
              .appSettings
              ?.productVariantEnabled ??
          false;

  bool _requiresVariant(StockItem item) =>
      _variantFeatureEnabled() &&
      item.productData != null &&
      item.productData!.hasVariants;

  ProductVariant? _selectedVariant(StockItem item) {
    final variantId = item.productVariantId;
    if (variantId == null || item.productData == null) return null;
    for (final variant in item.productData!.activeVariants) {
      if (variant.id == variantId) return variant;
    }
    return null;
  }

  ProductVariant? _variantForBarcode(GetProduct product, String barcode) {
    if (!_variantFeatureEnabled()) return null;
    final normalized = barcode.trim();
    if (normalized.isEmpty) return null;
    for (final variant in product.activeVariants) {
      if ((variant.barcode ?? '').trim() == normalized) return variant;
    }
    return null;
  }

  String _variantLabel(ProductVariant variant) {
    final attributes = variant.formattedAttributes.trim();
    if (attributes.isNotEmpty) return attributes;
    final sku = variant.sku?.trim() ?? '';
    return sku.isNotEmpty ? sku : 'Variant ${variant.id}';
  }

  void _applyVariantToItem(
    int index,
    ProductVariant? variant, {
    bool updatePending = true,
  }) {
    final item = stockItems[index];
    final product = item.productData;
    if (product == null) return;

    item.productVariantId = variant?.id;
    item.variantName = variant == null ? null : _variantLabel(variant);

    final productPrice =
        double.tryParse(product.price?.price?.toString() ?? '') ?? 0;
    final productMrp = double.tryParse(product.mrp?.toString() ?? '');
    final productPurchase =
        double.tryParse(product.purchasePrice?.toString() ?? '');

    item.barcode = variant?.barcode?.trim().isNotEmpty == true
        ? variant!.barcode!.trim()
        : (product.barcode ?? '');
    item.salePrice =
        (variant?.price ?? productPrice).toStringAsFixed(2);
    item.mrp =
        (variant?.mrp ?? productMrp ?? variant?.price ?? productPrice)
            .toStringAsFixed(2);
    item.purchaseRate =
        (variant?.purchasePrice ?? productPurchase ?? 0).toStringAsFixed(2);

    _getBarcodeController(index).text = item.barcode;
    _getRetailPriceController(index).text = item.salePrice;
    _getMrpController(index).text = item.mrp;
    _getPurchaseRateController(index).text = item.purchaseRate;

    _markForRecalculation();
    if (updatePending) _updatePendingStockItem(index);
  }

  // Clear product cache when category changes
  void _clearProductCache() {
    _filteredProductsCache.clear();
  }

  // Dispose and remove all controllers and focus nodes associated with a row index
  void _disposeRowResources(int index) {
    // Text controllers
    if (categorySearchControllers.containsKey(index)) {
      try {
        categorySearchControllers[index]!.dispose();
      } catch (_) {}
      categorySearchControllers.remove(index);
    }
    if (productSearchControllers.containsKey(index)) {
      try {
        productSearchControllers[index]!.dispose();
      } catch (_) {}
      productSearchControllers.remove(index);
    }
    if (barcodeControllers.containsKey(index)) {
      try {
        barcodeControllers[index]!.dispose();
      } catch (_) {}
      barcodeControllers.remove(index);
    }
    if (quantityControllers.containsKey(index)) {
      try {
        quantityControllers[index]!.dispose();
      } catch (_) {}
      quantityControllers.remove(index);
    }
    if (purchaseQtyControllers.containsKey(index)) {
      try {
        purchaseQtyControllers[index]!.dispose();
      } catch (_) {}
      purchaseQtyControllers.remove(index);
    }
    if (purchaseRateControllers.containsKey(index)) {
      try {
        purchaseRateControllers[index]!.dispose();
      } catch (_) {}
      purchaseRateControllers.remove(index);
    }
    if (retailPriceControllers.containsKey(index)) {
      try {
        retailPriceControllers[index]!.dispose();
      } catch (_) {}
      retailPriceControllers.remove(index);
    }
    if (mrpControllers.containsKey(index)) {
      try {
        mrpControllers[index]!.dispose();
      } catch (_) {}
      mrpControllers.remove(index);
    }
    if (wholesaleControllers.containsKey(index)) {
      try {
        wholesaleControllers[index]!.dispose();
      } catch (_) {}
      wholesaleControllers.remove(index);
    }
    if (batchNumberControllers.containsKey(index)) {
      try {
        batchNumberControllers[index]!.dispose();
      } catch (_) {}
      batchNumberControllers.remove(index);
    }
    if (unitSearchControllers.containsKey(index)) {
      try {
        unitSearchControllers[index]!.dispose();
      } catch (_) {}
      unitSearchControllers.remove(index);
    }
    if (purchaseUnitSearchControllers.containsKey(index)) {
      try {
        purchaseUnitSearchControllers[index]!.dispose();
      } catch (_) {}
      purchaseUnitSearchControllers.remove(index);
    }
    if (rackSearchControllers.containsKey(index)) {
      try {
        rackSearchControllers[index]!.dispose();
      } catch (_) {}
      rackSearchControllers.remove(index);
    }

    // Focus nodes
    if (barcodeFocusNodes.containsKey(index)) {
      try {
        barcodeFocusNodes[index]!.dispose();
      } catch (_) {}
      barcodeFocusNodes.remove(index);
    }
    if (quantityFocusNodes.containsKey(index)) {
      try {
        quantityFocusNodes[index]!.dispose();
      } catch (_) {}
      quantityFocusNodes.remove(index);
    }
  }

  // Rebuild index cache for performance optimization
  void _rebuildIndexCache() {
    _cachedVisibleItems.clear();
    _visibleToOriginalIndexMap.clear();

    int visibleIndex = 0;
    for (int i = 0; i < stockItems.length; i++) {
      if (!stockItems[i].isHidden && stockItems[i].isSuccessfullyAdded) {
        _cachedVisibleItems.add(stockItems[i]);
        _visibleToOriginalIndexMap[visibleIndex] = i;
        visibleIndex++;
      }
    }
    _needsIndexRebuild = false;
  }

  // Mark index cache as dirty when stock items change
  void _markIndexCacheDirty() {
    _needsIndexRebuild = true;
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
    _initHiveBox();
    // Load pending items after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadItemsSequentially();
    });
    // Tax calculation will be triggered when product data is available
    // No need to calculate tax for empty stock items in initState
  }

  /// Load items - pending items from StockProvider (persisted in Hive)
  Future<void> _loadItemsSequentially() async {
    final stockProvider = Provider.of<StockProvider>(context, listen: false);

    // Initialize StockProvider's Hive to load persisted pending items
    await stockProvider.initHive();

    final pendingItems = stockProvider.pendingStockItems;

    if (pendingItems.isNotEmpty) {
      // Load pending items - these are items that were successfully added and persisted
      _loadPendingStockItems();
      debugPrint('✅ Loaded ${pendingItems.length} pending items from Hive');
    } else {
      debugPrint('📂 No pending stock items found');
    }
  }

  /// Initialize Hive box for draft persistence
  Future<void> _initHiveBox() async {
    try {
      if (!Hive.isBoxOpen(_kDraftStockBoxName)) {
        _draftBox = await Hive.openBox(_kDraftStockBoxName);
      } else {
        _draftBox = Hive.box(_kDraftStockBoxName);
      }
      debugPrint('✅ Draft stock Hive box initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize draft Hive box: $e');
    }
  }

  /// Save current draft stock items to Hive (debounced)
  void _saveDraftToHive() {
    _draftSaveDebouncer?.cancel();
    _draftSaveDebouncer = Timer(_draftSaveDelay, () async {
      if (_draftBox == null || !_draftBox!.isOpen) return;

      try {
        // Only save items that are not yet successfully added (drafts)
        final draftItems = stockItems
            .where(
                (item) => !item.isSuccessfullyAdded && item.productData != null)
            .map((item) => _stockItemToMap(item))
            .toList();

        await _draftBox!.put('draft_items', draftItems);
        await _draftBox!.put('supplier_id', selectedSupplier?.id);
        await _draftBox!.put('store_id', selectedStore?.id);
        await _draftBox!.put('selected_date', selectedDate.toIso8601String());
        await _draftBox!
            .put('purchase_date', selectedPurchaseDate.toIso8601String());

        debugPrint('💾 Saved ${draftItems.length} draft items to Hive');
      } catch (e) {
        debugPrint('❌ Failed to save draft to Hive: $e');
      }
    });
  }

  /// Load draft stock items from Hive
  Future<void> _loadDraftFromHive() async {
    if (_draftBox == null || !_draftBox!.isOpen) {
      // Wait for box to be ready
      await Future.delayed(const Duration(milliseconds: 100));
      if (_draftBox == null || !_draftBox!.isOpen) {
        debugPrint('⏭️ Skipping draft load - Hive box not ready');
        return;
      }
    }

    try {
      final draftItems = _draftBox!.get('draft_items') as List<dynamic>?;
      if (draftItems == null || draftItems.isEmpty) {
        debugPrint('⏭️ No draft items found in Hive');
        return;
      }

      debugPrint('📂 Loading ${draftItems.length} draft items from Hive');

      // Only load if we don't have any items with productData
      final hasExistingProducts =
          stockItems.any((item) => item.productData != null);
      if (hasExistingProducts) {
        debugPrint('⏭️ Skipping draft load - existing items found');
        return;
      }

      // Convert draft items to StockItems first
      final List<StockItem> loadedItems = [];
      for (final itemMap in draftItems) {
        if (itemMap is Map) {
          final stockItem = _mapToStockItem(Map<String, dynamic>.from(itemMap));
          // Only add items that have actual product data
          if (stockItem.productData != null) {
            loadedItems.add(stockItem);
          }
        }
      }

      // Only update UI if we have valid items to load
      if (loadedItems.isEmpty) {
        debugPrint('⏭️ No valid draft items with product data');
        return;
      }

      setState(() {
        // Clear existing empty rows and replace with loaded items
        stockItems.clear();
        stockItems.addAll(loadedItems);

        // Add one empty row for new entries
        stockItems.add(StockItem());

        _markIndexCacheDirty();
      });

      // Update controllers
      _updateControllersFromStockItems();

      debugPrint('✅ Loaded ${loadedItems.length} draft items from Hive');
    } catch (e) {
      debugPrint('❌ Failed to load draft from Hive: $e');
    }
  }

  /// Convert StockItem to Map for Hive storage
  Map<String, dynamic> _stockItemToMap(StockItem item) {
    return {
      'barcode': item.barcode,
      'category': item.category,
      'product': item.product,
      'quantity': item.quantity,
      'purchaseQty': item.purchaseQty,
      'salePrice': item.salePrice,
      'mrp': item.mrp,
      'wholesale': item.wholesale,
      'purchaseRate': item.purchaseRate,
      'unit': item.unit,
      'rack': item.rack,
      'expDate': item.expDate.toIso8601String(),
      'batchNumber': item.batchNumber,
      'selectedUnit': item.selectedUnit,
      'selectedPurchaseUnit': item.selectedPurchaseUnit,
      'purchaseUnitName': item.purchaseUnitName,
      'purchaseConversionRate': item.purchaseConversionRate,
      'selectedRack': item.selectedRack,
      'taxInclude': item.taxInclude,
      'productId': item.productData?.productId,
      'productVariantId':
          _variantFeatureEnabled() ? item.productVariantId : null,
      'variantName': item.variantName,
      'categoryId': item.categoryData?.categoryId,
    };
  }

  /// Convert Map to StockItem from Hive storage
  StockItem _mapToStockItem(Map<String, dynamic> map) {
    final stockItem = StockItem(
      barcode: map['barcode'] ?? '',
      category: map['category'] ?? '',
      product: map['product'] ?? '',
      quantity: map['quantity'] ?? '1',
      purchaseQty: map['purchaseQty'] ?? '1',
      salePrice: map['salePrice'] ?? '0',
      mrp: map['mrp'] ?? '0',
      wholesale: map['wholesale'] ?? '',
      purchaseRate: map['purchaseRate'] ?? '0',
      unit: map['unit'] ?? '',
      rack: map['rack'] ?? '',
      expDate: map['expDate'] != null
          ? DateTime.tryParse(map['expDate']) ??
              DateTime.now().add(const Duration(days: 365))
          : DateTime.now().add(const Duration(days: 365)),
      batchNumber: map['batchNumber'] ?? '',
      selectedUnit: map['selectedUnit'],
      selectedPurchaseUnit: map['selectedPurchaseUnit'],
      purchaseUnitName: map['purchaseUnitName'],
      purchaseConversionRate: map['purchaseConversionRate'],
      selectedRack: map['selectedRack'],
      taxInclude: map['taxInclude'] ?? true,
      productVariantId: map['productVariantId'] is int
          ? map['productVariantId']
          : int.tryParse(map['productVariantId']?.toString() ?? ''),
      variantName: map['variantName']?.toString(),
    );

    // Try to restore product data
    final productId = map['productId'];
    if (productId != null) {
      try {
        final localProductProvider =
            Provider.of<LocalProductProvider>(context, listen: false);
        final product = localProductProvider.products.firstWhere(
          (p) => p.productId == productId,
          orElse: () => GetProduct(),
        );
        if (product.productId != null) {
          stockItem.productData = product;
        }
      } catch (e) {
        debugPrint('   - Could not restore product data: $e');
      }
    }

    // Try to restore category data
    final categoryId = map['categoryId'];
    if (categoryId != null) {
      try {
        final categoryProvider =
            Provider.of<CategoryProvider>(context, listen: false);
        final categoryList = categoryProvider.purchasableCategories;
        if (categoryList != null) {
          final category = categoryList.firstWhere(
            (c) => c.categoryId == categoryId,
            orElse: () => Category(),
          );
          if (category.categoryId != null) {
            stockItem.categoryData = category;
          }
        }
      } catch (e) {
        debugPrint('   - Could not restore category data: $e');
      }
    }

    // Try to restore unit display name from unit list
    _setUnitDataFromPending(stockItem);

    return stockItem;
  }

  /// Clear draft items from Hive (call after successful sync or reset)
  Future<void> _clearDraftFromHive() async {
    if (_draftBox == null || !_draftBox!.isOpen) return;
    try {
      await _draftBox!.delete('draft_items');
      debugPrint('🗑️ Cleared draft items from Hive');
    } catch (e) {
      debugPrint('❌ Failed to clear draft from Hive: $e');
    }
  }

  /// Set supplier data from pending item
  void _setSupplierDataFromPending(
      StockItem stockItem, Map<String, dynamic> pendingData) {
    try {
      final supplierProvider =
          Provider.of<SupplierProvider>(context, listen: false);
      final supplierId = pendingData['supplierId'];

      if (supplierId != null && supplierProvider.supplierList != null) {
        // Convert supplierId to int if it's not already
        int? id;
        if (supplierId is int) {
          id = supplierId;
        } else {
          id = int.tryParse(supplierId.toString());
        }

        if (id != null) {
          final supplier = supplierProvider.supplierList!.firstWhere(
            (s) => s.id == id,
            orElse: () => supplierProvider.supplierList!.first,
          );

          stockItem.supplierData = supplier;
          selectedSupplier = supplier; // Set the global selected supplier
          debugPrint('   - Supplier data set: ${supplier.name}');
        }
      }
    } catch (e) {
      debugPrint('   - Could not set supplier data: $e');
    }
  }

  @override
  void dispose() {
    // Dispose timers
    _quantityDebounceTimer?.cancel();
    _draftSaveDebouncer?.cancel();

    // Dispose all search controllers safely
    for (var controller in categorySearchControllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing category search controller: $e');
      }
    }
    for (var controller in productSearchControllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing product search controller: $e');
      }
    }
    for (var controller in barcodeControllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing barcode controller: $e');
      }
    }
    for (var controller in quantityControllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing quantity controller: $e');
      }
    }
    for (var controller in purchaseQtyControllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('Error disposing purchase qty controller: $e');
      }
    }

    // Dispose expanded field controllers safely
    for (var controller in purchaseRateControllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing purchase rate controller: $e');
      }
    }
    for (var controller in retailPriceControllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing retail price controller: $e');
      }
    }
    for (var controller in mrpControllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing MRP controller: $e');
      }
    }
    for (var controller in wholesaleControllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing wholesale controller: $e');
      }
    }
    for (var controller in batchNumberControllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing batch number controller: $e');
      }
    }
    for (var controller in unitSearchControllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('Error disposing unit search controller: $e');
      }
    }
    for (var controller in purchaseUnitSearchControllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('Error disposing purchase unit search controller: $e');
      }
    }
    for (var controller in rackSearchControllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('Error disposing rack search controller: $e');
      }
    }

    // Dispose all focus nodes safely
    for (var focusNode in barcodeFocusNodes.values) {
      try {
        focusNode.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing barcode focus node: $e');
      }
    }
    for (var focusNode in quantityFocusNodes.values) {
      try {
        focusNode.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing quantity focus node: $e');
      }
    }

    try {
      supplierSearchController.dispose();
    } catch (e) {
      debugPrint('⚠️ Error disposing supplier search controller: $e');
    }
    super.dispose();
  }

  // Get or create search controller for a specific row
  TextEditingController _getCategorySearchController(int index) {
    if (!categorySearchControllers.containsKey(index)) {
      categorySearchControllers[index] = TextEditingController();
    }
    return categorySearchControllers[index]!;
  }

  TextEditingController _getProductSearchController(int index) {
    if (!productSearchControllers.containsKey(index)) {
      productSearchControllers[index] = TextEditingController();
    }
    return productSearchControllers[index]!;
  }

  TextEditingController _getBarcodeController(int index) {
    if (!barcodeControllers.containsKey(index)) {
      String initialValue = '';
      if (index < stockItems.length) {
        initialValue = stockItems[index].barcode;
      }
      barcodeControllers[index] = TextEditingController(text: initialValue);
    }
    return barcodeControllers[index]!;
  }

  FocusNode _getBarcodeFocusNode(int index) {
    if (!barcodeFocusNodes.containsKey(index)) {
      barcodeFocusNodes[index] = FocusNode();
    }
    return barcodeFocusNodes[index]!;
  }

  TextEditingController _getQuantityController(int index) {
    if (!quantityControllers.containsKey(index)) {
      String initialValue = '1';
      if (index < stockItems.length) {
        initialValue = stockItems[index].quantity;
      }
      quantityControllers[index] = TextEditingController(text: initialValue);
    }
    return quantityControllers[index]!;
  }

  TextEditingController _getPurchaseQtyController(int index) {
    if (!purchaseQtyControllers.containsKey(index)) {
      String initialValue = '1';
      if (index < stockItems.length) {
        initialValue = stockItems[index].purchaseQty;
      }
      purchaseQtyControllers[index] = TextEditingController(text: initialValue);
    }
    return purchaseQtyControllers[index]!;
  }

  FocusNode _getQuantityFocusNode(int index) {
    if (!quantityFocusNodes.containsKey(index)) {
      quantityFocusNodes[index] = FocusNode();
    }
    return quantityFocusNodes[index]!;
  }

  TextEditingController _getPurchaseUnitSearchController(int index) {
    if (!purchaseUnitSearchControllers.containsKey(index)) {
      purchaseUnitSearchControllers[index] = TextEditingController();
    }
    return purchaseUnitSearchControllers[index]!;
  }

  String? _findUnitKeyByUnitName(String? unitName) {
    final normalizedUnit = unitName?.trim().toLowerCase();
    if (normalizedUnit == null || normalizedUnit.isEmpty) {
      return null;
    }

    final purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    final unitList = purchaseProvider.getUnitList;
    if (unitList == null || unitList.isEmpty) {
      return null;
    }

    for (final entry in unitList.entries) {
      if (entry.value.trim().toLowerCase() == normalizedUnit) {
        return entry.key;
      }
    }
    return null;
  }

  SaleUnit? _findMatchingSaleUnit(GetProduct product, String barcode) {
    final normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty) {
      return null;
    }

    for (final saleUnit in product.saleUnits ?? const <SaleUnit>[]) {
      final saleUnitBarcode = saleUnit.barcode?.trim() ?? '';
      if (saleUnitBarcode.isNotEmpty && saleUnitBarcode == normalizedBarcode) {
        return saleUnit;
      }
    }

    return null;
  }

  SaleUnit? _getSelectedPurchaseSaleUnit(StockItem item) {
    final selectedPurchaseUnit = item.selectedPurchaseUnit;
    if (selectedPurchaseUnit == null || selectedPurchaseUnit.isEmpty) {
      return null;
    }

    for (final saleUnit in item.productData?.saleUnits ?? const <SaleUnit>[]) {
      if (saleUnit.id?.toString() == selectedPurchaseUnit) {
        return saleUnit;
      }
    }

    return null;
  }

  List<SaleUnit> _getAvailablePurchaseUnits(StockItem item) {
    return item.productData?.saleUnits ?? const <SaleUnit>[];
  }

  bool _hasPurchaseUnits(StockItem item) {
    return _getAvailablePurchaseUnits(item).isNotEmpty;
  }

  double _parsePositiveDouble(String? value, {double fallback = 0.0}) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) {
      return fallback;
    }
    return parsed;
  }

  String _formatNumber(num value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  void _applyBaseUnitFromProduct(int index, GetProduct product) {
    final unitKey = _findUnitKeyByUnitName(product.unit);
    if (unitKey != null && unitKey.isNotEmpty) {
      stockItems[index].selectedUnit = unitKey;
      stockItems[index].unit = product.unit ?? '';
    } else {
      stockItems[index].selectedUnit = null;
      stockItems[index].unit = product.unit ?? '';
    }
  }

  void _syncStockQuantityFromPurchaseQty(int index) {
    if (index < 0 || index >= stockItems.length) {
      return;
    }

    final item = stockItems[index];
    final selectedSaleUnit = _getSelectedPurchaseSaleUnit(item);
    final purchaseQty = _parsePositiveDouble(item.purchaseQty, fallback: 1.0);

    if (selectedSaleUnit == null) {
      return;
    }

    final conversionRate =
        _parsePositiveDouble(selectedSaleUnit.conversionRate, fallback: 1.0);
    final baseQuantity = purchaseQty * conversionRate;

    item.purchaseConversionRate = selectedSaleUnit.conversionRate?.toString();
    item.quantity = _formatNumber(baseQuantity);
    _getQuantityController(index).text = item.quantity;
  }

  void _selectPurchaseUnit(int index, SaleUnit? saleUnit) {
    final item = stockItems[index];
    if (saleUnit == null) {
      item.selectedPurchaseUnit = null;
      item.purchaseUnitName = null;
      item.purchaseConversionRate = null;
      return;
    }

    item.selectedPurchaseUnit = saleUnit.id?.toString();
    item.purchaseUnitName = saleUnit.unitName?.trim();
    item.purchaseConversionRate = saleUnit.conversionRate?.toString();

    if ((item.purchaseQty).trim().isEmpty) {
      item.purchaseQty = '1';
      _getPurchaseQtyController(index).text = item.purchaseQty;
    }

    _syncStockQuantityFromPurchaseQty(index);
  }

  double _getPricingQuantity(StockItem item) {
    if (item.selectedPurchaseUnit != null &&
        item.selectedPurchaseUnit!.isNotEmpty) {
      return _parsePositiveDouble(item.purchaseQty, fallback: 0.0);
    }
    return _parsePositiveDouble(item.quantity, fallback: 0.0);
  }

  void _configurePurchaseUnitForProductSelection(
    int index,
    GetProduct product, {
    String? scannedBarcode,
  }) {
    final item = stockItems[index];
    final matchedSaleUnit = scannedBarcode == null
        ? null
        : _findMatchingSaleUnit(product, scannedBarcode);

    if (_hasPurchaseUnits(item)) {
      if ((item.purchaseQty).trim().isEmpty) {
        item.purchaseQty = '1';
        _getPurchaseQtyController(index).text = item.purchaseQty;
      }

      if (matchedSaleUnit != null) {
        _selectPurchaseUnit(index, matchedSaleUnit);
      } else {
        final currentSelection = _getSelectedPurchaseSaleUnit(item);
        if (currentSelection != null) {
          item.purchaseUnitName = currentSelection.unitName?.trim();
          item.purchaseConversionRate =
              currentSelection.conversionRate?.toString();
          _syncStockQuantityFromPurchaseQty(index);
        } else {
          item.selectedPurchaseUnit = null;
          item.purchaseUnitName = null;
          item.purchaseConversionRate = null;
        }
      }
      return;
    }

    item.purchaseQty = '1';
    item.selectedPurchaseUnit = null;
    item.purchaseUnitName = null;
    item.purchaseConversionRate = null;
    _getPurchaseQtyController(index).text = item.purchaseQty;
  }

  // Get or create expanded field controllers
  TextEditingController _getPurchaseRateController(int index) {
    if (!purchaseRateControllers.containsKey(index)) {
      String initialValue = '';
      if (index < stockItems.length) {
        initialValue = stockItems[index].purchaseRate;
      }
      purchaseRateControllers[index] =
          TextEditingController(text: initialValue);
    }
    return purchaseRateControllers[index]!;
  }

  TextEditingController _getRetailPriceController(int index) {
    if (!retailPriceControllers.containsKey(index)) {
      String initialValue = '';
      if (index < stockItems.length) {
        initialValue = stockItems[index].salePrice;
      }
      retailPriceControllers[index] = TextEditingController(text: initialValue);
    }
    return retailPriceControllers[index]!;
  }

  TextEditingController _getMrpController(int index) {
    if (!mrpControllers.containsKey(index)) {
      String initialValue = '';
      if (index < stockItems.length) {
        initialValue = stockItems[index].mrp;
      }
      mrpControllers[index] = TextEditingController(text: initialValue);
    }
    return mrpControllers[index]!;
  }

  TextEditingController _getWholesaleController(int index) {
    if (!wholesaleControllers.containsKey(index)) {
      String initialValue = '';
      if (index < stockItems.length) {
        initialValue = stockItems[index].wholesale;
      }
      wholesaleControllers[index] = TextEditingController(text: initialValue);
    }
    return wholesaleControllers[index]!;
  }

  TextEditingController _getBatchNumberController(int index) {
    if (!batchNumberControllers.containsKey(index)) {
      String initialValue = '';
      if (index < stockItems.length) {
        initialValue = stockItems[index].batchNumber;
      }
      batchNumberControllers[index] = TextEditingController(text: initialValue);
    }
    return batchNumberControllers[index]!;
  }

  Future<void> _initializeData() async {
    // Initialize any required data
    await _loadCategories(); // Ensure categories are fresh
    await _loadSuppliers();
    await _loadUnits(); // Load units
    await _loadRacks(); // Load racks
    await _loadActiveStore(); // Load active store from session
    await _loadPaymentMethods(); // Load payment methods from API
  }

  /// Load payment methods from API (uses cached data if available)
  Future<void> _loadPaymentMethods() async {
    final masterDataProvider =
        Provider.of<MasterDataProvider>(context, listen: false);

    // Check if payment methods are already cached in the provider
    final cachedMethods = masterDataProvider.paymentMethods;
    if (cachedMethods != null && cachedMethods.isNotEmpty) {
      debugPrint(
          '📋 [Add Stock] Using cached payment methods: ${cachedMethods.length}');
      setState(() {
        _paymentMethods = cachedMethods;
        _isLoadingPaymentMethods = false;
      });
      return;
    }

    // No cache, fetch from API
    setState(() {
      _isLoadingPaymentMethods = true;
    });

    try {
      final paymentMethods = await masterDataProvider.fetchPaymentMethods();

      if (mounted && paymentMethods != null) {
        setState(() {
          _paymentMethods = paymentMethods;
          _isLoadingPaymentMethods = false;
        });
        debugPrint(
            '📋 [Add Stock] Payment methods loaded: ${_paymentMethods.length}');
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error loading payment methods: $e');
      setState(() {
        _isLoadingPaymentMethods = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      // Load categories with caching (same as sidebar and stock)
      // Force load raw categories (ignoring sellable filter) for stock adding
      debugPrint('📥 Loading purchasable categories for stock adding...');
      await categoryProvider.ensureCategories(CategoryListScope.purchasable);
      debugPrint('✅ Purchasable categories ready');
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _loadSuppliers() async {
    try {
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      if (accessToken != null) {
        await Provider.of<SupplierProvider>(context, listen: false)
            .fetchSuppliers(accessToken: accessToken);
      }
    } catch (e) {
      debugPrint('Error loading suppliers: $e');
    }
  }

  Future<void> _loadUnits() async {
    try {
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      if (accessToken != null) {
        await Provider.of<PurchaseProvider>(context, listen: false)
            .listAllUnits(accessToken);
      }
    } catch (e) {
      debugPrint('Error loading units: $e');
    }
  }

  Future<void> _loadRacks() async {
    try {
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      if (accessToken != null) {
        await Provider.of<PurchaseProvider>(context, listen: false)
            .listMasterDataValues(accessToken, 'RACKS');
      }
    } catch (e) {
      debugPrint('Error loading racks: $e');
    }
  }

  Future<void> _loadActiveStore() async {
    // OPTIMIZATION: Try to get from StoreSessionProvider synchronously first to avoid UI delay
    try {
      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      if (storeSession.activeStore != null) {
        final activeStore = storeSession.activeStore!;

        // Try to find full store object in PurchaseProvider first
        final purchaseProvider =
            Provider.of<PurchaseProvider>(context, listen: false);

        GetStoreModelData? fullStoreData;
        if (purchaseProvider.getStoreList != null) {
          try {
            fullStoreData = purchaseProvider.getStoreList!.firstWhere(
              (s) => s.id == activeStore.storeId,
            );
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            // Use full data if available, otherwise create minimal object from session
            selectedStore = fullStoreData ??
                GetStoreModelData(
                  id: activeStore.storeId,
                  name: activeStore.storeName,
                );
          });
        }

        debugPrint(
            '✅ Active store loaded from session: ${activeStore.storeName} (ID: ${activeStore.storeId})');
        return;
      }
    } catch (e) {
      debugPrint('⚠️ Could not get active store from session: $e');
    }

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? activeStoreId = prefs.getInt('active_store_id');

      if (activeStoreId != null) {
        final purchaseProvider =
            Provider.of<PurchaseProvider>(context, listen: false);

        if (purchaseProvider.getStoreList != null) {
          final store = purchaseProvider.getStoreList!.firstWhere(
            (s) => s.id == activeStoreId,
            orElse: () => purchaseProvider.getStoreList!.first,
          );

          if (mounted) {
            setState(() {
              selectedStore = store;
            });
          }
          debugPrint(
              '✅ Active store loaded: ${store.name} (ID: $activeStoreId)');
        }
      } else {
        debugPrint('⚠️ No active store ID found in preferences');
      }
    } catch (e) {
      debugPrint('❌ Error loading active store: $e');
    }
  }

  /// Load pending stock items from StockProvider and populate the form
  void _loadPendingStockItems() {
    final stockProvider = Provider.of<StockProvider>(context, listen: false);
    final pendingItems = stockProvider.pendingStockItems;

    debugPrint(
        '🔄 LOADING PENDING STOCK ITEMS: ${pendingItems.length} items found');

    if (pendingItems.isNotEmpty) {
      // Use addPostFrameCallback to ensure setState is called after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            // Clear existing stock items
            stockItems.clear();

            // Load each pending item as an editable row
            for (int i = 0; i < pendingItems.length; i++) {
              final pendingItem = pendingItems[i];
              final stockItem = _createStockItemFromPendingData(pendingItem, i);
              stockItems.add(stockItem);
            }

            // Add one empty row for new items
            stockItems.add(StockItem());

            // CRITICAL: Mark index cache as dirty so SliverList rebuilds correctly
            _markIndexCacheDirty();

            // Mark for recalculation so total value updates
            _markForRecalculation();

            debugPrint(
                '✅ LOADED ${pendingItems.length} PENDING ITEMS AS EDITABLE ROWS');
          });

          // Update controllers with the loaded data
          _updateControllersFromStockItems();
        }
      });
    }
  }

  /// Create a StockItem from pending stock data
  StockItem _createStockItemFromPendingData(
      Map<String, dynamic> pendingData, int index) {
    debugPrint('🔄 CREATING STOCK ITEM FROM PENDING DATA (Index: $index)');
    debugPrint('   - Product ID: ${pendingData['productId']}');
    debugPrint('   - Product Name: ${pendingData['productName']}');
    debugPrint('   - Category Name: ${pendingData['categoryName']}');
    debugPrint('   - Local ID: ${pendingData['localId']}');
    debugPrint('   - Unit ID (from pending): ${pendingData['unit']}');
    debugPrint('   - Rack (from pending): ${pendingData['rack']}');

    // Create a new StockItem with data from pending item
    // Note: 'unit' field in pendingData contains the unit ID (selectedUnit), not the display name
    final unitId = pendingData['unit']?.toString();
    final rackValue = (pendingData['rack'] ?? '').toString();
    final stockItem = StockItem(
      barcode: (pendingData['barcode'] ?? '').toString(),
      category: (pendingData['categoryName'] ?? '').toString(),
      product: (pendingData['productName'] ?? '').toString(),
      quantity: (pendingData['quantity'] ?? '1').toString(),
      purchaseQty: (pendingData['purchaseQty'] ?? '1').toString(),
      salePrice: (pendingData['retailPrice'] ?? '0').toString(),
      mrp: (pendingData['mrp'] ?? '0').toString(),
      wholesale: (pendingData['wholesalePrice'] ?? '0').toString(),
      purchaseRate: (pendingData['purchaseRate'] ?? '0').toString(),
      unit: '', // Will be set from unit list lookup below
      selectedUnit: unitId, // Restore the unit ID for dropdown selection
      selectedPurchaseUnit: pendingData['purchaseUnitId']?.toString(),
      purchaseUnitName: pendingData['purchaseUnitName']?.toString(),
      purchaseConversionRate: pendingData['purchaseConversionRate']?.toString(),
      productVariantId: pendingData['productVariantId'] is int
          ? pendingData['productVariantId']
          : int.tryParse(pendingData['productVariantId']?.toString() ?? ''),
      variantName: pendingData['variantName']?.toString(),
      rack: rackValue,
      selectedRack: rackValue.isNotEmpty
          ? rackValue
          : null, // Restore rack for dropdown selection
      expDate: pendingData['expiryDate'] != null
          ? DateTime.tryParse(pendingData['expiryDate'].toString()) ??
              DateTime.now().add(const Duration(days: 365))
          : DateTime.now().add(const Duration(days: 365)),
      batchNumber: (pendingData['wholesaleMinUnit'] ?? '1').toString(),
      supplier: (pendingData['supplierName'] ?? '').toString(),
      supplierId: (pendingData['supplierId'] ?? 1) is int
          ? pendingData['supplierId']
          : int.tryParse(pendingData['supplierId'].toString()) ?? 1,
      isExpanded: false,
      isSuccessfullyAdded:
          true, // Mark as successfully added since it's from pending
      taxInclude: pendingData['taxInclude'] == true,
      retailPriceTax: (pendingData['retailPriceTax'] ?? '0.00').toString(),
      wholesalePriceTax:
          (pendingData['wholesalePriceTax'] ?? '0.00').toString(),
    );

    // Set the API response to track this as a pending item
    stockItem.apiResponse = {
      'status': 'pending',
      'localId': pendingData['localId'],
      'message': 'Loaded from pending list'
    };

    // Try to find and set the product data
    _setProductDataFromPending(stockItem, pendingData);
    final selectedPurchaseUnit = _getSelectedPurchaseSaleUnit(stockItem);
    if (selectedPurchaseUnit != null) {
      stockItem.purchaseUnitName =
          selectedPurchaseUnit.unitName ?? stockItem.purchaseUnitName;
      stockItem.purchaseConversionRate =
          selectedPurchaseUnit.conversionRate?.toString() ??
              stockItem.purchaseConversionRate;
    }

    // Try to find and set the category data
    _setCategoryDataFromPending(stockItem, pendingData);

    // Try to find and set the supplier data
    _setSupplierDataFromPending(stockItem, pendingData);

    // Try to find and set the store data
    _setStoreDataFromPending(stockItem, pendingData);

    // Try to find and set the unit display name from unit list
    _setUnitDataFromPending(stockItem);

    debugPrint('✅ STOCK ITEM CREATED SUCCESSFULLY');
    return stockItem;
  }

  /// Set unit display name from unit list based on selectedUnit (unit ID)
  void _setUnitDataFromPending(StockItem stockItem) {
    try {
      if (stockItem.selectedUnit != null &&
          stockItem.selectedUnit!.isNotEmpty) {
        final purchaseProvider =
            Provider.of<PurchaseProvider>(context, listen: false);
        final unitList = purchaseProvider.getUnitList;
        if (unitList != null && unitList.containsKey(stockItem.selectedUnit)) {
          stockItem.unit = unitList[stockItem.selectedUnit] ?? '';
          debugPrint(
              '   - Unit data set: ${stockItem.unit} (ID: ${stockItem.selectedUnit})');
        } else {
          debugPrint(
              '   - Unit ID ${stockItem.selectedUnit} not found in unit list');
        }
      }
    } catch (e) {
      debugPrint('   - Could not set unit data: $e');
    }
  }

  /// Set product data from pending item
  void _setProductDataFromPending(
      StockItem stockItem, Map<String, dynamic> pendingData) {
    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      final productId = pendingData['productId'];

      debugPrint('   - Looking for product ID: $productId');
      debugPrint(
          '   - Available products count: ${localProductProvider.products.length}');

      if (productId != null) {
        final product = localProductProvider.products.firstWhere(
          (p) => p.productId == productId,
          orElse: () => GetProduct(),
        );

        if (product.productId != null) {
          stockItem.productData = product;
          final variant = _selectedVariant(stockItem);
          if (stockItem.productVariantId != null && variant == null) {
            stockItem.productVariantId = null;
            stockItem.variantName = null;
          } else if (variant != null) {
            stockItem.variantName = _variantLabel(variant);
          }
          debugPrint(
              '   - Product data set: ${product.productName} (ID: ${product.productId})');
        } else {
          debugPrint(
              '   - ⚠️ Product ID $productId not found in LocalProductProvider');
        }
      }
    } catch (e) {
      debugPrint('   - Could not set product data: $e');
    }
  }

  /// Set category data from pending item
  void _setCategoryDataFromPending(
      StockItem stockItem, Map<String, dynamic> pendingData) {
    try {
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      final categoryList = categoryProvider.purchasableCategories;
      if (categoryList != null && categoryList.isNotEmpty) {
        final dynamic categoryNameDyn = pendingData['categoryName'];
        final String? categoryName = categoryNameDyn?.toString();
        final dynamic categoryIdDyn = pendingData['categoryId'];
        final int? categoryId = categoryIdDyn is int
            ? categoryIdDyn
            : int.tryParse(categoryIdDyn?.toString() ?? '');
        final String? categorySlug = pendingData['categorySlug']?.toString();

        Category? matchingCategory;
        // 1) Try by ID
        if (categoryId != null) {
          try {
            matchingCategory =
                categoryList.firstWhere((c) => c.categoryId == categoryId);
          } catch (_) {}
        }
        // 2) Try by slug
        if (matchingCategory == null && categorySlug != null) {
          try {
            matchingCategory = categoryList
                .firstWhere((c) => (c.categorySlug ?? '') == categorySlug);
          } catch (_) {}
        }
        // 3) Try by name (case-insensitive)
        if (matchingCategory == null && categoryName != null) {
          final target = categoryName.trim().toLowerCase();
          try {
            matchingCategory = categoryList.firstWhere(
                (c) => (c.categoryName ?? '').trim().toLowerCase() == target);
          } catch (_) {}
        }
        // 4) Fallback to first non-ALL
        if (matchingCategory == null) {
          try {
            matchingCategory = categoryList.firstWhere(
                (c) => (c.categoryName ?? '').toUpperCase() != 'ALL');
          } catch (_) {
            matchingCategory = categoryList.first;
          }
        }

        // Assign
        final mc = matchingCategory ?? categoryList.first;
        stockItem.categoryData = mc;
        stockItem.category = mc.categoryName ?? '';
        debugPrint(
            '   - Category data set: ${mc.categoryName} (ID: ${mc.categoryId})');
      }
    } catch (e) {
      debugPrint('   - Could not set category data: $e');
    }
  }

  /// Set store data from pending item
  void _setStoreDataFromPending(
      StockItem stockItem, Map<String, dynamic> pendingData) {
    try {
      final purchaseProvider =
          Provider.of<PurchaseProvider>(context, listen: false);
      final storeId = pendingData['storeId'];

      if (storeId != null && purchaseProvider.getStoreList != null) {
        // Convert storeId to int if it's not already
        int? id;
        if (storeId is int) {
          id = storeId;
        } else {
          id = int.tryParse(storeId.toString());
        }

        if (id != null) {
          final store = purchaseProvider.getStoreList!.firstWhere(
            (s) => s.id == id,
            orElse: () => purchaseProvider.getStoreList!.first,
          );

          selectedStore = store; // Set the global selected store
          debugPrint('   - Store data set: ${store.name}');
        }
      }
    } catch (e) {
      debugPrint('   - Could not set store data: $e');
    }
  }

  /// Update all controllers with current stock item data
  void _updateControllersFromStockItems() {
    if (!mounted) return;

    for (int i = 0; i < stockItems.length; i++) {
      final item = stockItems[i];

      // Update barcode controller
      _getBarcodeController(i).text = item.barcode;

      // Update quantity controller
      _getQuantityController(i).text = item.quantity;
      _getPurchaseQtyController(i).text = item.purchaseQty;

      // Update expanded field controllers
      _getPurchaseRateController(i).text = item.purchaseRate;
      _getRetailPriceController(i).text = item.salePrice;
      _getMrpController(i).text = item.mrp;
      _getWholesaleController(i).text = item.wholesale;
      _getBatchNumberController(i).text = item.batchNumber;
    }

    debugPrint('✅ UPDATED ALL CONTROLLERS WITH STOCK ITEM DATA');
  }

  Future<void> _addStockForSingleItem(int index) async {
    debugPrint('🔄 LOCAL STOCK ADDITION PROCESS STARTED FOR ITEM ${index + 1}');

    // Store the editing index before we modify anything
    int? editingIndex = _editingItemIndex;

    // Check if we're in edit mode
    if (editingIndex != null) {
      debugPrint(
          '✏️ UPDATE MODE: Checking if item at index $editingIndex was modified');
      final oldItem = stockItems[editingIndex];
      final currentItem = stockItems[index];

      // Check if any values actually changed
      bool hasChanges = oldItem.barcode != currentItem.barcode ||
          oldItem.product != currentItem.product ||
          oldItem.productVariantId != currentItem.productVariantId ||
          oldItem.category != currentItem.category ||
          oldItem.quantity != currentItem.quantity ||
          oldItem.salePrice != currentItem.salePrice ||
          oldItem.mrp != currentItem.mrp ||
          oldItem.wholesale != currentItem.wholesale ||
          oldItem.purchaseRate != currentItem.purchaseRate ||
          oldItem.taxInclude != currentItem.taxInclude ||
          oldItem.batchNumber != currentItem.batchNumber ||
          oldItem.rack != currentItem.rack ||
          oldItem.selectedUnit != currentItem.selectedUnit ||
          oldItem.expDate != currentItem.expDate;

      if (!hasChanges) {
        // No changes detected - clear the input row and cancel edit mode
        debugPrint('ℹ️ No changes detected - canceling edit mode');
        setState(() {
          _editingItemIndex = null;
          // Clear the input row instead of removing it
          _clearStockItem(index);
        });
        showScaffold(
          context: context,
          message: 'add_stock.no_changes_edit_cancelled'.tr,
        );
        return; // Exit early - don't add anything
      }

      // Changes detected - proceed with update
      debugPrint('✏️ Changes detected - proceeding with update');

      // Remove from pending storage
      if (oldItem.apiResponse != null &&
          oldItem.apiResponse!['localId'] != null) {
        final stockProvider =
            Provider.of<StockProvider>(context, listen: false);
        stockProvider.removeStockItemLocally(oldItem.apiResponse!['localId']);
        debugPrint('🗑️ Removed old item from pending storage');
      }

      // Adjust the current index if needed (if we're removing an item before the current one)
      if (editingIndex < index) {
        index = index - 1;
        debugPrint(
            '📊 Adjusted index from ${index + 1} to $index after removal');
      }

      // Remove old item from list
      setState(() {
        stockItems.removeAt(editingIndex);
        _markIndexCacheDirty();
      });

      debugPrint('🗑️ Removed old item from list at index $editingIndex');

      // Clear editing mode
      _editingItemIndex = null;
      debugPrint('✅ Cleared editing mode - will add updated item');
    }

    if (selectedStore == null) {
      debugPrint('❌ STORE VALIDATION FAILED: No store selected');
      showScaffoldError(context: context, message: 'add_stock.select_store_error'.tr);
      return;
    }

    if (selectedSupplier == null || selectedSupplier!.id == 0) {
      debugPrint('❌ SUPPLIER VALIDATION FAILED: No supplier selected');
      showScaffoldError(context: context, message: 'add_stock.select_supplier_error'.tr);
      return;
    }

    final item = stockItems[index];

    if (item.isHidden) {
      debugPrint(
          '❌ ITEM HIDDEN: Stock item ${index + 1} is hidden and cannot be added');
      showScaffoldError(
          context: context,
          message: 'add_stock.item_deleted_cannot_add'.tr);
      return;
    }

    if (item.isSuccessfullyAdded) {
      debugPrint(
          '❌ ITEM ALREADY ADDED: Stock item ${index + 1} is already successfully added');
      showScaffoldError(
          context: context,
          message: 'add_stock.item_already_added'.tr);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare stock item data for local storage
      final Map<String, dynamic> stockItemData = {
        'productId': item.productData?.productId,
        'productVariantId':
            _variantFeatureEnabled() ? item.productVariantId : null,
        'variantName': item.variantName,
        'variantRequired': _requiresVariant(item),
        'categoryId': item.categoryData?.categoryId,
        'quantity': item.quantity,
        // Only include purchaseQty for multi-unit products
        if (_hasPurchaseUnits(item)) ...{
          'purchaseQty': item.purchaseQty,
          'purchaseUnitId': item.selectedPurchaseUnit,
          'purchaseUnitName': item.purchaseUnitName,
          'purchaseConversionRate': item.purchaseConversionRate,
        },
        'retailPrice': item.salePrice,
        'purchaseRate': item.purchaseRate,
        'mrp': item.mrp.isNotEmpty ? item.mrp : item.salePrice,
        // Do not fallback wholesale to retail; save as empty string if not provided
        'wholesalePrice': item.wholesale.isNotEmpty ? item.wholesale : '',
        'unit':
            item.selectedUnit, // Changed to send unit ID instead of unit name
        'supplierId': selectedSupplier!.id,
        'storeId': selectedStore!.id,
        'expiryDate': DateFormat('yyyy-MM-dd').format(item.expDate),
        'userId': 1,
        'purchaseVoucherId': null,
        'purchaseId': null,
        'taxAmountRetail': item.calculatedTaxData?['retailTaxAmount'],
        'taxAmountWholesale': item.calculatedTaxData?['wholesaleTaxAmount'],
        'taxAmountPurchase': item.calculatedTaxData?['purchaseTaxAmount'],
        'wholesaleMinUnit':
            item.batchNumber.isNotEmpty ? item.batchNumber : '1',
        'rack': item.rack,
        'barcode': item.barcode,
        'batchNumber': item.batchNumber,
        'date': DateFormat('yyyy-MM-dd').format(selectedDate),
        'purchaseDate': DateFormat('yyyy-MM-dd').format(selectedPurchaseDate),
        'purchaseNumber': null,
        'taxInclude': item.taxInclude,
        'initialRetailPrice': item.salePrice,
        'initialWholesalePrice':
            item.wholesale.isNotEmpty ? item.wholesale : item.salePrice,
        'retailPriceTax': item.calculatedTaxData?['price_including_tax_retail'],
        'wholesalePriceTax':
            item.calculatedTaxData?['price_including_tax_wholesale'],
        'purchasePriceTax':
            item.calculatedTaxData?['price_including_tax_purchase'],
        // Additional data for UI reference
        'productName': item.product,
        'categoryName': item.category,
        'supplierName': selectedSupplier!.name,
        'storeName': selectedStore!.name,
      };

      debugPrint('📋 STOCK ITEM DATA FOR LOCAL STORAGE:');
      debugPrint('═══════════════════════════════════════════════════════════');
      stockItemData.forEach((key, value) {
        debugPrint('   $key: $value');
      });
      debugPrint('═══════════════════════════════════════════════════════════');

      // Add to local storage with validation
      final stockProvider = Provider.of<StockProvider>(context, listen: false);
      bool success = stockProvider.addStockItemLocally(stockItemData);

      if (success) {
        debugPrint('✅ STOCK ITEM ADDED TO LOCAL STORAGE SUCCESSFULLY');

        setState(() {
          stockItems[index].isSuccessfullyAdded = true;
          // Store the local ID for tracking
          stockItems[index].apiResponse = {
            'status': 'pending',
            'localId': stockItemData['localId'],
            'message': 'Added to pending list'
          };
        });

        // Mark for recalculation when single item is successfully added
        _markForRecalculation();
        _calculateTotalStockValue();
        showScaffold(
            context: context, message: 'add_stock.stock_item_added_pending'.tr);
        debugPrint('✅ SINGLE STOCK ITEM MARKED AS SUCCESSFULLY ADDED LOCALLY');

        // Automatically add a new empty row after successful stock addition
        debugPrint('🔄 AUTO-ADDING NEW ROW AFTER SUCCESSFUL LOCAL ADDITION');
        setState(() {
          stockItems.add(StockItem());
          _markIndexCacheDirty(); // Mark cache as dirty
        });
        debugPrint(
            '✅ NEW EMPTY ROW ADDED AUTOMATICALLY. Total items: ${stockItems.length}');

        // Focus on the barcode field of the next row after a short delay
        debugPrint('🔍 FOCUSING ON NEXT ROW BARCODE FIELD');
        Future.delayed(const Duration(milliseconds: 300), () {
          final nextRowIndex =
              stockItems.length - 1; // Index of the newly added row
          final nextBarcodeFocusNode = _getBarcodeFocusNode(nextRowIndex);

          // Request focus on the barcode field of the next row
          nextBarcodeFocusNode.requestFocus();
          debugPrint(
              '✅ FOCUS REQUESTED ON ROW ${nextRowIndex + 1} BARCODE FIELD');
        });
      } else {
        debugPrint('❌ LOCAL VALIDATION FAILED FOR ITEM ${index + 1}');

        // Get validation errors from stock provider
        final validationErrors = stockProvider.validateStockItem(stockItemData);
        String errorMessage = 'add_stock.complete_required_fields'.tr;

        validationErrors.forEach((field, error) {
          if (error != null) {
            errorMessage += '\n• $error';
          }
        });

        debugPrint('❌ VALIDATION ERRORS: $validationErrors');
        showScaffoldError(context: context, message: errorMessage);
      }
    } catch (e) {
      debugPrint('💥 EXCEPTION IN LOCAL STOCK ADDITION FOR ITEM ${index + 1}:');
      debugPrint('   - Exception Type: ${e.runtimeType}');
      debugPrint('   - Exception Message: $e');
      debugPrint('   - Stack Trace: ${StackTrace.current}');

      showScaffoldError(context: context, message: 'Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
      debugPrint('🏁 LOCAL STOCK ADDITION PROCESS ENDED');
    }
  }

  void _resetFormFields() {
    debugPrint('🔄 RESETTING FORM FIELDS STARTED');

    // Clear all search controllers
    debugPrint('🧹 CLEARING SEARCH CONTROLLERS...');
    supplierSearchController.clear();
    for (var controller in categorySearchControllers.values) {
      controller.clear();
    }
    for (var controller in productSearchControllers.values) {
      controller.clear();
    }
    for (var controller in barcodeControllers.values) {
      controller.clear();
    }
    for (var controller in quantityControllers.values) {
      controller.clear();
    }
    debugPrint('✅ SEARCH CONTROLLERS CLEARED');

    // Clear pending stock items from provider
    debugPrint('🧹 CLEARING PENDING STOCK ITEMS FROM PROVIDER...');
    Provider.of<StockProvider>(context, listen: false).clearPendingStockItems();
    debugPrint('✅ PENDING STOCK ITEMS CLEARED');

    // Clear draft items from Hive
    _clearDraftFromHive();

    setState(() {
      debugPrint('🔄 UPDATING STATE VARIABLES...');
      // Reset header fields (keep selectedStore as it's loaded from active session)
      // selectedStore remains unchanged - it's loaded from session
      selectedSupplier = null;
      selectedDate = DateTime.now();
      selectedPurchaseDate = DateTime.now();
      debugPrint('✅ HEADER FIELDS RESET');

      // Reset stock items to one empty row with no success flags
      stockItems = [StockItem(isSuccessfullyAdded: false)];
      _markIndexCacheDirty(); // Mark cache as dirty
      debugPrint('✅ STOCK ITEMS RESET TO 1 EMPTY ROW (NO SUCCESS FLAGS)');

      // Reset payment data
      paymentData = DynamicPaymentData();
      totalStockValue = 0.0;
      debugPrint('✅ PAYMENT DATA RESET');
    });

    debugPrint('✅ FORM FIELDS RESET COMPLETED');
  }

  /// Edit a successfully added stock item - populate input section with values
  void _editStockItem(int index) {
    final item = stockItems[index];
    _getBarcodeFocusNode(0).requestFocus();

    if (!item.isSuccessfullyAdded) {
      return;
    }

    setState(() {
      // Store which item we're editing
      _editingItemIndex = index;

      // Find the input row (first non-successfully-added item)
      int inputIndex = stockItems
          .indexWhere((item) => !item.isSuccessfullyAdded && !item.isHidden);

      if (inputIndex == -1) {
        // No input row exists, create one at the beginning
        stockItems.insert(0, StockItem());
        inputIndex = 0;
        _markIndexCacheDirty();
      }

      // Copy all values to the input row
      stockItems[inputIndex] = StockItem(
        barcode: item.barcode,
        category: item.category,
        product: item.product,
        quantity: item.quantity,
        purchaseQty: item.purchaseQty,
        salePrice: item.salePrice,
        mrp: item.mrp,
        wholesale: item.wholesale,
        purchaseRate: item.purchaseRate,
        unit: item.unit,
        rack: item.rack,
        expDate: item.expDate,
        batchNumber: item.batchNumber,
        productData: item.productData,
        productVariantId: item.productVariantId,
        variantName: item.variantName,
        categoryData: item.categoryData,
        selectedUnit: item.selectedUnit,
        selectedPurchaseUnit: item.selectedPurchaseUnit,
        purchaseUnitName: item.purchaseUnitName,
        purchaseConversionRate: item.purchaseConversionRate,
        selectedRack: item.selectedRack,
        taxInclude: item.taxInclude,
        retailPriceTax: item.retailPriceTax,
        wholesalePriceTax: item.wholesalePriceTax,
        calculatedTaxData: item.calculatedTaxData,
        isExpanded: true,
      );

      // Update controllers
      _getBarcodeController(inputIndex).text = item.barcode;
      _getQuantityController(inputIndex).text = item.quantity;
      _getPurchaseQtyController(inputIndex).text = item.purchaseQty;
      _getPurchaseRateController(inputIndex).text = item.purchaseRate;
      _getRetailPriceController(inputIndex).text = item.salePrice;
      _getMrpController(inputIndex).text = item.mrp;
      _getWholesaleController(inputIndex).text = item.wholesale;
      _getBatchNumberController(inputIndex).text = item.batchNumber;
    });

    // showScaffold(
    //   context: context,
    //   message: 'Editing item. Modify values and click Add to update.',
    // );
  }

  void _toggleExpanded(int index) {
    setState(() {
      stockItems[index].isExpanded = !stockItems[index].isExpanded;
    });
  }

  void _clearStockItem(int index) {
    setState(() {
      stockItems[index] = StockItem(); // Reset to empty item

      // Clear controllers for this index
      _getCategorySearchController(index).clear();
      _getProductSearchController(index).clear();
      _getBarcodeController(index).clear();
      _getQuantityController(index).text = '1';
      _getPurchaseQtyController(index).text = '1';

      // Clear expanded field controllers
      _getPurchaseRateController(index).clear();
      _getRetailPriceController(index).clear();
      _getMrpController(index).clear();
      _getWholesaleController(index).clear();
      _getBatchNumberController(index).clear();

      // Cancel edit mode if we're clearing the input row
      if (_editingItemIndex != null) {
        _cancelEditMode();
      }
    });
    debugPrint('🧹 CLEARED STOCK ITEM AT INDEX $index');
  }

  /// Cancel edit mode and remove the input row
  void _cancelEditMode() {
    if (_editingItemIndex == null) return;

    setState(() {
      // Find the input row
      int inputIndex = stockItems
          .indexWhere((item) => !item.isSuccessfullyAdded && !item.isHidden);

      if (inputIndex != -1) {
        // Remove the input row
        stockItems.removeAt(inputIndex);
        _markIndexCacheDirty();
      }

      // Clear editing mode
      _editingItemIndex = null;
    });

    showScaffold(
      context: context,
      message: 'add_stock.edit_cancelled'.tr,
    );
    debugPrint('🔄 Edit mode cancelled');
  }

  void _updateStockItemFieldInline(int index, String field, String value) {
    if (index < 0 || index >= stockItems.length) return;

    final item = stockItems[index];

    // Update the local item object field immediately for UI responsiveness
    setState(() {
      if (field == 'quantity') {
        item.quantity = value;
      } else if (field == 'salePrice') {
        item.salePrice = value;
      } else if (field == 'mrp') {
        item.mrp = value;
      } else if (field == 'purchaseRate') {
        item.purchaseRate = value;
      }
      // Mark for recalculation so the summary updates in next build
      _markForRecalculation();
    });

    // Debounce the heavy operations (Persistence & Tax)
    _inlineEditDebounceTimer?.cancel();
    _inlineEditDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      // Update in local storage (StockProvider)
      if (item.apiResponse != null && item.apiResponse!['localId'] != null) {
        final localId = item.apiResponse!['localId'];
        final stockProvider =
            Provider.of<StockProvider>(context, listen: false);

        // Map containing updated fields
        final Map<String, dynamic> updatedData = {
          'productId': item.productData?.productId,
          'productVariantId':
              _variantFeatureEnabled() ? item.productVariantId : null,
          'variantName': item.variantName,
          'variantRequired': _requiresVariant(item),
          'categoryId': item.categoryData?.categoryId,
          'quantity': item.quantity,
          'purchaseQty': item.purchaseQty,
          'purchaseUnitId': item.selectedPurchaseUnit,
          'purchaseUnitName': item.purchaseUnitName,
          'purchaseConversionRate': item.purchaseConversionRate,
          'retailPrice': item.salePrice,
          'purchaseRate': item.purchaseRate,
          'mrp': item.mrp.isNotEmpty ? item.mrp : item.salePrice,
          'wholesalePrice': item.wholesale.isNotEmpty ? item.wholesale : '',
          'unit': item.selectedUnit,
          'supplierId': selectedSupplier?.id ?? item.supplierId,
          'storeId':
              selectedStore?.id ?? 1, // Default store ID if none selected
          'expiryDate': DateFormat('yyyy-MM-dd').format(item.expDate),
          'userId': 1,
          'taxAmountRetail': item.calculatedTaxData?['retailTaxAmount'],
          'taxAmountWholesale': item.calculatedTaxData?['wholesaleTaxAmount'],
          'taxAmountPurchase': item.calculatedTaxData?['purchaseTaxAmount'],
          'wholesaleMinUnit':
              item.batchNumber.isNotEmpty ? item.batchNumber : '1',
          'rack': item.rack,
          'barcode': item.barcode,
          'batchNumber': item.batchNumber,
          'date': DateFormat('yyyy-MM-dd').format(selectedDate),
          'purchaseDate': DateFormat('yyyy-MM-dd').format(selectedPurchaseDate),
          'taxInclude': item.taxInclude,
          'initialRetailPrice': item.salePrice,
          'initialWholesalePrice':
              item.wholesale.isNotEmpty ? item.wholesale : item.salePrice,
          'retailPriceTax':
              item.calculatedTaxData?['price_including_tax_retail'],
          'wholesalePriceTax':
              item.calculatedTaxData?['price_including_tax_wholesale'],
          'purchasePriceTax':
              item.calculatedTaxData?['price_including_tax_purchase'],
          'productName': item.product,
          'categoryName': item.category,
          'supplierName': selectedSupplier?.name ?? item.supplier,
          'storeName': selectedStore?.name ?? '',
        };

        stockProvider.updateStockItemLocally(localId, updatedData);
      }

      // If price fields were changed, recalculate tax
      if (field == 'salePrice' || field == 'mrp') {
        _calculateTaxForStockItem(index, isRetail: true);
        _calculateTaxForStockItem(index, isRetail: false);
      }

      if (field == 'purchaseRate') {
        _calculateTaxForStockItem(index, isPurchase: true);
      }

      // Finally, update the total stock value for the Finish button validation
      _calculateTotalStockValue();
    });
  }

  /// Show Add Product Modal with barcode generation enabled
  Future<void> _showAddProductModal(int index) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AddProductWithBarcodeModal(
          barcode: null, // null enables barcode generation button
          isAddToCart: false,
        );
      },
    );

    // If a product was created, auto-fill the stock row
    if (result != null && result['product'] != null) {
      final product = result['product'];
      final String? initialQuantity = result['initialQuantity']?.toString();

      if (product is GetProduct) {
        debugPrint('🔄 AUTO-FILLING FROM ADD PRODUCT MODAL...');
        debugPrint(
            '   - Product: ${product.productName} (ID: ${product.productId})');

        // Get selling price from price object
        final String sellingPrice = product.price?.price?.toString() ?? '0';
        final String mrpValue = product.mrp?.toString() ?? '0';
        final String purchasePrice = product.purchasePrice ?? '0';

        setState(() {
          // Set product data
          stockItems[index].productData = product;
          stockItems[index].productVariantId = null;
          stockItems[index].variantName = null;
          stockItems[index].product = product.productName ?? '';
          stockItems[index].barcode = product.barcode ?? '';

          // Auto-fill category - find the Category from CategoryProvider
          if (product.category != null || product.categoryId != null) {
            debugPrint(
                '🔍 SEARCHING FOR CATEGORY: ${product.category?.name ?? product.categoryId}');
            final categoryProvider =
                Provider.of<CategoryProvider>(context, listen: false);
            List<Category>? categoryList = categoryProvider.searchCategory;
            if (categoryList == null || categoryList.isEmpty) {
              categoryList = categoryProvider.purchasableCategories;
            }
            if (categoryList != null && categoryList.isNotEmpty) {
              Category? matchingCategory;
              // 1) Match by categoryId
              if (product.categoryId != null) {
                try {
                  matchingCategory = categoryList.firstWhere(
                      (cat) => cat.categoryId == product.categoryId);
                } catch (_) {}
              }
              // 2) Match by slug
              if (matchingCategory == null && product.category?.slug != null) {
                try {
                  matchingCategory = categoryList.firstWhere((cat) =>
                      (cat.categorySlug ?? '') ==
                      (product.category!.slug ?? ''));
                } catch (_) {}
              }
              // 3) Match by name (case-insensitive, trimmed)
              if (matchingCategory == null && product.category?.name != null) {
                final targetName =
                    (product.category!.name ?? '').trim().toLowerCase();
                try {
                  matchingCategory = categoryList.firstWhere((cat) =>
                      (cat.categoryName ?? '').trim().toLowerCase() ==
                      targetName);
                } catch (_) {}
              }
              if (matchingCategory != null) {
                stockItems[index].categoryData = matchingCategory;
                stockItems[index].category =
                    matchingCategory.categoryName ?? '';
                debugPrint(
                    '   - Category: ${matchingCategory.categoryName} (ID: ${matchingCategory.categoryId})');
              }
            }
          }

          // Set pricing from product
          stockItems[index].salePrice = sellingPrice;
          stockItems[index].mrp = mrpValue;
          stockItems[index].purchaseRate = purchasePrice;
          stockItems[index].unit = product.unit ?? '';

          // Update price controllers
          _getRetailPriceController(index).text = sellingPrice;
          _getMrpController(index).text = mrpValue;
          _getPurchaseRateController(index).text = purchasePrice;

          // Auto-fill unit dropdown - find the matching unit key
          if (product.unit != null && product.unit!.isNotEmpty) {
            debugPrint('🔍 SEARCHING FOR UNIT KEY: ${product.unit}');
            final purchaseProvider =
                Provider.of<PurchaseProvider>(context, listen: false);
            final unitList = purchaseProvider.getUnitList;
            if (unitList != null) {
              // Find the key that matches the unit value
              String? matchingUnitKey = unitList.entries
                  .firstWhere(
                    (entry) => entry.value == product.unit,
                    orElse: () => const MapEntry('', ''),
                  )
                  .key;
              if (matchingUnitKey.isNotEmpty) {
                stockItems[index].selectedUnit =
                    matchingUnitKey; // Store unit ID
                stockItems[index].unit =
                    product.unit!; // Store unit name for display
                debugPrint('   - Unit Key (ID): $matchingUnitKey');
                debugPrint('   - Unit Name: ${product.unit}');
              }
            }
          }

          // Set quantity from modal if provided
          if (initialQuantity != null && initialQuantity.isNotEmpty) {
            stockItems[index].quantity = initialQuantity;
            _getQuantityController(index).text = initialQuantity;
          }

          // Update barcode controller
          _getBarcodeController(index).text = product.barcode ?? '';

          // Clear product cache to ensure dropdown shows the new product
          _clearProductCache();

          _markForRecalculation(); // Trigger recalculation
        });

        debugPrint('✅ Product auto-filled from modal: ${product.productName}');
        debugPrint('   - Barcode: ${product.barcode}');
        debugPrint('   - Sale Price: $sellingPrice');
        debugPrint('   - MRP: $mrpValue');
        debugPrint('   - Purchase Price: $purchasePrice');
        debugPrint('   - Quantity: $initialQuantity');

        // Calculate tax values after modal auto-fill so add/edit keeps pending tax data accurate.
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted || index >= stockItems.length) return;
          _calculateTaxForStockItem(index, isRetail: true);
          _calculateTaxForStockItem(index, isRetail: false);
          _calculateTaxForStockItem(index, isPurchase: true);
        });

        // Note: Draft saving disabled - only successfully added items are persisted via StockProvider
      }
    }
  }

  /// Update pending stock item when form fields change
  void _updatePendingStockItem(int index) {
    final item = stockItems[index];

    // Only update if item is successfully added (has localId)
    if (!item.isSuccessfullyAdded ||
        item.apiResponse == null ||
        item.apiResponse!['localId'] == null) {
      return;
    }

    final localId = item.apiResponse!['localId'];

    // Prepare updated stock item data
    final Map<String, dynamic> updatedStockItemData = {
      'productId': item.productData?.productId,
      'productVariantId':
          _variantFeatureEnabled() ? item.productVariantId : null,
      'variantName': item.variantName,
      'variantRequired': _requiresVariant(item),
      'categoryId': item.categoryData?.categoryId,
      'quantity': item.quantity,
      'purchaseQty': item.purchaseQty,
      'purchaseUnitId': item.selectedPurchaseUnit,
      'purchaseUnitName': item.purchaseUnitName,
      'purchaseConversionRate': item.purchaseConversionRate,
      'retailPrice': item.salePrice,
      'purchaseRate': item.purchaseRate,
      'mrp': item.mrp.isNotEmpty ? item.mrp : item.salePrice,
      'wholesalePrice':
          item.wholesale.isNotEmpty ? item.wholesale : item.salePrice,
      'unit': item.selectedUnit, // Changed to send unit ID instead of unit name
      'supplierId': selectedSupplier?.id ?? item.supplierId,
      'storeId': selectedStore?.id ?? 1,
      'expiryDate': DateFormat('yyyy-MM-dd').format(item.expDate),
      'userId': 1,
      'purchaseVoucherId': null,
      'purchaseId': null,
      'taxAmountRetail': item.calculatedTaxData?['retailTaxAmount'],
      'taxAmountWholesale': item.calculatedTaxData?['wholesaleTaxAmount'],
      'taxAmountPurchase': item.calculatedTaxData?['purchaseTaxAmount'],
      'wholesaleMinUnit': item.batchNumber.isNotEmpty ? item.batchNumber : '1',
      'rack': item.rack,
      'barcode': item.barcode,
      'batchNumber': item.batchNumber,
      'date': DateFormat('yyyy-MM-dd').format(selectedDate),
      'purchaseDate': DateFormat('yyyy-MM-dd').format(selectedPurchaseDate),
      'purchaseNumber': null,
      'taxInclude': item.taxInclude,
      'initialRetailPrice': item.salePrice,
      'initialWholesalePrice':
          item.wholesale.isNotEmpty ? item.wholesale : item.salePrice,
      'retailPriceTax': item.calculatedTaxData?['price_including_tax_retail'],
      'wholesalePriceTax':
          item.calculatedTaxData?['price_including_tax_wholesale'],
      'purchasePriceTax':
          item.calculatedTaxData?['price_including_tax_purchase'],
      // Additional data for UI reference
      'productName': item.product,
      'categoryName': item.category,
      'supplierName': selectedSupplier?.name ?? '',
      'storeName': selectedStore?.name ?? '',
    };

    // Update in provider
    final stockProvider = Provider.of<StockProvider>(context, listen: false);
    bool success =
        stockProvider.updateStockItemLocally(localId, updatedStockItemData);

    if (success) {
      debugPrint('✅ UPDATED PENDING STOCK ITEM: $localId');
    } else {
      debugPrint('❌ FAILED TO UPDATE PENDING STOCK ITEM: $localId');
    }
  }

  /// Sync recalculated tax fields to pending item storage after async tax API response.
  void _syncPendingItemAfterTaxRecalculation(int index, StockItem item) {
    if (!mounted) return;

    int resolvedIndex = index;
    if (resolvedIndex < 0 ||
        resolvedIndex >= stockItems.length ||
        !identical(stockItems[resolvedIndex], item)) {
      resolvedIndex = stockItems.indexOf(item);
    }

    if (resolvedIndex == -1) return;
    _updatePendingStockItem(resolvedIndex);
  }

  void _deleteStockItem(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Row(
            children: [
              const Icon(
                Icons.warning,
                color: Colors.red,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'add_stock.confirm_delete_title'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s16,
                    0.30,
                    ColorManager.textColor,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'add_stock.confirm_delete_message'.tr,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.30,
              Colors.grey.shade700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'add_stock.cancel'.tr,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s14,
                  0.30,
                  Colors.grey.shade600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();

                // Remove from local storage if it was added
                final item = stockItems[index];
                if (item.apiResponse != null &&
                    item.apiResponse!['localId'] != null) {
                  Provider.of<StockProvider>(context, listen: false)
                      .removeStockItemLocally(item.apiResponse!['localId']);
                }

                // Soft delete - hide the item instead of removing it
                setState(() {
                  stockItems[index].isHidden = true;
                  _markIndexCacheDirty(); // Mark cache as dirty
                  _markForRecalculation(); // Trigger recalculation
                  debugPrint(
                      '🗑️ SOFT DELETED (HIDDEN) STOCK ITEM AT INDEX $index');
                });

                showScaffold(
                    context: context,
                    message: 'add_stock.stock_item_deleted'.tr);
                debugPrint('🗑️ DELETED STOCK ITEM AT INDEX $index');
              },
              child: Text(
                'add_stock.delete'.tr,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s14,
                  0.30,
                  Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _calculateTotalStockValue() {
    if (_needsIndexRebuild) {
      _rebuildIndexCache();
    }

    double total = 0.0;
    // OPTIMIZED: Use cached visible items instead of iterating all items
    for (StockItem item in _cachedVisibleItems) {
      if (item.isSuccessfullyAdded && item.purchaseRate.isNotEmpty) {
        double purchaseRate = double.tryParse(item.purchaseRate) ?? 0.0;
        total += (purchaseRate * _getPricingQuantity(item));
      }
    }
    // Only update if changed (with small epsilon for floating point comparison)
    if (mounted && (totalStockValue - total).abs() > 0.01) {
      setState(() {
        totalStockValue = total;
      });
    }
  }

  double _getAdditionalPurchaseTaxTotal() {
    double total = 0.0;

    for (final item in stockItems) {
      if (!item.isSuccessfullyAdded || item.isHidden) continue;

      if (!item.taxInclude) {
        final quantity = _getPricingQuantity(item);
        final taxPerUnit =
            (item.calculatedTaxData?['purchaseTaxAmount'] as num?)
                    ?.toDouble() ??
                0.0;
        total += quantity * taxPerUnit;
      }
    }

    return total;
  }

  void _markForRecalculation() {
    _needsRecalculation = true;
  }

  /// Convert DynamicPaymentData to API format with payment method IDs
  Map<String, dynamic> _convertPaymentDataToApiFormat(
      DynamicPaymentData paymentData) {
    List<String> paymentMethodIds = [];
    List<Map<String, dynamic>> paidMethods = [];

    // Add primary method if present
    if (paymentData.primaryMethod != null &&
        paymentData.primaryAmount.isNotEmpty) {
      int? methodId = paymentData.primaryMethodId;
      double amount = double.tryParse(paymentData.primaryAmount) ?? 0.0;

      if (methodId != null && amount > 0) {
        paymentMethodIds.add(methodId.toString());
        paidMethods.add({
          'method': methodId,
          'amount': amount,
        });
      }
    }

    // Add secondary method if present
    if (paymentData.secondaryMethod != null &&
        paymentData.secondaryAmount.isNotEmpty) {
      int? methodId = paymentData.secondaryMethodId;
      double amount = double.tryParse(paymentData.secondaryAmount) ?? 0.0;

      if (methodId != null && amount > 0) {
        paymentMethodIds.add(methodId.toString());
        paidMethods.add({
          'method': methodId,
          'amount': amount,
        });
      }
    }

    return {
      'payment_methods': paymentMethodIds,
      'paid_methods': paidMethods,
    };
  }

  /// Show batch processing results dialog
  void _showBatchProcessingResults(Map<String, dynamic> batchResult) {
    final summary = batchResult['summary'] as Map<String, dynamic>;
    final int successful = summary['successful'] ?? 0;
    final int failed = summary['failed'] ?? 0;
    final int total = summary['total'] ?? 0;
    final List<dynamic> results = batchResult['results'] ?? [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(
                successful == total ? Icons.check_circle : Icons.warning,
                color: successful == total ? Colors.green : Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'add_stock.batch_title'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s16,
                    0.30,
                    ColorManager.textColor,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary cards
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          children: [
                            Text(
                              total.toString(),
                              style: buildCustomStyle(
                                FontWeightManager.bold,
                                FontSize.s20,
                                0.30,
                                Colors.blue.shade700,
                              ),
                            ),
                            Text(
                              'add_stock.batch_total'.tr,
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.27,
                                Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          children: [
                            Text(
                              successful.toString(),
                              style: buildCustomStyle(
                                FontWeightManager.bold,
                                FontSize.s20,
                                0.30,
                                Colors.green.shade700,
                              ),
                            ),
                            Text(
                              'add_stock.batch_successful'.tr,
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.27,
                                Colors.green.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          children: [
                            Text(
                              failed.toString(),
                              style: buildCustomStyle(
                                FontWeightManager.bold,
                                FontSize.s20,
                                0.30,
                                Colors.red.shade700,
                              ),
                            ),
                            Text(
                              'add_stock.batch_failed'.tr,
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.27,
                                Colors.red.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'add_stock.detailed_results'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s14,
                    0.30,
                    ColorManager.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                // Results list
                Expanded(
                  child: ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final result = results[index] as Map<String, dynamic>;
                      final bool isSuccess = result['status'] == 'success';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSuccess
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSuccess
                                ? Colors.green.shade200
                                : Colors.red.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isSuccess ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  result['itemIndex'].toString(),
                                  style: buildCustomStyle(
                                    FontWeightManager.semiBold,
                                    FontSize.s10,
                                    0.27,
                                    Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isSuccess ? 'add_stock.success'.tr : 'add_stock.failed'.tr,
                                    style: buildCustomStyle(
                                      FontWeightManager.semiBold,
                                      FontSize.s12,
                                      0.27,
                                      isSuccess
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    result['message'] ?? 'add_stock.no_message'.tr,
                                    style: buildCustomStyle(
                                      FontWeightManager.regular,
                                      FontSize.s11,
                                      0.27,
                                      Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isSuccess ? Icons.check_circle : Icons.error,
                              color: isSuccess ? Colors.green : Colors.red,
                              size: 20,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // Retry Failed Button (only show if there are failed items)
            if (failed > 0) ...[
              Consumer<StockProvider>(
                builder: (context, stockProvider, child) {
                  return TextButton.icon(
                    onPressed: stockProvider.batchProcessingLoading
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            stockProvider.resetFailedItemsForRetry();
                            showScaffold(
                                context: context,
                                message:
                                    'add_stock.retry_reset_message'.tr);
                          },
                    icon: Icon(
                      Icons.refresh,
                      size: 16,
                      color: stockProvider.batchProcessingLoading
                          ? Colors.grey
                          : Colors.orange.shade600,
                    ),
                    label: Text(
                      'add_stock.retry_failed'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s14,
                        0.30,
                        stockProvider.batchProcessingLoading
                            ? Colors.grey
                            : Colors.orange.shade600,
                      ),
                    ),
                  );
                },
              ),
            ],
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'add_stock.close'.tr,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s14,
                  0.30,
                  ColorManager.kPrimaryColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Show product details modal for the selected stock item
  void _showProductDetailsModal(int index) async {
    final item = stockItems[index];
    if (item.productData == null) return;

    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final currency = appSettingsProvider.appSettings?.currency ?? '';
    final productId = item.productData!.productId;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return ProductDetailsDialog(
          product: item.productData!,
          unitPrice: double.tryParse(item.salePrice) ?? 0.0,
          mrp: double.tryParse(item.mrp) ?? 0.0,
          quantity: num.tryParse(item.quantity) ?? 1,
          selectedStock: null, // Stock items don't have selectedStock
          isCompact: false,
          currency: currency,
        );
      },
    );

    // After dialog closes, refresh the product data from LocalProductProvider
    // This ensures any edits made in the dialog are reflected in the stock row
    if (mounted && productId != null) {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      // Find the updated product from the provider
      try {
        final updatedProduct = localProductProvider.products.firstWhere(
          (p) => p.productId == productId,
        );

        // Update the stock item with the refreshed product data
        setState(() {
          final previousVariantId = stockItems[index].productVariantId;
          stockItems[index].productData = updatedProduct;
          stockItems[index].product = updatedProduct.productName ?? '';
          ProductVariant? refreshedVariant;
          for (final variant in updatedProduct.activeVariants) {
            if (variant.id == previousVariantId) {
              refreshedVariant = variant;
              break;
            }
          }
          stockItems[index].productVariantId = refreshedVariant?.id;
          stockItems[index].variantName = refreshedVariant == null
              ? null
              : _variantLabel(refreshedVariant);
          stockItems[index].barcode =
              refreshedVariant?.barcode ?? updatedProduct.barcode ?? '';

          // Update barcode controller
          _getBarcodeController(index).text = stockItems[index].barcode;

          // Clear the filtered products cache to force rebuild with updated names
          _clearProductCache();

          debugPrint(
              '✅ Refreshed product data after edit: ${updatedProduct.productName}');
        });
      } catch (e) {
        debugPrint('⚠️ Could not find updated product: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    // Calculate total stock value only when needed
    if (_needsRecalculation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateTotalStockValue();
        _needsRecalculation = false;
      });
    }

    return SafeArea(
      child: Container(
        height: size.height,
        margin: const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: ColorManager.boxShadowColor,
              blurRadius: 6,
              offset: Offset(1, 1),
            ),
          ],
          color: Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 5.0, left: 5, right: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CustomBackButton(
              //   onPressed: () {
              //     sideBarController.index.value = 15;
              //   },
              //   text: 'All Stocks',
              // ),

              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      sideBarController.index.value = 15;
                    },
                    icon: const Icon(
                      Icons.arrow_back,
                      color: ColorManager.kPrimaryColor,
                      size: 24.0,
                    ),
                  ),
                  // const SizedBox(
                  //   width: 10,
                  // ),
                  Text(
                    'add_stock.title'.tr,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s20,
                      0.30,
                      ColorManager.textColor,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: CustomScrollView(
                    slivers: [
                      // Header Section (non-scrollable header content)
                      SliverToBoxAdapter(
                        child: Column(
                          // crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderSection(size),
                            // const SizedBox(height: 20),
                            // Input Section - Sticky at top (visually below header)
                            _buildInputSection(),
                            // const SizedBox(height: 20),
                            _buildStockTableHeader(),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),

                      // Stock Items List - Virtualized for performance (Below input)
                      _buildOptimizedStockList(),
                      // Footer Section (payment and action buttons)
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            _buildPaymentSection(),
                            const SizedBox(height: 20),
                            _buildActionButtons(size),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(Size size) {
    final bool isMobile = stockIsPhone(context);

    if (isMobile) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateField('add_stock.date'.tr, selectedDate,
                (date) => setState(() => selectedDate = date)),
            const SizedBox(height: 12),
            _buildStoreDropdown(size),
            const SizedBox(height: 12),
            _buildSupplierField(),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: _buildDateField('add_stock.date'.tr, selectedDate,
                  (date) => setState(() => selectedDate = date))),
          const SizedBox(width: 20),
          Expanded(child: _buildStoreDropdown(size)),
          const SizedBox(width: 20),
          Expanded(child: _buildSupplierField()),
        ],
      ),
    );
  }

  Widget _buildDateField(
      String title, DateTime selectedDate, Function(DateTime) onDateSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // BuildTextTile(
        //   isStarRed: true,
        //   isTextField: true,
        //   title: title,
        //   textStyle: buildCustomStyle(
        //     FontWeightManager.regular,
        //     FontSize.s14,
        //     0.27,
        //     Colors.black.withOpacity(0.6),
        //   ),
        // ),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          height: MediaQuery.of(context).size.height * .07,
          child: CalendarPickerTableCell(
            initialDate: selectedDate,
            onDateSelected: onDateSelected,
            hintText: 'add_stock.select_field'.tr.replaceAll('@field', title),
            isRequired: true,
            firstDate:
                DateTime(2020), // Allow past dates for all general date fields
            lastDate: DateTime(2030),
            showQuickActions: false, // No quick actions for header dates
            isForExpiry: false, // These are not expiry dates
            isAllowEdit: true, // Allow text editing for header dates
          ),
        ),
      ],
    );
  }

  Widget _buildStoreDropdown(Size size) {
    // Display active store as read-only field since it's set from session
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // BuildTextTile(
        //   isStarRed: true,
        //   isTextField: true,
        //   title: 'Store',
        //   textStyle: buildCustomStyle(
        //     FontWeightManager.regular,
        //     FontSize.s14,
        //     0.27,
        //     Colors.black.withOpacity(0.6),
        //   ),
        // ),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          height: MediaQuery.of(context).size.height * .07,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.store,
                  size: 20,
                  color: ColorManager.kPrimaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedStore?.name ?? 'add_stock.loading_active_store'.tr,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s14,
                      0.27,
                      selectedStore != null
                          ? Colors.black.withOpacity(0.8)
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
                if (selectedStore != null)
                  const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: Colors.green,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSupplierField() {
    return Consumer<SupplierProvider>(
      builder: (context, supplierProvider, child) {
        // Use allSuppliers to avoid pagination issues - shows all suppliers in dropdown
        List<Supplier> supplierList = supplierProvider.allSuppliers ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: BuildDropDownWithSearch<Supplier>(
                    // title: "Supplier",
                    hintText: 'add_stock.select_supplier'.tr,
                    value: selectedSupplier,
                    items: supplierList,
                    onChanged: (value) {
                      setState(() {
                        selectedSupplier = value;
                      });
                    },
                    displayText: (supplier) => supplier.name,
                    searchController: supplierSearchController,
                    isRequired: true,
                    searchHintText: 'add_stock.search_supplier'.tr,
                  ),
                ),
                const SizedBox(width: 8),
                // Add Supplier Button
                BuildBoxShadowContainer(
                  height: MediaQuery.of(context).size.height * .07,
                  width: 50,
                  circleRadius: 5,
                  child: InkWell(
                    onTap: () async {
                      debugPrint("ADD NEW SUPPLIER BUTTON PRESSED");
                      final result = await showAddSupplierModal(
                          context, MediaQuery.of(context).size,
                          showCreateAnother: false);
                      if (result != null &&
                          result is Map &&
                          result['status'] == 'success') {
                        final createdPhone = (result['phone'] ?? '').toString();
                        final createdName = (result['name'] ?? '').toString();

                        // Try to fetch the newly created supplier by phone and auto-select
                        try {
                          String? accessToken =
                              Provider.of<AuthModel>(context, listen: false)
                                  .token;
                          if (accessToken != null) {
                            // Refresh supplier list to include the new supplier
                            await Provider.of<SupplierProvider>(context,
                                    listen: false)
                                .fetchSuppliers(accessToken: accessToken);

                            // Find the newly created supplier in the updated list (use allSuppliers to avoid pagination)
                            final updatedSupplierList =
                                Provider.of<SupplierProvider>(context,
                                            listen: false)
                                        .allSuppliers ??
                                    [];

                            if (updatedSupplierList.isNotEmpty) {
                              try {
                                final newSupplier =
                                    updatedSupplierList.firstWhere(
                                  (supplier) => supplier.phone == createdPhone,
                                );

                                setState(() {
                                  selectedSupplier = newSupplier;
                                });

                                debugPrint(
                                    "✅ NEW SUPPLIER AUTO-SELECTED: ${newSupplier.name}");
                              } catch (e) {
                                // Supplier with matching phone not found, don't auto-select
                                debugPrint(
                                    "⚠️ Newly created supplier not found by phone: $createdPhone");
                              }
                            }
                          }
                        } catch (e) {
                          debugPrint("❌ ERROR AUTO-SELECTING NEW SUPPLIER: $e");
                          // Fallback: just refresh the supplier list
                          try {
                            String? accessToken =
                                Provider.of<AuthModel>(context, listen: false)
                                    .token;
                            if (accessToken != null) {
                              await Provider.of<SupplierProvider>(context,
                                      listen: false)
                                  .fetchSuppliers(accessToken: accessToken);
                            }
                          } catch (refreshError) {
                            debugPrint(
                                "❌ ERROR REFRESHING SUPPLIER LIST: $refreshError");
                          }
                        }
                      }
                    },
                    child: const Center(
                      child: Icon(
                        Icons.add,
                        size: 27,
                        color: ColorManager.kButtonGreen,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Current Balance Display
            if (selectedSupplier != null) ...[
              const SizedBox(height: 8),
              _buildSupplierBalanceDisplay(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStockTableHeader() {
    if (stockIsPhone(context)) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorManager.kPrimaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          _buildHeaderCell('add_stock.col_no'.tr, flex: 1, width: 40),
          _buildHeaderCell('add_stock.barcode'.tr, flex: 2),
          _buildHeaderCell('add_stock.product'.tr, flex: 4),
          _buildHeaderCell('add_stock.unit'.tr, flex: 1),
          _buildHeaderCell('add_stock.qty'.tr, flex: 1, width: 40),
          _buildHeaderCell('add_stock.purchase_rate'.tr, flex: 2),
          _buildHeaderCell('add_stock.retail_price'.tr, flex: 2),
          _buildHeaderCell('add_stock.mrp'.tr, flex: 1),
          _buildHeaderCell('add_stock.actions'.tr, flex: 2, isLast: true),
          // _buildHeaderCell("No.", flex: 0, width: 40),
          // _buildHeaderCell("Barcode", flex: 2),
          // _buildHeaderCell("Category", flex: 2),
          // _buildHeaderCell("Product", flex: 3),
          // _buildHeaderCell("Qty", flex: 1),
          // _buildHeaderCell("Actions", flex: 0, width: 150),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String title,
      {int flex = 1, double? width, bool isLast = false}) {
    if (flex == 0) {
      return SizedBox(
        width: width,
        child: Text(
          title,
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s12,
              0.27, ColorManager.kPrimaryColor),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Text(
          title,
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s12,
              0.27, ColorManager.kPrimaryColor),
          textAlign: isLast ? TextAlign.end : TextAlign.start,
        ),
      ),
    );
  }

  /// Get visible (non-hidden) stock items - OPTIMIZED with caching
  List<StockItem> get visibleStockItems {
    if (_needsIndexRebuild) {
      _rebuildIndexCache();
    }
    return _cachedVisibleItems;
  }

  /// Get the original index of a visible item - OPTIMIZED with O(1) lookup
  int getOriginalIndex(int visibleIndex) {
    if (_needsIndexRebuild) {
      _rebuildIndexCache();
    }
    return _visibleToOriginalIndexMap[visibleIndex] ?? -1;
  }

  /// Build optimized stock list using SliverList for virtualization
  /// This only builds visible items, preventing memory issues with 100+ items
  Widget _buildOptimizedStockList() {
    final visibleItems = visibleStockItems;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, visibleIndex) {
          int originalIndex = getOriginalIndex(visibleIndex);
          if (originalIndex < 0) return const SizedBox.shrink();

          // Use RepaintBoundary to isolate repaints for each row
          // return RepaintBoundary(
          //   child: _buildStockRow(originalIndex, visibleIndex,
          //       key: ValueKey('stock_row_$originalIndex')),
          // );

//---------------------------------------------------------------------------------------
          final item = stockItems[originalIndex];

          final bool isMobile = stockIsPhone(context);

          if (isMobile) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: No, Product Name, and Edit/Delete buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: ColorManager.kPrimaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${visibleIndex + 1}',
                                style: buildCustomStyle(
                                  FontWeightManager.bold,
                                  11,
                                  0.15,
                                  ColorManager.kPrimaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.product,
                                style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  12,
                                  0.15,
                                  ColorManager.textColor,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _editStockItem(originalIndex),
                            icon: const Icon(
                              Icons.edit,
                              size: 16,
                              color: ColorManager.kPrimaryColor,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () => _deleteStockItem(originalIndex),
                            icon: WebsafeSvg.asset(
                              ImageAssets.oderlistCloseIcon,
                              width: 16,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 16),

                  // Barcode & Unit Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'add_stock.barcode_prefix'.tr.replaceAll('@code', item.barcode.isEmpty ? "-" : item.barcode),
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          11,
                          0.15,
                          Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        'add_stock.unit_prefix'.tr.replaceAll('@unit', item.unit),
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          11,
                          0.15,
                          Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Editable fields in a 2x2 layout
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'add_stock.qty'.tr,
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                10,
                                0.15,
                                Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _InlineEditableField(
                              value: item.quantity,
                              hintText: 'add_stock.qty'.tr,
                              inputFormatters:
                                  quantityInputFormattersForUnit(item.unit),
                              onChanged: (val) => _updateStockItemFieldInline(
                                  originalIndex, 'quantity', val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'add_stock.purchase_rate'.tr,
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                10,
                                0.15,
                                Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Builder(
                              builder: (context) {
                                if (!item.taxInclude &&
                                    item.calculatedTaxData != null) {
                                  final effective = (item.calculatedTaxData![
                                          'price_including_tax_purchase'] as num?)
                                      ?.toDouble();
                                  if (effective != null && effective > 0) {
                                    return Container(
                                      height: 32,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        effective.toStringAsFixed(2),
                                        style: buildCustomStyle(
                                          FontWeightManager.regular,
                                          11,
                                          0.21,
                                          Colors.green.shade700,
                                        ),
                                      ),
                                    );
                                  }
                                }
                                return _InlineEditableField(
                                  value: item.purchaseRate,
                                  hintText: 'add_stock.rate_hint'.tr,
                                  onChanged: (val) =>
                                      _updateStockItemFieldInline(
                                          originalIndex, 'purchaseRate', val),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'add_stock.retail_price'.tr,
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                10,
                                0.15,
                                Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Builder(
                              builder: (context) {
                                if (!item.taxInclude &&
                                    item.calculatedTaxData != null) {
                                  final effective = (item.calculatedTaxData![
                                          'price_including_tax_retail'] as num?)
                                      ?.toDouble();
                                  if (effective != null && effective > 0) {
                                    return Container(
                                      height: 32,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        effective.toStringAsFixed(2),
                                        style: buildCustomStyle(
                                          FontWeightManager.regular,
                                          11,
                                          0.21,
                                          Colors.blue.shade700,
                                        ),
                                      ),
                                    );
                                  }
                                }
                                return _InlineEditableField(
                                  value: item.salePrice,
                                  hintText: 'add_stock.price_hint'.tr,
                                  onChanged: (val) =>
                                      _updateStockItemFieldInline(
                                          originalIndex, 'salePrice', val),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'add_stock.mrp'.tr,
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                10,
                                0.15,
                                Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _InlineEditableField(
                              value: item.mrp,
                              hintText: 'add_stock.mrp'.tr,
                              onChanged: (val) => _updateStockItemFieldInline(
                                  originalIndex, 'mrp', val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              color: visibleIndex.isEven ? Colors.white : Colors.grey.shade50,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
                child: InkWell(
                  onTap: () => _showProductDetailsModal(visibleIndex),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${visibleIndex + 1}',
                          style: buildCustomStyle(
                            FontWeightManager.regular,
                            11,
                            0.21,
                            ColorManager.textColor,
                          ),
                          textAlign: TextAlign.start,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.barcode,
                          style: buildCustomStyle(
                            FontWeightManager.regular,
                            11,
                            0.21,
                            ColorManager.textColor,
                          ),
                          textAlign: TextAlign.start,
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          item.product,
                          style: buildCustomStyle(
                            FontWeightManager.regular,
                            11,
                            0.21,
                            ColorManager.textColor,
                          ),
                          textAlign: TextAlign.start,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          item.unit,
                          style: buildCustomStyle(
                            FontWeightManager.regular,
                            11,
                            0.21,
                            ColorManager.textColor,
                          ),
                          textAlign: TextAlign.start,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: _InlineEditableField(
                          value: item.quantity,
                          hintText: 'add_stock.qty'.tr,
                          inputFormatters:
                              quantityInputFormattersForUnit(item.unit),
                          onChanged: (val) => _updateStockItemFieldInline(
                              originalIndex, 'quantity', val),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Builder(
                          builder: (context) {
                            // Show effective (tax-inclusive) purchase rate when tax is excluded
                            if (!item.taxInclude &&
                                item.calculatedTaxData != null) {
                              final effective = (item.calculatedTaxData![
                                      'price_including_tax_purchase'] as num?)
                                  ?.toDouble();
                              if (effective != null && effective > 0) {
                                return Text(
                                  effective.toStringAsFixed(2),
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    11,
                                    0.21,
                                    Colors.green.shade700,
                                  ),
                                );
                              }
                            }
                            return _InlineEditableField(
                              value: item.purchaseRate,
                              hintText: 'add_stock.rate_hint'.tr,
                              onChanged: (val) => _updateStockItemFieldInline(
                                  originalIndex, 'purchaseRate', val),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Builder(
                          builder: (context) {
                            // Show effective (tax-inclusive) retail price when tax is excluded
                            if (!item.taxInclude &&
                                item.calculatedTaxData != null) {
                              final effective = (item.calculatedTaxData![
                                      'price_including_tax_retail'] as num?)
                                  ?.toDouble();
                              if (effective != null && effective > 0) {
                                return Text(
                                  effective.toStringAsFixed(2),
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    11,
                                    0.21,
                                    Colors.blue.shade700,
                                  ),
                                );
                              }
                            }
                            return _InlineEditableField(
                              value: item.salePrice,
                              hintText: 'add_stock.price_hint'.tr,
                              onChanged: (val) => _updateStockItemFieldInline(
                                  originalIndex, 'salePrice', val),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: _InlineEditableField(
                          value: item.mrp,
                          hintText: 'add_stock.mrp'.tr,
                          onChanged: (val) => _updateStockItemFieldInline(
                              originalIndex, 'mrp', val),
                        ),
                      ),
                      Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                onPressed: () => _editStockItem(originalIndex),
                                icon: const Icon(
                                  Icons.edit,
                                  size: 15,
                                  color: ColorManager.kPrimaryColor,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(
                                width: 20,
                              ),
                              IconButton(
                                onPressed: () =>
                                    _deleteStockItem(originalIndex),
                                icon: WebsafeSvg.asset(
                                  ImageAssets.oderlistCloseIcon,
                                  width: 15,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          )),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        childCount: visibleItems.length,
        // Add extent hints for better performance
        addAutomaticKeepAlives: false, // Don't keep all items alive
        addRepaintBoundaries: false, // We add our own RepaintBoundary
      ),
    );
  }

  Widget _buildInputSection() {
    // Determine the number of successfully added items to calculate the correct index for the new item.
    int addedCount = stockItems
        .where((item) => item.isSuccessfullyAdded && !item.isHidden)
        .length;

    // Find indices of items that are NOT successfully added (input forms)
    final inputItemsIndices = <int>[];
    for (int i = 0; i < stockItems.length; i++) {
      if (!stockItems[i].isHidden && !stockItems[i].isSuccessfullyAdded) {
        inputItemsIndices.add(i);
      }
    }

    if (inputItemsIndices.isEmpty) return const SizedBox.shrink();

    return Column(
      children: inputItemsIndices.map((originalIndex) {
        // We pass 'addedCount' as the visible index so the row number continues sequentially.
        // If there are multiple input rows (rare), we increment the count.
        int currentVisibleIndex =
            addedCount + inputItemsIndices.indexOf(originalIndex);

        return Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
          child: _buildStockRow(originalIndex, currentVisibleIndex,
              key: ValueKey('input_stock_row_$originalIndex')),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentSection() {
    return Consumer<StockProvider>(
      builder: (context, stockProvider, child) {
        // Only show payment section if there are successfully added items or pending items
        bool hasSuccessfulItems = stockItems
            .any((item) => item.isSuccessfullyAdded && !item.isHidden);
        bool hasPendingItems = stockProvider.pendingStockItemsCount > 0;
        bool hasEditableItems = stockItems.any((item) =>
            item.isSuccessfullyAdded &&
            !item.isHidden &&
            item.apiResponse != null &&
            item.apiResponse!['status'] == 'pending');

        if (!hasSuccessfulItems && !hasPendingItems) {
          return const SizedBox.shrink(); // Hidden when no items added
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pending Items Info Section - Only show if there are pending items but no editable items loaded
            if (hasPendingItems && !hasEditableItems) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.pending_actions,
                      color: Colors.orange.shade600,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'add_stock.pending_items_ready'.tr,
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s14,
                              0.30,
                              Colors.orange.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'add_stock.pending_items_ready_desc'.tr.replaceAll('@count', stockProvider.pendingStockItemsCount.toString()),
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s12,
                              0.27,
                              Colors.orange.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Purchase Amount Details Section
            _buildPurchaseAmountDetails(),

            const SizedBox(height: 16),

            // Dynamic payment method selector using API payment methods
            BuildDynamicPaymentSelector(
              title: 'add_stock.select_payment_method'.tr,
              paymentMethods: _paymentMethods,
              isLoading: _isLoadingPaymentMethods,
              onPaymentChanged: (data) {
                setState(() {
                  paymentData = data;
                });
                debugPrint('Purchase Payment Data: ${data.totalAmount}');
              },
              showTotalAmount: true,
              maxMethods: 2, // Allow split payment with any 2 methods
            ),
          ],
        );
      },
    );
  }

  Widget _buildPurchaseAmountDetails() {
    // Calculate totals for successfully added items
    double totalPurchaseAmount = 0.0;
    int totalItems = 0;
    double totalQuantity = 0.0;

    for (StockItem item in stockItems) {
      if (item.isSuccessfullyAdded && !item.isHidden) {
        double quantity = double.tryParse(item.quantity) ?? 0.0;
        double pricingQuantity = _getPricingQuantity(item);
        double purchaseRate = double.tryParse(item.purchaseRate) ?? 0.0;

        // Calculate item total including tax if tax is not included in the price
        double itemTotal = purchaseRate * pricingQuantity;
        if (!item.taxInclude) {
          final taxPerUnit =
              (item.calculatedTaxData?['purchaseTaxAmount'] as num?)
                      ?.toDouble() ??
                  0.0;
          itemTotal += pricingQuantity * taxPerUnit;
        }

        totalPurchaseAmount += itemTotal;
        totalItems++;
        totalQuantity += quantity;
      }
    }

    // Get supplier information
    final double additionalPurchaseTax = _getAdditionalPurchaseTaxTotal();
    String supplierName = selectedSupplier?.name ?? 'add_stock.no_supplier'.tr;
    double supplierBalance =
        _getSupplierBalance(); // Helper method to get balance
    double totalPayable = totalPurchaseAmount + supplierBalance;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with supplier info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'add_stock.purchase_summary'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s16,
                        0.30,
                        ColorManager.kPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'add_stock.supplier_prefix'.tr.replaceAll('@name', supplierName),
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.27,
                        Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // Supplier balance badge
              _buildSupplierBalanceBadge(supplierBalance),
            ],
          ),

          const SizedBox(height: 16),

          // Purchase details in a single row
          // Purchase details in a single row (2x2 on mobile)
          Builder(
            builder: (context) {
              final bool isMobile = stockIsPhone(context);
              if (isMobile) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'add_stock.total_items'.tr,
                            totalItems.toString(),
                            Icons.inventory_2_outlined,
                            Colors.blue.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryCard(
                            'add_stock.total_purchase_amount'.tr,
                            '${totalPurchaseAmount.toStringAsFixed(2)}',
                            Icons.shopping_cart_outlined,
                            Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'add_stock.total_quantity'.tr,
                            _formatNumber(totalQuantity),
                            Icons.format_list_numbered_outlined,
                            Colors.orange.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryCard(
                            'add_stock.total_due_amount'.tr,
                            '${totalPayable.toStringAsFixed(2)}',
                            Icons.payment_outlined,
                            totalPayable >= 0
                                ? Colors.green.shade600
                                : Colors.red.shade600,
                            isHighlighted: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'add_stock.total_items'.tr,
                      totalItems.toString(),
                      Icons.inventory_2_outlined,
                      Colors.blue.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'add_stock.total_purchase_amount'.tr,
                      '${totalPurchaseAmount.toStringAsFixed(2)}',
                      Icons.shopping_cart_outlined,
                      Colors.green.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'add_stock.total_quantity'.tr,
                      _formatNumber(totalQuantity),
                      Icons.format_list_numbered_outlined,
                      Colors.orange.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'add_stock.total_due_amount'.tr,
                      '${totalPayable.toStringAsFixed(2)}',
                      Icons.payment_outlined,
                      totalPayable >= 0
                          ? Colors.green.shade600
                          : Colors.red.shade600,
                      isHighlighted: true,
                    ),
                  ),
                ],
              );
            },
          ),
          if (additionalPurchaseTax > 0) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'add_stock.additional_purchase_tax'.tr.replaceAll('@amount', additionalPurchaseTax.toStringAsFixed(2)),
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s11,
                  0.27,
                  Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupplierBalanceBadge(double balance) {
    // Determine badge color/icon from current balance sign
    // Positive => to pay (owe supplier) [red]
    // Negative => to receive (supplier owes us) [green]
    final bool isToPay = balance > 0;
    final bool isToReceive = balance < 0;

    Color badgeColor = isToPay
        ? Colors.red
        : isToReceive
            ? Colors.green
            : Colors.grey;

    IconData icon = isToPay
        ? Icons.arrow_upward
        : isToReceive
            ? Icons.arrow_downward
            : Icons.balance;

    String balanceText = balance.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'add_stock.supplier_balance'.tr,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s10,
                  0.27,
                  Colors.grey.shade600,
                ),
              ),
              Text(
                '$balanceText',
                style: buildCustomStyle(
                  FontWeightManager.bold,
                  FontSize.s12,
                  0.27,
                  badgeColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, // Background is always white
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlighted
              ? color
              : Colors.grey.shade200, // Border color changes if highlighted
          width: isHighlighted ? 2 : 1, // Border is thicker if highlighted
        ),
        boxShadow: [
          // Consistent shadow for all cards
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s11,
                    0.27,
                    Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: buildCustomStyle(
              FontWeightManager.bold,
              isHighlighted ? FontSize.s14 : FontSize.s13,
              0.27,
              isHighlighted
                  ? color
                  : Colors.black87, // Text color changes if highlighted
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get supplier balance
  double _getSupplierBalance() {
    if (selectedSupplier != null) {
      return selectedSupplier!.currentBalance;
    }
    return 0.0;
  }

  // Build supplier balance display under the dropdown
  Widget _buildSupplierBalanceDisplay() {
    double balance = _getSupplierBalance();
    // Determine UI based on balance sign, not payment type
    // Positive balance => we owe supplier (to pay)
    // Negative balance => supplier owes us (to receive)
    final bool isToPay = balance > 0;
    final bool isToReceive = balance < 0;

    Color textColor = isToPay
        ? Colors.red
        : isToReceive
            ? Colors.green
            : Colors.black;

    String balanceLabel = isToPay
        ? 'add_stock.amount_to_pay'.tr
        : isToReceive
            ? 'add_stock.amount_to_receive'.tr
            : 'add_stock.current_balance'.tr;

    IconData icon = isToPay
        ? Icons.arrow_upward
        : isToReceive
            ? Icons.arrow_downward
            : Icons.balance;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 10),
        Icon(
          icon,
          size: 14,
          color: textColor,
        ),
        const SizedBox(width: 6),
        Text(
          '$balanceLabel ${balance.abs().toStringAsFixed(2)}',
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.27,
            textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStockRow(int index, int visibleIndex, {Key? key}) {
    debugPrint("visible index: $visibleIndex index is $index");
    final item = stockItems[index];
    final bool isEditingInputRow =
        _editingItemIndex != null && !item.isSuccessfullyAdded;

    return BuildBoxShadowContainer(
      key: key,
      circleRadius: 7,
      margin: const EdgeInsets.symmetric(
        horizontal: 8,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          // Main row content
          stockIsPhone(context)
              ? _buildStockRowMobile(index, visibleIndex, isEditingInputRow, item)
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                // Row Number Indicator (centered circle, no square)
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: item.isSuccessfullyAdded
                              ? Colors.green
                              : Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${visibleIndex + 1}',
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s10,
                              0.27,
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Updated indicator - Yellow badge showing "Edited"
                      if (item.isSuccessfullyAdded &&
                          item.apiResponse != null &&
                          item.apiResponse!['localId'] != null) ...[
                        Consumer<StockProvider>(
                          builder: (context, stockProvider, child) {
                            final pendingItem =
                                stockProvider.getPendingStockItem(
                                    item.apiResponse!['localId']);
                            final bool isUpdated = pendingItem != null &&
                                pendingItem['updatedAt'] != null;

                            if (!isUpdated) return const SizedBox.shrink();

                            return Positioned(
                              top: -4,
                              right: -8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'add_stock.edited'.tr,
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Barcode Text Field with Add Product Button
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Expanded(
                        child: BuildBoxShadowContainer(
                          circleRadius: 5,
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: TextFormField(
                            controller: _getBarcodeController(index),
                            focusNode: _getBarcodeFocusNode(index),
                            decoration: InputDecoration(
                              hintText: 'add_stock.barcode'.tr,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                            ),
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s11,
                              0.27,
                              ColorManager.textColor,
                            ),
                            onTap: () {
                              // Select all text when field is tapped
                              _getBarcodeController(index).selection =
                                  TextSelection(
                                baseOffset: 0,
                                extentOffset:
                                    _getBarcodeController(index).text.length,
                              );
                            },
                            onFieldSubmitted: (value) {
                              // Update and auto-fill only on submit
                              stockItems[index].barcode = value;
                              _autoFillFromBarcode(index, value);
                              _updatePendingStockItem(index);
                              if (mounted) setState(() {});
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Add Product Button
                      Tooltip(
                        message: 'add_stock.create_new_product'.tr,
                        child: Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: const [
                              BoxShadow(
                                color: ColorManager.boxShadowColor,
                                blurRadius: 3,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.add,
                              size: 18,
                              color: Colors.white,
                            ),
                            onPressed: () => _showAddProductModal(index),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Product Dropdown with Search (maximum width)
                Expanded(
                  flex: 6,
                  child: SizedBox(
                    height: 40,
                    child: _buildProductDropdown(index),
                  ),
                ),
                const SizedBox(width: 4),
                // Info Button for Product Details
                if (stockItems[index].productData != null) ...[
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      boxShadow: const [
                        BoxShadow(
                          color: ColorManager.boxShadowColor,
                          blurRadius: 3,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Colors.blue,
                      ),
                      onPressed: () => _showProductDetailsModal(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      tooltip: 'add_stock.view_product_details'.tr,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                // Quantity Text Field (smaller and right-aligned) - Hidden for multi-unit products
                if (!_hasPurchaseUnits(item)) ...[
                  SizedBox(
                    width: 80, // Fixed width instead of flex
                    child: BuildBoxShadowContainer(
                      circleRadius: 5,
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: TextFormField(
                        controller: _getQuantityController(index),
                        focusNode: _getQuantityFocusNode(index),
                        keyboardType: TextInputType.number,
                        inputFormatters:
                            quantityInputFormattersForUnit(item.unit),
                        textAlign: TextAlign.right, // Right-aligned text
                        decoration: InputDecoration(
                          hintText: 'add_stock.qty'.tr,
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s11,
                          0.27,
                          ColorManager.textColor,
                        ),
                        onTap: () {
                          // Select all text when field is tapped
                          _getQuantityController(index).selection =
                              TextSelection(
                            baseOffset: 0,
                            extentOffset:
                                _getQuantityController(index).text.length,
                          );
                        },
                        onChanged: (value) {
                          // Update the value immediately for responsive UI
                          stockItems[index].quantity = value;
                          final selectedSaleUnit =
                              _getSelectedPurchaseSaleUnit(stockItems[index]);
                          if (selectedSaleUnit != null) {
                            final baseQuantity =
                                _parsePositiveDouble(value, fallback: 0.0);
                            final conversionRate = _parsePositiveDouble(
                              selectedSaleUnit.conversionRate,
                              fallback: 1.0,
                            );
                            if (baseQuantity > 0 && conversionRate > 0) {
                              stockItems[index].purchaseQty =
                                  _formatNumber(baseQuantity / conversionRate);
                              _getPurchaseQtyController(index).text =
                                  stockItems[index].purchaseQty;
                            }
                          }

                          // Debounce the heavy operations
                          _quantityDebounceTimer?.cancel();
                          _quantityDebounceTimer =
                              Timer(const Duration(milliseconds: 300), () {
                            if (mounted) {
                              setState(() {
                                // Update pending item if already added
                                _updatePendingStockItem(index);
                                // Mark for recalculation
                                _markForRecalculation();
                              });
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Actions - Add Stock Button + Clear/Delete Button + Expand Button
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Clear/Delete Button (Conditional)
                    if (item.productData != null ||
                        item.isSuccessfullyAdded) ...[
                      Tooltip(
                        message: isEditingInputRow
                            ? 'add_stock.cancel_edit'.tr
                            : item.isSuccessfullyAdded
                                ? 'add_stock.delete_stock_item'.tr
                                : 'add_stock.clear_product_selection'.tr,
                        child: Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            border:
                                Border.all(color: Colors.red.withOpacity(0.3)),
                            boxShadow: const [
                              BoxShadow(
                                color: ColorManager.boxShadowColor,
                                blurRadius: 3,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              isEditingInputRow
                                  ? Icons.close
                                  : item.isSuccessfullyAdded
                                      ? Icons.delete
                                      : Icons.clear,
                              size: 18,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              if (item.isSuccessfullyAdded) {
                                _deleteStockItem(index);
                              } else {
                                _clearStockItem(index);
                              }
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                          ),
                        ),
                      ),
                    ],
                    // Spacing between delete and add buttons
                    if (item.productData != null || item.isSuccessfullyAdded)
                      const SizedBox(width: 8),
                    // Add Stock Button (Only show if not already added)
                    if (!item.isSuccessfullyAdded) ...[
                      Tooltip(
                        message: _isLoading
                            ? (isEditingInputRow ? 'add_stock.saving'.tr : 'add_stock.adding'.tr)
                            : (isEditingInputRow
                                ? 'add_stock.save_changes'.tr
                                : 'add_stock.add_stock_item'.tr),
                        child: Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: _isLoading
                                ? Colors.grey
                                : ColorManager.kPrimaryColor,
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: const [
                              BoxShadow(
                                color: ColorManager.boxShadowColor,
                                blurRadius: 3,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              _isLoading
                                  ? Icons.hourglass_empty
                                  : (isEditingInputRow
                                      ? Icons.save
                                      : Icons.add),
                              size: 18,
                              color: Colors.white,
                            ),
                            onPressed: _isLoading
                                ? null
                                : () => _addStockForSingleItem(index),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Expand Button with Tooltip
                    Tooltip(
                      message: item.isExpanded
                          ? 'add_stock.hide_details'.tr
                          : 'add_stock.show_details'.tr,
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: item.isExpanded
                                  ? ColorManager.kPrimaryColor
                                  : Colors.grey.withOpacity(0.3)),
                          boxShadow: const [
                            BoxShadow(
                              color: ColorManager.boxShadowColor,
                              blurRadius: 3,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            item.isExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 18,
                            color: item.isExpanded
                                ? ColorManager.kPrimaryColor
                                : Colors.grey.shade600,
                          ),
                          onPressed: () => _toggleExpanded(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                      ),
                    ),
                    // if (stockItems.length > 1) ...[
                    //   const SizedBox(width: 8),
                    //   BuildBoxShadowContainer(
                    //     circleRadius: 7,
                    //     height: 40,
                    //     width: 40,
                    //     child: IconButton(
                    //       icon: item.isSuccessfullyAdded
                    //           ? const Icon(Icons.check_circle,
                    //               size: 18, color: Colors.green)
                    //           : const Icon(Icons.delete,
                    //               size: 18, color: Colors.red),
                    //       onPressed: item.isSuccessfullyAdded
                    //           ? null // Disable button for successfully added rows
                    //           : () => _removeStockRow(index),
                    //       padding: EdgeInsets.zero,
                    //       constraints: const BoxConstraints(
                    //         minWidth: 40,
                    //         minHeight: 40,
                    //       ),
                    //     ),
                    //   ),
                    // ],
                  ],
                ),
              ],
            ),
          ),
          _buildVariantSelector(index),
          // Quick preview for collapsed items with data - Single Row Layout
          if (!item.isExpanded &&
              (item.salePrice.isNotEmpty ||
                  item.purchaseRate.isNotEmpty ||
                  item.mrp.isNotEmpty ||
                  item.wholesale.isNotEmpty ||
                  item.unit.isNotEmpty ||
                  item.rack.isNotEmpty ||
                  item.batchNumber.isNotEmpty))
            Container(
              padding: const EdgeInsets.only(left: 48, right: 8, bottom: 8),
              child: Row(
                children: [
                  // All details in one row
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (_variantFeatureEnabled() &&
                            item.variantName?.isNotEmpty == true)
                          _buildDetailChip(
                            'add_stock.variant'.tr,
                            item.variantName!,
                            Icons.tune,
                            Colors.deepPurple.shade600,
                          ),
                        if (item.salePrice.isNotEmpty)
                          _buildDetailChip(
                              'add_stock.retail'.tr,
                              !item.taxInclude && item.calculatedTaxData != null
                                  ? ((item.calculatedTaxData![
                                                  'price_including_tax_retail']
                                              as num?)
                                          ?.toDouble()
                                          ?.toStringAsFixed(2) ??
                                      item.salePrice)
                                  : item.salePrice,
                              Icons.sell,
                              Colors.blue.shade600),
                        if (item.purchaseRate.isNotEmpty)
                          _buildDetailChip(
                              'add_stock.purchase'.tr,
                              !item.taxInclude && item.calculatedTaxData != null
                                  ? ((item.calculatedTaxData![
                                                  'price_including_tax_purchase']
                                              as num?)
                                          ?.toDouble()
                                          ?.toStringAsFixed(2) ??
                                      item.purchaseRate)
                                  : item.purchaseRate,
                              Icons.shopping_cart,
                              Colors.green.shade600),
                        if (item.mrp.isNotEmpty)
                          _buildDetailChip('add_stock.mrp'.tr, "${item.mrp}",
                              Icons.local_offer, Colors.orange.shade600),
                        if (item.wholesale.isNotEmpty)
                          _buildDetailChip('add_stock.wholesale'.tr, "${item.wholesale}",
                              Icons.store, Colors.purple.shade600),
                        if (item.unit.isNotEmpty)
                          _buildDetailChip('add_stock.unit'.tr, item.unit, Icons.straighten,
                              Colors.indigo.shade600),
                        if (item.purchaseUnitName != null &&
                            item.purchaseUnitName!.isNotEmpty)
                          _buildDetailChip(
                              'add_stock.purchase_unit'.tr,
                              '${item.purchaseUnitName} x ${item.purchaseQty}',
                              Icons.inventory_2_outlined,
                              Colors.deepOrange.shade600),
                        if (item.rack.isNotEmpty)
                          _buildDetailChip('add_stock.rack'.tr, item.rack, Icons.shelves,
                              Colors.teal.shade600),
                        if (item.batchNumber.isNotEmpty)
                          _buildDetailChip('add_stock.min_wholesale'.tr, item.batchNumber,
                              Icons.numbers, Colors.brown.shade600),
                      ],
                    ),
                  ),
                  // Purchase Total (Quantity × Purchase Price)
                  Builder(
                    builder: (context) {
                      final qty = _getPricingQuantity(item);
                      double purchasePrice =
                          double.tryParse(item.purchaseRate) ?? 0;
                      // Use effective (tax-inclusive) purchase rate when tax is excluded
                      if (!item.taxInclude && item.calculatedTaxData != null) {
                        final effective = (item.calculatedTaxData![
                                'price_including_tax_purchase'] as num?)
                            ?.toDouble();
                        if (effective != null && effective > 0) {
                          purchasePrice = effective;
                        }
                      }
                      final purchaseTotal = qty * purchasePrice;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          'add_stock.total_colon'.tr.replaceAll('@amount', purchaseTotal.toStringAsFixed(2)),
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s10,
                            0.27,
                            Colors.green.shade700,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          // Expanded section with additional fields
          if (item.isExpanded)
            Container(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: _buildExpandedSection(index),
            ),
        ],
      ),
    );
  }

  Widget _buildStockRowMobile(int index, int visibleIndex, bool isEditingInputRow, StockItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row Number Indicator & Barcode Row
          Row(
            children: [
              // Row Number Indicator
              SizedBox(
                width: 32,
                height: 32,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: item.isSuccessfullyAdded
                            ? Colors.green
                            : Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${visibleIndex + 1}',
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s10,
                            0.27,
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (item.isSuccessfullyAdded &&
                        item.apiResponse != null &&
                        item.apiResponse!['localId'] != null) ...[
                      Consumer<StockProvider>(
                        builder: (context, stockProvider, child) {
                          final pendingItem =
                              stockProvider.getPendingStockItem(
                                  item.apiResponse!['localId']);
                          final bool isUpdated = pendingItem != null &&
                              pendingItem['updatedAt'] != null;

                          if (!isUpdated) return const SizedBox.shrink();

                          return Positioned(
                            top: -4,
                            right: -8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                'add_stock.edited'.tr,
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Barcode Text Field with Add Product Button
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: BuildBoxShadowContainer(
                        circleRadius: 5,
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: TextFormField(
                          controller: _getBarcodeController(index),
                          focusNode: _getBarcodeFocusNode(index),
                          decoration: InputDecoration(
                            hintText: 'add_stock.barcode'.tr,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                          style: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s11,
                            0.27,
                            ColorManager.textColor,
                          ),
                          onTap: () {
                            _getBarcodeController(index).selection =
                                TextSelection(
                              baseOffset: 0,
                              extentOffset:
                                  _getBarcodeController(index).text.length,
                            );
                          },
                          onFieldSubmitted: (value) {
                            stockItems[index].barcode = value;
                            _autoFillFromBarcode(index, value);
                            _updatePendingStockItem(index);
                            if (mounted) setState(() {});
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'add_stock.create_new_product'.tr,
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: const [
                            BoxShadow(
                              color: ColorManager.boxShadowColor,
                              blurRadius: 3,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.add,
                            size: 18,
                            color: Colors.white,
                          ),
                          onPressed: () => _showAddProductModal(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Product Dropdown & Info Button Row
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: _buildProductDropdown(index),
                ),
              ),
              if (stockItems[index].productData != null) ...[
                const SizedBox(width: 8),
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    boxShadow: const [
                      BoxShadow(
                        color: ColorManager.boxShadowColor,
                        blurRadius: 3,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.blue,
                    ),
                    onPressed: () => _showProductDetailsModal(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    tooltip: 'add_stock.view_product_details'.tr,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Quantity and Action Buttons Row
          Row(
            children: [
              // Qty Field (if not multi-unit)
              if (!_hasPurchaseUnits(item)) ...[
                Expanded(
                  child: BuildBoxShadowContainer(
                    circleRadius: 5,
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextFormField(
                      controller: _getQuantityController(index),
                      focusNode: _getQuantityFocusNode(index),
                      keyboardType: TextInputType.number,
                      inputFormatters: quantityInputFormattersForUnit(item.unit),
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: 'add_stock.qty'.tr,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s11,
                        0.27,
                        ColorManager.textColor,
                      ),
                      onTap: () {
                        _getQuantityController(index).selection =
                            TextSelection(
                          baseOffset: 0,
                          extentOffset:
                              _getQuantityController(index).text.length,
                        );
                      },
                      onChanged: (value) {
                        stockItems[index].quantity = value;
                        final selectedSaleUnit =
                            _getSelectedPurchaseSaleUnit(stockItems[index]);
                        if (selectedSaleUnit != null) {
                          final baseQuantity =
                              _parsePositiveDouble(value, fallback: 0.0);
                          final conversionRate = _parsePositiveDouble(
                            selectedSaleUnit.conversionRate,
                            fallback: 1.0,
                          );
                          if (baseQuantity > 0 && conversionRate > 0) {
                            stockItems[index].purchaseQty =
                                _formatNumber(baseQuantity / conversionRate);
                            _getPurchaseQtyController(index).text =
                                stockItems[index].purchaseQty;
                          }
                        }

                        _quantityDebounceTimer?.cancel();
                        _quantityDebounceTimer =
                            Timer(const Duration(milliseconds: 300), () {
                          if (mounted) {
                            setState(() {
                              _updatePendingStockItem(index);
                              _markForRecalculation();
                            });
                          }
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ] else ...[
                const Expanded(child: SizedBox.shrink()),
              ],
              
              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.productData != null || item.isSuccessfullyAdded) ...[
                    Tooltip(
                      message: isEditingInputRow
                          ? 'add_stock.cancel_edit'.tr
                          : item.isSuccessfullyAdded
                              ? 'add_stock.delete_stock_item'.tr
                              : 'add_stock.clear_product_selection'.tr,
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                          boxShadow: const [
                            BoxShadow(
                              color: ColorManager.boxShadowColor,
                              blurRadius: 3,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            isEditingInputRow
                                ? Icons.close
                                : item.isSuccessfullyAdded
                                    ? Icons.delete
                                    : Icons.clear,
                            size: 18,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            if (item.isSuccessfullyAdded) {
                              _deleteStockItem(index);
                            } else {
                              _clearStockItem(index);
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (item.productData != null || item.isSuccessfullyAdded)
                    const SizedBox(width: 8),
                  if (!item.isSuccessfullyAdded) ...[
                    Tooltip(
                      message: _isLoading
                          ? (isEditingInputRow ? 'add_stock.saving'.tr : 'add_stock.adding'.tr)
                          : (isEditingInputRow
                              ? 'add_stock.save_changes'.tr
                              : 'add_stock.add_stock_item'.tr),
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: _isLoading
                              ? Colors.grey
                              : ColorManager.kPrimaryColor,
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: const [
                            BoxShadow(
                              color: ColorManager.boxShadowColor,
                              blurRadius: 3,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isLoading
                                ? Icons.hourglass_empty
                                : (isEditingInputRow
                                    ? Icons.save
                                    : Icons.add),
                            size: 18,
                            color: Colors.white,
                          ),
                          onPressed: _isLoading
                              ? null
                              : () => _addStockForSingleItem(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Tooltip(
                    message: item.isExpanded
                        ? 'add_stock.hide_details'.tr
                        : 'add_stock.show_details'.tr,
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: item.isExpanded
                                ? ColorManager.kPrimaryColor
                                : Colors.grey.withOpacity(0.3)),
                        boxShadow: const [
                          BoxShadow(
                            color: ColorManager.boxShadowColor,
                            blurRadius: 3,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          item.isExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 18,
                          color: item.isExpanded
                              ? ColorManager.kPrimaryColor
                              : Colors.grey.shade600,
                        ),
                        onPressed: () => _toggleExpanded(index),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _autoFillFromBarcode(int index, String barcode) {
    debugPrint('🔍 BARCODE AUTO-FILL TRIGGERED');
    debugPrint('   - Row index: $index');
    debugPrint('   - Barcode: $barcode');

    if (barcode.isEmpty) {
      debugPrint('❌ BARCODE IS EMPTY - SKIPPING AUTO-FILL');
      return;
    }

    // Directly perform auto-fill on submit
    _performBarcodeAutoFill(index, barcode);
  }

  Future<void> _performBarcodeAutoFill(int index, String barcode) async {
    // Check if index is valid
    if (index >= stockItems.length) {
      debugPrint('⚠️ Invalid index for barcode auto-fill: $index');
      return;
    }

    // Get the LocalProductProvider
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    debugPrint('🔍 SEARCHING LOCAL PRODUCT DATABASE...');

    // Find product by barcode
    List<GetProduct> products =
        localProductProvider.filterProductByBarcode(barCode: barcode);
    debugPrint('📊 SEARCH RESULTS: ${products.length} products found');

    if (products.isNotEmpty) {
      GetProduct localProduct = products.first;
      final matchedVariant = _variantForBarcode(localProduct, barcode);
      debugPrint(
          '✅ PRODUCT FOUND: ${localProduct.productName} (ID: ${localProduct.productId})');

      setState(() {
        debugPrint('🔄 AUTO-FILLING FIELDS...');
        // Auto-fill basic fields
        stockItems[index].productData =
            localProduct; // Now safe to set directly
        stockItems[index].productVariantId = matchedVariant?.id;
        stockItems[index].variantName =
            matchedVariant == null ? null : _variantLabel(matchedVariant);
        stockItems[index].barcode =
            matchedVariant?.barcode ?? localProduct.barcode ?? '';
        stockItems[index].product = localProduct.productName ?? '';
        // Update barcode controller to reflect the change
        _getBarcodeController(index).text = stockItems[index].barcode;
        debugPrint('   - Product: ${localProduct.productName}');
        debugPrint('   - Barcode: ${localProduct.barcode}');

        // Auto-fill category - find the category from CategoryProvider
        if (localProduct.category != null) {
          debugPrint(
              '🔍 SEARCHING FOR CATEGORY: ${localProduct.category!.name}');
          final categoryProvider =
              Provider.of<CategoryProvider>(context, listen: false);
          List<Category>? categoryList = categoryProvider.searchCategory;
          if (categoryList == null || categoryList.isEmpty) {
            categoryList = categoryProvider.purchasableCategories;
          }
          if (categoryList != null && categoryList.isNotEmpty) {
            // Debug print all loaded categories for visibility
            debugPrint(
                '📚 Loaded categories for matching (${categoryList.length}):');
            for (final cat in categoryList) {
              debugPrint(
                  '   - ID: ${cat.categoryId}, Name: ${cat.categoryName}, Slug: ${cat.categorySlug}');
            }

            Category? matchingCategory;
            // 1) Try match by product.categoryId first
            if (localProduct.categoryId != null) {
              try {
                matchingCategory = categoryList
                    .firstWhere((c) => c.categoryId == localProduct.categoryId);
              } catch (_) {}
            }
            // 2) Try by slug
            if (matchingCategory == null &&
                localProduct.category?.slug != null) {
              try {
                matchingCategory = categoryList.firstWhere((c) =>
                    (c.categorySlug ?? '') ==
                    (localProduct.category!.slug ?? ''));
              } catch (_) {}
            }
            // 3) Try by name (case-insensitive)
            if (matchingCategory == null &&
                localProduct.category?.name != null) {
              final target =
                  (localProduct.category!.name ?? '').trim().toLowerCase();
              try {
                matchingCategory = categoryList.firstWhere((c) =>
                    (c.categoryName ?? '').trim().toLowerCase() == target);
              } catch (_) {}
            }
            // 4) Fallback to first non-ALL
            if (matchingCategory == null) {
              try {
                matchingCategory = categoryList.firstWhere(
                    (c) => (c.categoryName ?? '').toUpperCase() != 'ALL');
              } catch (_) {
                matchingCategory = categoryList.first;
              }
            }

            final mc = matchingCategory ?? categoryList.first;
            stockItems[index].categoryData = mc;
            stockItems[index].category = mc.categoryName ?? '';
            if (localProduct.categoryId != null &&
                mc.categoryId != localProduct.categoryId) {
              debugPrint(
                  '⚠️ Category mismatch: product.categoryId=${localProduct.categoryId} but matched categoryId=${mc.categoryId}. This may filter out the product from dropdown.');
            }
            debugPrint(
                '   - Category selected: ${mc.categoryName} (ID: ${mc.categoryId}, slug: ${mc.categorySlug})');
          } else {
            debugPrint('⚠️ No categories available to match.');
          }
        }

// Auto-fill expanded fields
        stockItems[index].salePrice =
            matchedVariant?.price?.toString() ??
                localProduct.price?.price?.toString() ??
                '0';
        stockItems[index].mrp = matchedVariant?.mrp?.toString() ??
            localProduct.mrp?.toString() ??
            localProduct.price?.price?.toString() ??
            '0';
        _applyBaseUnitFromProduct(index, localProduct);
        _configurePurchaseUnitForProductSelection(
          index,
          localProduct,
          scannedBarcode: barcode,
        );
        debugPrint('   - Sale Price: ${stockItems[index].salePrice}');
        debugPrint('   - MRP: ${stockItems[index].mrp}');
        debugPrint('   - Unit: ${stockItems[index].unit}');

        // Update controllers with new values
        _getRetailPriceController(index).text = stockItems[index].salePrice;
        _getMrpController(index).text = stockItems[index].mrp;

        // Auto-fill purchase rate: use only product-level purchasePrice; do not fall back to stock entries
        final String? computedPurchasePrice =
            matchedVariant?.purchasePrice?.toString() ??
                localProduct.purchasePrice;
        if (computedPurchasePrice != null &&
            computedPurchasePrice.toString().isNotEmpty) {
          stockItems[index].purchaseRate = computedPurchasePrice.toString();
          debugPrint(
              '   - Purchase Rate (from product): ${stockItems[index].purchaseRate}');
        } else {
          debugPrint(
              '   - Purchase Rate: not available on product, leaving empty');
        }

        // Do not set wholesale price by default; only set if you have a meaningful value in your model
        // Currently no explicit wholesale field in GetProduct; leave as-is to avoid defaults
        if (stockItems[index].wholesale.isNotEmpty) {
          debugPrint(
              '   - Wholesale Price (pre-existing): ${stockItems[index].wholesale}');
        } else {
          debugPrint('   - Wholesale Price: not available, leaving empty');
        }

        // Do not set minimum units for wholesale by default; leave as-is
        if (stockItems[index].batchNumber.isNotEmpty) {
          debugPrint(
              '   - Batch Number (pre-existing): ${stockItems[index].batchNumber}');
        } else {
          debugPrint('   - Batch Number: not available, leaving empty');
        }

        // Update controllers with new values only when non-empty
        if (stockItems[index].purchaseRate.isNotEmpty) {
          _getPurchaseRateController(index).text =
              stockItems[index].purchaseRate;
        }
        if (stockItems[index].wholesale.isNotEmpty) {
          _getWholesaleController(index).text = stockItems[index].wholesale;
        }
        if (stockItems[index].batchNumber.isNotEmpty) {
          _getBatchNumberController(index).text = stockItems[index].batchNumber;
        }

        _markForRecalculation(); // Trigger recalculation
      });

      // Trigger tax calculation for both retail and wholesale prices after auto-fill
      // Add small delay to ensure UI updates smoothly
      Future.delayed(const Duration(milliseconds: 100), () {
        _calculateTaxForStockItem(index, isRetail: true);
        _calculateTaxForStockItem(index, isRetail: false);
        _calculateTaxForStockItem(index, isPurchase: true);
      });

      // Auto-focus on quantity field with text selection after auto-fill
      Future.delayed(const Duration(milliseconds: 200), () {
        final quantityFocusNode = _getQuantityFocusNode(index);
        final quantityController = _getQuantityController(index);

        // Update controller text to match current quantity
        quantityController.text = stockItems[index].quantity;

        // Request focus and select all text
        quantityFocusNode.requestFocus();
        quantityController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: quantityController.text.length,
        );

        debugPrint('✅ AUTO-FOCUSED ON QUANTITY FIELD WITH TEXT SELECTION');
      });

      debugPrint('✅ AUTO-FILL COMPLETED SUCCESSFULLY');
    } else {
      debugPrint('❌ NO PRODUCT FOUND FOR BARCODE: $barcode');
      // Show the AddProductWithBarcodeModal if no product is found
      final created = await showDialog(
        context: context,
        builder: (context) => AddProductWithBarcodeModal(barcode: barcode),
      );

      // If user created a product, attempt to autofill again using the returned product data
      if (created != null) {
        try {
          GetProduct createdProduct;
          String? initialQuantityStr;

          if (created is GetProduct) {
            createdProduct = created;
          } else if (created is Map<String, dynamic>) {
            // New return shape from modal: { 'product': GetProduct|Map, 'initialQuantity': String }
            if (created.containsKey('product')) {
              final dynamic productPayload = created['product'];
              initialQuantityStr = created['initialQuantity']?.toString();
              if (productPayload is GetProduct) {
                createdProduct = productPayload;
              } else if (productPayload is Map<String, dynamic>) {
                createdProduct = GetProduct.fromJson(productPayload);
              } else {
                createdProduct = GetProduct();
              }
            } else {
              // Backward compatibility: modal may have returned raw JSON product
              createdProduct = GetProduct.fromJson(created);
            }
          } else {
            // Unknown type; fallback to re-running with the same barcode
            createdProduct = GetProduct();
          }

          // If quantity was provided by the modal, set it before re-running autofill
          if (initialQuantityStr != null && initialQuantityStr.isNotEmpty) {
            setState(() {
              stockItems[index].quantity = initialQuantityStr!;
            });
            // Update controller immediately so post-autofill focus selects the correct text
            _getQuantityController(index).text = initialQuantityStr;
          }

          final String newBarcode = createdProduct.barcode ?? barcode;
          debugPrint(
              '🔄 PRODUCT CREATED FROM MODAL. RETRYING AUTO-FILL WITH BARCODE: $newBarcode');
          // Re-run the autofill with the new/confirmed barcode
          await _performBarcodeAutoFill(index, newBarcode);
        } catch (e) {
          debugPrint(
              '⚠️ Could not parse returned product. Retrying with original barcode. Error: $e');
          await _performBarcodeAutoFill(index, barcode);
        }
      }
    }
  }

  Widget _buildExpandedSection(int index) {
    final item = stockItems[index];
    final bool isMobile = stockIsPhone(context);

    if (isMobile) {
      return Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1 - Category, Unit
            Row(
              children: [
                Expanded(
                  child: _buildExpandedCategoryDropdown(index),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildExpandedUnitDropdown(index),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2 - Purchase Rate, Retail Price
            Row(
              children: [
                Expanded(
                  child: _buildExpandedTextField(
                    'add_stock.purchase_rate'.tr,
                    item.purchaseRate,
                    (value) {
                      setState(() {
                        stockItems[index].purchaseRate = value;
                        _markForRecalculation(); // Trigger recalculation
                        _calculateTaxForStockItem(index, isPurchase: true);
                      });
                      _updatePendingStockItem(index);
                    },
                    isRequired: true,
                    keyboardType: TextInputType.number,
                    controller: _getPurchaseRateController(index),
                    inputFontSize: FontSize.s13,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildExpandedTextField(
                    'add_stock.retail_price'.tr,
                    item.salePrice,
                    (value) {
                      setState(() {
                        stockItems[index].salePrice = value;
                        // Recalculate tax when retail price changes
                        _calculateTaxForStockItem(index, isRetail: true);
                      });
                      _updatePendingStockItem(index);
                    },
                    isRequired: true,
                    keyboardType: TextInputType.number,
                    controller: _getRetailPriceController(index),
                    inputFontSize: FontSize.s13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 3 - MRP
            Row(
              children: [
                Expanded(
                  child: _buildExpandedTextField(
                    'add_stock.mrp'.tr,
                    item.mrp,
                    (value) {
                      setState(() {
                        stockItems[index].mrp = value;
                      });
                      _updatePendingStockItem(index);
                    },
                    keyboardType: TextInputType.number,
                    controller: _getMrpController(index),
                    inputFontSize: FontSize.s13,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
            const SizedBox(height: 10),

            if (_hasPurchaseUnits(item)) ...[
              // Row 4 - Purchase Unit, Purchase Qty
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildExpandedPurchaseUnitDropdown(index),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildExpandedPurchaseQtyField(index),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 5 - Conversion Rate, Base Qty
              Row(
                children: [
                  Expanded(
                    child: _buildReadOnlyInfoField(
                      'add_stock.conversion_rate'.tr,
                      item.purchaseConversionRate?.isNotEmpty == true
                          ? item.purchaseConversionRate!
                          : '-',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildReadOnlyInfoField(
                      'add_stock.base_quantity'.tr,
                      item.quantity.isNotEmpty ? item.quantity : '-',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // Row 6 - Expiry Date, Wholesale Price
            Row(
              children: [
                Expanded(
                  child: _buildExpandedDatePicker(
                    'add_stock.expiry_date'.tr,
                    item.expDate,
                    (date) {
                      setState(() => stockItems[index].expDate = date);
                      _updatePendingStockItem(index);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildExpandedTextField(
                    'add_stock.wholesale_price'.tr,
                    item.wholesale,
                    (value) {
                      setState(() {
                        stockItems[index].wholesale = value;
                        // Recalculate tax when wholesale price changes
                        _calculateTaxForStockItem(index, isRetail: false);
                      });
                      _updatePendingStockItem(index);
                    },
                    keyboardType: TextInputType.number,
                    controller: _getWholesaleController(index),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 7 - Minimum Units, Rack
            Row(
              children: [
                Expanded(
                  child: _buildExpandedTextField(
                    'add_stock.minimum_units_wholesale'.tr,
                    item.batchNumber, // Reusing batchNumber field for minimum units
                    (value) {
                      setState(() => stockItems[index].batchNumber = value);
                      _updatePendingStockItem(index);
                    },
                    controller: _getBatchNumberController(index),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildExpandedRackDropdown(index),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tax Details Section
            _buildTaxDetailsSection(index),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First row - Category, Unit, Purchase Rate, Retail Price, MRP
          Row(
            children: [
              Expanded(
                child: _buildExpandedCategoryDropdown(index),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildExpandedUnitDropdown(index),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildExpandedTextField(
                  'add_stock.purchase_rate'.tr,
                  item.purchaseRate,
                  (value) {
                    setState(() {
                      stockItems[index].purchaseRate = value;
                      _markForRecalculation(); // Trigger recalculation
                      _calculateTaxForStockItem(index, isPurchase: true);
                    });
                    _updatePendingStockItem(index);
                  },
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  controller: _getPurchaseRateController(index),
                  inputFontSize: FontSize.s13,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildExpandedTextField(
                  'add_stock.retail_price'.tr,
                  item.salePrice,
                  (value) {
                    setState(() {
                      stockItems[index].salePrice = value;
                      // Recalculate tax when retail price changes
                      _calculateTaxForStockItem(index, isRetail: true);
                    });
                    _updatePendingStockItem(index);
                  },
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  controller: _getRetailPriceController(index),
                  inputFontSize: FontSize.s13,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildExpandedTextField(
                  'add_stock.mrp'.tr,
                  item.mrp,
                  (value) {
                    setState(() {
                      stockItems[index].mrp = value;
                    });
                    _updatePendingStockItem(index);
                  },
                  keyboardType: TextInputType.number,
                  controller: _getMrpController(index),
                  inputFontSize: FontSize.s13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_hasPurchaseUnits(item)) ...[
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildExpandedPurchaseUnitDropdown(index),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildExpandedPurchaseQtyField(index),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildReadOnlyInfoField(
                    'add_stock.conversion_rate'.tr,
                    item.purchaseConversionRate?.isNotEmpty == true
                        ? item.purchaseConversionRate!
                        : '-',
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildReadOnlyInfoField(
                    'add_stock.base_quantity'.tr,
                    item.quantity.isNotEmpty ? item.quantity : '-',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          // Second row - Expiry Date, Wholesale Price, Minimum Units for Wholesale, Rack
          Row(
            children: [
              Expanded(
                child: _buildExpandedDatePicker(
                  'add_stock.expiry_date'.tr,
                  item.expDate,
                  (date) {
                    setState(() => stockItems[index].expDate = date);
                    _updatePendingStockItem(index);
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildExpandedTextField(
                  'add_stock.wholesale_price'.tr,
                  item.wholesale,
                  (value) {
                    setState(() {
                      stockItems[index].wholesale = value;
                      // Recalculate tax when wholesale price changes
                      _calculateTaxForStockItem(index, isRetail: false);
                    });
                    _updatePendingStockItem(index);
                  },
                  keyboardType: TextInputType.number,
                  controller: _getWholesaleController(index),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildExpandedTextField(
                  'add_stock.minimum_units_wholesale'.tr,
                  item.batchNumber, // Reusing batchNumber field for minimum units
                  (value) {
                    setState(() => stockItems[index].batchNumber = value);
                    _updatePendingStockItem(index);
                  },
                  controller: _getBatchNumberController(index),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildExpandedRackDropdown(index),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Tax Details Section
          _buildTaxDetailsSection(index),
        ],
      ),
    );
  }

  Widget _buildExpandedTextField(
    String label,
    String value,
    Function(String) onChanged, {
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    TextEditingController? controller,
    double inputFontSize = FontSize.s11,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s11,
                0.27,
                Colors.black.withOpacity(0.6),
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s11,
                  0.27,
                  Colors.red,
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        BuildBoxShadowContainer(
          circleRadius: 5,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextFormField(
            controller: controller ?? TextEditingController(text: value),
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: buildCustomStyle(
              FontWeightManager.regular,
              inputFontSize,
              0.27,
              ColorManager.textColor,
            ),
            decoration: InputDecoration(
              hintText: 'add_stock.enter_field'.tr.replaceAll('@field', label),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onTap: () {
              // Select all text when field is tapped
              if (controller != null) {
                controller.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: controller.text.length,
                );
              }
            },
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedDatePicker(
    String label,
    DateTime selectedDate,
    Function(DateTime) onDateSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s11,
                0.27,
                Colors.black.withOpacity(0.6),
              ),
            ),
            Text(
              ' *',
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s11,
                0.27,
                Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        BuildBoxShadowContainer(
          circleRadius: 5,
          height: 40,
          child: CalendarPickerTableCell(
            initialDate: selectedDate,
            onDateSelected: onDateSelected,
            hintText: 'add_stock.select_field'.tr.replaceAll('@field', label),
            isRequired: true,
            firstDate: DateTime.now(), // Expiry dates should be in the future
            lastDate: DateTime.now()
                .add(const Duration(days: 3650)), // 10 years from now
            showQuickActions:
                true, // Enable quick date selection for expiry dates
            isForExpiry: true, // Show quick actions only for expiry dates
            isAllowEdit: true, // Allow text editing for expiry dates
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedCategoryDropdown(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'add_stock.category'.tr,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s11,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 40,
          child: Selector<CategoryProvider, List<Category>?>(
            selector: (context, provider) => provider.category,
            shouldRebuild: (previous, current) =>
                previous?.length != current?.length,
            builder: (context, categoryList, child) {
              final filteredCategories = categoryList
                      ?.where((category) => category.categoryName != "ALL")
                      .toList() ??
                  [];

              return BuildDropDownWithSearch<Category>(
                title: null,
                hintText: 'add_stock.select_category'.tr,
                value: stockItems[index].categoryData,
                items: filteredCategories,
                onChanged: (category) {
                  setState(() {
                    stockItems[index].categoryData = category;
                    stockItems[index].category = category?.categoryName ?? '';
                    // Clear product when category changes
                    stockItems[index].productData = null;
                    stockItems[index].productVariantId = null;
                    stockItems[index].variantName = null;
                    stockItems[index].product = '';
                    // Clear product cache to force refresh
                    _clearProductCache();
                  });
                  if (category != null) {
                    Provider.of<GridSelectionProvider>(context, listen: false)
                        .listAllProducts(
                            filterCategory: category.categoryId.toString());
                  }
                  // Update pending item if already added
                  _updatePendingStockItem(index);
                },
                displayText: (category) => category.categoryName ?? '',
                searchController: _getCategorySearchController(index),
                isRequired: false,
                height: 40,
                searchHintText: 'add_stock.search_category'.tr,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVariantSelector(int index) {
    return Consumer<AppSettingsProvider>(
      builder: (context, settingsProvider, child) {
        final item = stockItems[index];
        final enabled =
            settingsProvider.appSettings?.productVariantEnabled ?? false;
        final product = item.productData;
        if (!enabled || product == null || !product.hasVariants) {
          return const SizedBox.shrink();
        }

        final variants = product.activeVariants;
        final selected = _selectedVariant(item);

        return Padding(
          padding: EdgeInsets.only(
            left: stockIsPhone(context) ? 8 : 48,
            right: 8,
            bottom: 10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'add_stock.product_variant_required'.tr,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s11,
                  0.27,
                  Colors.black.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 40,
                child: BuildDropDownWithSearch<ProductVariant>(
                  title: null,
                  hintText: variants.isEmpty
                      ? 'add_stock.no_active_variants'.tr
                      : 'add_stock.select_product_variant'.tr,
                  value: selected,
                  items: variants,
                  onChanged: (variant) {
                    setState(() {
                      _applyVariantToItem(
                        index,
                        variant,
                        updatePending: false,
                      );
                    });
                    _updatePendingStockItem(index);
                    _calculateTaxForStockItem(index, isRetail: true);
                    _calculateTaxForStockItem(index, isPurchase: true);
                  },
                  displayText: _variantLabel,
                  isRequired: true,
                  height: 40,
                  searchHintText: 'add_stock.search_variant'.tr,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductDropdown(int index) {
    return Selector<LocalProductProvider, List<GetProduct>>(
      selector: (context, provider) => provider.products,
      shouldRebuild: (previous, current) {
        // Rebuild if length changes
        if (previous.length != current.length) return true;
        // Also rebuild if any product name changed (for edit updates)
        for (int i = 0; i < previous.length; i++) {
          if (previous[i].productName != current[i].productName ||
              previous[i].barcode != current[i].barcode) {
            return true;
          }
        }
        return false;
      },
      builder: (context, allProducts, child) {
        // Use cached filtered products to avoid repeated filtering
        final selectedCategoryId = stockItems[index].categoryData?.categoryId;
        final cacheKey = selectedCategoryId;

        List<GetProduct> filteredProducts;
        if (_filteredProductsCache.containsKey(cacheKey)) {
          filteredProducts = _filteredProductsCache[cacheKey]!;
        } else {
          // Filter and cache the results
          if (selectedCategoryId != null) {
            filteredProducts = allProducts
                .where((p) => p.categoryId == selectedCategoryId)
                .toList();
          } else {
            filteredProducts = allProducts;
          }

          // De-duplicate by productId
          final Map<int, GetProduct> productMap = {};
          for (var product in filteredProducts) {
            if (product.productId != null) {
              productMap[product.productId!] = product;
            }
          }
          filteredProducts = productMap.values.toList();

          // Cache the result
          _filteredProductsCache[cacheKey] = filteredProducts;
        }

        List<GetProduct> uniqueProducts = filteredProducts;

        // Ensure the selected value exists in the items list
        GetProduct? selectedProduct = stockItems[index].productData;
        if (selectedProduct != null && selectedProduct.productId != null) {
          // Find the actual product instance from the unique list
          try {
            final matched = uniqueProducts.firstWhere(
              (product) => product.productId == selectedProduct!.productId,
            );
            selectedProduct = matched;
          } catch (e) {
            // If missing due to category mismatch, keep null to avoid dropdown error
            selectedProduct = null;
          }
        }

        return BuildDropDownWithSearch<GetProduct>(
          title: null,
          hintText: 'add_stock.select_product'.tr,
          value: selectedProduct,
          items: uniqueProducts,
          onChanged: (product) {
            if (product != null) {
              debugPrint('🔄 PRODUCT DROPDOWN AUTO-FILL TRIGGERED');
              debugPrint('   - Row index: $index');
              debugPrint(
                  '   - Product: ${product.productName} (ID: ${product.productId})');
              // Print all available product details as pretty JSON for debugging
              try {
                const encoder = JsonEncoder.withIndent('  ');
                final productJson = product.toJson();
                final pretty = encoder.convert(productJson);
                debugPrint('📦 Selected product full details (pretty JSON):');
                debugPrint(pretty);
              } catch (e) {
                debugPrint('⚠️ Failed to serialize product to JSON: $e');
              }

              setState(() {
                debugPrint(
                    '🔄 AUTO-FILLING ALL FIELDS FROM PRODUCT SELECTION...');
                // Auto-fill basic fields
                stockItems[index].productData = product;
                stockItems[index].productVariantId = null;
                stockItems[index].variantName = null;
                stockItems[index].product = product.productName ?? '';
                stockItems[index].barcode = product.barcode ?? '';
                // Update barcode controller to reflect the change
                _getBarcodeController(index).text = product.barcode ?? '';
                debugPrint('   - Product: ${product.productName}');
                debugPrint('   - Barcode: ${product.barcode}');

                // Auto-fill category - find the category from CategoryProvider
                if (product.category != null) {
                  debugPrint(
                      '🔍 SEARCHING FOR CATEGORY: ${product.category!.name}');
                  final categoryProvider =
                      Provider.of<CategoryProvider>(context, listen: false);
                  // Prefer searchCategory (same source as Add Category screen), fallback to category
                  List<Category>? categoryList =
                      categoryProvider.searchCategory;
                  if (categoryList == null || categoryList.isEmpty) {
                    categoryList = categoryProvider.purchasableCategories;
                  }
                  if (categoryList != null && categoryList.isNotEmpty) {
                    // Debug print all loaded categories for visibility
                    debugPrint(
                        '📚 Loaded categories (${categoryList.length}):');
                    for (final cat in categoryList) {
                      debugPrint(
                          '   - ID: ${cat.categoryId}, Name: ${cat.categoryName}, Slug: ${cat.categorySlug}');
                    }
                    Category? matchingCategory;
                    // 1) Match by categoryId
                    if (product.categoryId != null) {
                      try {
                        matchingCategory = categoryList.firstWhere(
                            (cat) => cat.categoryId == product.categoryId);
                      } catch (_) {}
                    }
                    // 2) Match by slug
                    if (matchingCategory == null &&
                        product.category?.slug != null) {
                      try {
                        matchingCategory = categoryList.firstWhere((cat) =>
                            (cat.categorySlug ?? '') ==
                            (product.category!.slug ?? ''));
                      } catch (_) {}
                    }
                    // 3) Match by name (case-insensitive, trimmed)
                    if (matchingCategory == null &&
                        product.category?.name != null) {
                      final targetName =
                          (product.category!.name ?? '').trim().toLowerCase();
                      try {
                        matchingCategory = categoryList.firstWhere((cat) =>
                            (cat.categoryName ?? '').trim().toLowerCase() ==
                            targetName);
                      } catch (_) {}
                    }
                    // 4) Fallback to first non-ALL
                    if (matchingCategory == null) {
                      try {
                        matchingCategory = categoryList.firstWhere((cat) =>
                            (cat.categoryName ?? '').toUpperCase() != 'ALL');
                      } catch (_) {
                        matchingCategory = categoryList.first;
                      }
                    }
                    // Ensure non-null assignment and remove lint warnings
                    final mc = matchingCategory ?? categoryList.first;
                    stockItems[index].categoryData = mc;
                    stockItems[index].category = mc.categoryName ?? '';
                    debugPrint(
                        '   - Category: ${mc.categoryName} (ID: ${mc.categoryId}, slug: ${mc.categorySlug})');
                  }
                }

// Auto-fill expanded fields
                stockItems[index].salePrice =
                    product.price?.price?.toString() ?? '0';
                stockItems[index].mrp = product.mrp?.toString() ??
                    product.price?.price?.toString() ??
                    '0';
                _applyBaseUnitFromProduct(index, product);
                _configurePurchaseUnitForProductSelection(index, product);
                debugPrint('   - Sale Price: ${stockItems[index].salePrice}');
                debugPrint('   - MRP: ${stockItems[index].mrp}');
                debugPrint('   - Unit: ${stockItems[index].unit}');

                // Update controllers with new values
                _getRetailPriceController(index).text =
                    stockItems[index].salePrice;
                _getMrpController(index).text = stockItems[index].mrp;

                // Auto-fill Prices (MRP and Sale Price)
                stockItems[index].salePrice =
                    product.price?.price?.toString() ?? '0';
                stockItems[index].mrp = product.mrp?.toString() ??
                    product.price?.price?.toString() ??
                    '0';

                // Purchase Rate Fallback: Try product.purchasePrice, then fallback to latest stock purchase_price
                String? purchaseRate = (product.purchasePrice != null &&
                        product.purchasePrice.toString().isNotEmpty &&
                        product.purchasePrice != "0")
                    ? product.purchasePrice.toString()
                    : null;

                if (purchaseRate == null &&
                    product.stock != null &&
                    product.stock!.isNotEmpty) {
                  final latestStock = product.stock!.first;
                  if (latestStock.purchasePrice != null &&
                      latestStock.purchasePrice!.isNotEmpty) {
                    purchaseRate = latestStock.purchasePrice;
                  }
                }
                stockItems[index].purchaseRate = purchaseRate ?? '';

                // Update ALL controllers to reflect auto-filled values
                _getRetailPriceController(index).text =
                    stockItems[index].salePrice;
                _getMrpController(index).text = stockItems[index].mrp;
                _getPurchaseRateController(index).text =
                    stockItems[index].purchaseRate;
                _getWholesaleController(index).text = '';
                _getBatchNumberController(index).text = '';

                debugPrint(
                    '   - ✅ PRICE AUTO-FILL: Sale: ${stockItems[index].salePrice}, MRP: ${stockItems[index].mrp}, Purchase: ${stockItems[index].purchaseRate}');

                _markForRecalculation();
              });

              // Trigger tax calculation for both retail and wholesale prices after product selection
              // Add small delay to ensure UI updates smoothly
              Future.delayed(const Duration(milliseconds: 100), () {
                _calculateTaxForStockItem(index, isRetail: true);
                _calculateTaxForStockItem(index, isRetail: false);
                _calculateTaxForStockItem(index, isPurchase: true);
              });

              // Auto-focus on quantity field with text selection after product selection
              Future.delayed(const Duration(milliseconds: 200), () {
                final quantityFocusNode = _getQuantityFocusNode(index);
                final quantityController = _getQuantityController(index);
                _calculateTaxForStockItem(index, isPurchase: true);

                // Update controller text to match current quantity
                quantityController.text = stockItems[index].quantity;

                // Request focus and select all text
                quantityFocusNode.requestFocus();
                quantityController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: quantityController.text.length,
                );

                debugPrint(
                    '✅ AUTO-FOCUSED ON QUANTITY FIELD WITH TEXT SELECTION FROM PRODUCT DROPDOWN');
              });

              debugPrint('✅ PRODUCT DROPDOWN AUTO-FILL COMPLETED SUCCESSFULLY');

              // Note: Draft saving disabled - only successfully added items are persisted via StockProvider
            }
          },
          displayText: (product) => product.productName ?? '',
          searchController: _getProductSearchController(index),
          isRequired: false,
          height: 40,
          searchHintText: 'add_stock.search_product'.tr,
        );
      },
    );
  }

  Widget _buildExpandedUnitDropdown(int index) {
    return Selector<PurchaseProvider, Map<String, String>?>(
      selector: (context, provider) => provider.getUnitList,
      shouldRebuild: (previous, current) => previous?.length != current?.length,
      builder: (context, unitList, child) {
        List<String> unitKeys = unitList?.keys.toList() ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'add_stock.unit'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s11,
                    0.27,
                    Colors.black.withOpacity(0.6),
                  ),
                ),
                Text(
                  ' *',
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s11,
                    0.27,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            BuildDropDownWithSearch<String>(
              title: null,
              hintText: 'add_stock.select_unit'.tr,
              value: stockItems[index].selectedUnit,
              items: unitKeys,
              onChanged: (String? newValue) {
                setState(() {
                  stockItems[index].selectedUnit = newValue; // Store unit ID
                  stockItems[index].unit =
                      unitList?[newValue] ?? ''; // Store unit name for display
                });
                _updatePendingStockItem(index);
              },
              displayText: (unitKey) => unitList?[unitKey] ?? unitKey,
              searchController:
                  TextEditingController(), // Consider reusing controllers
              isRequired: false,
              height: 40,
              searchHintText: 'add_stock.search_unit'.tr,
            ),
          ],
        );
      },
    );
  }

  Widget _buildExpandedPurchaseUnitDropdown(int index) {
    final item = stockItems[index];
    final purchaseUnits = _getAvailablePurchaseUnits(item);
    final selectedSaleUnit = _getSelectedPurchaseSaleUnit(item);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'add_stock.purchase_unit'.tr,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s11,
                0.27,
                Colors.black.withOpacity(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        BuildDropDownWithSearch<SaleUnit>(
          title: null,
          hintText: 'add_stock.select_purchase_unit'.tr,
          value: selectedSaleUnit,
          items: purchaseUnits,
          onChanged: (SaleUnit? newValue) {
            setState(() {
              _selectPurchaseUnit(index, newValue);
              _markForRecalculation();
            });
            _updatePendingStockItem(index);
          },
          displayText: (saleUnit) {
            final unitName = saleUnit.unitName?.trim();
            final conversionRate = saleUnit.conversionRate?.trim();
            if (unitName == null || unitName.isEmpty) {
              return 'add_stock.unknown_unit'.tr;
            }
            if (conversionRate == null || conversionRate.isEmpty) {
              return unitName;
            }
            return '$unitName (${conversionRate}x)';
          },
          searchController: _getPurchaseUnitSearchController(index),
          isRequired: false,
          height: 40,
          searchHintText: 'add_stock.search_purchase_unit'.tr,
        ),
      ],
    );
  }

  Widget _buildExpandedPurchaseQtyField(int index) {
    final item = stockItems[index];
    return _buildExpandedTextField(
      'add_stock.purchase_qty'.tr,
      item.purchaseQty,
      (value) {
        setState(() {
          stockItems[index].purchaseQty = value;
          _syncStockQuantityFromPurchaseQty(index);
          _markForRecalculation();
        });
        _updatePendingStockItem(index);
      },
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters:
          quantityInputFormattersForUnit(item.purchaseUnitName ?? item.unit),
      controller: _getPurchaseQtyController(index),
    );
  }

  Widget _buildReadOnlyInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s11,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 2),
        BuildBoxShadowContainer(
          circleRadius: 5,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s12,
                0.27,
                ColorManager.textColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedRackDropdown(int index) {
    return Selector<PurchaseProvider, Map<String, String>?>(
      selector: (context, provider) => provider.getMasterDataValues,
      shouldRebuild: (previous, current) => previous?.length != current?.length,
      builder: (context, rackList, child) {
        List<String> rackKeys = rackList?.keys.toList() ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'add_stock.rack'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s11,
                    0.27,
                    Colors.black.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            BuildDropDownWithSearch<String>(
              title: null,
              hintText: 'add_stock.select_rack'.tr,
              value: stockItems[index].selectedRack,
              items: rackKeys,
              onChanged: (String? newValue) {
                setState(() {
                  stockItems[index].selectedRack = newValue;
                  stockItems[index].rack = newValue ?? '';
                });
                _updatePendingStockItem(index);
              },
              displayText: (rackKey) => rackList?[rackKey] ?? rackKey,
              searchController:
                  TextEditingController(), // Consider reusing controllers
              isRequired: false,
              height: 40,
              searchHintText: 'add_stock.search_rack'.tr,
            ),
          ],
        );
      },
    );
  }

  Widget _buildTaxDetailsSection(int index) {
    final item = stockItems[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tax calculation cards with tax settings on the left
        Row(
          children: [
            // Tax Settings on the left
            Expanded(
              flex: 1,
              child: Container(
                height: 80,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'add_stock.including_tax'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s11,
                          0.27,
                          Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: item.taxInclude,
                        onChanged: (bool value) {
                          setState(() {
                            item.taxInclude = value;
                            debugPrint(
                                '🧮 [StockTax] Tax include toggled for item $index -> $value');
                            _calculateTaxForStockItem(index, isRetail: true);
                            _calculateTaxForStockItem(index, isRetail: false);
                            _calculateTaxForStockItem(index, isPurchase: true);
                          });
                          _updatePendingStockItem(index);
                        },
                        activeThumbColor: ColorManager.kPrimaryColor,
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: Colors.grey.shade300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildTaxCard(
                'add_stock.retail_price'.tr,
                "1",
                item.taxInclude
                    ? '${(item.calculatedTaxData?['price_including_tax_retail'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"}'
                    : '${(item.calculatedTaxData?['price_excluding_tax_retail'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"} + ${(item.calculatedTaxData?['retailTaxAmount'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"}',
                'add_stock.tax_percent'.tr.replaceAll('@rate', (item.calculatedTaxData?['tax_rate_retail'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"),
                Colors.blue,
                item.taxInclude,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildTaxCard(
                'add_stock.wholesale_price'.tr,
                "2",
                item.taxInclude
                    ? '${(item.calculatedTaxData?['price_including_tax_wholesale'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"}'
                    : '${(item.calculatedTaxData?['price_excluding_tax_wholesale'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"} + ${(item.calculatedTaxData?['wholesaleTaxAmount'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"}',
                'add_stock.tax_percent'.tr.replaceAll('@rate', (item.calculatedTaxData?['tax_rate_wholesale'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"),
                Colors.orange,
                item.taxInclude,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildTaxCard(
                'add_stock.purchase_rate'.tr,
                "3",
                item.taxInclude
                    ? '${(item.calculatedTaxData?['price_including_tax_purchase'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"}'
                    : '${(item.calculatedTaxData?['price_excluding_tax_purchase'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"} + ${(item.calculatedTaxData?['purchaseTaxAmount'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"}',
                'add_stock.tax_percent'.tr.replaceAll('@rate', (item.calculatedTaxData?['tax_rate_purchase'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"),
                Colors.green,
                item.taxInclude,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailChip(
      String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          "$label: $value",
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s10,
            0.27,
            Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildTaxCard(String title, String badgeText, String priceText,
      String taxText, Color color, bool isIncluding) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    badgeText,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s11,
                      0.27,
                      Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s12,
                    0.27,
                    color,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  priceText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s13,
                    0.27,
                    Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  taxText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s10,
                    0.27,
                    Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _calculateTaxForStockItem(int index,
      {bool isRetail = true, bool isPurchase = false}) async {
    // Check if index is valid
    if (index >= stockItems.length) {
      debugPrint('⚠️ Invalid index for tax calculation: $index');
      return;
    }

    final item = stockItems[index];
    final String calculationType =
        isPurchase ? 'Purchase' : (isRetail ? 'Retail' : 'Wholesale');

    debugPrint(
        '🧮 [StockTax] Starting tax calculation | item=$index | type=$calculationType');

    if (item.productData == null ||
        item.categoryData == null ||
        item.productData!.productId == null ||
        item.categoryData!.categoryId == null) {
      debugPrint(
          '⚠️ [StockTax] Cannot calculate tax: product/category missing | item=$index | type=$calculationType');

      // Only set state if we have valid calculated tax data structure
      if (mounted) {
        setState(() {
          item.calculatedTaxData ??= {};
          if (isPurchase) {
            item.calculatedTaxData!['purchaseTaxAmount'] = 0.0;
            item.calculatedTaxData!['tax_rate_purchase'] = 0.0;
            item.calculatedTaxData!['price_including_tax_purchase'] = 0.0;
            item.calculatedTaxData!['price_excluding_tax_purchase'] = 0.0;
          } else if (isRetail) {
            item.calculatedTaxData!['retailTaxAmount'] = 0.0;
            item.calculatedTaxData!['tax_rate_retail'] = 0.0;
            item.calculatedTaxData!['price_including_tax_retail'] = 0.0;
            item.calculatedTaxData!['price_excluding_tax_retail'] = 0.0;
          } else {
            item.calculatedTaxData!['wholesaleTaxAmount'] = 0.0;
            item.calculatedTaxData!['tax_rate_wholesale'] = 0.0;
            item.calculatedTaxData!['price_including_tax_wholesale'] = 0.0;
            item.calculatedTaxData!['price_excluding_tax_wholesale'] = 0.0;
          }
        });
      }
      return;
    }

    final double priceToCalculate = isPurchase
        ? (double.tryParse(item.purchaseRate) ?? 0.0)
        : (isRetail
            ? (double.tryParse(item.salePrice) ?? 0.0)
            : (double.tryParse(item.wholesale) ?? 0.0));

    debugPrint(
        '🧮 [StockTax] Payload | item=$index | type=$calculationType | productId=${item.productData!.productId} | categoryId=${item.categoryData!.categoryId} | price=$priceToCalculate | taxInclude=${item.taxInclude}');

    final String? accessToken =
        Provider.of<AuthModel>(context, listen: false).token;
    if (accessToken == null) {
      debugPrint(
          '❌ [StockTax] Cannot calculate tax: access token not found | item=$index | type=$calculationType');
      return;
    }

    try {
      final taxData = await Provider.of<StockProvider>(context, listen: false)
          .calculateTaxAPI(
        accessToken: accessToken,
        price: priceToCalculate,
        productId: item.productData!.productId!,
        categoryId: item.categoryData!.categoryId!,
        taxInclude: item.taxInclude,
      );

      if (taxData != null && mounted) {
        debugPrint(
            '✅ [StockTax] API success | item=$index | type=$calculationType | response=$taxData');
        setState(() {
          if (isPurchase) {
            item.calculatedTaxData = {
              ...?item.calculatedTaxData,
              'purchaseTaxAmount':
                  (taxData['tax_amount'] as num?)?.toDouble() ?? 0.0,
              'tax_rate_purchase':
                  (taxData['tax_rate'] as num?)?.toDouble() ?? 0.0,
              'price_including_tax_purchase':
                  (taxData['price_including_tax'] as num?)?.toDouble() ?? 0.0,
              'price_excluding_tax_purchase':
                  (taxData['price_excluding_tax'] as num?)?.toDouble() ?? 0.0,
            };
          } else if (isRetail) {
            item.calculatedTaxData = {
              ...?item.calculatedTaxData, // Preserve other data if any
              'retailTaxAmount':
                  (taxData['tax_amount'] as num?)?.toDouble() ?? 0.0,
              'tax_rate_retail':
                  (taxData['tax_rate'] as num?)?.toDouble() ?? 0.0,
              'price_including_tax_retail':
                  (taxData['price_including_tax'] as num?)?.toDouble() ??
                      0.0, // Store prices
              'price_excluding_tax_retail':
                  (taxData['price_excluding_tax'] as num?)?.toDouble() ?? 0.0,
            };
          } else {
            item.calculatedTaxData = {
              ...?item.calculatedTaxData, // Preserve other data if any
              'wholesaleTaxAmount':
                  (taxData['tax_amount'] as num?)?.toDouble() ?? 0.0,
              'tax_rate_wholesale':
                  (taxData['tax_rate'] as num?)?.toDouble() ?? 0.0,
              'price_including_tax_wholesale':
                  (taxData['price_including_tax'] as num?)?.toDouble() ?? 0.0,
              'price_excluding_tax_wholesale':
                  (taxData['price_excluding_tax'] as num?)?.toDouble() ?? 0.0,
            };
          }
        });
      } else {
        debugPrint(
            '❌ [StockTax] Tax API returned null | item=$index | type=$calculationType');
        if (mounted) {
          setState(() {
            if (isPurchase) {
              item.calculatedTaxData = {
                ...?item.calculatedTaxData,
                'purchaseTaxAmount': 0.0,
                'tax_rate_purchase': 0.0,
                'price_including_tax_purchase': 0.0,
                'price_excluding_tax_purchase': 0.0,
              };
            } else if (isRetail) {
              item.calculatedTaxData = {
                ...?item.calculatedTaxData, // Preserve other data if any
                'retailTaxAmount': 0.0,
                'tax_rate_retail': 0.0,
                'price_including_tax_retail': 0.0,
                'price_excluding_tax_retail': 0.0,
              };
            } else {
              item.calculatedTaxData = {
                ...?item.calculatedTaxData, // Preserve other data if any
                'wholesaleTaxAmount': 0.0,
                'tax_rate_wholesale': 0.0,
                'price_including_tax_wholesale': 0.0,
                'price_excluding_tax_wholesale': 0.0,
              };
            }
          });
        }
      }
    } catch (e) {
      debugPrint(
          '💥 [StockTax] Exception in tax calculation | item=$index | type=$calculationType | error=$e');
      if (mounted) {
        setState(() {
          if (isPurchase) {
            item.calculatedTaxData = {
              ...?item.calculatedTaxData,
              'purchaseTaxAmount': 0.0,
              'tax_rate_purchase': 0.0,
              'price_including_tax_purchase': 0.0,
              'price_excluding_tax_purchase': 0.0,
            };
          } else if (isRetail) {
            item.calculatedTaxData = {
              ...?item.calculatedTaxData, // Preserve other data if any
              'retailTaxAmount': 0.0,
              'tax_rate_retail': 0.0,
              'price_including_tax_retail': 0.0,
              'price_excluding_tax_retail': 0.0,
            };
          } else {
            item.calculatedTaxData = {
              ...?item.calculatedTaxData, // Preserve other data if any
              'wholesaleTaxAmount': 0.0,
              'tax_rate_wholesale': 0.0,
              'price_including_tax_wholesale': 0.0,
              'price_excluding_tax_wholesale': 0.0,
            };
          }
        });
      }
    }

    // Keep pending storage in sync after async tax updates, including inline edit flows.
    _syncPendingItemAfterTaxRecalculation(index, item);
  }

  Widget _buildActionButtons(Size size) {
    final bool isMobile = stockIsPhone(context);
    final double buttonWidth = isMobile ? 0 : size.width * 0.15;
    final double buttonFontSize = isMobile ? FontSize.s12 : FontSize.s14;

    Widget finishButton = Consumer<StockProvider>(
      builder: (context, stockProvider, child) {
        return CustomRoundButton(
          title: stockProvider.batchProcessingLoading
              ? 'add_stock.processing'.tr
              : 'add_stock.finish_button'.tr.replaceAll('@count', stockProvider.pendingStockItemsCount.toString()),
          isLoading: stockProvider.batchProcessingLoading,
          fct: stockProvider.batchProcessingLoading
              ? () {}
              : () async {
                  debugPrint('🏁 FINISH BUTTON CLICKED');

                  // Check if we have any pending stock items
                  if (stockProvider.pendingStockItemsCount == 0) {
                    debugPrint('❌ NO PENDING STOCK ITEMS FOUND');
                    showScaffoldError(
                        context: context,
                        message:
                            'add_stock.no_pending_items'.tr);
                    return;
                  }

                  // Validate payment data if payment methods are provided
                  Map<String, dynamic> apiPaymentData =
                      _convertPaymentDataToApiFormat(paymentData);
                  List<String>? paymentMethods =
                      apiPaymentData['payment_methods'];
                  List<Map<String, dynamic>>? paidMethods =
                      apiPaymentData['paid_methods'];

                  // Calculate total stock value for confirmation dialog
                  final int itemCount = stockProvider.pendingStockItemsCount;
                  final double additionalPurchaseTax =
                      _getAdditionalPurchaseTaxTotal();
                  // Match purchase summary: Total Due Amount = total purchase
                  // amount for this stock batch + additional excluded tax + current supplier balance.
                  final double supplierBalance = _getSupplierBalance();
                  final double totalDueAmount = totalStockValue +
                      additionalPurchaseTax +
                      supplierBalance;

                  // Check if payment data is provided
                  final bool hasPayment =
                      paymentMethods != null && paymentMethods.isNotEmpty;

                  // Optional validation: if payment data is provided, ensure it's complete
                  if (hasPayment) {
                    debugPrint('✅ PAYMENT DATA PROVIDED - VALIDATING...');
                    debugPrint('   - Payment Methods: $paymentMethods');
                    debugPrint('   - Paid Methods: $paidMethods');

                    if (paidMethods == null || paidMethods.isEmpty) {
                      debugPrint(
                          '❌ PAYMENT VALIDATION FAILED: Payment methods provided but no amounts specified');
                      showScaffoldError(
                          context: context,
                          message:
                              'add_stock.specify_payment_amounts'.tr);
                      return;
                    }

                    // Check if any payment amount is zero or negative
                    bool hasInvalidAmount = paidMethods.any((method) {
                      double amount =
                          (method['amount'] as num?)?.toDouble() ?? 0.0;
                      return amount <= 0;
                    });

                    if (hasInvalidAmount) {
                      debugPrint(
                          '❌ PAYMENT VALIDATION FAILED: One or more payment amounts are zero or negative');
                      showScaffoldError(
                          context: context,
                          message: 'add_stock.payment_amounts_positive'.tr);
                      return;
                    }

                    debugPrint('✅ PAYMENT DATA VALIDATION PASSED');

                    // Show payment summary confirmation dialog
                    final confirmed =
                        await StockConfirmationDialog.showPaymentSummary(
                      context: context,
                      itemCount: itemCount,
                      totalAmount: totalStockValue,
                      totalDueAmount: totalDueAmount,
                      paymentData: paymentData,
                      onConfirm: () {},
                      stockItems: stockProvider.pendingStockItems,
                      supplierOldBalance: supplierBalance,
                    );

                    if (confirmed != true) {
                      debugPrint('❌ USER CANCELLED PAYMENT CONFIRMATION');
                      return;
                    }
                    debugPrint('✅ USER CONFIRMED PAYMENT SUMMARY');
                  } else {
                    debugPrint(
                        'ℹ️ NO PAYMENT DATA PROVIDED - SHOWING CONFIRMATION');

                    // Show no payment confirmation dialog
                    final confirmed =
                        await StockConfirmationDialog.showNoPaymentConfirmation(
                      context: context,
                      itemCount: itemCount,
                      totalAmount: totalStockValue,
                      totalDueAmount: totalDueAmount,
                      onConfirm: () {},
                      stockItems: stockProvider.pendingStockItems,
                      supplierOldBalance: supplierBalance,
                    );

                    if (confirmed != true) {
                      debugPrint('❌ USER CANCELLED - WANTS TO ADD PAYMENT');
                      return;
                    }
                    debugPrint('✅ USER CONFIRMED SUBMISSION WITHOUT PAYMENT');
                  }

                  debugPrint(
                      '📦 STARTING BATCH PROCESSING OF ${stockProvider.pendingStockItemsCount} STOCK ITEMS');

                  try {
                    final String? accessToken =
                        Provider.of<AuthModel>(context, listen: false).token;
                    if (accessToken == null) {
                      throw Exception('add_stock.access_token_not_found'.tr);
                    }

                    // Process all pending stock items
                    final batchResult = await stockProvider
                        .processPendingStockItems(
                      accessToken,
                      variantsEnabled: _variantFeatureEnabled(),
                    );

                    debugPrint('📡 BATCH PROCESSING RESULT: $batchResult');
                    debugPrint('📡 BATCH PROCESSING RESULT (PRETTY):');
                    debugPrint(const JsonEncoder.withIndent('  ')
                        .convert(batchResult));

                    if (batchResult['success'] == true) {
                      final summary =
                          batchResult['summary'] as Map<String, dynamic>;
                      final int successful = summary['successful'] ?? 0;
                      final int failed = summary['failed'] ?? 0;
                      final int total = summary['total'] ?? 0;

                      debugPrint('✅ BATCH PROCESSING COMPLETED');
                      debugPrint('   - Successful: $successful');
                      debugPrint('   - Failed: $failed');
                      debugPrint('   - Total: $total');

                      // Only show results dialog if there are failures
                      if (failed > 0) {
                        _showBatchProcessingResults(batchResult);
                        showScaffold(
                            context: context,
                            message:
                                'add_stock.failed_items_remain'.tr.replaceAll('@count', failed.toString()));
                      } else {
                        // All successful - just show success message
                        showScaffold(
                            context: context,
                            message:
                                'add_stock.all_items_success'.tr.replaceAll('@count', successful.toString()));
                      }

                      // If we have successful items, try to complete the purchase order
                      if (successful > 0) {
                        final successfulItems = summary['successfulItems']
                            as List<Map<String, dynamic>>;

                        debugPrint(
                            '🧾 DEBUG SUCCESSFUL ITEMS API RESPONSE DUMP START');
                        for (int i = 0; i < successfulItems.length; i++) {
                          final item = successfulItems[i];
                          final apiResponse = item['apiResponse'];
                          debugPrint(
                              '   • Successful item #${i + 1} | localId=${item['localId']}');
                          if (apiResponse == null) {
                            debugPrint('     - apiResponse: null');
                            continue;
                          }

                          try {
                            debugPrint('     - apiResponse (pretty):');
                            debugPrint(const JsonEncoder.withIndent('  ')
                                .convert(apiResponse));
                          } catch (_) {
                            debugPrint('     - apiResponse: $apiResponse');
                          }

                          if (apiResponse is Map<String, dynamic>) {
                            final dataNode = apiResponse['data'];
                            debugPrint(
                                '     - apiResponse data runtimeType: ${dataNode.runtimeType}');
                            if (dataNode is Map<String, dynamic>) {
                              debugPrint(
                                  '     - apiResponse data keys: ${dataNode.keys.toList()}');
                            }
                          }
                        }
                        debugPrint(
                            '🧾 DEBUG SUCCESSFUL ITEMS API RESPONSE DUMP END');

                        // Look for purchase_voucher_id in the successful API responses
                        String? purchaseId;
                        for (var item in successfulItems) {
                          if (item['apiResponse'] != null &&
                              item['apiResponse']['data'] != null &&
                              item['apiResponse']['data']['purchase_voucher_id'] !=
                                  null) {
                            purchaseId = item['apiResponse']['data']
                                    ['purchase_voucher_id']
                                .toString();
                            debugPrint(
                                '✅ FOUND PURCHASE VOUCHER ID: $purchaseId');
                            break;
                          }
                        }

                        if (purchaseId != null) {
                          debugPrint(
                              '🚀 CALLING FINISH PURCHASE ORDER API WITH PURCHASE VOUCHER ID: $purchaseId');

                          try {
                            final result =
                                await Provider.of<PurchaseProvider>(context,
                                        listen: false)
                                    .finishPurchaseOrder(
                              accessToken: accessToken,
                              purchaseVoucherId: purchaseId,
                              paymentMethods: paymentMethods,
                              paidMethods: paidMethods,
                            );

                            if (result is Map<String, dynamic> &&
                                result['status'] == 'success') {
                              debugPrint(
                                  '✅ PURCHASE ORDER COMPLETED SUCCESSFULLY');

                              // Only reset form if no failed items remain
                              final remainingPending =
                                  summary['remainingPending'] ?? 0;
                              if (remainingPending == 0) {
                                debugPrint(
                                    '🔄 NO FAILED ITEMS - RESETTING FORM');
                                _resetFormFields();
                              } else {
                                debugPrint(
                                    '⚠️ FAILED ITEMS REMAIN - NOT RESETTING FORM');
                                // Just clear the successfully added items from UI
                                setState(() {
                                  stockItems.removeWhere(
                                      (item) => item.isSuccessfullyAdded);
                                  if (stockItems.isEmpty) {
                                    stockItems.add(StockItem());
                                  }
                                });
                              }

                              // Trigger stock-only sync followed by full sync
                              Future.microtask(() async {
                                try {
                                  final syncProvider =
                                      Provider.of<SyncProvider>(context,
                                          listen: false);

                                  // Step 1: Quick stock-only sync for immediate updates
                                  debugPrint('🔄 Starting stock-only sync...');
                                  bool stockSyncSuccess = await syncProvider
                                      .syncStockDataOnly(context);
                                  if (stockSyncSuccess) {
                                    debugPrint(
                                        '✅ STOCK-ONLY SYNC COMPLETED SUCCESSFULLY');
                                  } else {
                                    debugPrint(
                                        '⚠️ STOCK-ONLY SYNC SKIPPED (ALREADY RUNNING)');
                                  }

                                  // Step 2: Full comprehensive sync for complete data consistency
                                  debugPrint('🔄 Starting comprehensive sync...');
                                  await syncProvider.syncAllData(context);
                                  debugPrint(
                                      '✅ COMPREHENSIVE SYNC COMPLETED SUCCESSFULLY');
                                } catch (e) {
                                  debugPrint('❌ SYNC PROCESS FAILED: $e');
                                }
                              });
                            } else {
                              debugPrint('❌ PURCHASE ORDER COMPLETION FAILED');
                              showScaffoldError(
                                  context: context,
                                  message:
                                      'add_stock.purchase_order_completion_failed'.tr);
                            }
                          } catch (e) {
                            debugPrint('💥 ERROR COMPLETING PURCHASE ORDER: $e');
                            showScaffoldError(
                                context: context,
                                message:
                                    'add_stock.error_completing_purchase_order'.tr.replaceAll('@error', e.toString()));
                          }
                        } else {
                          debugPrint(
                              '❌ NO PURCHASE ID FOUND IN SUCCESSFUL ITEMS');
                          showScaffoldError(
                              context: context,
                              message:
                                  'add_stock.purchase_order_not_completed'.tr);
                        }
                      }
                    } else {
                      debugPrint('❌ BATCH PROCESSING FAILED');
                      showScaffoldError(
                          context: context,
                          message: batchResult['message'] ??
                              'add_stock.batch_processing_failed'.tr);
                    }
                  } catch (e) {
                    debugPrint('💥 ERROR IN BATCH PROCESSING: $e');
                    showScaffoldError(
                        context: context,
                        message:
                            'add_stock.error_processing_stock_items'.tr.replaceAll('@error', e.toString()));
                  }
                },
          height: 50,
          width: isMobile ? double.infinity : buttonWidth,
          fontSize: buttonFontSize,
          boxColor: ColorManager.kPrimaryColor,
          textColor: Colors.white,
        );
      },
    );

    Widget cancelButton = CustomRoundButton(
      title: 'add_stock.cancel'.tr,
      fct: () {
        sideBarController.index.value = 15;
      },
      height: 50,
      width: isMobile ? double.infinity : buttonWidth,
      fontSize: buttonFontSize,
      boxColor: Colors.white,
      borderColor: ColorManager.kPrimaryColor,
      textColor: ColorManager.kPrimaryColor,
    );

    if (isMobile) {
      return Row(
        children: [
          Expanded(child: finishButton),
          const SizedBox(width: 12),
          Expanded(child: cancelButton),
        ],
      );
    }

    return Row(
      children: [
        finishButton,
        const SizedBox(width: 15),
        cancelButton,
      ],
    );
  }
}

class _InlineEditableField extends StatefulWidget {
  final String value;
  final Function(String) onChanged;
  final String hintText;
  final List<TextInputFormatter>? inputFormatters;

  const _InlineEditableField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hintText = '',
    this.inputFormatters,
  });

  @override
  State<_InlineEditableField> createState() => _InlineEditableFieldState();
}

class _InlineEditableFieldState extends State<_InlineEditableField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(_InlineEditableField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: TextInputType.number,
      inputFormatters: widget.inputFormatters,
      textAlign: TextAlign.start,
      style: buildCustomStyle(
        FontWeightManager.regular,
        11,
        0.21,
        ColorManager.textColor,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        border: InputBorder.none,
        hintText: widget.hintText,
        hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
      onTap: () {
        // Use a post-frame callback to ensure text selection happens after the tap is processed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_controller.text.isNotEmpty && _focusNode.hasFocus) {
            _controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _controller.text.length,
            );
          }
        });
        Provider.of<KeyboardProvider>(context, listen: false).show(
          'number',
          _controller,
          replaceOnFirstInput: true,
        );
      },
      onChanged: widget.onChanged,
    );
  }
}
