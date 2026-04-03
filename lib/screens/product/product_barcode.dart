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
import 'package:pos_machine/screens/print/thermal/barcode_printer_service.dart';
import 'widgets/confirm_barcode_print_modal.dart';

class ProductBarcodeScreen extends StatefulWidget {
  const ProductBarcodeScreen({super.key});

  @override
  State<ProductBarcodeScreen> createState() => _ProductBarcodeScreenState();
}

class _ProductBarcodeScreenState extends State<ProductBarcodeScreen> {
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
  List<String> categories = ["All Categories"];
  List<String> stores = ["All Stores"];

  // ── NEW: multi-select state ──
  final Set<int> _selectedIndexes = {};
  bool get _allSelected =>
      _selectedIndexes.length ==
      (Provider.of<StockProvider>(context, listen: false)
              .listStockModelDataList
              ?.length ??
          0);

  @override
  void initState() {
    super.initState();
    loadInitData();
    categoryController.text = "All Categories";
    storeController.text = "All Stores";
    stockStatusController.text = "All Statuses";
  }

  // ── ALL ORIGINAL LOGIC BELOW — UNTOUCHED ──

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

      await Provider.of<StockProvider>(context, listen: false)
          .loadAllStocks(accessToken);

      await Provider.of<PurchaseProvider>(context, listen: false)
          .listAllStores(accessToken, null);

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

    final categoryList = categoryProvider.category ?? [];
    final uniqueCategories = categoryList
        .map((category) => category.categoryName ?? "")
        .where((categoryName) => categoryName.isNotEmpty)
        .toList();
    uniqueCategories.sort();

