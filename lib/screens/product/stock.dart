import 'dart:ui';

import 'package:get/get.dart';

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/stock_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/widgets/edit_stock_dialog.dart';
import 'package:provider/provider.dart';

import '../../components/build_container_box.dart';
import '../../components/build_round_button.dart';

import '../../models/list_stock.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'widgets/adjust_stock_modal.dart';
import 'widgets/move_stock_modal.dart';
import 'widgets/withdraw_stock_modal.dart';

class AddStockScreen extends StatefulWidget {
  const AddStockScreen({super.key});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final TextEditingController stockNameController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController categorySearchController =
      TextEditingController();
  final TextEditingController barcodeController = TextEditingController();
  final TextEditingController rackController = TextEditingController();
  final TextEditingController storeController = TextEditingController();
  final TextEditingController storeSearchController = TextEditingController();
  final TextEditingController stockStatusController = TextEditingController();
  ListStockModelData? selectedStock;
  bool initLoading = false;
  bool isInitialized = false;
  List<String> categories = ["All Categories"]; // Default category option
  List<String> stores = ["All Stores"]; // Default store option

  @override
  void initState() {
    super.initState();
    loadInitData();
    categoryController.text = "All Categories"; // Initialize with default value
    storeController.text = "All Stores"; // Initialize with default value
    stockStatusController.text =
        "All Statuses"; // Initialize with default value
  }

  void loadInitData() async {
    debugPrint('🎬 LOADING STOCK SCREEN INIT DATA');
    try {
      setState(() {
        initLoading = true;
      });

      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null || accessToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Authentication token is missing")),
        );
        return;
      }

      // Load categories from CategoryProvider with caching (same as sidebar)
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      if (!categoryProvider.isCategoriesLoaded) {
        debugPrint("📥 Loading categories from API...");
        await categoryProvider.listAllCategory();
        debugPrint("✅ Categories loaded and cached");
      } else {
        debugPrint(
            "📋 Using cached categories (${categoryProvider.category?.length ?? 0} items)");
      }

      // Load all stocks for local pagination
      await Provider.of<StockProvider>(context, listen: false)
          .loadAllStocks(accessToken);

      // Load all stores for move stock modal
      await Provider.of<PurchaseProvider>(context, listen: false)
          .listAllStores(accessToken, null);

      // Extract categories from CategoryProvider and stores from stocks
      _extractCategoriesAndStores();

