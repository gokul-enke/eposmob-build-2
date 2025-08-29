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
import 'package:pos_machine/models/get_suppliers.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/stock_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/sync_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'dart:convert'; // Added for json.decode
import 'package:pos_machine/widgets/add_product_modal.dart';

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
  GetSuppliersModelData? supplierData;
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
  
  // Focus nodes for barcode fields
  final Map<int, FocusNode> barcodeFocusNodes = {};

  // Selected header values
  GetStoreModelData? selectedStore;
  DateTime selectedDate = DateTime.now();
  DateTime selectedPurchaseDate = DateTime.now();
  GetSuppliersModelData? selectedSupplier;

  // Stock items list
  List<StockItem> stockItems = [StockItem()]; // Start with one empty row

  bool _isLoading = false;
  bool _isFinishingOrder = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    // Call initial tax calculation for any existing stock items
    for (int i = 0; i < stockItems.length; i++) {
      _calculateTaxForStockItem(i, isRetail: true);
      _calculateTaxForStockItem(i, isRetail: false);
    }
  }

  @override
  void dispose() {
    // Dispose all search controllers
    categorySearchControllers.values
        .forEach((controller) => controller.dispose());
    productSearchControllers.values
        .forEach((controller) => controller.dispose());
    barcodeControllers.values.forEach((controller) => controller.dispose());
    
    // Dispose all focus nodes
    barcodeFocusNodes.values.forEach((focusNode) => focusNode.dispose());
    
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
        await Provider.of<PurchaseProvider>(context, listen: false)
            .listAllSuppliers(accessToken, null);
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

  void _addNewStockRow() async {
    debugPrint('🔄 ADD NEW STOCK ROW BUTTON CLICKED');
    debugPrint('📊 CURRENT STATE:');
    debugPrint('   - Total stock items: ${stockItems.length}');
    debugPrint('   - Selected store: ${selectedStore?.name ?? 'None'}');
    debugPrint(
        '   - Selected supplier: ${selectedSupplier?.user?.name ?? 'None'}');
    debugPrint(
        '   - Selected date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}');

    // DON'T clear success flags - preserve already added rows
    debugPrint('✅ PRESERVING SUCCESS FLAGS FOR ALREADY ADDED ROWS');

    // First, add stock for all completed rows (excluding already added ones)
    debugPrint('🔄 CALLING _addStockForCompletedRows()...');
    bool stockAddedSuccessfully = await _addStockForCompletedRows();

    // If stock addition failed due to validation, don't add new row
    if (!stockAddedSuccessfully) {
      debugPrint('❌ STOCK ADDITION FAILED - NOT ADDING NEW ROW');
      return;
    }

    // Then add a new empty row (DON'T reset fields)
    debugPrint('🔄 ADDING NEW EMPTY ROW...');
    setState(() {
      stockItems.add(StockItem());
    });
    debugPrint('✅ NEW EMPTY ROW ADDED. Total items: ${stockItems.length}');
  }

  Future<bool> _addStockForCompletedRows() async {
    debugPrint('🔄 STOCK ADDITION PROCESS STARTED');

    if (selectedStore == null) {
      debugPrint('❌ STORE VALIDATION FAILED: No store selected');
      showScaffoldError(context: context, message: 'Please select a store');
      return false; // Indicate failure
    }
    debugPrint('✅ STORE VALIDATION PASSED: Store ID ${selectedStore!.id}');

    if (selectedSupplier == null || selectedSupplier!.id == 0) {
      debugPrint('❌ SUPPLIER VALIDATION FAILED: No supplier selected');
      showScaffoldError(context: context, message: 'Please select a supplier');
      return false; // Indicate failure
    }
    debugPrint(
        '✅ SUPPLIER VALIDATION PASSED: Supplier ID ${selectedSupplier!.id}');

    // Find completed rows (rows with product and category selected)
    List<StockItem> completedRows = stockItems
        .where((item) =>
            item.productData != null &&
            item.categoryData != null &&
            item.product.isNotEmpty &&
            item.category.isNotEmpty &&
            !item
                .isSuccessfullyAdded) // ❌ EXCLUDE ALREADY SUCCESSFULLY ADDED ROWS
        .toList();

    debugPrint('📊 COMPLETED ROWS ANALYSIS:');
    debugPrint('   - Total rows: ${stockItems.length}');
    debugPrint(
        '   - Completed rows (excluding already added): ${completedRows.length}');

    for (int i = 0; i < stockItems.length; i++) {
      final item = stockItems[i];
      debugPrint(
          '   - Row ${i + 1}: Product=${item.product}, Category=${item.category}, ProductData=${item.productData != null}, CategoryData=${item.categoryData != null}, AlreadyAdded=${item.isSuccessfullyAdded}');
    }

    if (completedRows.isEmpty) {
      debugPrint('❌ COMPLETED ROWS VALIDATION FAILED: No completed rows found');
      showScaffoldError(
          context: context,
          message:
              'Please complete at least one stock item before adding a new row');
      return false; // Indicate failure
    }
    debugPrint(
        '✅ COMPLETED ROWS VALIDATION PASSED: ${completedRows.length} rows ready for API');

    setState(() {
      _isLoading = true;
    });
    debugPrint('🔄 LOADING STATE SET: true');

    try {
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      if (accessToken == null) {
        debugPrint('❌ AUTH VALIDATION FAILED: No access token found');
        throw Exception('Access token not found');
      }
      debugPrint(
          '✅ AUTH VALIDATION PASSED: Token exists (${accessToken.substring(0, 10)}...)');

      int successCount = 0;
      int totalCount = completedRows.length;
      List<String> errorMessages = []; // To collect individual error messages
      debugPrint('🚀 STARTING API CALLS FOR ${totalCount} STOCK ITEMS');

      // Submit each completed stock item
      for (int i = 0; i < completedRows.length; i++) {
        final item = completedRows[i];
        debugPrint('📦 PROCESSING STOCK ITEM ${i + 1}/${totalCount}:');
        debugPrint(
            '   - Product: ${item.product} (ID: ${item.productData?.productId})');
        debugPrint(
            '   - Category: ${item.category} (ID: ${item.categoryData?.categoryId})');
        debugPrint('   - Quantity: ${item.quantity}');
        debugPrint('   - Retail Price: ${item.salePrice}');
        debugPrint('   - Purchase Rate: ${item.purchaseRate}');
        debugPrint('   - MRP: ${item.mrp}');
        debugPrint('   - Wholesale: ${item.wholesale}');
        debugPrint('   - Unit ID: ${item.selectedUnit}');
        debugPrint('   - Unit Name: ${item.unit}');
        debugPrint('   - Rack: ${item.rack}');
        debugPrint('   - Barcode: ${item.barcode}');
        debugPrint('   - Batch Number: ${item.batchNumber}');
        debugPrint(
            '   - Expiry Date: ${DateFormat('yyyy-MM-dd').format(item.expDate)}');
        debugPrint('   - Store ID: ${selectedStore!.id}');
        debugPrint(
            '   - Supplier ID: ${selectedSupplier?.id ?? item.supplierId}');

        if (item.productData != null && item.categoryData != null) {
          try {
            debugPrint('🌐 MAKING API CALL FOR ITEM ${i + 1}...');

            // 📋 DEBUG: Print complete API request body for addProductStockAPI
            final Map<String, dynamic> apiRequestBody = {
              'accessToken':
                  '${accessToken.substring(0, 20)}...', // Only show first 20 chars for security
              'productId': item.productData!.productId.toString(),
              'categoryId': item.categoryData!.categoryId.toString(),
              'quantity': item.quantity,
              'retailPrice': item.salePrice,
              'purchaseRate': item.purchaseRate,
              'mrp': item.mrp,
              'wholesalePrice': item.wholesale,
              'unit': item.unit,
              'supplierId': selectedSupplier?.id?.toString() ??
                  item.supplierId.toString(),
              'storeId': selectedStore!.id.toString(),
              'expiryDate': DateFormat('yyyy-MM-dd').format(item.expDate),
              'userId': '1',
              'purchaseVoucherId': null,
              'purchaseId': null,
              'taxAmountRetail': null,
              'taxAmountWholesale': null,
              'wholesaleMinUnit': item.batchNumber,
              'rack': item.rack,
              'barcode': item.barcode,
              'batchNumber': item.batchNumber,
              'date': DateFormat('yyyy-MM-dd').format(selectedDate),
              'purchaseDate':
                  DateFormat('yyyy-MM-dd').format(selectedPurchaseDate),
              'purchaseNumber': null,
              'taxInclude': item.taxInclude,
              'initialRetailPrice': item.salePrice,
              'initialWholesalePrice': item.wholesale,
              'retailPriceTax': null,
              'wholesalePriceTax': null,
            };

            debugPrint('📋 ADD STOCK API REQUEST BODY FOR ITEM ${i + 1}:');
            debugPrint(
                '═══════════════════════════════════════════════════════════');
            apiRequestBody.forEach((key, value) {
              debugPrint('   $key: $value');
            });
            debugPrint(
                '═══════════════════════════════════════════════════════════');

            var apiResponse =
                await Provider.of<StockProvider>(context, listen: false)
                    .addProductStockAPI(
              accessToken: accessToken,
              productId: item.productData!.productId.toString(),
              categoryId: item.categoryData!.categoryId.toString(),
              quantity: item.quantity,
              retailPrice: item.salePrice,
              purchaseRate: item.purchaseRate,
              mrp: item.mrp,
              wholesalePrice: item.wholesale,
              unit: item.unit, // Send unit value instead of unit ID
              supplierId: selectedSupplier?.id?.toString() ??
                  item.supplierId.toString(),
              storeId: selectedStore!.id.toString(),
              expiryDate: DateFormat('yyyy-MM-dd').format(item.expDate),
              userId: '1',
              purchaseVoucherId: null,
              purchaseId: null,
              taxAmountRetail: null,
              taxAmountWholesale: null,
              wholesaleMinUnit: item.batchNumber,
              rack: item.rack,
              barcode: item.barcode,
              batchNumber: item.batchNumber,
              date: DateFormat('yyyy-MM-dd').format(selectedDate),
              purchaseDate:
                  DateFormat('yyyy-MM-dd').format(selectedPurchaseDate),
              purchaseNumber: null,
              taxInclude: item.taxInclude, // Pass the boolean directly
              initialRetailPrice: item.salePrice,
              initialWholesalePrice: item.wholesale,
              retailPriceTax: null,
              wholesalePriceTax: null,
              context: context,
            );

            // 🔍 DEBUG: Print the complete API response
            debugPrint('📡 ADD STOCK API RESPONSE FOR ITEM ${i + 1}:');
            debugPrint('   - Response: $apiResponse');
            debugPrint('   - Response type: ${apiResponse.runtimeType}');

            // Store the response in the stock item for later use
            int originalIndex = stockItems.indexOf(item);
            if (originalIndex != -1) {
              stockItems[originalIndex].apiResponse = apiResponse;
            }

            // Check if purchase_id is in the response and API call was successful
            if (apiResponse is Map<String, dynamic> &&
                apiResponse['status'] == 'success') {
              debugPrint('   - Status: ${apiResponse['status']}');
              debugPrint('   - Message: ${apiResponse['message']}');
              debugPrint('   - Data: ${apiResponse['data']}');

              if (apiResponse['data'] != null &&
                  apiResponse['data'] is Map<String, dynamic>) {
                debugPrint(
                    '   - Purchase ID: ${(apiResponse['data']['purchase_id'] as num?)?.toString()}');
                debugPrint(
                    '   - Stock ID: ${(apiResponse['data']['id'] as num?)?.toString()}');
              }
              successCount++;
              debugPrint('✅ API CALL SUCCESSFUL FOR ITEM ${i + 1}');
              if (originalIndex != -1) {
                stockItems[originalIndex].isSuccessfullyAdded = true;
                debugPrint(
                    '✅ MARKED ORIGINAL ROW ${originalIndex + 1} AS SUCCESSFULLY ADDED');
              }
            } else {
              String errorMessage = 'Failed to add stock';
              if (apiResponse is Map<String, dynamic> &&
                  apiResponse['message'] != null) {
                // The message from StockProvider is now the raw response.body (a JSON string)
                try {
                  final decodedRootMessage =
                      json.decode(apiResponse['message']);

                  if (decodedRootMessage is Map<String, dynamic> &&
                      decodedRootMessage['message'] != null) {
                    final actualMessage = decodedRootMessage['message'];

                    if (actualMessage is String) {
                      errorMessage = actualMessage; // Simple string message
                    } else if (actualMessage is Map<String, dynamic>) {
                      // Complex validation error map
                      errorMessage = actualMessage.values
                          .expand((e) => e as List)
                          .join(', ');
                    }
                  } else if (decodedRootMessage is String) {
                    // Fallback for cases where message might be a simple string at root
                    errorMessage = decodedRootMessage;
                  }
                } catch (e) {
                  // If it's not valid JSON, treat the original message as a simple string
                  errorMessage = apiResponse['message'].toString();
                }
              }
              debugPrint(
                  '❌ API CALL FAILED FOR ITEM ${i + 1} (Status: ${apiResponse['status'] ?? 'Unknown'}), Error: $errorMessage');
              errorMessages.add(errorMessage); // Add error to the list
              showScaffoldError(context: context, message: errorMessage);
              // Do not increment successCount, isSuccessfullyAdded remains false
            }
          } catch (e) {
            debugPrint('❌ API CALL FAILED FOR ITEM ${i + 1}: $e');
            errorMessages.add(e.toString()); // Add exception error to the list
            showScaffoldError(
                context: context, message: 'Error: ${e.toString()}');
          }
        } else {
          debugPrint(
              '❌ SKIPPING ITEM ${i + 1}: Missing product or category data');
        }
      }

      debugPrint('📊 API CALLS SUMMARY:');
      debugPrint('   - Total items: $totalCount');
      debugPrint('   - Successful: $successCount');
      debugPrint('   - Failed: ${totalCount - successCount}');

      if (successCount > 0) {
        debugPrint(
            '🎉 STOCK ADDITION COMPLETED: $successCount items added successfully');

        showScaffold(
            context: context,
            message:
                '$successCount out of $totalCount stock items added successfully');

        // DON'T reset form fields - keep the data for reference
        debugPrint('✅ FORM FIELDS PRESERVED - NO RESET');
        return true; // Indicate success
      } else {
        // Display aggregated error messages if no items were successful
        String finalErrorMessage = errorMessages.isNotEmpty
            ? 'Failed to add stock items:\n${errorMessages.join('\n')}'
            : 'Failed to add stock items. Please try again.';

        debugPrint(
            '❌ STOCK ADDITION FAILED: No items were added successfully. Details: $finalErrorMessage');
        showScaffoldError(context: context, message: finalErrorMessage);
        return false; // Indicate failure
      }
    } catch (e) {
      debugPrint('💥 CRITICAL ERROR IN STOCK ADDITION PROCESS: $e');
      showScaffoldError(context: context, message: 'Error: ${e.toString()}');
      return false; // Indicate failure
    } finally {
      setState(() {
        _isLoading = false;
      });
      debugPrint('🔄 LOADING STATE SET: false');
      debugPrint('🏁 STOCK ADDITION PROCESS ENDED');
    }
  }

  Future<void> _addStockForSingleItem(int index) async {
    debugPrint(
        '🔄 SINGLE STOCK ADDITION PROCESS STARTED FOR ITEM ${index + 1}');

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

    // Validate the specific item
    if (item.productData == null ||
        item.categoryData == null ||
        item.product.isEmpty ||
        item.category.isEmpty) {
      debugPrint('❌ ITEM VALIDATION FAILED: Incomplete stock item data');
      showScaffoldError(
          context: context,
          message: 'Please complete all required fields for this stock item');
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
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      if (accessToken == null) {
        throw Exception('Access token not found');
      }

      debugPrint('🌐 MAKING API CALL FOR SINGLE ITEM ${index + 1}...');

      // 📋 DEBUG: Print complete API request body for single item addProductStockAPI
      final Map<String, dynamic> singleItemApiRequestBody = {
        'accessToken':
            '${accessToken.substring(0, 20)}...', // Only show first 20 chars for security
        'productId': item.productData!.productId.toString(),
        'categoryId': item.categoryData!.categoryId.toString(),
        'quantity': item.quantity,
        'retailPrice': item.salePrice,
        'purchaseRate': item.purchaseRate,
        'mrp': item.mrp,
        'wholesalePrice': item.wholesale,
        'unit': item.unit,
        'supplierId':
            selectedSupplier?.id?.toString() ?? item.supplierId.toString(),
        'storeId': selectedStore!.id.toString(),
        'expiryDate': DateFormat('yyyy-MM-dd').format(item.expDate),
        'userId': '1',
        'purchaseVoucherId': null,
        'purchaseId': null,
        'taxAmountRetail': null,
        'taxAmountWholesale': null,
        'wholesaleMinUnit': item.batchNumber,
        'rack': item.rack,
        'barcode': item.barcode,
        'batchNumber': item.batchNumber,
        'date': DateFormat('yyyy-MM-dd').format(selectedDate),
        'purchaseDate': DateFormat('yyyy-MM-dd').format(selectedPurchaseDate),
        'purchaseNumber': null,
        'taxInclude': item.taxInclude,
        'initialRetailPrice': item.salePrice,
        'initialWholesalePrice': item.wholesale,
        'retailPriceTax': null,
        'wholesalePriceTax': null,
      };

      debugPrint(
          '📋 SINGLE ITEM ADD STOCK API REQUEST BODY FOR ITEM ${index + 1}:');
      debugPrint('═══════════════════════════════════════════════════════════');
      singleItemApiRequestBody.forEach((key, value) {
        debugPrint('   $key: $value');
      });
      debugPrint('═══════════════════════════════════════════════════════════');

      var apiResponse = await Provider.of<StockProvider>(context, listen: false)
          .addProductStockAPI(
        accessToken: accessToken,
        productId: item.productData!.productId.toString(),
        categoryId: item.categoryData!.categoryId.toString(),
        quantity: item.quantity,
        retailPrice: item.salePrice,
        purchaseRate: item.purchaseRate,
        mrp: item.mrp,
        wholesalePrice: item.wholesale,
        unit: item.unit,
        supplierId:
            selectedSupplier?.id?.toString() ?? item.supplierId.toString(),
        storeId: selectedStore!.id.toString(),
        expiryDate: DateFormat('yyyy-MM-dd').format(item.expDate),
        userId: '1',
        purchaseVoucherId: null,
        purchaseId: null,
        taxAmountRetail: null,
        taxAmountWholesale: null,
        wholesaleMinUnit: item.batchNumber,
        rack: item.rack,
        barcode: item.barcode,
        batchNumber: item.batchNumber,
        date: DateFormat('yyyy-MM-dd').format(selectedDate),
        purchaseDate: DateFormat('yyyy-MM-dd').format(selectedPurchaseDate),
        purchaseNumber: null,
        taxInclude: item.taxInclude,
        initialRetailPrice: item.salePrice,
        initialWholesalePrice: item.wholesale,
        retailPriceTax: null,
        wholesalePriceTax: null,
        context: context,
      );

      // Store the response in the stock item
      stockItems[index].apiResponse = apiResponse;

      if (apiResponse is Map<String, dynamic> &&
          apiResponse['status'] == 'success') {
        setState(() {
          stockItems[index].isSuccessfullyAdded = true;
        });
        showScaffold(
            context: context, message: 'Stock item added successfully');
        debugPrint('✅ SINGLE STOCK ITEM ADDED SUCCESSFULLY');

        // Automatically add a new empty row after successful stock addition
        debugPrint('🔄 AUTO-ADDING NEW ROW AFTER SUCCESSFUL STOCK ADDITION');
        setState(() {
          stockItems.add(StockItem());
        });
        debugPrint(
            '✅ NEW EMPTY ROW ADDED AUTOMATICALLY. Total items: ${stockItems.length}');

        // Focus on the barcode field of the next row after a short delay
        debugPrint('🔍 FOCUSING ON NEXT ROW BARCODE FIELD');
        Future.delayed(const Duration(milliseconds: 300), () {
          final nextRowIndex = stockItems.length - 1; // Index of the newly added row
          final nextBarcodeFocusNode = _getBarcodeFocusNode(nextRowIndex);
          
          // Request focus on the barcode field of the next row
          nextBarcodeFocusNode.requestFocus();
          debugPrint('✅ FOCUS REQUESTED ON ROW ${nextRowIndex + 1} BARCODE FIELD');
        });
      } else {
        String errorMessage = 'Failed to add stock';
        if (apiResponse is Map<String, dynamic> &&
            apiResponse['message'] != null) {
          try {
            final decodedRootMessage = json.decode(apiResponse['message']);
            if (decodedRootMessage is Map<String, dynamic> &&
                decodedRootMessage['message'] != null) {
              final actualMessage = decodedRootMessage['message'];
              if (actualMessage is String) {
                errorMessage = actualMessage;
              } else if (actualMessage is Map<String, dynamic>) {
                errorMessage =
                    actualMessage.values.expand((e) => e as List).join(', ');
              }
            } else if (decodedRootMessage is String) {
              errorMessage = decodedRootMessage;
            }
          } catch (e) {
            errorMessage = apiResponse['message'].toString();
          }
        }
        showScaffoldError(context: context, message: errorMessage);
        debugPrint('❌ SINGLE STOCK ITEM ADDITION FAILED: $errorMessage');
      }
    } catch (e) {
      showScaffoldError(context: context, message: 'Error: ${e.toString()}');
      debugPrint('💥 ERROR IN SINGLE STOCK ADDITION: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
      debugPrint('🏁 SINGLE STOCK ADDITION PROCESS ENDED');
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
    debugPrint('✅ SEARCH CONTROLLERS CLEARED');

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
    });

    debugPrint('✅ FORM FIELDS RESET COMPLETED');
  }

  void _toggleExpanded(int index) {
    setState(() {
      stockItems[index].isExpanded = !stockItems[index].isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

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
    return Consumer<PurchaseProvider>(
      builder: (context, purchaseProvider, child) {
        List<GetSuppliersModelData>? supplierList =
            purchaseProvider.supplierList;

        return BuildDropDownWithSearch<GetSuppliersModelData>(
          title: "Supplier",
          hintText: "Select Supplier",
          value: selectedSupplier,
          items: supplierList ?? <GetSuppliersModelData>[],
          onChanged: (value) {
            setState(() {
              selectedSupplier = value;
            });
          },
          displayText: (supplier) => supplier.user?.name ?? 'Unknown Supplier',
          searchController: supplierSearchController,
          isRequired: true,
          searchHintText: "Search for supplier...",
        );
      },
    );
  }

  Widget _buildStockTableHeader() {
    int completedItems =
        stockItems.where((item) => item.isSuccessfullyAdded).length;
    int totalItems = stockItems.length;

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

  Widget _buildStockTable() {
    return Column(
      children: List.generate(stockItems.length, (index) {
        return _buildStockRow(index);
      }),
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
                      child: Container(
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
                      initialValue: item.quantity,
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
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Actions - Add Stock Button + Expand Button
                SizedBox(
                  width: 150,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                          _buildDetailChip("Retail", "₹${item.salePrice}", Icons.sell, Colors.blue.shade600),
                        if (item.purchaseRate.isNotEmpty)
                          _buildDetailChip("Purchase", "₹${item.purchaseRate}", Icons.shopping_cart, Colors.green.shade600),
                        if (item.mrp.isNotEmpty)
                          _buildDetailChip("MRP", "₹${item.mrp}", Icons.local_offer, Colors.orange.shade600),
                        if (item.wholesale.isNotEmpty)
                          _buildDetailChip("Wholesale", "₹${item.wholesale}", Icons.store, Colors.purple.shade600),
                        if (item.unit.isNotEmpty)
                          _buildDetailChip("Unit", item.unit, Icons.straighten, Colors.indigo.shade600),
                        if (item.rack.isNotEmpty)
                          _buildDetailChip("Rack", item.rack, Icons.shelves, Colors.teal.shade600),
                        if (item.batchNumber.isNotEmpty)
                          _buildDetailChip("Min Wholesale", item.batchNumber, Icons.numbers, Colors.brown.shade600),
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
  void _autoFillFromBarcode(int index, String barcode) {
    debugPrint('🔍 BARCODE AUTO-FILL TRIGGERED');
    debugPrint('   - Row index: $index');
    debugPrint('   - Barcode: $barcode');

    if (barcode.isEmpty) {
      debugPrint('❌ BARCODE IS EMPTY - SKIPPING AUTO-FILL');
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
      _calculateTaxForStockItem(index, isRetail: true);
      _calculateTaxForStockItem(index, isRetail: false);

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
          // First row - Unit, Rack, Minimum Units for Wholesale, Purchase Rate
          Row(
            children: [
              Expanded(
                child: _buildExpandedUnitDropdown(index),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildExpandedRackDropdown(index),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildExpandedTextField(
                  "Minimum Units for Wholesale",
                  item.batchNumber, // Reusing batchNumber field for minimum units
                  (value) =>
                      setState(() => stockItems[index].batchNumber = value),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildExpandedTextField(
                  "Purchase Rate",
                  item.purchaseRate,
                  (value) =>
                      setState(() => stockItems[index].purchaseRate = value),
                  isRequired: true,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Second row - Retail Price, MRP, Wholesale Price, Expiry Date
          Row(
            children: [
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
                  },
                  keyboardType: TextInputType.number,
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
                  },
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildExpandedDatePicker(
                  "Expiry Date",
                  item.expDate,
                  (date) => setState(() => stockItems[index].expDate = date),
                ),
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
              _calculateTaxForStockItem(index, isRetail: true);
              _calculateTaxForStockItem(index, isRetail: false);

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

  Widget _buildDetailChip(String label, String value, IconData icon, Color color) {
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
    final item = stockItems[index];

    if (item.productData == null || item.categoryData == null) {
      debugPrint(
          '⚠️ Cannot calculate tax: Product or Category data missing for item $index');
      setState(() {
        item.calculatedTaxData = {
          'retailTaxAmount': 0.0,
          'wholesaleTaxAmount': 0.0,
          'tax_rate_retail': 0.0,
          'tax_rate_wholesale': 0.0,
        };
      });
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

      if (taxData != null) {
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
    } catch (e) {
      debugPrint(
          '💥 Error calculating tax for item $index (${isRetail ? 'Retail' : 'Wholesale'}): $e');
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
        CustomRoundButton(
          title: _isFinishingOrder ? "Processing..." : "Finish",
          isLoading: _isFinishingOrder,
          fct: _isFinishingOrder
              ? () {}
              : () async {
                  debugPrint('🏁 FINISH BUTTON CLICKED');

                  // Check if we have any successfully added stock items
                  List<StockItem> addedItems = stockItems
                      .where((item) => item.isSuccessfullyAdded)
                      .toList();

                  if (addedItems.isEmpty) {
                    debugPrint('❌ NO SUCCESSFULLY ADDED STOCK ITEMS FOUND');
                    showScaffoldError(
                        context: context,
                        message:
                            'No stock items have been added successfully. Please add some stock items first.');
                    return;
                  }

                  debugPrint(
                      '📦 FOUND ${addedItems.length} SUCCESSFULLY ADDED STOCK ITEMS');

                  // Look for purchase_id in the API responses
                  String? purchaseId;
                  for (int i = 0; i < addedItems.length; i++) {
                    final item = addedItems[i];
                    debugPrint('🔍 CHECKING ITEM ${i + 1} FOR PURCHASE ID:');
                    debugPrint('   - API Response: ${item.apiResponse}');

                    if (item.apiResponse != null &&
                        item.apiResponse!['data'] != null &&
                        item.apiResponse!['data']['purchase_id'] != null) {
                      purchaseId =
                          item.apiResponse!['data']['purchase_id'].toString();
                      debugPrint('✅ FOUND PURCHASE ID: $purchaseId');
                      break;
                    }
                  }

                  if (purchaseId == null) {
                    debugPrint(
                        '❌ NO PURCHASE ID FOUND IN ANY STOCK API RESPONSE');
                    showScaffoldError(
                        context: context,
                        message:
                            'Could not find purchase ID. Please try adding stock items again.');
                    return;
                  }

                  debugPrint(
                      '🚀 CALLING FINISH PURCHASE ORDER API WITH PURCHASE ID: $purchaseId');

                  setState(() {
                    _isFinishingOrder = true;
                  });

                  try {
                    final String? accessToken =
                        Provider.of<AuthModel>(context, listen: false).token;
                    if (accessToken == null) {
                      throw Exception('Access token not found');
                    }

                    final result = await Provider.of<PurchaseProvider>(context,
                            listen: false)
                        .finishPurchaseOrder(
                      accessToken: accessToken,
                      purchaseId: purchaseId,
                    );

                    debugPrint(
                        '📡 FINISH PURCHASE ORDER API RESPONSE: $result');
                    debugPrint(
                        '📡 FINISH PURCHASE ORDER API RESPONSE TYPE: ${result.runtimeType}');

                    // Enhanced debug printing for the response structure
                    if (result is Map<String, dynamic>) {
                      debugPrint(
                          '📋 FINISH PURCHASE ORDER API RESPONSE DETAILS:');
                      debugPrint(
                          '═══════════════════════════════════════════════════════════');
                      result.forEach((key, value) {
                        debugPrint('   $key: $value');
                        if (value is Map || value is List) {
                          debugPrint('   $key type: ${value.runtimeType}');
                          if (value is Map) {
                            debugPrint('   $key contents: ${value.toString()}');
                          }
                        }
                      });
                      debugPrint(
                          '═══════════════════════════════════════════════════════════');
                    } else {
                      debugPrint(
                          '📋 FINISH PURCHASE ORDER API RESPONSE (Non-Map): $result');
                    }

                    if (result is Map<String, dynamic> &&
                        result['status'] == 'success') {
                      debugPrint(
                          '✅ FINISH PURCHASE ORDER SUCCESSFUL - SHOWING SUCCESS NOTIFICATION');
                      
                      // Stop loading immediately after success
                      setState(() {
                        _isFinishingOrder = false;
                      });
                      
                      showScaffold(
                          context: context,
                          message:
                              'Purchase order completed successfully!');

                      debugPrint(
                          '🔄 RESETTING FORM FIELDS AFTER SUCCESSFUL COMPLETION');
                      // Reset form after successful completion
                      _resetFormFields();

                      debugPrint('🔄 TRIGGERING BACKGROUND SYNC TO UPDATE LOCAL DATA');
                      // Trigger sync in background without waiting
                      Future.microtask(() async {
                        try {
                          final syncProvider =
                              Provider.of<SyncProvider>(context, listen: false);
                          await syncProvider.syncAllData(context);
                          debugPrint('✅ BACKGROUND SYNC COMPLETED SUCCESSFULLY');
                        } catch (e) {
                          debugPrint(
                              '❌ BACKGROUND SYNC FAILED AFTER PURCHASE ORDER COMPLETION: $e');
                          // Silently fail background sync - user doesn't need to see this error
                        }
                      });

                      debugPrint('✅ STAYING ON CURRENT PAGE WITH CLEARED FIELDS');
                      // Stay on the same page - do not navigate away
                    } else {
                      // Stop loading on error
                      setState(() {
                        _isFinishingOrder = false;
                      });
                      
                      final message = result is Map<String, dynamic>
                          ? (result['message'] ?? 'Unknown error')
                          : 'Unknown error';
                      debugPrint(
                          '❌ FINISH PURCHASE ORDER FAILED - SHOWING ERROR NOTIFICATION: $message');
                      showScaffoldError(
                          context: context,
                          message:
                              'Failed to complete purchase order: $message');
                    }
                  } catch (e) {
                    // Stop loading on exception
                    setState(() {
                      _isFinishingOrder = false;
                    });
                    
                    debugPrint(
                        '💥 ERROR CALLING FINISH PURCHASE ORDER API: $e');
                    debugPrint(
                        '❌ SHOWING ERROR NOTIFICATION FOR API EXCEPTION');
                    showScaffoldError(
                        context: context,
                        message:
                            'Error completing purchase order: ${e.toString()}');
                  } finally {
                    // Loading state is already handled in success/error cases
                    // Ensure loading is stopped in case of unexpected scenarios
                    if (_isFinishingOrder) {
                      setState(() {
                        _isFinishingOrder = false;
                      });
                    }
                  }
                },
          height: 50,
          width: size.width * 0.15,
          fontSize: FontSize.s14,
          boxColor: ColorManager.kPrimaryColor,
          textColor: Colors.white,
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