    List<String> uniqueStores = [];
    if (allStocks != null && allStocks.isNotEmpty) {
      uniqueStores = allStocks
          .map((stock) => stock.storeName ?? "")
          .where((store) => store.isNotEmpty)
          .toSet()
          .toList();
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
      _selectedIndexes.clear(); // clear selection on reset
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

  void _handlePrintSelected(List<ListStockModelData> selectedStocks) async {
    debugPrint('🖨️ PRINT triggered for ${selectedStocks.length} items');

    final validStocks = selectedStocks
        .where((stock) =>
            stock.barCode != null && stock.barCode!.trim().isNotEmpty)
        .toList();

    if (validStocks.length < selectedStocks.length) {
      final bool shouldContinue = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Missing Barcode'),
              content: Text(validStocks.isEmpty
                  ? 'These products don\'t have a barcode. Please add a barcode first.'
                  : 'Some products don\'t have a barcode. Do you want to skip them and continue?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context,
                      false), // Returning false to indicate cancel/close
                  child: Text(validStocks.isEmpty ? 'Close' : 'Cancel'),
                ),
                if (validStocks.isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.pop(
                        context, true), // Returning true to indicate continue
                    child: const Text('Continue'),
                  ),
              ],
            ),
          ) ??
          false;

      if (!shouldContinue || validStocks.isEmpty) {
        return;
      }
    }

    final Map<String, dynamic>? result = await showDialog(
      context: context,
      builder: (context) =>
          ConfirmBarcodePrintModal(selectedStocks: validStocks),
    );

    if (result != null &&
        result['items'] != null &&
        (result['items'] as List).isNotEmpty) {
      final barcodePrinterService = BarcodePrinterService();
      barcodePrinterService.printBarcodes(
        context: context,
        printItems: result['items'],
        stickerSize: result['size'] ?? '50x25',
      );
    }
  }

  void _handlePrintSingle(ListStockModelData stock) async {
    debugPrint('🖨️ PRINT single: ${stock.productName}');

    if (stock.barCode == null || stock.barCode!.trim().isEmpty) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Missing Barcode'),
          content: const Text(
              'This product don\'t have a barcode. Please add a barcode first.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      return;
    }

    final Map<String, dynamic>? result = await showDialog(
      context: context,
      builder: (context) => ConfirmBarcodePrintModal(selectedStocks: [stock]),
    );

    if (result != null &&
        result['items'] != null &&
        (result['items'] as List).isNotEmpty) {
      final barcodePrinterService = BarcodePrinterService();
      barcodePrinterService.printBarcodes(
        context: context,
        printItems: result['items'],
        stickerSize: result['size'] ?? '50x25',
      );
    }
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
                    "Print Barcodes",
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s20, 0.30, ColorManager.textColor),
                  ),
                  Row(
                    children: [
                      // ── NEW: Print Selected button, shown when items are selected ──
                      if (_selectedIndexes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: CustomRoundButton(
                            title:
                                "Print Selected (${_selectedIndexes.length})",
                            fct: () {
                              final stocks = Provider.of<StockProvider>(context,
                                      listen: false)
                                  .listStockModelDataList;
                              if (stocks != null) {
                                final selected = _selectedIndexes
                                    .map((i) => stocks[i])
                                    .toList();
                                _handlePrintSelected(selected);
                              }
                            },
                            fontSize: 12,
                            height: 45,
                            width: 180,
                          ),
                        ),
                      // CustomRoundButton(
                      //   title: "Print Barcode",
                      //   fct: () async {
                      //     sideBarController.index.value = 18;
                      //   },
                      //   fontSize: 12,
                      //   height: 45,
                      //   width: 150,
                      // ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // ── FILTERS — ORIGINAL, UNTOUCHED ──
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BuildDropDownWithSearch<String>(
                              title: null,
                              showName: false,
                              hintText: 'Select Category',
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: Container()),
                      const SizedBox(width: 15),
                      Expanded(child: Container()),
                      const SizedBox(width: 15),
                      Expanded(child: Container()),
                      const SizedBox(width: 15),
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

                                // column widths — shared between header and body
                                const Map<int, TableColumnWidth> colWidths = {
                                  0: FixedColumnWidth(48), // Checkbox
                                  1: FlexColumnWidth(2.0), // Product Name
                                  2: FlexColumnWidth(1.3), // Barcode
                                  3: FlexColumnWidth(1.3), // Category
                                  4: FlexColumnWidth(0.7), // Qty
                                  5: FlexColumnWidth(1.0), // Price
                                  6: FlexColumnWidth(1.0), // MRP
                                  7: FlexColumnWidth(1.1), // SKU
                                  8: FlexColumnWidth(0.8), // Action
                                };

                                final allSelected = _selectedIndexes.length ==
                                    listStockModelDataList.length;

                                return BuildBoxShadowContainer(
                                  margin: const EdgeInsets.only(top: 5),
                                  circleRadius: 7,
                                  offsetValue: const Offset(2, 2),
                                  blurRadius: 8.0,
                                  color: Colors.white,
                                  child: Column(
                                    children: [
                                      // ── CHANGED: new table header ──
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
                                          columnWidths: colWidths,
                                          border: null,
                                          defaultVerticalAlignment:
                                              TableCellVerticalAlignment.middle,
                                          children: [
                                            TableRow(
                                              children: [
                                                // Select-all checkbox
                                                Center(
                                                  child: Checkbox(
                                                    value: allSelected,
                                                    onChanged: (val) {
                                                      setState(() {
                                                        if (val == true) {
                                                          _selectedIndexes
                                                              .addAll(
                                                            List.generate(
                                                                listStockModelDataList
                                                                    .length,
                                                                (i) => i),
                                                          );
                                                        } else {
                                                          _selectedIndexes
                                                              .clear();
                                                        }
                                                      });
                                                    },
                                                    activeColor: ColorManager
                                                        .kPrimaryColor,
                                                  ),
                                                ),
                                                _buildTableHeader(
                                                    'Product Name'),
                                                _buildTableHeader('Barcode'),
                                                _buildTableHeader('Category'),
                                                _buildTableHeader('Qty'),
                                                _buildTableHeader('Price'),
                                                _buildTableHeader('MRP'),
                                                _buildTableHeader('SKU'),
                                                _buildTableHeader('Action'),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // ── CHANGED: new table body ──
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
                                                columnWidths: colWidths,
                                                border: null,
                                                defaultVerticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                children: [
                                                  ...listStockModelDataList
                                                      .asMap()
                                                      .entries
                                                      .map((entry) {
                                                    final int index = entry.key;
                                                    final stock = entry.value;
                                                    final isSelected =
                                                        _selectedIndexes
                                                            .contains(index);

                                                    return TableRow(
                                                      decoration: BoxDecoration(
                                                        color: isSelected
                                                            ? ColorManager
                                                                .kPrimaryColor
                                                                .withOpacity(
                                                                    0.07)
                                                            : index % 2 == 0
                                                                ? Colors.white
                                                                : Colors.grey
                                                                    .withOpacity(
                                                                        0.1),
                                                      ),
                                                      children: [
                                                        // Row checkbox
                                                        Center(
                                                          child: Checkbox(
                                                            value: isSelected,
                                                            onChanged: (val) {
                                                              setState(() {
                                                                if (val ==
                                                                    true) {
                                                                  _selectedIndexes
                                                                      .add(
                                                                          index);
                                                                } else {
                                                                  _selectedIndexes
                                                                      .remove(
                                                                          index);
                                                                }
                                                              });
                                                            },
                                                            activeColor:
                                                                ColorManager
                                                                    .kPrimaryColor,
                                                          ),
                                                        ),
                                                        _buildTableCell(
                                                            stock.productName ??
                                                                ''),
                                                        _buildTableCell(
                                                            stock.barCode ??
                                                                'N/A'),
                                                        _buildTableCell(stock
                                                                .categoryName ??
                                                            'N/A'),
                                                        _buildTableCell(stock
                                                                .qty
                                                                ?.toString() ??
                                                            'N/A'),
                                                        _buildTableCell(
                                                            stock.retailPrice ??
                                                                'N/A'),
                                                        _buildTableCell(
                                                            stock.mrp ?? 'N/A'),
                                                        _buildTableCell(
                                                            stock.mrp ?? 'N/A'),
                                                        // ── Print icon ──
                                                        Center(
                                                          child: IconButton(
                                                            icon: const Icon(
                                                                Icons.print,
                                                                size: 18,
                                                                color: Colors
                                                                    .blue),
                                                            onPressed: () =>
                                                                _handlePrintSingle(
                                                                    stock),
                                                            padding:
                                                                EdgeInsets.zero,
                                                            constraints:
                                                                const BoxConstraints(),
                                                            tooltip:
                                                                "Print Barcode",
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
                    // ── ORIGINAL pagination — untouched ──
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