      setState(() {
        isInitialized = true;
        initLoading = false;
      });
    } catch (error) {
      debugPrint("Error loading stocks: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading stocks: $error")),
      );
      setState(() {
        initLoading = false;
      });
    }
  }

  void _extractCategoriesAndStores() {
    final stockProvider = Provider.of<StockProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final allStocks = stockProvider.allStocks;

    // Get categories from CategoryProvider (same as sidebar)
    final categoryList = categoryProvider.category ?? [];
    final uniqueCategories = categoryList
        .map((category) => category.categoryName ?? "")
        .where((categoryName) => categoryName.isNotEmpty)
        .toList();

    // Sort categories alphabetically
    uniqueCategories.sort();

    // Extract unique stores from stocks
    List<String> uniqueStores = [];
    if (allStocks != null && allStocks.isNotEmpty) {
      uniqueStores = allStocks
          .map((stock) => stock.storeName ?? "")
          .where((store) => store.isNotEmpty)
          .toSet()
          .toList();

      // Sort stores alphabetically
      uniqueStores.sort();
    }

    setState(() {
      categories = ["All Categories", ...uniqueCategories];
      stores = ["All Stores", ...uniqueStores];
    });

    debugPrint("📋 CATEGORIES LOADED: ${categories.length} categories found");
    debugPrint("📋 Categories: $categories");
  }

  void searchStocks() {
    StockProvider provider = Provider.of<StockProvider>(context, listen: false);
    provider.applyStockFiltersLocally(
      filterName: stockNameController.text,
      filterCategory: categoryController.text == "All Categories"
          ? null
          : categoryController.text,
      filterBarcode:
          barcodeController.text.isEmpty ? null : barcodeController.text,
      filterRack: rackController.text.isEmpty ? null : rackController.text,
      filterStore:
          storeController.text == "All Stores" ? null : storeController.text,
      filterStatus: stockStatusController.text == "All Statuses"
          ? null
          : stockStatusController.text,
      page: 1,
    );
  }

  void resetSearch() {
    setState(() {
      stockNameController.clear();
      categoryController.text = "All Categories";
      barcodeController.clear();
      rackController.clear();
      storeController.text = "All Stores";
      stockStatusController.text = "All Statuses";
    });
    Provider.of<StockProvider>(context, listen: false).resetStockFilters();
  }

  void _showStockDetails(ListStockModelData stock) {
    setState(() {
      selectedStock = stock;
    });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width / 2,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stock Details',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildDetailRow('Product Name', stock.productName ?? 'N/A'),
                    _buildDetailRow('Category', stock.categoryName ?? 'N/A'),
                    _buildDetailRow('Store Name', stock.storeName ?? 'N/A'),
                    _buildDetailRow('Supplier', stock.supplierName ?? 'N/A'),
                    _buildDetailRow('Unit', stock.unit ?? 'N/A'),
                    _buildDetailRow(
                        'Retail Price', stock.retailPrice?.toString() ?? 'N/A'),
                    _buildDetailRow('MRP', stock.mrp?.toString() ?? 'N/A'),
                    _buildDetailRow('Purchase Price',
                        stock.purchaseRate?.toString() ?? 'N/A'),
                    _buildDetailRow('Quantity', stock.qty?.toString() ?? 'N/A'),
                    _buildDetailRow('Rack', stock.rack ?? 'N/A'),
                    _buildDetailRow('Barcode', stock.barCode ?? 'N/A'),
                    _buildDetailRow('Wholesale Price',
                        stock.wholesalePrice?.toString() ?? 'N/A'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CustomRoundButton(
                    title: "Close",
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    borderColor: ColorManager.kPrimaryColor,
                    fct: () => Navigator.pop(context),
                    height: 45,
                    width: 120,
                    fontSize: FontSize.s12,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditStockModal(ListStockModelData stock) {
    if (stock.stockId == null) {
      showScaffoldError(
        context: context,
        message: 'Stock id missing. Unable to edit this row.',
      );
      return;
    }

    showEditStockDialog(
      context: context,
      stockId: stock.stockId!,
      title: 'Edit Stock: ${stock.productName ?? ''}',
      initialRetailPrice: stock.retailPrice ?? '',
      initialMrp: stock.mrp ?? '',
      initialPurchasePrice: stock.purchaseRate ?? '',
      initialQuantity: stock.qty?.toString() ?? '0',
      initialRack: stock.rack ?? '',
    );
  }

  void _showAdjustStockModal(ListStockModelData stock) {
    debugPrint(
        '🛠️ SHOW ADJUST STOCK MODAL: ID=${stock.stockId}, Name=${stock.productName}');
    showDialog(
      context: context,
      builder: (context) => AdjustStockModal(stock: stock),
    );
  }

  void _showMoveStockModal(ListStockModelData stock) {
    debugPrint(
        '🚚 SHOW MOVE STOCK MODAL: ID=${stock.stockId}, Name=${stock.productName}');
    final purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    debugPrint('   STORES AVAILABLE: ${purchaseProvider.storeList.length}');
    showDialog(
      context: context,
      builder: (context) => MoveStockModal(
        stock: stock,
        stores: purchaseProvider.storeList,
      ),
    );
  }

  void _showWithdrawStockModal(ListStockModelData stock) {
    debugPrint(
        '💸 SHOW WITHDRAW STOCK MODAL: ID=${stock.stockId}, Name=${stock.productName}');
    showDialog(
      context: context,
      builder: (context) => WithdrawStockModal(stock: stock),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label: ',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s14,
                0.20,
                ColorManager.textColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.20,
                ColorManager.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s14,
          0.18,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {Color? textColor, Color? bgColor}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor ?? Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.13,
              textColor ?? Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final SideBarController sideBarController = Get.put(SideBarController());
    final bool isSmallScreen = size.width < 600;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
            color: Colors.white),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Product Stock List",
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s20, 0.30, ColorManager.textColor),
                  ),
                  CustomRoundButton(
                    title: "Add Stock",
                    fct: () async {
                      sideBarController.index.value = 18;
                    },
                    fontSize: 12,
                    height: 45,
                    width: 150,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Column(
                children: [
                  // First row with 4 fields
                  Row(
                    children: [
                      // Stock Name field
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Text(
                            //   "Stock Name",
                            //   style: buildCustomStyle(
                            //     FontWeightManager.regular,
                            //     FontSize.s14,
                            //     0.27,
                            //     Colors.black.withOpacity(0.6),
                            //   ),
                            // ),
                            // const SizedBox(height: 8),
                            BuildBoxShadowContainer(
                              circleRadius: 7,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 15),
                              height: 45,
                              child: TextField(
                                controller: stockNameController,
                                onChanged: (value) {
                                  searchStocks();
                                },
                                decoration: InputDecoration(
                                  hintText: 'Stock Name',
                                  hintStyle: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s12,
                                    0.27,
                                    ColorManager.textColor.withOpacity(.5),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s12,
                                  0.27,
                                  ColorManager.textColor.withOpacity(.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 15),

                      // Category dropdown
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Text(
                            //   "Category",
                            //   style: buildCustomStyle(
                            //     FontWeightManager.regular,
                            //     FontSize.s14,
                            //     0.27,
                            //     Colors.black.withOpacity(0.6),
                            //   ),
                            // ),
                            // const SizedBox(height: 8),
                            BuildDropDownWithSearch<String>(
                              title: null,
                              showName: false,
                              hintText: 'Please Select',
                              value: categoryController.text == "All Categories"
                                  ? null
                                  : categoryController.text,
                              items: categories
                                  .where((category) =>
                                      category != "All Categories")
                                  .toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  categoryController.text =
                                      newValue ?? "All Categories";
                                });
                                searchStocks();
                              },
                              displayText: (category) => category,
                              searchController: categorySearchController,
                              height: 45,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 0, vertical: 0),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 15),

                      // Barcode field
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Text(
                            //   "Barcode",
                            //   style: buildCustomStyle(
                            //     FontWeightManager.regular,
                            //     FontSize.s14,
                            //     0.27,
                            //     Colors.black.withOpacity(0.6),
                            //   ),
                            // ),
                            // const SizedBox(height: 8),
                            BuildBoxShadowContainer(
                              circleRadius: 7,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 15),
                              height: 45,
                              child: TextField(
                                controller: barcodeController,
                                onChanged: (value) {
                                  searchStocks();
                                },
                                decoration: InputDecoration(
                                  hintText: 'Barcode',
                                  hintStyle: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s12,
                                    0.27,
                                    ColorManager.textColor.withOpacity(.5),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s12,
                                  0.27,
                                  ColorManager.textColor.withOpacity(.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 15),

                      // Rack Search field
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Text(
                            //   "Rack Search",
                            //   style: buildCustomStyle(
                            //     FontWeightManager.regular,
                            //     FontSize.s14,
                            //     0.27,
                            //     Colors.black.withOpacity(0.6),
                            //   ),
                            // ),
                            // const SizedBox(height: 8),
                            BuildBoxShadowContainer(
                              circleRadius: 7,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 15),
                              height: 45,
                              child: TextField(
                                controller: rackController,
                                onChanged: (value) {
                                  searchStocks();
                                },
                                decoration: InputDecoration(
                                  hintText: 'Rack Number',
                                  hintStyle: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s12,
                                    0.27,
                                    ColorManager.textColor.withOpacity(.5),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s12,
                                  0.27,
                                  ColorManager.textColor.withOpacity(.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Second row with 4 fields
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Store Filter dropdown
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Text(
                            //   "Store Filter",
                            //   style: buildCustomStyle(
                            //     FontWeightManager.regular,
                            //     FontSize.s14,
                            //     0.27,
                            //     Colors.black.withOpacity(0.6),
                            //   ),
                            // ),
                            // const SizedBox(height: 8),
                            BuildDropDownWithSearch<String>(
                              title: null,
                              showName: false,
                              hintText: 'Select Store',
                              value: storeController.text == "All Stores"
                                  ? null
                                  : storeController.text,
                              items: stores
                                  .where((store) => store != "All Stores")
                                  .toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  storeController.text =
                                      newValue ?? "All Stores";
                                });
                                searchStocks();
                              },
                              displayText: (store) => store,
                              searchController: storeSearchController,
                              height: 45,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 0, vertical: 0),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 15),

                      // Stock Status Filter dropdown
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BuildDropDownWithSearch<String>(
                              title: null,
                              showName: false,
                              hintText: 'Stock Status',
                              value:
                                  stockStatusController.text == "All Statuses"
                                      ? null
                                      : stockStatusController.text,
                              items: const [
                                "Out of Stock",
                                "Low Stock",
                                "At Reorder Level"
                              ],
                              onChanged: (String? newValue) {
                                setState(() {
                                  stockStatusController.text =
                                      newValue ?? "All Statuses";
                                });
                                searchStocks();
                              },
                              displayText: (status) => status,
                              searchController: TextEditingController(),
                              height: 45,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 0, vertical: 0),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 15),

                      // Empty space to maintain layout
                      Expanded(child: Container()),

                      const SizedBox(width: 15),

                      // Reset button
                      Expanded(
                        child: CustomRoundButton(
                          title: "Reset",
                          boxColor: Colors.white,
                          textColor: ColorManager.kPrimaryColor,
                          borderColor: ColorManager.kPrimaryColor,
                          fct: resetSearch,
                          height: 45,
                          width: double.infinity,
                          fontSize: FontSize.s12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: initLoading ||
                              Provider.of<StockProvider>(context, listen: true)
                                  .stockIsLoading
                          ? const Center(
                              child: CircularProgressIndicator.adaptive())
                          : Consumer<StockProvider>(
                              builder: (context, stockProvider, child) {
                                List<ListStockModelData>?
                                    listStockModelDataList =
                                    stockProvider.listStockModelDataList;

                                if (listStockModelDataList == null ||
                                    listStockModelDataList.isEmpty) {
                                  return const Center(
                                      child: Text("No stock data available"));
                                }

                                return BuildBoxShadowContainer(
                                  margin: const EdgeInsets.only(top: 5),
                                  circleRadius: 7,
                                  offsetValue: const Offset(2, 2),
                                  blurRadius: 8.0,
                                  color: Colors.white,
                                  child: Column(
                                    children: [
                                      // Fixed table header
                                      Container(
                                        decoration: const BoxDecoration(
                                          color: ColorManager.tableBGColor,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black12,
                                              offset: Offset(0, 2),
                                              blurRadius: 2.0,
                                            ),
                                          ],
                                        ),
                                        child: Table(
                                          columnWidths: {
                                            0: const FlexColumnWidth(
                                                1.7), // Product
                                            1: const FlexColumnWidth(
                                                1.1), // Barcode
                                            2: const FlexColumnWidth(
                                                1.0), // Retail Price
                                            3: const FlexColumnWidth(
                                                0.9), // MRP
                                            4: const FlexColumnWidth(
                                                0.9), // Purchase Price
                                            5: const FlexColumnWidth(
                                                0.7), // Quantity
                                            6: const FlexColumnWidth(
                                                0.8), // Unit
                                            7: const FlexColumnWidth(
                                                0.9), // Rack
                                            8: const FlexColumnWidth(
                                                1.2), // Order Date
                                            9: FlexColumnWidth(
                                                MediaQuery.of(context)
                                                            .size
                                                            .width <
                                                        1200
                                                    ? 2.5
                                                    : 1.8), // Action
                                          },
                                          border: null,
                                          defaultVerticalAlignment:
                                              TableCellVerticalAlignment.middle,
                                          children: [
                                            TableRow(
                                              children: [
                                                _buildTableHeader('Product'),
                                                _buildTableHeader('Barcode'),
                                                _buildTableHeader(
                                                    'Retail Price'),
                                                _buildTableHeader('MRP'),
                                                _buildTableHeader(
                                                    'Purchase Price'),
                                                _buildTableHeader('Quantity'),
                                                _buildTableHeader('Unit'),
                                                _buildTableHeader('Rack'),
                                                _buildTableHeader('Order Date'),
                                                _buildTableHeader('Action'),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Scrollable table body
                                      Expanded(
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors.grab,
                                          child: ScrollConfiguration(
                                            behavior:
                                                ScrollConfiguration.of(context)
                                                    .copyWith(
                                              dragDevices: {
                                                PointerDeviceKind.mouse,
                                                PointerDeviceKind.touch,
                                                PointerDeviceKind.stylus,
                                                PointerDeviceKind.trackpad,
                                              },
                                            ),
                                            child: SingleChildScrollView(
                                              physics:
                                                  const BouncingScrollPhysics(),
                                              scrollDirection: Axis.vertical,
                                              child: Table(
                                                columnWidths: {
                                                  0: const FlexColumnWidth(
                                                      1.7), // Product
                                                  1: const FlexColumnWidth(
                                                      1.1), // Barcode
                                                  2: const FlexColumnWidth(
                                                      1.0), // Retail Price
                                                  3: const FlexColumnWidth(
                                                      0.9), // MRP
                                                  4: const FlexColumnWidth(
                                                      0.9), // Purchase Price
                                                  5: const FlexColumnWidth(
                                                      0.7), // Quantity
                                                  6: const FlexColumnWidth(
                                                      0.8), // Unit
                                                  7: const FlexColumnWidth(
                                                      0.9), // Rack
                                                  8: const FlexColumnWidth(
                                                      1.2), // Order Date
                                                  9: FlexColumnWidth(
                                                      MediaQuery.of(context)
                                                                  .size
                                                                  .width <
                                                              1200
                                                          ? 2.5
                                                          : 1.8), // Action
                                                },
                                                border: null,
                                                defaultVerticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                children: [
                                                  // Table Rows
                                                  ...listStockModelDataList
                                                      .asMap()
                                                      .entries
                                                      .map((entry) {
                                                    final int index = entry.key;
                                                    final stock = entry.value;
                                                    return TableRow(
                                                      decoration: BoxDecoration(
                                                        color: index % 2 == 0
                                                            ? Colors.white
                                                            : Colors.grey
                                                                .withOpacity(
                                                                    0.1),
                                                      ),
                                                      children: [
                                                        _buildTableCell(
                                                            '${stock.productName}'),
                                                        _buildTableCell(() {
                                                          final barcode =
                                                              stock.barCode ??
                                                                  'N/A';
                                                          debugPrint(
                                                              '🔍 DISPLAY BARCODE: "$barcode" for product: ${stock.productName}');
                                                          return barcode;
                                                        }()), // Updated to show actual barcode
                                                        _buildTableCell(
                                                            '${stock.retailPrice}'),
                                                        _buildTableCell(
                                                            stock.mrp ?? "N/A"),
                                                        _buildTableCell(stock
                                                                .purchaseRate ??
                                                            "N/A"),
                                                        _buildTableCell(
                                                          '${stock.qty}',
                                                          textColor: (stock
                                                                          .stockStatus ==
                                                                      'Out of Stock' ||
                                                                  stock.stockStatus ==
                                                                      'Low Stock' ||
                                                                  stock.stockStatus ==
                                                                      'At Reorder Level')
                                                              ? Colors.white
                                                              : Colors.black,
                                                          bgColor: stock
                                                                      .stockStatus ==
                                                                  'Out of Stock'
                                                              ? ColorManager
                                                                  .kRed
                                                              : stock.stockStatus ==
                                                                      'Low Stock'
                                                                  ? ColorManager
                                                                      .kOrange
                                                                  : stock.stockStatus ==
                                                                          'At Reorder Level'
                                                                      ? ColorManager
                                                                          .kButtonYellow
                                                                      : Colors
                                                                          .transparent,
                                                        ),
                                                        _buildTableCell(
                                                            '${stock.unit}'),
                                                        _buildTableCell(
                                                            stock.rack ??
                                                                "N/A"),
                                                        _buildTableCell(DateHelper
                                                            .formatISODate(stock
                                                                    .orderDate ??
                                                                "")), // Order Date
                                                        Center(
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              BuildBoxShadowContainer(
                                                                  margin:
                                                                      const EdgeInsets
                                                                          .all(
                                                                          2),
                                                                  color: ColorManager
                                                                      .kPrimaryColor
                                                                      .withOpacity(
                                                                          0.9),
                                                                  circleRadius:
                                                                      5,
                                                                  child:
                                                                      IconButton(
                                                                    icon:
                                                                        const Icon(
                                                                      Icons
                                                                          .edit,
                                                                      size: 18,
                                                                      color: Colors
                                                                          .white,
                                                                    ),
                                                                    onPressed: () =>
                                                                        _showEditStockModal(
                                                                            stock),
                                                                    constraints: const BoxConstraints(
                                                                        minWidth:
                                                                            36,
                                                                        minHeight:
                                                                            36),
                                                                    padding:
                                                                        EdgeInsets
                                                                            .zero,
                                                                  )),
                                                              BuildBoxShadowContainer(
                                                                margin:
                                                                    const EdgeInsets
                                                                        .all(2),
                                                                circleRadius: 5,
                                                                child:
                                                                    IconButton(
                                                                  icon: Icon(
                                                                    Icons
                                                                        .visibility,
                                                                    size: 18,
                                                                    color: ColorManager
                                                                        .kPrimaryColor
                                                                        .withOpacity(
                                                                            0.9),
                                                                  ),
                                                                  onPressed: () =>
                                                                      _showStockDetails(
                                                                          stock),
                                                                  constraints:
                                                                      const BoxConstraints(
                                                                    minWidth:
                                                                        36,
                                                                    minHeight:
                                                                        36,
                                                                  ),
                                                                  padding:
                                                                      EdgeInsets
                                                                          .zero,
                                                                ),
                                                              ),
                                                              BuildBoxShadowContainer(
                                                                  margin:
                                                                      const EdgeInsets
                                                                          .all(
                                                                          2),
                                                                  circleRadius:
                                                                      5,
                                                                  child:
                                                                      PopupMenuButton<
                                                                          String>(
                                                                    color: Colors
                                                                        .white,
                                                                    surfaceTintColor:
                                                                        Colors
                                                                            .white,
                                                                    padding:
                                                                        EdgeInsets
                                                                            .zero,
                                                                    constraints:
                                                                        const BoxConstraints(
                                                                      minWidth:
                                                                          36,
                                                                      minHeight:
                                                                          36,
                                                                    ),
                                                                    icon:
                                                                        const Icon(
                                                                      Icons
                                                                          .more_vert,
                                                                      size: 16,
                                                                      color: ColorManager
                                                                          .kPrimaryColor,
                                                                    ),
                                                                    onSelected:
                                                                        (value) {
                                                                      if (value ==
                                                                          'adjust') {
                                                                        _showAdjustStockModal(
                                                                            stock);
                                                                      } else if (value ==
                                                                          'move') {
                                                                        _showMoveStockModal(
                                                                            stock);
                                                                      } else if (value ==
                                                                          'withdraw') {
                                                                        _showWithdrawStockModal(
                                                                            stock);
                                                                      }
                                                                    },
                                                                    itemBuilder:
                                                                        (BuildContext
                                                                                context) =>
                                                                            [
                                                                      const PopupMenuItem<
                                                                          String>(
                                                                        value:
                                                                            'adjust',
                                                                        child:
                                                                            Row(
                                                                          children: [
                                                                            Icon(Icons.sync,
                                                                                size: 18,
                                                                                color: ColorManager.kPrimaryColor),
                                                                            SizedBox(width: 8),
                                                                            Text('Adjust Stock'),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                      const PopupMenuItem<
                                                                          String>(
                                                                        value:
                                                                            'move',
                                                                        child:
                                                                            Row(
                                                                          children: [
                                                                            Icon(Icons.arrow_forward,
                                                                                size: 18,
                                                                                color: ColorManager.kPrimaryColor),
                                                                            SizedBox(width: 8),
                                                                            Text('Move Stock'),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                      const PopupMenuItem<
                                                                          String>(
                                                                        value:
                                                                            'withdraw',
                                                                        child:
                                                                            Row(
                                                                          children: [
                                                                            Icon(Icons.arrow_downward,
                                                                                size: 18,
                                                                                color: ColorManager.kPrimaryColor),
                                                                            SizedBox(width: 8),
                                                                            Text('Withdraw Stock'),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  )),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  }),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    PaginationControl(
                      currentPage:
                          Provider.of<StockProvider>(context, listen: true)
                              .stockCurrentPage,
                      totalPages:
                          Provider.of<StockProvider>(context, listen: true)
                              .stockTotalPages,
                      onPageChanged: (int page) {
                        Provider.of<StockProvider>(context, listen: false)
                            .goToStockPage(page);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    stockNameController.dispose();
    categoryController.dispose();
    categorySearchController.dispose();
    barcodeController.dispose();
    rackController.dispose();
    storeController.dispose();
    storeSearchController.dispose();
    super.dispose();
  }
}
