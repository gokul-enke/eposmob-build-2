import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_border.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/report_provider.dart';
import 'package:provider/provider.dart';

class ConsumedStocksReportScreen extends StatefulWidget {
  const ConsumedStocksReportScreen({super.key});

  @override
  State<ConsumedStocksReportScreen> createState() =>
      _ConsumedStocksReportScreenState();
}

class _ConsumedStocksReportScreenState
    extends State<ConsumedStocksReportScreen> {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController fromDateController = TextEditingController();
  final TextEditingController untilDateController = TextEditingController();

  String? selectedProductId;
  String? selectedStoreId;
  int currentPage = 1;

  int get _pageSize =>
      Provider.of<ReportsProvider>(context, listen: false)
          .consumedStocksReport
          ?.data
          ?.pagination
          ?.perPage ??
      25;

  SideBarController sideBarController = Get.put(SideBarController());
  bool initLoading = false;
  bool _showFilters = true;

  bool _isMobile(BuildContext ctx) => MediaQuery.of(ctx).size.width < 768;

  List<dynamic> stores = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStores();
      loadInitData();
      if (mounted) setState(() => _showFilters = !_isMobile(context));
    });
  }

  Future<void> _loadStores() async {
    final storesList = await SharedPreferenceProvider().getStores();
    if (storesList != null && mounted) {
      setState(() {
        stores = storesList;
      });
    }
  }

  void _showLoadError(Object error) {
    debugPrint('Error fetching consumed stocks report: $error');
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Consumed stock report is currently unavailable.'),
          backgroundColor: Colors.red,
        ),
      );
  }

  void loadInitData({int page = 1}) async {
    try {
      setState(() {
        initLoading = true;
        currentPage = page;
      });

      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      ReportsProvider reportsProvider =
          Provider.of<ReportsProvider>(context, listen: false);

      await reportsProvider.fetchConsumedStocksReport(
        accessToken: accessToken ?? "",
        productId: selectedProductId,
        storeId: selectedStoreId,
        from: fromDateController.text,
        until: untilDateController.text,
        page: page,
      );
    } catch (error) {
      _showLoadError(error);
    } finally {
      if (mounted) {
        setState(() {
          initLoading = false;
        });
      }
    }
  }

  void searchConsumedStocks() {
    loadInitData(page: 1);
  }

  void resetSearch() {
    setState(() {
      searchController.clear();
      fromDateController.clear();
      untilDateController.clear();
      selectedProductId = null;
      selectedStoreId = null;
    });
    loadInitData(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    ReportsProvider reportsProvider = Provider.of<ReportsProvider>(context);
    LocalProductProvider productProvider =
        Provider.of<LocalProductProvider>(context);
    final reportData = reportsProvider.consumedStocksReport?.data?.data ?? [];
    final pagination = reportsProvider.consumedStocksReport?.data?.pagination;

    return SafeArea(
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
            color: Colors.white),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: _isMobile(context) ? 12.0 : 20.0,
            horizontal: _isMobile(context) ? 12.0 : 20.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPageHeader(),
              const SizedBox(height: 15),
              if (_showFilters) _buildFilters(reportData, productProvider),
              if (_showFilters) const SizedBox(height: 15),
              _buildReportContent(reportData, pagination),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            "Consumed Stocks Report",
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s20,
              0.30,
              ColorManager.textColor,
            ),
          ),
        ),
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
    );
  }

  Widget _buildFilters(
      List<dynamic> reportData, LocalProductProvider productProvider) {
    final productDropdown = _buildFilterField(
      label: "Product",
      child: BuildDropDownWithSearch<dynamic>(
        title: null,
        hintText: "All Products",
        value: selectedProductId != null
            ? productProvider.products.firstWhereOrNull(
                (p) => p.productId.toString() == selectedProductId)
            : null,
        items: productProvider.products,
        displayText: (p) => p.productName ?? "",
        height: 45,
        width: double.infinity,
        margin: EdgeInsets.zero,
        onChanged: (p) {
          setState(() => selectedProductId = p?.productId.toString());
          searchConsumedStocks();
        },
        searchHintText: 'Search Product...',
      ),
    );

    final storeDropdown = _buildFilterField(
      label: "Store",
      child: BuildDropDownWithSearch<dynamic>(
        title: null,
        hintText: "All Stores",
        value: selectedStoreId != null
            ? stores
                .firstWhereOrNull((s) => s['id'].toString() == selectedStoreId)
            : null,
        items: stores,
        displayText: (s) => s['store_name'] ?? "",
        height: 45,
        width: double.infinity,
        margin: EdgeInsets.zero,
        onChanged: (s) {
          setState(() => selectedStoreId = s?['id'].toString());
          searchConsumedStocks();
        },
        searchHintText: 'Search Store...',
      ),
    );

    final fromDateField = _buildFilterField(
      label: "From Date",
      child: BuildBorderContainer(
        height: 45,
        width: double.infinity,
        child: CalendarPickerTableCell(
          onDateSelected: (date) {
            fromDateController.text = DateFormat('yyyy-MM-dd').format(date);
            searchConsumedStocks();
          },
        ),
      ),
    );

    final untilDateField = _buildFilterField(
      label: "Until Date",
      child: BuildBorderContainer(
        height: 45,
        width: double.infinity,
        child: CalendarPickerTableCell(
          onDateSelected: (date) {
            untilDateController.text = DateFormat('yyyy-MM-dd').format(date);
            searchConsumedStocks();
          },
        ),
      ),
    );

    final resetButton = CustomRoundButton(
      title: "Reset",
      boxColor: Colors.white,
      textColor: ColorManager.kPrimaryColor,
      borderColor: ColorManager.kPrimaryColor,
      fct: resetSearch,
      height: 45,
      width: double.infinity,
      fontSize: FontSize.s12,
    );

    if (_isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: productDropdown),
            const SizedBox(width: 8),
            Expanded(child: storeDropdown),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: fromDateField),
            const SizedBox(width: 8),
            Expanded(child: untilDateField),
          ]),
          const SizedBox(height: 8),
          resetButton,
        ],
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: productDropdown),
            const SizedBox(width: 10),
            Expanded(child: storeDropdown),
            const SizedBox(width: 10),
            Expanded(child: fromDateField),
            const SizedBox(width: 10),
            Expanded(child: untilDateField),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(flex: 3, child: SizedBox()),
            const SizedBox(width: 10),
            Expanded(child: resetButton),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileConsumedCard(dynamic item, int index) {
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
              children: [
                Text(
                  '#${(currentPage - 1) * _pageSize + index + 1}  ',
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s13, 0.20, ColorManager.textColor),
                ),
                Expanded(
                  child: SelectableText(
                    item.product ?? "-",
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s13, 0.20, ColorManager.textColor),
                  ),
                ),
              ],
            ),
            const Divider(height: 12),
            Row(
              children: [
                _buildMobileCardStat('Store', item.store ?? '-',
                    selectable: true),
                _buildMobileCardStat('Withdrawn By', item.withdrawnBy ?? '-',
                    selectable: true),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMobileCardStat(
                    'Qty Withdrawn', item.quantityWithdrawn ?? '-'),
                _buildMobileCardStat('New Qty', '${item.newQuantity ?? 0}'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.createdAt ?? '-',
              style: buildCustomStyle(
                  FontWeightManager.regular, FontSize.s10, 0.15, Colors.grey),
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
          selectable
              ? SelectableText(
                  value,
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s12, 0.18, Colors.black87),
                )
              : Text(
                  value,
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s12, 0.18, Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ],
      ),
    );
  }

  Widget _buildReportContent(List<dynamic> reportData, dynamic pagination) {
    if (initLoading) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    if (_isMobile(context)) {
      return Expanded(
        child: reportData.isEmpty
            ? _buildNoDataFoundUI()
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: reportData.length,
                      itemBuilder: (ctx, i) =>
                          _buildMobileConsumedCard(reportData[i], i),
                    ),
                  ),
                  if (pagination != null && pagination.total! > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15.0),
                      child: PaginationControl(
                        currentPage: pagination.currentPage ?? 1,
                        totalPages: pagination.lastPage ?? 1,
                        onPageChanged: (page) => loadInitData(page: page),
                      ),
                    ),
                ],
              ),
      );
    }

    return Expanded(
      child: BuildBoxShadowContainer(
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
                columnWidths: const {
                  0: FlexColumnWidth(0.5),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(1.2),
                  3: FlexColumnWidth(1.2),
                  4: FlexColumnWidth(1.0),
                  5: FlexColumnWidth(1.2),
                  6: FlexColumnWidth(1.5),
                },
                border: null,
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    children: [
                      _buildTableHeader("No"),
                      _buildTableHeader("Product"),
                      _buildTableHeader("Store"),
                      _buildTableHeader("Quantity Withdrawn"),
                      _buildTableHeader("New Quantity"),
                      _buildTableHeader("Withdrawn By"),
                      _buildTableHeader("Date & Time"),
                    ],
                  ),
                ],
              ),
            ),
            // Scrollable table body
            Expanded(
              child: reportData.isEmpty
                  ? _buildNoDataFoundUI()
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(0.5),
                          1: FlexColumnWidth(1.5),
                          2: FlexColumnWidth(1.2),
                          3: FlexColumnWidth(1.2),
                          4: FlexColumnWidth(1.0),
                          5: FlexColumnWidth(1.2),
                          6: FlexColumnWidth(1.5),
                        },
                        border: null,
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: reportData
                            .asMap()
                            .entries
                            .map((entry) =>
                                _buildDataRow(entry.value, entry.key))
                            .toList(),
                      ),
                    ),
            ),
            if (pagination != null && pagination.total! > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 15.0),
                child: PaginationControl(
                  currentPage: pagination.currentPage ?? 1,
                  totalPages: pagination.lastPage ?? 1,
                  onPageChanged: (page) => loadInitData(page: page),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(4.0),
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
        child,
      ],
    );
  }

  Widget _buildTableHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.18,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  TableRow _buildDataRow(dynamic item, int index) {
    return TableRow(
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : Colors.grey.withOpacity(0.1),
      ),
      children: [
        _buildTableCell("${index + 1}"),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 18.0),
            child: Center(
              child: SelectableText(
                item.product ?? "",
                textAlign: TextAlign.center,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s9,
                  0.13,
                  Colors.black,
                ),
              ),
            ),
          ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 18.0),
            child: Center(
              child: SelectableText(
                item.store ?? "",
                textAlign: TextAlign.center,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s9,
                  0.13,
                  Colors.black,
                ),
              ),
            ),
          ),
        ),
        _buildTableCell(item.quantityWithdrawn ?? ""),
        _buildTableCell("${item.newQuantity}"),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 18.0),
            child: Center(
              child: SelectableText(
                item.withdrawnBy ?? "",
                textAlign: TextAlign.center,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s9,
                  0.13,
                  Colors.black,
                ),
              ),
            ),
          ),
        ),
        _buildTableCell(item.createdAt ?? ""),
      ],
    );
  }

  Widget _buildTableCell(String content) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 18.0),
        child: Text(
          content,
          textAlign: TextAlign.center,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s9,
            0.13,
            Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildNoDataFoundUI() {
    return Container(
      height: 300,
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 60,
            color: ColorManager.kPrimaryColor.withOpacity(0.7),
          ),
          const SizedBox(height: 15),
          Text(
            'No records found',
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s18,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.20,
              Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
