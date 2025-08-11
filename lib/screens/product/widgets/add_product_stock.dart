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
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
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

  // Selected header values
  GetStoreModelData? selectedStore;
  DateTime selectedDate = DateTime.now();
  DateTime selectedPurchaseDate = DateTime.now();
  GetSuppliersModelData? selectedSupplier;

  // Stock items list
  List<StockItem> stockItems = [StockItem()]; // Start with one empty row

  bool _isLoading = false;

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
        debugPrint('   - Unit: ${item.unit}');
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
              unit: item.unit,
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

  void _resetFormFields() {
    debugPrint('🔄 RESETTING FORM FIELDS STARTED');

    // Clear all search controllers
    debugPrint('🧹 CLEARING SEARCH CONTROLLERS...');
    supplierSearchController.clear();
    categorySearchControllers.values
        .forEach((controller) => controller.clear());
    productSearchControllers.values.forEach((controller) => controller.clear());
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

  void _removeStockRow(int index) {
    if (stockItems.length > 1) {
      // Dispose controllers for the removed row
      categorySearchControllers[index]?.dispose();
      productSearchControllers[index]?.dispose();
      categorySearchControllers.remove(index);
      productSearchControllers.remove(index);

      setState(() {
        stockItems.removeAt(index);
      });
    }
  }

  void _showStockDetailModal(int index) {
    // Remove this method as we're replacing it with expandable functionality
  }

  void _toggleExpanded(int index) {
    setState(() {
      stockItems[index].isExpanded = !stockItems[index].isExpanded;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      showScaffoldError(
          context: context, message: 'Please fill all required fields');
      return;
    }

    if (selectedStore == null) {
      showScaffoldError(context: context, message: 'Please select a store');
      return;
    }

    // Validate stock items
    for (int i = 0; i < stockItems.length; i++) {
      final item = stockItems[i];
      if (item.product.isEmpty || item.category.isEmpty) {
        showScaffoldError(
            context: context, message: 'Please complete stock item ${i + 1}');
        return;
      }
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

      // Submit each stock item
      for (final item in stockItems) {
        if (item.productData != null && item.categoryData != null) {
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
            wholesaleMinUnit:
                item.batchNumber, // Use batchNumber for wholesaleMinUnit
            rack: item.rack,
            barcode: item.barcode,
            batchNumber: item.batchNumber,
            date: DateFormat('yyyy-MM-dd').format(selectedDate),
            purchaseDate: DateFormat('yyyy-MM-dd').format(selectedPurchaseDate),
            purchaseNumber: null,
            taxInclude: item.taxInclude, // Pass the boolean directly
            initialRetailPrice: item.salePrice,
            initialWholesalePrice: item.wholesale,
            retailPriceTax: null,
            wholesalePriceTax: null,
            context: context,
          );
        }
      }

      showScaffold(
          context: context, message: 'All stock items added successfully');
      _clearForm();
      sideBarController.index.value = 15;
    } catch (e) {
      showScaffoldError(context: context, message: 'Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearForm() {
    supplierSearchController.clear();
    // Clear all search controllers
    categorySearchControllers.values
        .forEach((controller) => controller.clear());
    productSearchControllers.values.forEach((controller) => controller.clear());
    setState(() {
      selectedStore = null;
      selectedSupplier = null;
      selectedDate = DateTime.now();
      selectedPurchaseDate = DateTime.now();
      stockItems = [StockItem()];
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
      margin: const EdgeInsets.symmetric(horizontal: 8),
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
          items: supplierList ?? [],
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
          SizedBox(
            width: stockItems.length > 1 ? 100 : 50,
            child: _buildHeaderCell("Actions", flex: 0),
          ),
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
                // Row Number
                SizedBox(
                  width: 40,
                  child: Center(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: item.isSuccessfullyAdded
                            ? Colors.green
                            : ColorManager.kPrimaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s10,
                            0.27,
                            Colors.white,
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
                      initialValue: item.barcode,
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
                // Actions - Fixed width instead of flex
                SizedBox(
                  width: stockItems.length > 1 ? 100 : 50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                          border:
                              Border.all(color: Colors.grey.withOpacity(0.3)),
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
                            color: ColorManager.kPrimaryColor,
                          ),
                          onPressed: () => _toggleExpanded(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
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
              stockItems[index].selectedUnit = matchingUnitKey;
              debugPrint('   - Unit Key: $matchingUnitKey');
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
              setState(() {
                stockItems[index].productData = product;
                stockItems[index].product = product.productName ?? '';
                stockItems[index].barcode = product.barcode ?? '';
                stockItems[index].salePrice =
                    product.price?.price?.toString() ?? '0';
                stockItems[index].mrp = product.mrp?.toString() ??
                    product.price?.price?.toString() ??
                    '0';
                stockItems[index].purchaseRate =
                    product.stock?.firstOrNull?.purchasePrice ?? '0';
                stockItems[index].unit = product.unit ?? '';
              });
              // Trigger tax calculation for both retail and wholesale prices after product selection
              _calculateTaxForStockItem(index, isRetail: true);
              _calculateTaxForStockItem(index, isRetail: false);
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
                  stockItems[index].selectedUnit = newValue;
                  stockItems[index].unit = newValue ?? '';
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
    double retailPrice = double.tryParse(item.salePrice) ?? 0.0;
    double wholesalePrice = double.tryParse(item.wholesale) ?? 0.0;
    double retailTaxAmount = item.calculatedTaxData?['retailTaxAmount'] ?? 0.0;
    double wholesaleTaxAmount =
        item.calculatedTaxData?['wholesaleTaxAmount'] ?? 0.0;
    double retailTaxRate = item.calculatedTaxData?['tax_rate_retail'] ?? 0.0;
    double wholesaleTaxRate =
        item.calculatedTaxData?['tax_rate_wholesale'] ?? 0.0;

    return BuildBoxShadowContainer(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 0),
      circleRadius: 7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Including Tax Toggle
              Expanded(
                child: Row(
                  children: [
                    Switch(
                      value: item.taxInclude,
                      onChanged: (bool value) {
                        setState(() {
                          item.taxInclude = value;
                          _calculateTaxForStockItem(index,
                              isRetail:
                                  true); // Recalculate both prices based on toggle
                          _calculateTaxForStockItem(index, isRetail: false);
                        });
                      },
                      activeColor: ColorManager.kPrimaryColor,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Colors.grey.shade300, // Set inactive track color to a more visible light grey
                    ),
                    Text(
                      "Including Tax",
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s12,
                        0.27,
                        Colors.black.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Retail Price + Tax
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Retail Price + Tax",
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.27,
                        ColorManager.textColor,
                      ),
                    ),
                    Text(
                      item.taxInclude
                          ? '${(item.calculatedTaxData?['price_including_tax_retail'] as num?)?.toDouble().toStringAsFixed(2)} ' +
                              '(Tax: ${(item.calculatedTaxData?['tax_rate_retail'] as num?)?.toDouble().toStringAsFixed(2)})'
                          : '${(item.calculatedTaxData?['price_excluding_tax_retail'] as num?)?.toDouble().toStringAsFixed(2)} + ' +
                              '${(item.calculatedTaxData?['retailTaxAmount'] as num?)?.toDouble().toStringAsFixed(2)} ' +
                              '(Tax: ${(item.calculatedTaxData?['tax_rate_retail'] as num?)?.toDouble().toStringAsFixed(2)})',
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s12,
                        0.27,
                        Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              // Wholesale Price + Tax
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Wholesale Price + Tax",
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.27,
                        ColorManager.textColor,
                      ),
                    ),
                    Text(
                      item.taxInclude
                          ? '${(item.calculatedTaxData?['price_including_tax_wholesale'] as num?)?.toDouble().toStringAsFixed(2)} ' +
                              '(Tax: ${(item.calculatedTaxData?['tax_rate_wholesale'] as num?)?.toDouble().toStringAsFixed(2)})'
                          : '${(item.calculatedTaxData?['price_excluding_tax_wholesale'] as num?)?.toDouble().toStringAsFixed(2)} + ' +
                              '${(item.calculatedTaxData?['wholesaleTaxAmount'] as num?)?.toDouble().toStringAsFixed(2)} ' +
                              '(Tax: ${(item.calculatedTaxData?['tax_rate_wholesale'] as num?)?.toDouble().toStringAsFixed(2)})',
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s12,
                        0.27,
                        Colors.black,
                      ),
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
        CustomRoundButton(
          title: _isLoading ? "Adding..." : "Add Stock",
          fct: _isLoading ? () {} : _addNewStockRow,
          height: 50,
          width: size.width * 0.12,
          fontSize: FontSize.s14,
          boxColor: _isLoading ? Colors.grey : ColorManager.kPrimaryColor,
        ),
        const SizedBox(width: 15),
        CustomRoundButton(
          title: "Finish",
          fct: () async {
            debugPrint('🏁 FINISH BUTTON CLICKED');

            // Check if we have any successfully added stock items
            List<StockItem> addedItems =
                stockItems.where((item) => item.isSuccessfullyAdded).toList();

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
              debugPrint('❌ NO PURCHASE ID FOUND IN ANY STOCK API RESPONSE');
              showScaffoldError(
                  context: context,
                  message:
                      'Could not find purchase ID. Please try adding stock items again.');
              return;
            }

            debugPrint(
                '🚀 CALLING FINISH PURCHASE ORDER API WITH PURCHASE ID: $purchaseId');

            try {
              final String? accessToken =
                  Provider.of<AuthModel>(context, listen: false).token;
              if (accessToken == null) {
                throw Exception('Access token not found');
              }

              final result =
                  await Provider.of<PurchaseProvider>(context, listen: false)
                      .finishPurchaseOrder(
                accessToken: accessToken,
                purchaseId: purchaseId,
              );

              debugPrint('📡 FINISH PURCHASE ORDER API RESPONSE: $result');

              if (result is Map<String, dynamic> &&
                  result['status'] == 'success') {
                showScaffold(
                    context: context,
                    message: 'Purchase order completed successfully!');
                // Reset form after successful completion
                _resetFormFields();
              } else {
                final message = result is Map<String, dynamic>
                    ? (result['message'] ?? 'Unknown error')
                    : 'Unknown error';
                showScaffoldError(
                    context: context,
                    message: 'Failed to complete purchase order: $message');
              }
            } catch (e) {
              debugPrint('💥 ERROR CALLING FINISH PURCHASE ORDER API: $e');
              showScaffoldError(
                  context: context,
                  message: 'Error completing purchase order: ${e.toString()}');
            }
          },
          height: 50,
          width: size.width * 0.15,
          fontSize: FontSize.s14,
          boxColor: Colors.white,
          borderColor: ColorManager.kPrimaryColor,
          textColor: ColorManager.kPrimaryColor,
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
