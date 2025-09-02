import 'package:flutter/material.dart';
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
import 'package:pos_machine/widgets/add_product_modal.dart';
import 'package:pos_machine/components/build_restricted_payment_selector.dart';

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

  // Additional details for modal
  String batchNumber;
  String supplier;
  int supplierId;
  GetProduct? productData;
  Category? categoryData;
  Supplier? supplierData;
  bool isExpanded; // Add this field for expandable functionality
  String? selectedUnit; // Add selected unit for dropdown
  String? selectedRack; // Add selected rack for dropdown
  bool isSuccessfullyAdded; // Add this field to track successful addition
  Map<String, dynamic>? apiResponse; // Add this field to store API response
  bool taxInclude; // Add this field for tax inclusion toggle
  String retailPriceTax; // Add this for retail price with tax
  String wholesalePriceTax; // Add this for wholesale price with tax
  Map<String, dynamic>? calculatedTaxData; // Store calculated tax data

  StockItem({
    this.barcode = '',
    this.category = '',
    this.product = '',
    this.quantity = '1',
    this.salePrice = '0',
    this.mrp = '0',
    this.wholesale = '0',
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
    this.isExpanded = false, // Initialize as collapsed
    this.selectedUnit, // Initialize selected unit
    this.selectedRack, // Initialize selected rack
    this.isSuccessfullyAdded = false, // Initialize as not added
    this.apiResponse, // Initialize apiResponse
    this.taxInclude = false, // Initialize as false
    this.retailPriceTax = '0.00', // Initialize as 0.00
    this.wholesalePriceTax = '0.00', // Initialize as 0.00
    this.calculatedTaxData, // Initialize
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

  @override
  void initState() {
    super.initState();
    _initializeData();
    // Tax calculation will be triggered when product data is available
    // No need to calculate tax for empty stock items in initState
  }

  @override
  void dispose() {
    // Dispose timer
    _barcodeTimer?.cancel();

    // Dispose all search controllers
    categorySearchControllers.values
        .forEach((controller) => controller.dispose());
    productSearchControllers.values
        .forEach((controller) => controller.dispose());
    barcodeControllers.values.forEach((controller) => controller.dispose());
    quantityControllers.values.forEach((controller) => controller.dispose());

    // Dispose all focus nodes
    barcodeFocusNodes.values.forEach((focusNode) => focusNode.dispose());
    quantityFocusNodes.values.forEach((focusNode) => focusNode.dispose());

    supplierSearchController.dispose();
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
      barcodeControllers[index] =
          TextEditingController(text: stockItems[index].barcode);
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
      quantityControllers[index] =
          TextEditingController(text: stockItems[index].quantity);
    }
    return quantityControllers[index]!;
  }

  FocusNode _getQuantityFocusNode(int index) {
    if (!quantityFocusNodes.containsKey(index)) {
      quantityFocusNodes[index] = FocusNode();
    }
    return quantityFocusNodes[index]!;
  }

  Future<void> _initializeData() async {
    // Initialize any required data
    await _loadSuppliers();
    await _loadUnits(); // Load units
    await _loadRacks(); // Load racks
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
        'wholesalePrice':
            item.wholesale.isNotEmpty ? item.wholesale : item.salePrice,
        'unit': item.unit,
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

        // Recalculate total stock value when single item is successfully added
        _calculateTotalStockValue();

        showScaffold(
            context: context, message: 'Stock item added to pending list');
        debugPrint('✅ SINGLE STOCK ITEM MARKED AS SUCCESSFULLY ADDED LOCALLY');

        // Automatically add a new empty row after successful stock addition
        debugPrint('🔄 AUTO-ADDING NEW ROW AFTER SUCCESSFUL LOCAL ADDITION');
        setState(() {
          stockItems.add(StockItem());
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
      // Reset header fields
      selectedStore = null;
      selectedSupplier = null;
      selectedDate = DateTime.now();
      selectedPurchaseDate = DateTime.now();
      debugPrint('✅ HEADER FIELDS RESET');

      // Reset stock items to one empty row with no success flags
      stockItems = [StockItem(isSuccessfullyAdded: false)];
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
      'unit': item.unit,
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
              Icon(
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

                // Remove from UI
                setState(() {
                  if (stockItems.length > 1) {
                    stockItems.removeAt(index);

                    // Clean up controllers for this index
                    categorySearchControllers[index]?.dispose();
                    productSearchControllers[index]?.dispose();
                    barcodeControllers[index]?.dispose();
                    quantityControllers[index]?.dispose();
                    barcodeFocusNodes[index]?.dispose();
                    quantityFocusNodes[index]?.dispose();

                    // Remove from maps
                    categorySearchControllers.remove(index);
                    productSearchControllers.remove(index);
                    barcodeControllers.remove(index);
                    quantityControllers.remove(index);
                    barcodeFocusNodes.remove(index);
                    quantityFocusNodes.remove(index);
                  } else {
                    // If it's the last item, just clear it
                    _clearStockItem(index);
                  }
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
    for (StockItem item in stockItems) {
      if (item.isSuccessfullyAdded && item.purchaseRate.isNotEmpty) {
        double purchaseRate = double.tryParse(item.purchaseRate) ?? 0.0;
        double quantity = double.tryParse(item.quantity) ?? 0.0;
        total += (purchaseRate * quantity);
      }
    }
    setState(() {
      totalStockValue = total;
    });
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

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    // Calculate total stock value outside of any Consumer build method
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateTotalStockValue();
    });

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
            firstDate: DateTime(2020), // Allow past dates for all general date fields
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
    return Consumer<PurchaseProvider>(
      builder: (context, purchaseProvider, child) {
        List<GetStoreModelData>? storeList = purchaseProvider.getStoreList;

        return BuildDropDownWithSearch<GetStoreModelData>(
          title: "Store",
          hintText: "Select Store",
          value: selectedStore,
          items: storeList ?? [],
          onChanged: (value) {
            setState(() {
              selectedStore = value;
            });
          },
          displayText: (store) => store.name ?? 'Unknown Store',
          searchController:
              TextEditingController(), // A new controller for this dropdown
          isRequired: true,
          searchHintText: "Search store...",
        );
      },
    );
  }

  Widget _buildSupplierField() {
    return Consumer<SupplierProvider>(
      builder: (context, supplierProvider, child) {
        List<Supplier> supplierList = supplierProvider.supplierList ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BuildDropDownWithSearch<Supplier>(
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
          _buildHeaderCell("Actions", flex: 0, width: 190),
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

  Widget _buildStockTable() {
    return Column(
      children: List.generate(stockItems.length, (index) {
        return _buildStockRow(index);
      }),
    );
  }

  Widget _buildPaymentSection() {
    return Consumer<StockProvider>(
      builder: (context, stockProvider, child) {
        // Only show payment section if there are successfully added items or pending items
        bool hasSuccessfulItems =
            stockItems.any((item) => item.isSuccessfullyAdded);
        bool hasPendingItems = stockProvider.pendingStockItemsCount > 0;

        if (!hasSuccessfulItems && !hasPendingItems) {
          return const SizedBox.shrink(); // Hidden when no items added
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pending Items Info Section
            if (hasPendingItems && !hasSuccessfulItems) ...[
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
      if (item.isSuccessfullyAdded) {
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
                  'Total Payable',
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
    String paymentType = _getSupplierPaymentType();

    // Color coding same as supplier list:
    // Red for 'to_pay' (we owe TO the supplier)
    // Green for 'to_receive' (supplier owes TO us)
    Color badgeColor = paymentType == 'to_pay'
        ? Colors.red
        : paymentType == 'to_receive'
            ? Colors.green
            : Colors.grey;

    IconData icon = paymentType == 'to_pay'
        ? Icons.arrow_upward
        : paymentType == 'to_receive'
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

  // Helper method to get supplier payment type
  String _getSupplierPaymentType() {
    if (selectedSupplier != null) {
      return selectedSupplier!.paymentType;
    }
    return 'to_pay';
  }

  // Build supplier balance display under the dropdown
  Widget _buildSupplierBalanceDisplay() {
    double balance = _getSupplierBalance();
    String paymentType = _getSupplierPaymentType();

    // Color coding same as supplier list:
    // Red for 'to_pay' (we owe TO the supplier)
    // Green for 'to_receive' (supplier owes TO us)
    Color textColor = paymentType == 'to_pay'
        ? Colors.red
        : paymentType == 'to_receive'
            ? Colors.green
            : Colors.black;

    String balanceLabel = paymentType == 'to_pay'
        ? 'Amount to Pay'
        : paymentType == 'to_receive'
            ? 'Amount to Receive'
            : 'Current Balance';

    IconData icon = paymentType == 'to_pay'
        ? Icons.arrow_upward
        : paymentType == 'to_receive'
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
          '$balanceLabel ₹${balance.toStringAsFixed(2)}',
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

  Widget _buildStockRow(int index) {
    final item = stockItems[index];

    return BuildBoxShadowContainer(
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
                // Row Number Indicator
                SizedBox(
                  width: 40,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: item.isSuccessfullyAdded
                          ? Colors.green.shade50
                          : Colors.blue.shade50,
                      border: Border.all(
                        color: item.isSuccessfullyAdded
                            ? Colors.green
                            : Colors.blue,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: item.isSuccessfullyAdded
                                  ? Colors.green
                                  : Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s12,
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
                                final pendingItem =
                                    stockProvider.getPendingStockItem(
                                        item.apiResponse!['localId']);
                                final bool isUpdated = pendingItem != null &&
                                    pendingItem['updatedAt'] != null;

                                if (!isUpdated) return const SizedBox.shrink();

                                return Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
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
                      onChanged: (value) {
                        setState(() {
                          stockItems[index].barcode = value;
                        });
                        // Auto-fill fields when barcode is entered
                        _autoFillFromBarcode(index, value);
                        // Update pending item if already added
                        _updatePendingStockItem(index);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Category Dropdown with Search
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 40,
                    child: _buildCategoryDropdown(index),
                  ),
                ),
                const SizedBox(width: 8),
                // Product Dropdown with Search
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 40,
                    child: _buildProductDropdown(index),
                  ),
                ),
                const SizedBox(width: 8),
                // Quantity Text Field
                Expanded(
                  flex: 1,
                  child: BuildBoxShadowContainer(
                    circleRadius: 5,
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextFormField(
                      controller: _getQuantityController(index),
                      focusNode: _getQuantityFocusNode(index),
                      keyboardType: TextInputType.number,
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
                      onChanged: (value) {
                        setState(() {
                          stockItems[index].quantity = value;
                        });
                        // Update pending item if already added
                        _updatePendingStockItem(index);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Actions - Add Stock Button + Clear/Delete Button + Expand Button
                SizedBox(
                  width: 190, // Increased width to accommodate new button
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                        const SizedBox(width: 8),
                      ],
                      // Add Stock Button (Visible without expanding)
                      CustomRoundButton(
                        title: item.isSuccessfullyAdded
                            ? "Added"
                            : (_isLoading ? "Adding..." : "Add"),
                        fct: item.isSuccessfullyAdded || _isLoading
                            ? () {}
                            : () => _addStockForSingleItem(index),
                        height: 40,
                        width: 70,
                        fontSize: FontSize.s10,
                        boxColor: item.isSuccessfullyAdded
                            ? Colors.green
                            : (_isLoading
                                ? Colors.grey
                                : ColorManager.kPrimaryColor),
                        textColor: Colors.white,
                      ),
                      const SizedBox(width: 8),
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

  // Auto-fill method for barcode scanning
  Timer? _barcodeTimer;

  void _autoFillFromBarcode(int index, String barcode) {
    debugPrint('🔍 BARCODE AUTO-FILL TRIGGERED');
    debugPrint('   - Row index: $index');
    debugPrint('   - Barcode: $barcode');

    if (barcode.isEmpty) {
      debugPrint('❌ BARCODE IS EMPTY - SKIPPING AUTO-FILL');
      return;
    }

    // Cancel previous timer to debounce rapid barcode inputs
    _barcodeTimer?.cancel();

    // Add delay to prevent multiple rapid API calls during barcode scanning
    _barcodeTimer = Timer(const Duration(milliseconds: 500), () {
      _performBarcodeAutoFill(index, barcode);
    });
  }

  void _performBarcodeAutoFill(int index, String barcode) {
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
          final categoryList = categoryProvider.category;
          if (categoryList != null) {
            // Find category by name from ProductCategory
            final matchingCategory = categoryList.firstWhere(
              (cat) => cat.categoryName == localProduct.category!.name,
              orElse: () => categoryList.first, // fallback to first category
            );
            stockItems[index].categoryData = matchingCategory;
            stockItems[index].category = matchingCategory.categoryName ?? '';
            debugPrint('   - Category: ${matchingCategory.categoryName}');
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
                  orElse: () => MapEntry('', ''),
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

        // Auto-fill purchase rate from first available stock
        if (localProduct.stock != null && localProduct.stock!.isNotEmpty) {
          stockItems[index].purchaseRate =
              localProduct.stock!.first.purchasePrice ?? '0';
          debugPrint('   - Purchase Rate: ${stockItems[index].purchaseRate}');
        }

        // Auto-fill wholesale price (use MRP as default if no wholesale price)
        stockItems[index].wholesale = localProduct.mrp?.toString() ??
            localProduct.price?.price?.toString() ??
            '0';
        debugPrint('   - Wholesale Price: ${stockItems[index].wholesale}');

        // Auto-fill Minimum Units for Wholesale with default value
        stockItems[index].batchNumber =
            '1'; // Default minimum units for wholesale
        debugPrint('   - Batch Number: ${stockItems[index].batchNumber}');
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
      showDialog(
        context: context,
        builder: (context) => AddProductWithBarcodeModal(barcode: barcode),
      );
    }
  }

  Widget _buildExpandedSection(int index) {
    final item = stockItems[index];

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First row - Unit, Purchase Rate, Retail Price, MRP
          Row(
            children: [
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
            initialValue: value,
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
            lastDate: DateTime.now().add(const Duration(days: 3650)), // 10 years from now
            showQuickActions: true, // Enable quick date selection for expiry dates
            isForExpiry: label.toLowerCase().contains('expiry'), // Show quick actions only for expiry dates
            isAllowEdit: true, // Allow text editing for expiry dates
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown(int index) {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, child) {
        List<Category>? categoryList = categoryProvider.category;

        return BuildDropDownWithSearch<Category>(
          title: null,
          hintText: "Select category",
          value: stockItems[index].categoryData,
          items: categoryList
                  ?.where((category) => category.categoryName != "ALL")
                  .toList() ??
              [],
          onChanged: (category) {
            setState(() {
              stockItems[index].categoryData = category;
              stockItems[index].category = category?.categoryName ?? '';
              // Clear product when category changes
              stockItems[index].productData = null;
              stockItems[index].product = '';
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
    );
  }

  Widget _buildProductDropdown(int index) {
    return Consumer<LocalProductProvider>(
      builder: (context, localProductProvider, child) {
        List<GetProduct> allProducts = localProductProvider.products;
        List<GetProduct> uniqueProducts = [];
        Map<int, GetProduct> productMap = {};

        if (allProducts.isNotEmpty) {
          for (var product in allProducts) {
            if (product.productId != null) {
              // Use productId as key to ensure uniqueness
              productMap[product.productId!] = product;
            }
          }
          uniqueProducts = productMap.values.toList();
        }

        // Ensure the selected value exists in the items list
        GetProduct? selectedProduct = stockItems[index].productData;
        if (selectedProduct != null && selectedProduct.productId != null) {
          // Find the actual product instance from the unique list
          try {
            selectedProduct = uniqueProducts.firstWhere(
              (product) => product.productId == selectedProduct!.productId,
            );
          } catch (e) {
            // If not found, set to null to avoid dropdown error
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
                  final categoryList = categoryProvider.category;
                  if (categoryList != null) {
                    // Find category by name from ProductCategory
                    final matchingCategory = categoryList.firstWhere(
                      (cat) => cat.categoryName == product.category!.name,
                      orElse: () =>
                          categoryList.first, // fallback to first category
                    );
                    stockItems[index].categoryData = matchingCategory;
                    stockItems[index].category =
                        matchingCategory.categoryName ?? '';
                    debugPrint(
                        '   - Category: ${matchingCategory.categoryName}');
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
                          orElse: () => MapEntry('', ''),
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

                // Auto-fill purchase rate from first available stock
                if (product.stock != null && product.stock!.isNotEmpty) {
                  stockItems[index].purchaseRate =
                      product.stock!.first.purchasePrice ?? '0';
                  debugPrint(
                      '   - Purchase Rate: ${stockItems[index].purchaseRate}');
                }

                // Auto-fill wholesale price (use MRP as default if no wholesale price)
                stockItems[index].wholesale = product.mrp?.toString() ??
                    product.price?.price?.toString() ??
                    '0';
                debugPrint(
                    '   - Wholesale Price: ${stockItems[index].wholesale}');

                // Auto-fill Minimum Units for Wholesale with default value
                stockItems[index].batchNumber =
                    '1'; // Default minimum units for wholesale
                debugPrint(
                    '   - Batch Number: ${stockItems[index].batchNumber}');
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
    return Consumer<PurchaseProvider>(
      builder: (context, purchaseProvider, child) {
        Map<String, String>? unitList = purchaseProvider.getUnitList;
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
              searchController: TextEditingController(),
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
    return Consumer<PurchaseProvider>(
      builder: (context, purchaseProvider, child) {
        Map<String, String>? rackList = purchaseProvider.getMasterDataValues;
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
              searchController: TextEditingController(),
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
                                      debugPrint('✅ COMPREHENSIVE SYNC COMPLETED SUCCESSFULLY');
                                      
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
