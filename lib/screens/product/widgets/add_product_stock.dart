import 'package:flutter/material.dart';
import 'package:pos_machine/helpers/date_helper.dart';
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
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/stock_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/sync_provider.dart';
import 'package:pos_machine/providers/supplier_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // Added for Timer
import 'dart:convert';
import 'package:pos_machine/widgets/add_product_modal.dart';
import 'package:pos_machine/components/build_restricted_payment_selector.dart';
import 'package:pos_machine/screens/suppliers/add_supplier_modal.dart';
import 'package:pos_machine/widgets/product_details_dialog.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StockItem {
  String barcode;
  String category;
  String product;
  String quantity;
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
  Category? categoryData;
  Supplier? supplierData;
  bool isExpanded; // Add this field for expandable functionality
  bool isEditing; // Add this field to toggle edit mode for already-added rows
  String? selectedUnit; // Add selected unit for dropdown
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
    this.categoryData,
    this.supplierData,
    this.isExpanded = false,
    this.isEditing = false,
    this.selectedUnit,
    this.selectedRack,
    this.isSuccessfullyAdded = false,
    this.apiResponse,
    this.taxInclude = false,
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

  // Header form controllers
  final TextEditingController supplierSearchController =
      TextEditingController();

  // Search controllers for each row
  final Map<int, TextEditingController> categorySearchControllers = {};
  final Map<int, TextEditingController> productSearchControllers = {};
  final Map<int, TextEditingController> barcodeControllers = {};
  final Map<int, TextEditingController> quantityControllers = {};

  // Expanded field controllers for each row
  final Map<int, TextEditingController> purchaseRateControllers = {};
  final Map<int, TextEditingController> retailPriceControllers = {};
  final Map<int, TextEditingController> mrpControllers = {};
  final Map<int, TextEditingController> wholesaleControllers = {};
  final Map<int, TextEditingController> batchNumberControllers = {};
  // Search controllers for expanded dropdowns
  final Map<int, TextEditingController> unitSearchControllers = {};
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

  // Payment method state
  RestrictedPaymentData paymentData = RestrictedPaymentData();
  double totalStockValue = 0.0;
  bool _needsRecalculation =
      false; // Flag to track if total needs recalculation

  // Debounce timer for quantity input
  Timer? _quantityDebounceTimer;

  // Cache for filtered products per category
  final Map<int?, List<GetProduct>> _filteredProductsCache = {};

  // Performance optimization: Cache visible items and index mapping
  List<StockItem> _cachedVisibleItems = [];
  Map<int, int> _visibleToOriginalIndexMap = {};
  bool _needsIndexRebuild = true;

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
      if (!stockItems[i].isHidden) {
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
    // Load pending items after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPendingStockItems();
    });
    // Tax calculation will be triggered when product data is available
    // No need to calculate tax for empty stock items in initState
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

    // Dispose all search controllers safely
    categorySearchControllers.values.forEach((controller) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing category search controller: $e');
      }
    });
    productSearchControllers.values.forEach((controller) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing product search controller: $e');
      }
    });
    barcodeControllers.values.forEach((controller) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing barcode controller: $e');
      }
    });
    quantityControllers.values.forEach((controller) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing quantity controller: $e');
      }
    });

    // Dispose expanded field controllers safely
    purchaseRateControllers.values.forEach((controller) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing purchase rate controller: $e');
      }
    });
    retailPriceControllers.values.forEach((controller) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing retail price controller: $e');
      }
    });
    mrpControllers.values.forEach((controller) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing MRP controller: $e');
      }
    });
    wholesaleControllers.values.forEach((controller) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing wholesale controller: $e');
      }
    });
    batchNumberControllers.values.forEach((controller) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing batch number controller: $e');
      }
    });

    // Dispose all focus nodes safely
    barcodeFocusNodes.values.forEach((focusNode) {
      try {
        focusNode.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing barcode focus node: $e');
      }
    });
    quantityFocusNodes.values.forEach((focusNode) {
      try {
        focusNode.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing quantity focus node: $e');
      }
    });

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

  FocusNode _getQuantityFocusNode(int index) {
    if (!quantityFocusNodes.containsKey(index)) {
      quantityFocusNodes[index] = FocusNode();
    }
    return quantityFocusNodes[index]!;
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
  }

  Future<void> _loadCategories() async {
    try {
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      // Load categories with caching (same as sidebar and stock)
      if (!categoryProvider.isCategoriesLoaded) {
        debugPrint("📥 Loading categories from API...");
        await categoryProvider.listAllCategory();
        debugPrint("✅ Categories loaded and cached");
      } else {
        debugPrint(
            "📋 Using cached categories (${categoryProvider.category?.length ?? 0} items)");
      }
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

    // Create a new StockItem with data from pending item
    final stockItem = StockItem(
      barcode: (pendingData['barcode'] ?? '').toString(),
      category: (pendingData['categoryName'] ?? '').toString(),
      product: (pendingData['productName'] ?? '').toString(),
      quantity: (pendingData['quantity'] ?? '1').toString(),
      salePrice: (pendingData['retailPrice'] ?? '0').toString(),
      mrp: (pendingData['mrp'] ?? '0').toString(),
      wholesale: (pendingData['wholesalePrice'] ?? '0').toString(),
      purchaseRate: (pendingData['purchaseRate'] ?? '0').toString(),
      unit: (pendingData['unit'] ?? '').toString(),
      rack: (pendingData['rack'] ?? '').toString(),
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

    // Try to find and set the category data
    _setCategoryDataFromPending(stockItem, pendingData);

    // Try to find and set the supplier data
    _setSupplierDataFromPending(stockItem, pendingData);

    // Try to find and set the store data
    _setStoreDataFromPending(stockItem, pendingData);

    debugPrint('✅ STOCK ITEM CREATED SUCCESSFULLY');
    return stockItem;
  }

  /// Set product data from pending item
  void _setProductDataFromPending(
      StockItem stockItem, Map<String, dynamic> pendingData) {
    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      final productId = pendingData['productId'];

      if (productId != null) {
        final product = localProductProvider.products.firstWhere(
          (p) => p.productId == productId,
          orElse: () => GetProduct(),
        );

        if (product.productId != null) {
          stockItem.productData = product;
          debugPrint('   - Product data set: ${product.productName}');
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
      final categoryList = categoryProvider.category;
      if (categoryList != null && categoryList.isNotEmpty) {
        final dynamic categoryNameDyn = pendingData['categoryName'];
        final String? categoryName =
            categoryNameDyn != null ? categoryNameDyn.toString() : null;
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

    if (selectedStore == null) {
      debugPrint('❌ STORE VALIDATION FAILED: No store selected');
      showScaffoldError(context: context, message: 'Please select a store');
      return;
    }

    if (selectedSupplier == null || selectedSupplier!.id == 0) {
      debugPrint('❌ SUPPLIER VALIDATION FAILED: No supplier selected');
      showScaffoldError(context: context, message: 'Please select a supplier');
      return;
    }

    final item = stockItems[index];

    if (item.isHidden) {
      debugPrint(
          '❌ ITEM HIDDEN: Stock item ${index + 1} is hidden and cannot be added');
      showScaffoldError(
          context: context,
          message: 'This stock item has been deleted and cannot be added');
      return;
    }

    if (item.isSuccessfullyAdded) {
      debugPrint(
          '❌ ITEM ALREADY ADDED: Stock item ${index + 1} is already successfully added');
      showScaffoldError(
          context: context,
          message: 'This stock item has already been added successfully');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare stock item data for local storage
      final Map<String, dynamic> stockItemData = {
        'productId': item.productData?.productId,
        'categoryId': item.categoryData?.categoryId,
        'quantity': item.quantity,
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
            context: context, message: 'Stock item added to pending list');
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
        String errorMessage = 'Please complete all required fields:';

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
    categorySearchControllers.values
        .forEach((controller) => controller.clear());
    productSearchControllers.values.forEach((controller) => controller.clear());
    barcodeControllers.values.forEach((controller) => controller.clear());
    quantityControllers.values.forEach((controller) => controller.clear());
    debugPrint('✅ SEARCH CONTROLLERS CLEARED');

    // Clear pending stock items from provider
    debugPrint('🧹 CLEARING PENDING STOCK ITEMS FROM PROVIDER...');
    Provider.of<StockProvider>(context, listen: false).clearPendingStockItems();
    debugPrint('✅ PENDING STOCK ITEMS CLEARED');

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
      paymentData = RestrictedPaymentData();
      totalStockValue = 0.0;
      debugPrint('✅ PAYMENT DATA RESET');
    });

    debugPrint('✅ FORM FIELDS RESET COMPLETED');
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

      // Clear expanded field controllers
      _getPurchaseRateController(index).clear();
      _getRetailPriceController(index).clear();
      _getMrpController(index).clear();
      _getWholesaleController(index).clear();
      _getBatchNumberController(index).clear();
    });
    debugPrint('🧹 CLEARED STOCK ITEM AT INDEX $index');
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
      'categoryId': item.categoryData?.categoryId,
      'quantity': item.quantity,
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
                  'Confirm Delete',
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
            'Are you sure you want to delete this stock item? This action cannot be undone.',
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
                'Cancel',
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
                  debugPrint(
                      '🗑️ SOFT DELETED (HIDDEN) STOCK ITEM AT INDEX $index');
                });

                showScaffold(
                    context: context,
                    message: 'Stock item deleted successfully');
                debugPrint('🗑️ DELETED STOCK ITEM AT INDEX $index');
              },
              child: Text(
                'Delete',
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
    double total = 0.0;
    // OPTIMIZED: Use cached visible items instead of iterating all items
    for (StockItem item in _cachedVisibleItems) {
      if (item.isSuccessfullyAdded && item.purchaseRate.isNotEmpty) {
        double purchaseRate = double.tryParse(item.purchaseRate) ?? 0.0;
        double quantity = double.tryParse(item.quantity) ?? 0.0;
        total += (purchaseRate * quantity);
      }
    }
    // Only update if changed (with small epsilon for floating point comparison)
    if (mounted && (totalStockValue - total).abs() > 0.01) {
      setState(() {
        totalStockValue = total;
      });
    }
  }

  void _markForRecalculation() {
    _needsRecalculation = true;
  }

  /// Convert RestrictedPaymentData to API format
  Map<String, dynamic> _convertPaymentDataToApiFormat(
      RestrictedPaymentData paymentData) {
    List<String> paymentMethods = [];
    List<Map<String, dynamic>> paidMethods = [];

    String _getMethodString(RestrictedPaymentType method) {
      switch (method) {
        case RestrictedPaymentType.cash:
          return 'CASH';
        case RestrictedPaymentType.card:
          return 'CARD';
        case RestrictedPaymentType.upi:
          return 'UPI';
      }
    }

    // Add primary method if present
    if (paymentData.primaryMethod != null &&
        paymentData.primaryAmount.isNotEmpty) {
      String methodString = _getMethodString(paymentData.primaryMethod!);
      double amount = double.tryParse(paymentData.primaryAmount) ?? 0.0;

      if (amount > 0) {
        paymentMethods.add(methodString);
        paidMethods.add({
          'method': methodString,
          'amount': amount,
        });
      }
    }

    // Add secondary method if present
    if (paymentData.secondaryMethod != null &&
        paymentData.secondaryAmount.isNotEmpty) {
      String methodString = _getMethodString(paymentData.secondaryMethod!);
      double amount = double.tryParse(paymentData.secondaryAmount) ?? 0.0;

      if (amount > 0) {
        paymentMethods.add(methodString);
        paidMethods.add({
          'method': methodString,
          'amount': amount,
        });
      }
    }

    return {
      'payment_methods': paymentMethods,
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
                  'Batch Processing Results',
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
                              'Total',
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
                              'Successful',
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
                              'Failed',
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
                  'Detailed Results:',
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
                                    isSuccess ? 'Success' : 'Failed',
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
                                    result['message'] ?? 'No message',
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
                                    'Failed items reset for retry. Click Finish to try again.');
                          },
                    icon: Icon(
                      Icons.refresh,
                      size: 16,
                      color: stockProvider.batchProcessingLoading
                          ? Colors.grey
                          : Colors.orange.shade600,
                    ),
                    label: Text(
                      'Retry Failed',
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
                'Close',
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
  void _showProductDetailsModal(int index) {
    final item = stockItems[index];
    if (item.productData == null) return;

    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final currency = appSettingsProvider.appSettings?.currency ?? '';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return ProductDetailsDialog(
          product: item.productData!,
          unitPrice: double.tryParse(item.salePrice) ?? 0.0,
          mrp: double.tryParse(item.mrp) ?? 0.0,
          quantity: int.tryParse(item.quantity) ?? 1,
          selectedStock: null, // Stock items don't have selectedStock
          isCompact: false,
          currency: currency,
        );
      },
    );
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
          padding: const EdgeInsets.only(top: 20.0, left: 10, right: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomBackButton(
                onPressed: () {
                  sideBarController.index.value = 15;
                },
                text: 'All Stocks',
              ),
              Text(
                'Add Product Stock',
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s20,
                  0.30,
                  ColorManager.textColor,
                ),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderSection(size),
                        const SizedBox(height: 20),
                        _buildStockTableHeader(),
                        const SizedBox(height: 10),
                        _buildStockTable(),
                        const SizedBox(height: 20),
                        _buildPaymentSection(),
                        const SizedBox(height: 20),
                        _buildActionButtons(size),
                        const SizedBox(height: 20),
                      ],
                    ),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: _buildDateField("Date", selectedDate,
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
        BuildTextTile(
          isStarRed: true,
          isTextField: true,
          title: title,
          textStyle: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s14,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          height: MediaQuery.of(context).size.height * .07,
          child: CalendarPickerTableCell(
            initialDate: selectedDate,
            onDateSelected: onDateSelected,
            hintText: "Select $title",
            isRequired: title.toLowerCase().contains('date'),
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
        BuildTextTile(
          isStarRed: true,
          isTextField: true,
          title: 'Store',
          textStyle: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s14,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
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
                    selectedStore?.name ?? 'Loading active store...',
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
                    title: "Supplier",
                    hintText: "Select Supplier",
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
                    searchHintText: "Search for supplier...",
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
                                final newSupplier = updatedSupplierList.firstWhere(
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
          _buildHeaderCell("No.", flex: 0, width: 40),
          _buildHeaderCell("Barcode", flex: 2),
          _buildHeaderCell("Category", flex: 2),
          _buildHeaderCell("Product", flex: 3),
          _buildHeaderCell("Qty", flex: 1),
          _buildHeaderCell("Actions", flex: 0, width: 150),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String title, {int flex = 1, double? width}) {
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
      child: Text(
        title,
        style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s12, 0.27,
            ColorManager.kPrimaryColor),
        textAlign: TextAlign.center,
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

  Widget _buildStockTable() {
    final visibleItems = visibleStockItems;
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visibleItems.length,
      itemBuilder: (context, visibleIndex) {
        int originalIndex = getOriginalIndex(visibleIndex);
        // Add key for better performance - prevents unnecessary rebuilds
        return _buildStockRow(originalIndex, visibleIndex,
            key: ValueKey('stock_row_$originalIndex'));
      },
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
                            'Pending Items Ready',
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s14,
                              0.30,
                              Colors.orange.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${stockProvider.pendingStockItemsCount} stock items are ready to be processed. Click "Finish" to process all items via API.',
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

            // Payment method selector with restrictions (no validation)
            BuildRestrictedPaymentSelector(
              title: "Select Payment Method",
              availableMethods: const [
                RestrictedPaymentType.cash,
                RestrictedPaymentType.card,
                RestrictedPaymentType.upi,
              ], // Supports all methods but blocks Card + UPI
              onPaymentChanged: (data) {
                setState(() {
                  paymentData = data;
                });
                debugPrint('Purchase Payment Data: ${data.totalAmount}');
              },
              showTotalAmount: true,
              // expectedAmount: totalStockValue, // Validation removed - no amount validation
              // showRestrictionInfo: false, // Default - no info box shown
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
    int totalQuantity = 0;

    for (StockItem item in stockItems) {
      if (item.isSuccessfullyAdded && !item.isHidden) {
        double quantity = double.tryParse(item.quantity) ?? 0.0;
        double purchaseRate = double.tryParse(item.purchaseRate) ?? 0.0;

        totalPurchaseAmount += (purchaseRate * quantity);
        totalItems++;
        totalQuantity += quantity.toInt();
      }
    }

    // Get supplier information
    String supplierName = selectedSupplier?.name ?? 'No Supplier';
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
                      'Purchase Summary',
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s16,
                        0.30,
                        ColorManager.kPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Supplier: $supplierName',
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
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Items',
                  totalItems.toString(),
                  Icons.inventory_2_outlined,
                  Colors.blue.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Total Purchase Amount',
                  '₹${totalPurchaseAmount.toStringAsFixed(2)}',
                  Icons.shopping_cart_outlined,
                  Colors.green.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Total Quantity',
                  totalQuantity.toString(),
                  Icons.format_list_numbered_outlined,
                  Colors.orange.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Total Due Amount',
                  '₹${totalPayable.toStringAsFixed(2)}',
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
                'Supplier Balance',
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s10,
                  0.27,
                  Colors.grey.shade600,
                ),
              ),
              Text(
                '₹$balanceText',
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
        ? 'Amount to Pay'
        : isToReceive
            ? 'Amount to Receive'
            : 'Current Balance';

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
          '$balanceLabel ₹${balance.abs().toStringAsFixed(2)}',
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
    final item = stockItems[index];

    return BuildBoxShadowContainer(
      key: key,
      circleRadius: 7,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          // Main row content
          Padding(
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
                      // Updated indicator
                      if (item.isSuccessfullyAdded &&
                          item.apiResponse != null &&
                          item.apiResponse!['localId'] != null) ...[
                        Consumer<StockProvider>(
                          builder: (context, stockProvider, child) {
                            final pendingItem = stockProvider
                                .getPendingStockItem(item.apiResponse!['localId']);
                            final bool isUpdated =
                                pendingItem != null && pendingItem['updatedAt'] != null;

                            if (!isUpdated) return const SizedBox.shrink();

                            return const Positioned(
                              top: 0,
                              right: 0,
                              child: SizedBox(
                                width: 8,
                                height: 8,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
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
                // Barcode Text Field
                Expanded(
                  flex: 2,
                  child: BuildBoxShadowContainer(
                    circleRadius: 5,
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextFormField(
                      controller: _getBarcodeController(index),
                      focusNode: _getBarcodeFocusNode(index),
                      decoration: const InputDecoration(
                        hintText: 'Barcode',
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
                        _getBarcodeController(index).selection = TextSelection(
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
                      tooltip: "View product details",
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                // Quantity Text Field (smaller and right-aligned)
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
                      textAlign: TextAlign.right, // Right-aligned text
                      decoration: const InputDecoration(
                        hintText: 'Qty',
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
                        _getQuantityController(index).selection = TextSelection(
                          baseOffset: 0,
                          extentOffset:
                              _getQuantityController(index).text.length,
                        );
                      },
                      onChanged: (value) {
                        // Update the value immediately for responsive UI
                        stockItems[index].quantity = value;

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
                // Actions - Add Stock Button + Clear/Delete Button + Expand Button
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      // Clear/Delete Button (Conditional)
                      if (item.productData != null ||
                          item.isSuccessfullyAdded) ...[
                        Tooltip(
                          message: item.isSuccessfullyAdded
                              ? "Delete stock item"
                              : "Clear product selection",
                          child: Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                  color: Colors.red.withOpacity(0.3)),
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
                                item.isSuccessfullyAdded
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
                          message: _isLoading ? "Adding..." : "Add stock item",
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
                                _isLoading ? Icons.hourglass_empty : Icons.add,
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
                            ? "Hide details"
                            : "Show prices, expiry & tax details",
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
              padding: const EdgeInsets.only(left: 48, right: 16, bottom: 8),
              child: Row(
                children: [
                  // All details in one row
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (item.salePrice.isNotEmpty)
                          _buildDetailChip("Retail", "₹${item.salePrice}",
                              Icons.sell, Colors.blue.shade600),
                        if (item.purchaseRate.isNotEmpty)
                          _buildDetailChip("Purchase", "₹${item.purchaseRate}",
                              Icons.shopping_cart, Colors.green.shade600),
                        if (item.mrp.isNotEmpty)
                          _buildDetailChip("MRP", "₹${item.mrp}",
                              Icons.local_offer, Colors.orange.shade600),
                        if (item.wholesale.isNotEmpty)
                          _buildDetailChip("Wholesale", "₹${item.wholesale}",
                              Icons.store, Colors.purple.shade600),
                        if (item.unit.isNotEmpty)
                          _buildDetailChip("Unit", item.unit, Icons.straighten,
                              Colors.indigo.shade600),
                        if (item.rack.isNotEmpty)
                          _buildDetailChip("Rack", item.rack, Icons.shelves,
                              Colors.teal.shade600),
                        if (item.batchNumber.isNotEmpty)
                          _buildDetailChip("Min Wholesale", item.batchNumber,
                              Icons.numbers, Colors.brown.shade600),
                      ],
                    ),
                  ),
                  // Expand hint
                  Text(
                    "Tap ⌄ to expand",
                    style: buildCustomStyle(
                      FontWeightManager.regular,
                      FontSize.s9,
                      0.27,
                      Colors.grey.shade500,
                    ),
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
      debugPrint(
          '✅ PRODUCT FOUND: ${localProduct.productName} (ID: ${localProduct.productId})');

      setState(() {
        debugPrint('🔄 AUTO-FILLING FIELDS...');
        // Auto-fill basic fields
        stockItems[index].productData =
            localProduct; // Now safe to set directly
        stockItems[index].barcode = localProduct.barcode ?? '';
        stockItems[index].product = localProduct.productName ?? '';
        // Update barcode controller to reflect the change
        _getBarcodeController(index).text = localProduct.barcode ?? '';
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
            categoryList = categoryProvider.category;
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
            localProduct.price?.price?.toString() ?? '0';
        stockItems[index].mrp = localProduct.mrp?.toString() ??
            localProduct.price?.price?.toString() ??
            '0';
        stockItems[index].unit = localProduct.unit ?? '';
        debugPrint('   - Sale Price: ${stockItems[index].salePrice}');
        debugPrint('   - MRP: ${stockItems[index].mrp}');
        debugPrint('   - Unit: ${stockItems[index].unit}');

        // Update controllers with new values
        _getRetailPriceController(index).text = stockItems[index].salePrice;
        _getMrpController(index).text = stockItems[index].mrp;

        // Auto-fill unit dropdown - find the matching unit key
        if (localProduct.unit != null && localProduct.unit!.isNotEmpty) {
          debugPrint('🔍 SEARCHING FOR UNIT KEY: ${localProduct.unit}');
          final purchaseProvider =
              Provider.of<PurchaseProvider>(context, listen: false);
          final unitList = purchaseProvider.getUnitList;
          if (unitList != null) {
            // Find the key that matches the unit value
            String? matchingUnitKey = unitList.entries
                .firstWhere(
                  (entry) => entry.value == localProduct.unit,
                  orElse: () => const MapEntry('', ''),
                )
                .key;
            if (matchingUnitKey.isNotEmpty) {
              stockItems[index].selectedUnit = matchingUnitKey; // Store unit ID
              stockItems[index].unit =
                  localProduct.unit!; // Store unit name for display
              debugPrint('   - Unit Key (ID): $matchingUnitKey');
              debugPrint('   - Unit Name: ${localProduct.unit}');
            }
          }
        }

        // Auto-fill purchase rate: use only product-level purchasePrice; do not fall back to stock entries
        final String? computedPurchasePrice = localProduct.purchasePrice;
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
      });

      // Trigger tax calculation for both retail and wholesale prices after auto-fill
      // Add small delay to ensure UI updates smoothly
      Future.delayed(const Duration(milliseconds: 100), () {
        _calculateTaxForStockItem(index, isRetail: true);
        _calculateTaxForStockItem(index, isRetail: false);
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
            _getQuantityController(index).text = initialQuantityStr!;
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
                  "Purchase Rate",
                  item.purchaseRate,
                  (value) {
                    setState(() => stockItems[index].purchaseRate = value);
                    _updatePendingStockItem(index);
                  },
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  controller: _getPurchaseRateController(index),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildExpandedTextField(
                  "Retail Price",
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
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildExpandedTextField(
                  "MRP",
                  item.mrp,
                  (value) {
                    setState(() {
                      stockItems[index].mrp = value;
                    });
                    _updatePendingStockItem(index);
                  },
                  keyboardType: TextInputType.number,
                  controller: _getMrpController(index),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Second row - Expiry Date, Wholesale Price, Minimum Units for Wholesale, Rack
          Row(
            children: [
              Expanded(
                child: _buildExpandedDatePicker(
                  "Expiry Date",
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
                  "Wholesale Price",
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
                  "Minimum Units for Wholesale",
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
    TextEditingController? controller,
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
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s11,
              0.27,
              ColorManager.textColor,
            ),
            decoration: InputDecoration(
              hintText: "Enter $label",
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
            hintText: "Select $label",
            isRequired: label.toLowerCase().contains('expiry'),
            firstDate: DateTime.now(), // Expiry dates should be in the future
            lastDate: DateTime.now()
                .add(const Duration(days: 3650)), // 10 years from now
            showQuickActions:
                true, // Enable quick date selection for expiry dates
            isForExpiry: label
                .toLowerCase()
                .contains('expiry'), // Show quick actions only for expiry dates
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
          "Category",
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
            shouldRebuild: (previous, current) => previous?.length != current?.length,
            builder: (context, categoryList, child) {
              final filteredCategories = categoryList
                      ?.where((category) => category.categoryName != "ALL")
                      .toList() ??
                  [];

              return BuildDropDownWithSearch<Category>(
                title: null,
                hintText: "Select category",
                value: stockItems[index].categoryData,
                items: filteredCategories,
                onChanged: (category) {
                  setState(() {
                    stockItems[index].categoryData = category;
                    stockItems[index].category = category?.categoryName ?? '';
                    // Clear product when category changes
                    stockItems[index].productData = null;
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
                searchHintText: "Search category...",
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductDropdown(int index) {
    return Selector<LocalProductProvider, List<GetProduct>>(
      selector: (context, provider) => provider.products,
      shouldRebuild: (previous, current) => previous.length != current.length,
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
          hintText: "Select product",
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
                    categoryList = categoryProvider.category;
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
                stockItems[index].unit = product.unit ?? '';
                debugPrint('   - Sale Price: ${stockItems[index].salePrice}');
                debugPrint('   - MRP: ${stockItems[index].mrp}');
                debugPrint('   - Unit: ${stockItems[index].unit}');

                // Update controllers with new values
                _getRetailPriceController(index).text =
                    stockItems[index].salePrice;
                _getMrpController(index).text = stockItems[index].mrp;

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

                // Auto-fill purchase rate: use only product-level purchasePrice; do not fall back to stock entries
                if (product.purchasePrice != null &&
                    product.purchasePrice!.toString().isNotEmpty) {
                  stockItems[index].purchaseRate =
                      product.purchasePrice!.toString();
                  debugPrint(
                      '   - Purchase Rate (from product): ${stockItems[index].purchaseRate}');
                } else {
                  debugPrint(
                      '   - Purchase Rate: not available on product, leaving empty');
                }

                // Auto-fill wholesale price: leave empty as no wholesale price field exists on product
                stockItems[index].wholesale = '';
                debugPrint(
                    '   - Wholesale Price: not available on product, leaving empty');

                // Auto-fill Minimum Units for Wholesale: leave empty as no wholesale min unit field exists on product
                stockItems[index].batchNumber = '';
                debugPrint(
                    '   - Batch Number: not available on product, leaving empty');

                // Update controllers with new values
                _getPurchaseRateController(index).text =
                    stockItems[index].purchaseRate;
                _getWholesaleController(index).text =
                    stockItems[index].wholesale;
                _getBatchNumberController(index).text =
                    stockItems[index].batchNumber;
              });

              // Trigger tax calculation for both retail and wholesale prices after product selection
              // Add small delay to ensure UI updates smoothly
              Future.delayed(const Duration(milliseconds: 100), () {
                _calculateTaxForStockItem(index, isRetail: true);
                _calculateTaxForStockItem(index, isRetail: false);
              });

              // Auto-focus on quantity field with text selection after product selection
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

                debugPrint(
                    '✅ AUTO-FOCUSED ON QUANTITY FIELD WITH TEXT SELECTION FROM PRODUCT DROPDOWN');
              });

              debugPrint('✅ PRODUCT DROPDOWN AUTO-FILL COMPLETED SUCCESSFULLY');
            }
          },
          displayText: (product) => product.productName ?? '',
          searchController: _getProductSearchController(index),
          isRequired: false,
          height: 40,
          searchHintText: "Search product...",
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
                  "Unit",
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
              hintText: "Select Unit",
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
              searchHintText: "Search unit...",
            ),
          ],
        );
      },
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
                  "Rack",
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
              hintText: "Select Rack",
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
              searchHintText: "Search rack...",
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
                    Text(
                      "Including Tax",
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s10,
                        0.27,
                        Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: item.taxInclude,
                        onChanged: (bool value) {
                          setState(() {
                            item.taxInclude = value;
                            _calculateTaxForStockItem(index, isRetail: true);
                            _calculateTaxForStockItem(index, isRetail: false);
                          });
                          _updatePendingStockItem(index);
                        },
                        activeColor: ColorManager.kPrimaryColor,
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
                "Retail Price",
                item.taxInclude
                    ? '₹${(item.calculatedTaxData?['price_including_tax_retail'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"}'
                    : '₹${(item.calculatedTaxData?['price_excluding_tax_retail'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"} + ₹${(item.calculatedTaxData?['retailTaxAmount'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"}',
                'Tax: ${(item.calculatedTaxData?['tax_rate_retail'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"}%',
                Colors.blue,
                item.taxInclude,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildTaxCard(
                "Wholesale Price",
                item.taxInclude
                    ? '₹${(item.calculatedTaxData?['price_including_tax_wholesale'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"}'
                    : '₹${(item.calculatedTaxData?['price_excluding_tax_wholesale'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"} + ₹${(item.calculatedTaxData?['wholesaleTaxAmount'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"}',
                'Tax: ${(item.calculatedTaxData?['tax_rate_wholesale'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"}%',
                Colors.orange,
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

  Widget _buildTaxCard(String title, String priceText, String taxText,
      Color color, bool isIncluding) {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(12),
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
                    title == "Retail Price" ? "1" : "2",
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s10,
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
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s11,
                    0.27,
                    color,
                  ),
                ),
              ),
            ],
          ),
          Text(
            priceText,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s12,
              0.27,
              Colors.black87,
            ),
          ),
          Text(
            taxText,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s10,
              0.27,
              Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _calculateTaxForStockItem(int index,
      {bool isRetail = true}) async {
    // Check if index is valid
    if (index >= stockItems.length) {
      debugPrint('⚠️ Invalid index for tax calculation: $index');
      return;
    }

    final item = stockItems[index];

    if (item.productData == null ||
        item.categoryData == null ||
        item.productData!.productId == null ||
        item.categoryData!.categoryId == null) {
      debugPrint(
          '⚠️ Cannot calculate tax: Product or Category data missing for item $index');

      // Only set state if we have valid calculated tax data structure
      if (mounted) {
        setState(() {
          item.calculatedTaxData ??= {};
          if (isRetail) {
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

    final double priceToCalculate = isRetail
        ? (double.tryParse(item.salePrice) ?? 0.0)
        : (double.tryParse(item.wholesale) ?? 0.0);

    final String? accessToken =
        Provider.of<AuthModel>(context, listen: false).token;
    if (accessToken == null) {
      debugPrint('❌ Cannot calculate tax: Access token not found.');
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
        setState(() {
          if (isRetail) {
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
        debugPrint(
            '✅ Tax calculation successful for item $index (${isRetail ? 'Retail' : 'Wholesale'}): $taxData');
      } else {
        debugPrint(
            '❌ Tax calculation failed for item $index (${isRetail ? 'Retail' : 'Wholesale'})');
        if (mounted) {
          setState(() {
            if (isRetail) {
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
          '💥 Error calculating tax for item $index (${isRetail ? 'Retail' : 'Wholesale'}): $e');
      if (mounted) {
        setState(() {
          if (isRetail) {
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
  }

  Widget _buildActionButtons(Size size) {
    return Row(
      children: [
        // CustomRoundButton(
        //   title: "Add New Row",
        //   fct: () {
        //     setState(() {
        //       stockItems.add(StockItem());
        //     });
        //   },
        //   height: 50,
        //   width: size.width * 0.12,
        //   fontSize: FontSize.s14,
        //   boxColor: ColorManager.kPrimaryColor,
        // ),
        // const SizedBox(width: 15),
        Consumer<StockProvider>(
          builder: (context, stockProvider, child) {
            return CustomRoundButton(
              title: stockProvider.batchProcessingLoading
                  ? "Processing..."
                  : "Finish (${stockProvider.pendingStockItemsCount} items)",
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
                                'No stock items have been added to pending list. Please add some stock items first.');
                        return;
                      }

                      // Validate payment data if payment methods are provided
                      Map<String, dynamic> apiPaymentData =
                          _convertPaymentDataToApiFormat(paymentData);
                      List<String>? paymentMethods =
                          apiPaymentData['payment_methods'];
                      List<Map<String, dynamic>>? paidMethods =
                          apiPaymentData['paid_methods'];

                      // Optional validation: if payment data is provided, ensure it's complete
                      if (paymentMethods != null && paymentMethods.isNotEmpty) {
                        debugPrint('✅ PAYMENT DATA PROVIDED - VALIDATING...');
                        debugPrint('   - Payment Methods: $paymentMethods');
                        debugPrint('   - Paid Methods: $paidMethods');

                        if (paidMethods == null || paidMethods.isEmpty) {
                          debugPrint(
                              '❌ PAYMENT VALIDATION FAILED: Payment methods provided but no amounts specified');
                          showScaffoldError(
                              context: context,
                              message:
                                  'Please specify payment amounts for selected payment methods.');
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
                              message:
                                  'Payment amounts must be greater than zero.');
                          return;
                        }

                        debugPrint('✅ PAYMENT DATA VALIDATION PASSED');
                      } else {
                        debugPrint(
                            'ℹ️ NO PAYMENT DATA PROVIDED - PROCEEDING WITHOUT PAYMENT INFO');
                      }

                      debugPrint(
                          '📦 STARTING BATCH PROCESSING OF ${stockProvider.pendingStockItemsCount} STOCK ITEMS');

                      try {
                        final String? accessToken =
                            Provider.of<AuthModel>(context, listen: false)
                                .token;
                        if (accessToken == null) {
                          throw Exception('Access token not found');
                        }

                        // Process all pending stock items
                        final batchResult = await stockProvider
                            .processPendingStockItems(accessToken);

                        debugPrint('📡 BATCH PROCESSING RESULT: $batchResult');

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
                                    '$failed items failed and remain in pending list. You can retry by clicking Finish again.');
                          } else {
                            // All successful - just show success message
                            showScaffold(
                                context: context,
                                message:
                                    'All $successful stock items processed successfully!');
                          }

                          // If we have successful items, try to complete the purchase order
                          if (successful > 0) {
                            final successfulItems = summary['successfulItems']
                                as List<Map<String, dynamic>>;

                            // Look for purchase_id in the successful API responses
                            String? purchaseId;
                            for (var item in successfulItems) {
                              if (item['apiResponse'] != null &&
                                  item['apiResponse']['data'] != null &&
                                  item['apiResponse']['data']['purchase_id'] !=
                                      null) {
                                purchaseId = item['apiResponse']['data']
                                        ['purchase_id']
                                    .toString();
                                debugPrint('✅ FOUND PURCHASE ID: $purchaseId');
                                break;
                              }
                            }

                            if (purchaseId != null) {
                              debugPrint(
                                  '🚀 CALLING FINISH PURCHASE ORDER API WITH PURCHASE ID: $purchaseId');

                              try {
                                final result =
                                    await Provider.of<PurchaseProvider>(context,
                                            listen: false)
                                        .finishPurchaseOrder(
                                  accessToken: accessToken,
                                  purchaseId: purchaseId,
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
                                      debugPrint(
                                          '🔄 Starting stock-only sync...');
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
                                      debugPrint(
                                          '🔄 Starting comprehensive sync...');
                                      await syncProvider.syncAllData(context);
                                      debugPrint(
                                          '✅ COMPREHENSIVE SYNC COMPLETED SUCCESSFULLY');
                                    } catch (e) {
                                      debugPrint('❌ SYNC PROCESS FAILED: $e');
                                    }
                                  });
                                } else {
                                  debugPrint(
                                      '❌ PURCHASE ORDER COMPLETION FAILED');
                                  showScaffoldError(
                                      context: context,
                                      message:
                                          'Purchase order completion failed. Stock items were added but order was not finalized.');
                                }
                              } catch (e) {
                                debugPrint(
                                    '💥 ERROR COMPLETING PURCHASE ORDER: $e');
                                showScaffoldError(
                                    context: context,
                                    message:
                                        'Error completing purchase order: ${e.toString()}');
                              }
                            } else {
                              debugPrint(
                                  '❌ NO PURCHASE ID FOUND IN SUCCESSFUL ITEMS');
                              showScaffoldError(
                                  context: context,
                                  message:
                                      'Stock items were processed but purchase order could not be completed.');
                            }
                          }
                        } else {
                          debugPrint('❌ BATCH PROCESSING FAILED');
                          showScaffoldError(
                              context: context,
                              message: batchResult['message'] ??
                                  'Batch processing failed');
                        }
                      } catch (e) {
                        debugPrint('💥 ERROR IN BATCH PROCESSING: $e');
                        showScaffoldError(
                            context: context,
                            message:
                                'Error processing stock items: ${e.toString()}');
                      }
                    },
              height: 50,
              width: size.width * 0.15,
              fontSize: FontSize.s14,
              boxColor: ColorManager.kPrimaryColor,
              textColor: Colors.white,
            );
          },
        ),
        const SizedBox(width: 15),
        CustomRoundButton(
          title: "Cancel",
          fct: () {
            sideBarController.index.value = 15;
          },
          height: 50,
          width: size.width * 0.15,
          fontSize: FontSize.s14,
          boxColor: Colors.white,
          borderColor: ColorManager.kPrimaryColor,
          textColor: ColorManager.kPrimaryColor,
        ),
      ],
    );
  }
}
