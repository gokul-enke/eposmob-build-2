import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/report_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/models/executive.dart'; // For Store model
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/get_stock_report_model.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_border.dart';

class StockReportScreen extends StatefulWidget {
  const StockReportScreen({super.key});

  @override
  State<StockReportScreen> createState() => _StockReportScreenState();
}

class _StockReportScreenState extends State<StockReportScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  bool initLoading = false;
  bool _showFilters = true;

  bool _isMobile(BuildContext ctx) => MediaQuery.of(ctx).size.width < 768;

  // Filter variables
  int? selectedStoreId;
  String? selectedStoreName;
  int? selectedCategoryId;
  String? selectedCategoryName;
  String? selectedProductName;
  String? selectedStockLevel = 'All';
  String? selectedExpiryFilter = 'All';
  DateTime? selectedFromDate;
  DateTime? selectedUntilDate;
  DateTime? selectedSnapshotDate;
  int _datePickerResetKey = 0;
  final ScrollController _tableScrollController = ScrollController();

  // Pagination
  int _currentPage = 1;

  int get _pageSize =>
      Provider.of<ReportsProvider>(context, listen: false)
          .stockReport
          ?.pagination
          ?.perPage ??
      20;

  @override
  void initState() {
    super.initState();
    loadInitData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showFilters = !_isMobile(context));
    });
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    super.dispose();
  }

  Future<void> loadInitData({int? page}) async {
    if (!mounted) return;
    setState(() {
      initLoading = true;
    });

    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      ReportsProvider reportsProvider =
          Provider.of<ReportsProvider>(context, listen: false);

      String? stockLevelParam;
      if (selectedStockLevel == 'Below Reorder') {
        stockLevelParam = 'below_reorder';
      }

      String? expiringParam;
      if (selectedExpiryFilter == '1 Month') {
        expiringParam = 'one_month';
      } else if (selectedExpiryFilter == '3 Months') {
        expiringParam = 'three_months';
      } else if (selectedExpiryFilter == '6 Months') {
        expiringParam = 'six_months';
      } else if (selectedExpiryFilter == '1 Year') {
        expiringParam = 'one_year';
      }

      final df = DateFormat('yyyy-MM-dd');

      await reportsProvider.fetchStockReport(
        accessToken: accessToken ?? "",
        product: selectedProductName,
        storeId: selectedStoreId,
        categoryId: selectedCategoryId,
        stockLevel: stockLevelParam,
        expiringWithin: expiringParam,
        snapshotDate:
            selectedSnapshotDate != null ? df.format(selectedSnapshotDate!) : null,
        from: selectedFromDate != null ? df.format(selectedFromDate!) : null,
        until: selectedUntilDate != null ? df.format(selectedUntilDate!) : null,
        page: page ?? _currentPage,
      );

      if (page != null) {
        _currentPage = page;
      } else if (reportsProvider.stockReport?.pagination?.currentPage != null) {
        _currentPage = reportsProvider.stockReport!.pagination!.currentPage!;
      }
    } catch (error) {
      debugPrint('Error loading stock report: $error');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Stock report is currently unavailable.'),
              backgroundColor: Colors.red,
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() {
          initLoading = false;
        });
      }
    }
  }

  void _resetFilters() {
    setState(() {
      selectedStoreId = null;
      selectedStoreName = null;
      selectedCategoryId = null;
      selectedCategoryName = null;
      selectedProductName = null;
      selectedStockLevel = 'All';
      selectedExpiryFilter = 'All';
      selectedFromDate = null;
      selectedUntilDate = null;
      selectedSnapshotDate = null;
      _currentPage = 1;
      _datePickerResetKey++;
    });
    loadInitData();
  }

  @override
  Widget build(BuildContext context) {
    ReportsProvider reportsProvider = Provider.of<ReportsProvider>(context);

    final mainContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 15),
        if (_showFilters) _buildFilters(),
        if (_showFilters) const SizedBox(height: 15),
        _buildSummaryBlock(reportsProvider),
        const SizedBox(height: 15),
        _buildReportTable(reportsProvider),
        const SizedBox(height: 10),
        _buildPagination(reportsProvider),
      ],
    );

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => await loadInitData(),
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: _isMobile(context) ? 5 : 10,
            vertical: _isMobile(context) ? 10 : 20,
          ),
          padding: EdgeInsets.all(_isMobile(context) ? 4 : 8),
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
            padding: EdgeInsets.symmetric(
              vertical: _isMobile(context) ? 12.0 : 20.0,
              horizontal: _isMobile(context) ? 12.0 : 20.0,
            ),
            child: _isMobile(context)
                ? SingleChildScrollView(
                    child: mainContent,
                  )
                : mainContent,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            "Stock Report",
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s20,
              0.30,
              ColorManager.textColor,
            ),
          ),
        ),
        Row(
          children: [
            if (_isMobile(context))
              TextButton.icon(
                onPressed: () => setState(() => _showFilters = !_showFilters),
                icon: Icon(
                  _showFilters ? Icons.filter_list_off : Icons.filter_list,
                  size: 18,
                  color: ColorManager.kPrimaryColor,
                ),
                label: Text(
                  _showFilters ? 'Hide' : 'Filters',
                  style: const TextStyle(
                      color: ColorManager.kPrimaryColor, fontSize: 12),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryBlock(ReportsProvider provider) {
    final summary = provider.stockReport?.summary;
    final totalUnits = summary?.totalUnits?.toString() ?? '0';
    final totalStockValue = summary?.totalStockValue != null
        ? double.tryParse(summary!.totalStockValue.toString())?.toStringAsFixed(2) ?? '0.00'
        : '0.00';
    final totalRetailValue = summary?.totalRetailValue != null
        ? double.tryParse(summary!.totalRetailValue.toString())?.toStringAsFixed(2) ?? '0.00'
        : '0.00';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorManager.kPrimaryColor.withOpacity(0.1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          return Flex(
            direction: isNarrow ? Axis.vertical : Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem("Total Stocked Units", totalUnits, Icons.inventory_2_outlined),
              if (isNarrow) const Divider(height: 16),
              _buildSummaryItem("Total Stock Value (Cost)", "$totalStockValue", Icons.monetization_on_outlined),
              if (isNarrow) const Divider(height: 16),
              _buildSummaryItem("Total Retail Value (Sale)", "$totalRetailValue", Icons.shopping_bag_outlined),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: ColorManager.kPrimaryColor),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s11,
                0.15,
                Colors.black54,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: buildCustomStyle(
                FontWeightManager.bold,
                FontSize.s16,
                0.20,
                ColorManager.textColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final storeProvider = Provider.of<StoreSessionProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final productProvider = Provider.of<LocalProductProvider>(context);

    final viewStockAsOfField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "View Stock As Of",
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.27,
              Colors.black.withOpacity(0.6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.centerRight,
          children: [
            BuildBorderContainer(
              height: 45,
              width: double.infinity,
              child: CalendarPickerTableCell(
                key: ValueKey('snapshot_$_datePickerResetKey'),
                initialDate: selectedSnapshotDate,
                hintText: "Leave blank to show current stock",
                onDateSelected: (date) {
                  setState(() {
                    selectedSnapshotDate = date;
                    _currentPage = 1;
                  });
                  loadInitData();
                },
              ),
            ),
            if (selectedSnapshotDate != null)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedSnapshotDate = null;
                      _currentPage = 1;
                    });
                    loadInitData();
                  },
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.black54,
                  ),
                ),
              ),
          ],
        ),
      ],
    );

    final storeDropdown = _buildFilterDropdown<Store>(
      label: "Store",
      hint: "All Stores",
      value: selectedStoreId != null
          ? storeProvider.availableStores
              .firstWhereOrNull((s) => s.storeId == selectedStoreId)
          : null,
      items: storeProvider.availableStores,
      displayText: (s) => s.storeName ?? "",
      onChanged: (s) {
        setState(() {
          selectedStoreId = s?.storeId;
          selectedStoreName = s?.storeName;
          _currentPage = 1;
        });
        loadInitData();
      },
    );

    final categoryDropdown = _buildFilterDropdown<Category>(
      label: "Category",
      hint: "All Categories",
      value: selectedCategoryId != null
          ? categoryProvider.category
              ?.firstWhereOrNull((c) => c.categoryId == selectedCategoryId)
          : null,
      items: categoryProvider.category ?? [],
      displayText: (c) => c.categoryName ?? "",
      onChanged: (c) {
        setState(() {
          selectedCategoryId = c?.categoryId;
          selectedCategoryName = c?.categoryName;
          _currentPage = 1;
        });
        loadInitData();
      },
    );

    final productDropdown = _buildFilterDropdown<GetProduct>(
      label: "Product",
      hint: "All Products",
      value: selectedProductName != null
          ? productProvider.products
              .firstWhereOrNull((p) => p.productName == selectedProductName)
          : null,
      items: productProvider.products,
      displayText: (p) => p.productName ?? "",
      onChanged: (p) {
        setState(() {
          selectedProductName = p?.productName;
          _currentPage = 1;
        });
        loadInitData();
      },
    );

    final stockLevelDropdown = _buildFilterDropdown<String>(
      label: "Stock Level",
      hint: "All Levels",
      value: selectedStockLevel,
      items: const ['All', 'Below Reorder'],
      displayText: (val) => val,
      onChanged: (val) {
        setState(() {
          selectedStockLevel = val ?? 'All';
          _currentPage = 1;
        });
        loadInitData();
      },
    );

    final expiryDropdown = _buildFilterDropdown<String>(
      label: "Expiry Filter",
      hint: "All Expiries",
      value: selectedExpiryFilter,
      items: const ['All', '1 Month', '3 Months', '6 Months', '1 Year'],
      displayText: (val) => val,
      onChanged: (val) {
        setState(() {
          selectedExpiryFilter = val ?? 'All';
          _currentPage = 1;
        });
        loadInitData();
      },
    );

    final fromDateField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "From Date",
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.27,
              Colors.black.withOpacity(0.6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        BuildBorderContainer(
          height: 45,
          width: double.infinity,
          child: CalendarPickerTableCell(
            key: ValueKey('from_$_datePickerResetKey'),
            initialDate: selectedFromDate,
            onDateSelected: (date) {
              setState(() {
                selectedFromDate = date;
                _currentPage = 1;
              });
              loadInitData();
            },
          ),
        ),
      ],
    );

    final untilDateField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Until Date",
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.27,
              Colors.black.withOpacity(0.6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        BuildBorderContainer(
          height: 45,
          width: double.infinity,
          child: CalendarPickerTableCell(
            key: ValueKey('until_$_datePickerResetKey'),
            initialDate: selectedUntilDate,
            onDateSelected: (date) {
              setState(() {
                selectedUntilDate = date;
                _currentPage = 1;
              });
              loadInitData();
            },
          ),
        ),
      ],
    );

    if (_isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: viewStockAsOfField),
            const SizedBox(width: 8),
            Expanded(child: storeDropdown),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: categoryDropdown),
            const SizedBox(width: 8),
            Expanded(child: productDropdown),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: stockLevelDropdown),
            const SizedBox(width: 8),
            Expanded(child: expiryDropdown),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: fromDateField),
            const SizedBox(width: 8),
            Expanded(child: untilDateField),
          ]),
          const SizedBox(height: 12),
          CustomRoundButton(
            title: "Reset",
            boxColor: Colors.white,
            textColor: ColorManager.kPrimaryColor,
            fct: _resetFilters,
            height: 45,
            width: double.infinity,
            fontSize: FontSize.s12,
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 1, child: viewStockAsOfField),
            const SizedBox(width: 10),
            Expanded(flex: 1, child: storeDropdown),
            const SizedBox(width: 10),
            Expanded(flex: 1, child: categoryDropdown),
            const SizedBox(width: 10),
            Expanded(flex: 1, child: productDropdown),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 1, child: stockLevelDropdown),
            const SizedBox(width: 10),
            Expanded(flex: 1, child: expiryDropdown),
            const SizedBox(width: 10),
            Expanded(flex: 1, child: fromDateField),
            const SizedBox(width: 10),
            Expanded(flex: 1, child: untilDateField),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 45),
              child: CustomRoundButton(
                title: "Reset",
                boxColor: Colors.white,
                textColor: ColorManager.kPrimaryColor,
                fct: _resetFilters,
                height: 45,
                width: 80,
                fontSize: FontSize.s12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterDropdown<T>({
    required String label,
    required String hint,
    required T? value,
    required List<T> items,
    required String Function(T) displayText,
    required void Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.27,
              Colors.black.withOpacity(0.6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        BuildDropDownWithSearch<T>(
          title: null,
          hintText: hint,
          value: value,
          items: items,
          displayText: displayText,
          height: 45,
          margin: EdgeInsets.zero,
          onChanged: onChanged,
          searchHintText: 'Search...',
          width: double.infinity,
        ),
      ],
    );
  }



  Widget _buildMobileStockCard(int index, StockReportData item) {
    final stockVal = item.stockValue != null
        ? double.tryParse(item.stockValue.toString())?.toStringAsFixed(2) ?? '0.00'
        : '0.00';
    final retailVal = item.retailValue != null
        ? double.tryParse(item.retailValue.toString())?.toStringAsFixed(2) ?? '0.00'
        : '0.00';

    final expDate = item.expiryDate != null && item.expiryDate!.isNotEmpty
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(item.expiryDate!))
        : '-';

    final retailPriceVal = item.retailPrice != null
        ? double.tryParse(item.retailPrice.toString())?.toStringAsFixed(2) ?? '0.00'
        : '0.00';
    final mrpVal = item.mrp != null
        ? double.tryParse(item.mrp.toString())?.toStringAsFixed(2) ?? '0.00'
        : '0.00';
    final purchasePriceVal = item.purchasePrice != null
        ? double.tryParse(item.purchasePrice.toString())?.toStringAsFixed(2) ?? '0.00'
        : '0.00';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        '#${(_currentPage - 1) * _pageSize + index + 1}  ',
                        style: buildCustomStyle(FontWeightManager.semiBold,
                            FontSize.s13, 0.20, ColorManager.textColor),
                      ),
                      Expanded(
                        child: SelectableText(
                          item.name,
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s13, 0.20, ColorManager.textColor),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  item.barcode ?? '-',
                  style: buildCustomStyle(
                      FontWeightManager.medium, FontSize.s11, 0.16, Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMobileCardStat('Category', item.categoryName ?? '-',
                    selectable: true),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stores',
                          style: buildCustomStyle(FontWeightManager.regular,
                              FontSize.s10, 0.15, Colors.grey)),
                      const SizedBox(height: 2),
                      _buildStoreCountBadge(item),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMobileCardStat(
                    'Stock', "${item.totalQuantity ?? 0} ${item.unit ?? 'PCS'}"),
                _buildMobileCardStat('Expiry', expDate),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMobileCardStat('Retail Price', retailPriceVal),
                _buildMobileCardStat('MRP', mrpVal),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMobileCardStat('Purchase Price', purchasePriceVal),
                _buildMobileCardStat('Stock Value', stockVal),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMobileCardStat('Retail Value', retailVal),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCardStat(String label, String value,
      {bool selectable = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: buildCustomStyle(
                  FontWeightManager.regular, FontSize.s10, 0.15, Colors.grey)),
          Row(
            children: [
              Flexible(
                child: selectable
                    ? SelectableText(
                        value,
                        style: buildCustomStyle(FontWeightManager.medium,
                            FontSize.s12, 0.18, Colors.black87),
                      )
                    : Text(value,
                        style: buildCustomStyle(FontWeightManager.medium,
                            FontSize.s12, 0.18, Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportTable(ReportsProvider reportsProvider) {
    if (initLoading) {
      if (_isMobile(context)) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: CircularProgressIndicator.adaptive(),
          ),
        );
      }
      return const Expanded(
          child: Center(child: CircularProgressIndicator.adaptive()));
    }

    if (_isMobile(context)) {
      return reportsProvider.stockReport == null ||
              reportsProvider.stockReport!.data.isEmpty
          ? _buildNoDataFoundUI()
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reportsProvider.stockReport!.data.length,
              itemBuilder: (ctx, i) => _buildMobileStockCard(
                  i, reportsProvider.stockReport!.data[i]),
            );
    }

    return Expanded(
      child: BuildBoxShadowContainer(
        margin: const EdgeInsets.only(top: 5),
        circleRadius: 7,
        offsetValue: const Offset(2, 2),
        blurRadius: 8.0,
        color: Colors.white,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tableWidth = constraints.maxWidth > 1200
                ? constraints.maxWidth
                : 1200.0;
            return Scrollbar(
              thumbVisibility: true,
              trackVisibility: true,
              controller: _tableScrollController,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _tableScrollController,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      // Table Header
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
                          columnWidths: const {
                            0: FlexColumnWidth(0.4), // No
                            1: FlexColumnWidth(1.8), // Product Name
                            2: FlexColumnWidth(1.2), // Category
                            3: FlexColumnWidth(1.1), // Stores Count
                            4: FlexColumnWidth(1.1), // Barcode
                            5: FlexColumnWidth(1.0), // Retail Price
                            6: FlexColumnWidth(1.0), // MRP
                            7: FlexColumnWidth(1.0), // Purchase Price
                            8: FlexColumnWidth(1.0), // Current Stock
                            9: FlexColumnWidth(1.0), // Stock Value
                            10: FlexColumnWidth(1.0), // Retail Value
                            11: FlexColumnWidth(1.0), // Expiry Date
                          },
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                              children: [
                                _buildTableHeaderCell("No"),
                                _buildTableHeaderCell("Product Name"),
                                _buildTableHeaderCell("Category"),
                                _buildTableHeaderCell("Stores"),
                                _buildTableHeaderCell("Barcode"),
                                _buildTableHeaderCell("Retail\nPrice"),
                                _buildTableHeaderCell("MRP"),
                                _buildTableHeaderCell("Purchase\nPrice"),
                                _buildTableHeaderCell("Current\nStock"),
                                _buildTableHeaderCell("Stock\nValue"),
                                _buildTableHeaderCell("Retail\nValue"),
                                _buildTableHeaderCell("Expiry\nDate"),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Table Body
                      Expanded(
                        child: reportsProvider.stockReport == null ||
                                reportsProvider.stockReport!.data.isEmpty
                            ? _buildNoDataFoundUI()
                            : ScrollConfiguration(
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
                                  child: Table(
                                    columnWidths: const {
                                      0: FlexColumnWidth(0.4),
                                      1: FlexColumnWidth(1.8),
                                      2: FlexColumnWidth(1.2),
                                      3: FlexColumnWidth(1.1),
                                      4: FlexColumnWidth(1.1),
                                      5: FlexColumnWidth(1.0),
                                      6: FlexColumnWidth(1.0),
                                      7: FlexColumnWidth(1.0),
                                      8: FlexColumnWidth(1.0),
                                      9: FlexColumnWidth(1.0),
                                      10: FlexColumnWidth(1.0),
                                      11: FlexColumnWidth(1.0),
                                    },
                                    defaultVerticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    children: reportsProvider.stockReport!.data
                                        .asMap()
                                        .entries
                                        .map((entry) => _buildDataRow(
                                            entry.key, entry.value, context))
                                        .toList(),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s11,
          0.15,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  TableRow _buildDataRow(
      int index, StockReportData item, BuildContext context) {
    final stockVal = item.stockValue != null
        ? double.tryParse(item.stockValue.toString())?.toStringAsFixed(2) ?? '0.00'
        : '0.00';
    final retailVal = item.retailValue != null
        ? double.tryParse(item.retailValue.toString())?.toStringAsFixed(2) ?? '0.00'
        : '0.00';

    final expDate = item.expiryDate != null && item.expiryDate!.isNotEmpty
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(item.expiryDate!))
        : '-';

    final retailPriceVal = item.retailPrice != null
        ? double.tryParse(item.retailPrice.toString())?.toStringAsFixed(2) ?? '0.00'
        : '0.00';
    final mrpVal = item.mrp != null
        ? double.tryParse(item.mrp.toString())?.toStringAsFixed(2) ?? '0.00'
        : '0.00';
    final purchasePriceVal = item.purchasePrice != null
        ? double.tryParse(item.purchasePrice.toString())?.toStringAsFixed(2) ?? '0.00'
        : '0.00';

    return TableRow(
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : Colors.grey.withOpacity(0.05),
      ),
      children: [
        _buildTableCell(
            ((_currentPage - 1) * _pageSize + index + 1).toString()),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                item.name,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s9,
                  0.13,
                  Colors.black87,
                ),
              ),
            ),
          ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: SelectableText(
                item.categoryName ?? "-",
                textAlign: TextAlign.center,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s9,
                  0.13,
                  Colors.black87,
                ),
              ),
            ),
          ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(child: _buildStoreCountBadge(item)),
          ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      item.barcode ?? "-",
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s9,
                        0.13,
                        Colors.black87,
                      ),
                    ),
                  ),
                  if (item.barcode != null &&
                      item.barcode!.isNotEmpty &&
                      item.barcode != '-') ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: item.barcode!));
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text('Barcode copied to clipboard'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                      },
                      child: const Icon(
                        Icons.copy,
                        size: 14,
                        color: Colors.black38,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        _buildTableCell(retailPriceVal),
        _buildTableCell(mrpVal),
        _buildTableCell(purchasePriceVal),
        _buildTableCell("${item.totalQuantity ?? 0} ${item.unit ?? 'PCS'}"),
        _buildTableCell(stockVal),
        _buildTableCell(retailVal),
        _buildTableCell(expDate),
      ],
    );
  }

  Widget _buildStoreCountBadge(StockReportData item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${item.storeCount ?? 1}',
        style: const TextStyle(
          color: ColorManager.kPrimaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTableCell(String content,
      {TextAlign textAlign = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        content,
        textAlign: textAlign,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s9,
          0.13,
          Colors.black87,
        ),
      ),
    );
  }

  Widget _buildNoDataFoundUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No data found",
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s16,
              0.2,
              Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(ReportsProvider reportsProvider) {
    int totalPages = reportsProvider.stockReport?.pagination?.lastPage ?? 1;
    return PaginationControl(
      currentPage: _currentPage,
      totalPages: totalPages,
      onPageChanged: (int page) {
        if (!initLoading && page >= 1 && page <= totalPages) {
          loadInitData(page: page);
        }
      },
    );
  }
}
