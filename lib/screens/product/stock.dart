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
import 'widgets/stock_responsive.dart';
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
  bool _showFilters = false;
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
        debugPrint('📥 Ensuring sellable categories are loaded...');
        await categoryProvider.ensureCategoriesLoaded();
        debugPrint('✅ Categories ready');
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

  bool _hasActiveFilters() {
    return stockNameController.text.isNotEmpty ||
        categoryController.text != "All Categories" ||
        barcodeController.text.isNotEmpty ||
        rackController.text.isNotEmpty ||
        storeController.text != "All Stores" ||
        stockStatusController.text != "All Statuses";
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
    final bool isMobile = stockIsPhone(context);
    final double horizontalMargin = isMobile ? 8 : 10;
    final double horizontalPadding = isMobile ? 12 : 20;

    return SafeArea(
      child: Container(
        margin: EdgeInsetsDirectional.only(
          start: horizontalMargin,
          end: horizontalMargin,
          top: isMobile ? 8 : 10,
          bottom: isMobile ? 8 : 10,
        ),
        padding: EdgeInsets.all(isMobile ? 4 : 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isMobile ? 16 : 22),
          border: Border.all(color: Colors.grey.withOpacity(0.12)),
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
          padding: EdgeInsetsDirectional.symmetric(
            vertical: isMobile ? 12.0 : 5.0,
            horizontal: horizontalPadding,
          ),
          child: isMobile
              ? SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMobileHeader(sideBarController),
                      const SizedBox(height: 10),
                      _buildMobileFiltersSection(size),
                      const SizedBox(height: 10),
                      initLoading ||
                              Provider.of<StockProvider>(context, listen: true)
                                  .stockIsLoading
                          ? _buildLoadingState()
                          : Consumer<StockProvider>(
                              builder: (context, stockProvider, child) {
                                final listStockModelDataList =
                                    stockProvider.listStockModelDataList;

                                if (listStockModelDataList == null ||
                                    listStockModelDataList.isEmpty) {
                                  return _buildEmptyState();
                                }

                                return _buildMobileStockList(
                                    listStockModelDataList);
                              },
                            ),
                      const SizedBox(height: 10),
                      StockPaginationBar(
                        currentPage: Provider.of<StockProvider>(context,
                                listen: true)
                            .stockCurrentPage,
                        totalPages: Provider.of<StockProvider>(context,
                                listen: true)
                            .stockTotalPages,
                        onPageChanged: (int page) {
                          Provider.of<StockProvider>(context, listen: false)
                              .goToStockPage(page);
                        },
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDesktopHeader(sideBarController),
                    const SizedBox(height: 10),
                    _buildDesktopFilters(size),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: initLoading ||
                                    Provider.of<StockProvider>(context,
                                            listen: true)
                                        .stockIsLoading
                                ? _buildLoadingState()
                                : Consumer<StockProvider>(
                                    builder: (context, stockProvider, child) {
                                      final listStockModelDataList =
                                          stockProvider
                                              .listStockModelDataList;

                                      if (listStockModelDataList == null ||
                                          listStockModelDataList.isEmpty) {
                                        return _buildEmptyState();
                                      }

                                      return _buildDesktopStockTable(
                                          listStockModelDataList);
                                    },
                                  ),
                          ),
                          const SizedBox(height: 10),
                          PaginationControl(
                            currentPage: Provider.of<StockProvider>(context,
                                    listen: true)
                                .stockCurrentPage,
                            totalPages: Provider.of<StockProvider>(context,
                                    listen: true)
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

  Widget _buildDesktopHeader(SideBarController sideBarController) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Product Stock List",
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20, 0.30,
              ColorManager.textColor),
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
    );
  }

  Widget _buildMobileHeader(SideBarController sideBarController) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "Product Stock List",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s20,
                  0.30,
                  ColorManager.textColor,
                ),
              ),
            ),
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(
                      _showFilters
                          ? Icons.filter_alt
                          : Icons.filter_alt_outlined,
                      color: ColorManager.kPrimaryColor,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    onPressed: () {
                      setState(() => _showFilters = !_showFilters);
                    },
                    tooltip: _showFilters ? 'Hide Filters' : 'Show Filters',
                  ),
                  if (_hasActiveFilters())
                    PositionedDirectional(
                      end: 6,
                      top: 6,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CustomRoundButton(
          title: "Add Stock",
          fct: () async {
            sideBarController.index.value = 18;
          },
          fontSize: 12,
          height: 45,
          width: double.infinity,
        ),
      ],
    );
  }

  Widget _buildMobileFiltersSection(Size size) {
    if (!_showFilters) {
      return const SizedBox.shrink();
    }

    return StockContentCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Filters',
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s14,
                    0.25,
                    ColorManager.textColor,
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  icon: const Icon(Icons.expand_less),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  onPressed: () => setState(() => _showFilters = false),
                  tooltip: 'Hide Filters',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStockNameField(),
          const SizedBox(height: 10),
          _buildCategoryDropdown(),
          const SizedBox(height: 10),
          _buildBarcodeField(),
          const SizedBox(height: 10),
          _buildRackField(),
          const SizedBox(height: 10),
          _buildStoreDropdown(),
          const SizedBox(height: 10),
          _buildStockStatusDropdown(),
          const SizedBox(height: 12),
          CustomRoundButton(
            title: "Reset",
            boxColor: Colors.white,
            textColor: ColorManager.kPrimaryColor,
            borderColor: ColorManager.kPrimaryColor,
            fct: resetSearch,
            height: 44,
            width: double.infinity,
            fontSize: FontSize.s12,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFilters(Size size) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStockNameField()),
            const SizedBox(width: 15),
            Expanded(child: _buildCategoryDropdown()),
            const SizedBox(width: 15),
            Expanded(child: _buildBarcodeField()),
            const SizedBox(width: 15),
            Expanded(child: _buildRackField()),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _buildStoreDropdown()),
            const SizedBox(width: 15),
            Expanded(child: _buildStockStatusDropdown()),
            const SizedBox(width: 15),
            const Expanded(child: SizedBox()),
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
    );
  }

  Widget _buildStockNameField() {
    return BuildBoxShadowContainer(
      circleRadius: 7,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsetsDirectional.only(start: 15),
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
    );
  }

  Widget _buildCategoryDropdown() {
    return BuildDropDownWithSearch<String>(
      title: null,
      showName: false,
      hintText: 'Please Select',
      value: categoryController.text == "All Categories"
          ? null
          : categoryController.text,
      items: categories
          .where((category) => category != "All Categories")
          .toList(),
      onChanged: (String? newValue) {
        setState(() {
          categoryController.text = newValue ?? "All Categories";
        });
        searchStocks();
      },
      displayText: (category) => category,
      searchController: categorySearchController,
      height: 45,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
    );
  }

  Widget _buildBarcodeField() {
    return BuildBoxShadowContainer(
      circleRadius: 7,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsetsDirectional.only(start: 15),
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
    );
  }

  Widget _buildRackField() {
    return BuildBoxShadowContainer(
      circleRadius: 7,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsetsDirectional.only(start: 15),
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
    );
  }

  Widget _buildStoreDropdown() {
    return BuildDropDownWithSearch<String>(
      title: null,
      showName: false,
      hintText: 'Select Store',
      value: storeController.text == "All Stores" ? null : storeController.text,
      items: stores.where((store) => store != "All Stores").toList(),
      onChanged: (String? newValue) {
        setState(() {
          storeController.text = newValue ?? "All Stores";
        });
        searchStocks();
      },
      displayText: (store) => store,
      searchController: storeSearchController,
      height: 45,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
    );
  }

  Widget _buildStockStatusDropdown() {
    return BuildDropDownWithSearch<String>(
      title: null,
      showName: false,
      hintText: 'Stock Status',
      value: stockStatusController.text == "All Statuses"
          ? null
          : stockStatusController.text,
      items: const [
        "Out of Stock",
        "Low Stock",
        "At Reorder Level"
      ],
      onChanged: (String? newValue) {
        setState(() {
          stockStatusController.text = newValue ?? "All Statuses";
        });
        searchStocks();
      },
      displayText: (status) => status,
      searchController: TextEditingController(),
      height: 45,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator.adaptive(),
          SizedBox(height: 14),
          Text(
            'Loading stock...',
            style: TextStyle(
              color: ColorManager.kGreyColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters = _hasActiveFilters();
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 88,
              width: 88,
              decoration: BoxDecoration(
                color: ColorManager.kPrimaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 40,
                color: ColorManager.kPrimaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters
                  ? 'No stock matches your filters'
                  : 'No stock data available',
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s16,
                0.18,
                ColorManager.textColor,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 8),
              Text(
                'Try adjusting or clearing your filters.',
                textAlign: TextAlign.center,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.15,
                  Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              CustomRoundButton(
                title: 'Reset filters',
                boxColor: Colors.white,
                textColor: ColorManager.kPrimaryColor,
                borderColor: ColorManager.kPrimaryColor,
                fct: resetSearch,
                height: 44,
                width: 160,
                fontSize: FontSize.s12,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileStockList(List<ListStockModelData> stocks) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
      itemCount: stocks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _buildMobileStockCard(stocks[index]);
      },
    );
  }

  List<Widget> _buildMobileStockActionButtons(ListStockModelData stock) {
    return [
      Tooltip(
        message: 'Edit stock',
        child: SizedBox(
          width: 30,
          height: 30,
          child: BuildBoxShadowContainer(
            color: ColorManager.kPrimaryColor.withOpacity(0.9),
            circleRadius: 6,
            child: IconButton(
              icon: const Icon(Icons.edit, size: 14, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _showEditStockModal(stock),
            ),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Tooltip(
        message: 'View details',
        child: SizedBox(
          width: 30,
          height: 30,
          child: BuildBoxShadowContainer(
            color: Colors.white,
            circleRadius: 6,
            child: IconButton(
              icon: Icon(Icons.visibility,
                  size: 14,
                  color: ColorManager.kPrimaryColor.withOpacity(0.9)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _showStockDetails(stock),
            ),
          ),
        ),
      ),
      const SizedBox(width: 6),
      SizedBox(
        width: 30,
        height: 30,
        child: BuildBoxShadowContainer(
          circleRadius: 6,
          child: PopupMenuButton<String>(
            color: Colors.white,
            surfaceTintColor: Colors.white,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.more_vert,
              size: 14,
              color: ColorManager.kPrimaryColor,
            ),
            onSelected: (value) {
              if (value == 'adjust') {
                _showAdjustStockModal(stock);
              } else if (value == 'move') {
                _showMoveStockModal(stock);
              } else if (value == 'withdraw') {
                _showWithdrawStockModal(stock);
              }
            },
            itemBuilder: (BuildContext context) => const [
              PopupMenuItem<String>(
                value: 'adjust',
                child: Row(
                  children: [
                    Icon(Icons.sync,
                        size: 18, color: ColorManager.kPrimaryColor),
                    SizedBox(width: 8),
                    Text('Adjust Stock'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'move',
                child: Row(
                  children: [
                    Icon(Icons.arrow_forward,
                        size: 18, color: ColorManager.kPrimaryColor),
                    SizedBox(width: 8),
                    Text('Move Stock'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'withdraw',
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward,
                        size: 18, color: ColorManager.kPrimaryColor),
                    SizedBox(width: 8),
                    Text('Withdraw Stock'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildCompactFieldBox({
    required String label,
    required String value,
    Color? valueColor,
    Color? valueBgColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s10,
              0.15,
              Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          valueBgColor != null
              ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: valueBgColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    value,
                    style: buildCustomStyle(
                      FontWeightManager.bold,
                      FontSize.s12,
                      0.18,
                      valueColor ?? Colors.white,
                    ),
                  ),
                )
              : Text(
                  value,
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s12,
                    0.18,
                    valueColor ?? ColorManager.textColor,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildMobileStockCard(ListStockModelData stock) {
    final barcode = stock.barCode ?? 'N/A';
    final qtyColors = _quantityColors(stock);
    final orderDate =
        DateHelper.formatISODate(stock.orderDate ?? '');

    return StockContentCard(
      padding: const EdgeInsetsDirectional.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock.productName ?? 'Unnamed',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s14,
                        0.20,
                        ColorManager.kPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stock.categoryName ?? ''}${(stock.categoryName ?? '').isNotEmpty && (stock.storeName ?? '').isNotEmpty ? ' · ' : ''}${stock.storeName ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s11,
                        0.15,
                        Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: _buildMobileStockActionButtons(stock),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildCompactFieldBox(
                  label: 'Retail',
                  value: '${stock.retailPrice ?? 'N/A'}',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildCompactFieldBox(
                  label: 'Qty',
                  value: '${stock.qty}',
                  valueColor: qtyColors.$1,
                  valueBgColor: qtyColors.$2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildCompactFieldBox(
                  label: 'Barcode',
                  value: barcode,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildCompactFieldBox(
                  label: 'Order Date',
                  value: orderDate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (Color?, Color?) _quantityColors(ListStockModelData stock) {
    if (stock.stockStatus == 'Out of Stock') {
      return (Colors.white, ColorManager.kRed);
    }
    if (stock.stockStatus == 'Low Stock') {
      return (Colors.white, ColorManager.kOrange);
    }
    if (stock.stockStatus == 'At Reorder Level') {
      return (Colors.white, ColorManager.kButtonYellow);
    }
    return (null, null);
  }



  List<Widget> _buildDesktopStockActionButtons(ListStockModelData stock) {
    return [
      BuildBoxShadowContainer(
        margin: const EdgeInsets.all(2),
        color: ColorManager.kPrimaryColor.withOpacity(0.9),
        circleRadius: 5,
        child: IconButton(
          icon: const Icon(
            Icons.edit,
            size: 18,
            color: Colors.white,
          ),
          onPressed: () => _showEditStockModal(stock),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: EdgeInsets.zero,
        ),
      ),
      BuildBoxShadowContainer(
        margin: const EdgeInsets.all(2),
        circleRadius: 5,
        child: IconButton(
          icon: Icon(
            Icons.visibility,
            size: 18,
            color: ColorManager.kPrimaryColor.withOpacity(0.9),
          ),
          onPressed: () => _showStockDetails(stock),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: EdgeInsets.zero,
        ),
      ),
      BuildBoxShadowContainer(
        margin: const EdgeInsets.all(2),
        circleRadius: 5,
        child: PopupMenuButton<String>(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: const Icon(
            Icons.more_vert,
            size: 16,
            color: ColorManager.kPrimaryColor,
          ),
          onSelected: (value) {
            if (value == 'adjust') {
              _showAdjustStockModal(stock);
            } else if (value == 'move') {
              _showMoveStockModal(stock);
            } else if (value == 'withdraw') {
              _showWithdrawStockModal(stock);
            }
          },
          itemBuilder: (BuildContext context) => const [
            PopupMenuItem<String>(
              value: 'adjust',
              child: Row(
                children: [
                  Icon(Icons.sync,
                      size: 18, color: ColorManager.kPrimaryColor),
                  SizedBox(width: 8),
                  Text('Adjust Stock'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'move',
              child: Row(
                children: [
                  Icon(Icons.arrow_forward,
                      size: 18, color: ColorManager.kPrimaryColor),
                  SizedBox(width: 8),
                  Text('Move Stock'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'withdraw',
              child: Row(
                children: [
                  Icon(Icons.arrow_downward,
                      size: 18, color: ColorManager.kPrimaryColor),
                  SizedBox(width: 8),
                  Text('Withdraw Stock'),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildDesktopStockTable(List<ListStockModelData> listStockModelDataList) {
    return BuildBoxShadowContainer(
      margin: const EdgeInsets.only(top: 5),
      circleRadius: 7,
      offsetValue: const Offset(2, 2),
      blurRadius: 8.0,
      color: Colors.white,
      child: Column(
        children: [
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
                0: const FlexColumnWidth(1.7),
                1: const FlexColumnWidth(1.1),
                2: const FlexColumnWidth(1.0),
                3: const FlexColumnWidth(0.9),
                4: const FlexColumnWidth(0.9),
                5: const FlexColumnWidth(0.7),
                6: const FlexColumnWidth(0.8),
                7: const FlexColumnWidth(0.9),
                8: const FlexColumnWidth(1.2),
                9: FlexColumnWidth(
                  MediaQuery.of(context).size.width < 1200 ? 2.5 : 1.8,
                ),
              },
              border: null,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    _buildTableHeader('Product'),
                    _buildTableHeader('Barcode'),
                    _buildTableHeader('Retail Price'),
                    _buildTableHeader('MRP'),
                    _buildTableHeader('Purchase Price'),
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
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.touch,
                    PointerDeviceKind.stylus,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.vertical,
                  child: Table(
                    columnWidths: {
                      0: const FlexColumnWidth(1.7),
                      1: const FlexColumnWidth(1.1),
                      2: const FlexColumnWidth(1.0),
                      3: const FlexColumnWidth(0.9),
                      4: const FlexColumnWidth(0.9),
                      5: const FlexColumnWidth(0.7),
                      6: const FlexColumnWidth(0.8),
                      7: const FlexColumnWidth(0.9),
                      8: const FlexColumnWidth(1.2),
                      9: FlexColumnWidth(
                        MediaQuery.of(context).size.width < 1200 ? 2.5 : 1.8,
                      ),
                    },
                    border: null,
                    defaultVerticalAlignment:
                        TableCellVerticalAlignment.middle,
                    children: [
                      ...listStockModelDataList.asMap().entries.map((entry) {
                        final int index = entry.key;
                        final stock = entry.value;
                        final barcode = stock.barCode ?? 'N/A';
                        debugPrint(
                            '🔍 DISPLAY BARCODE: "$barcode" for product: ${stock.productName}');
                        final qtyColors = _quantityColors(stock);
                        return TableRow(
                          decoration: BoxDecoration(
                            color: index % 2 == 0
                                ? Colors.white
                                : Colors.grey.withOpacity(0.1),
                          ),
                          children: [
                            _buildTableCell('${stock.productName}'),
                            _buildTableCell(barcode),
                            _buildTableCell('${stock.retailPrice}'),
                            _buildTableCell(stock.mrp ?? "N/A"),
                            _buildTableCell(stock.purchaseRate ?? "N/A"),
                            _buildTableCell(
                              '${stock.qty}',
                              textColor: qtyColors.$1 ?? Colors.black,
                              bgColor: qtyColors.$2,
                            ),
                            _buildTableCell('${stock.unit}'),
                            _buildTableCell(stock.rack ?? "N/A"),
                            _buildTableCell(
                              DateHelper.formatISODate(
                                  stock.orderDate ?? ""),
                            ),
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: _buildDesktopStockActionButtons(stock),
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
