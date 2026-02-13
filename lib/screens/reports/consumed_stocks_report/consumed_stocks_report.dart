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

  SideBarController sideBarController = Get.put(SideBarController());
  bool initLoading = false;

  List<dynamic> stores = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStores();
      loadInitData();
    });
  }

  Future<void> _loadStores() async {
    final storesList = await SharedPreferenceProvider().getStores();
    if (storesList != null) {
      setState(() {
        stores = storesList;
      });
    }
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
      debugPrint("Error fetching consumed stocks report: $error");
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
            color: Colors.white),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _buildFilterField(
                          label: "Product",
                          child: BuildDropDownWithSearch<dynamic>(
                            title: null,
                            hintText: "All Products",
                            value: selectedProductId != null
                                ? productProvider.products.firstWhereOrNull(
                                    (p) =>
                                        p.productId.toString() ==
                                        selectedProductId)
                                : null,
                            items: productProvider.products,
                            displayText: (p) => p.productName ?? "",
                            height: 45,
                            width: double.infinity,
                            margin: EdgeInsets.zero,
                            onChanged: (p) {
                              setState(() =>
                                  selectedProductId = p?.productId.toString());
                              searchConsumedStocks();
                            },
                            searchHintText: 'Search Product...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildFilterField(
                          label: "Store",
                          child: BuildDropDownWithSearch<dynamic>(
                            title: null,
                            hintText: "All Stores",
                            value: selectedStoreId != null
                                ? stores.firstWhereOrNull((s) =>
                                    s['id'].toString() == selectedStoreId)
                                : null,
                            items: stores,
                            displayText: (s) => s['store_name'] ?? "",
                            height: 45,
                            width: double.infinity,
                            margin: EdgeInsets.zero,
                            onChanged: (s) {
                              setState(
                                  () => selectedStoreId = s?['id'].toString());
                              searchConsumedStocks();
                            },
                            searchHintText: 'Search Store...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildFilterField(
                          label: "From Date",
                          child: BuildBorderContainer(
                            height: 45,
                            width: double.infinity,
                            child: CalendarPickerTableCell(
                              onDateSelected: (date) {
                                fromDateController.text =
                                    DateFormat('yyyy-MM-dd').format(date);
                                searchConsumedStocks();
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildFilterField(
                          label: "Until Date",
                          child: BuildBorderContainer(
                            height: 45,
                            width: double.infinity,
                            child: CalendarPickerTableCell(
                              onDateSelected: (date) {
                                untilDateController.text =
                                    DateFormat('yyyy-MM-dd').format(date);
                                searchConsumedStocks();
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Expanded(flex: 3, child: SizedBox()),
                      const SizedBox(width: 10),
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
              const SizedBox(height: 15),
              initLoading
                  ? const Expanded(
                      child: Center(child: CircularProgressIndicator()))
                  : Expanded(
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
                                  0: FlexColumnWidth(0.5), // No
                                  1: FlexColumnWidth(1.5), // Product
                                  2: FlexColumnWidth(1.2), // Store
                                  3: FlexColumnWidth(1.2), // Qty Withdrawn
                                  4: FlexColumnWidth(1.0), // New Qty
                                  5: FlexColumnWidth(1.2), // Withdrawn By
                                  6: FlexColumnWidth(1.5), // Date & Time
                                },
                                border: null,
                                defaultVerticalAlignment:
                                    TableCellVerticalAlignment.middle,
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
                                            .map((entry) => _buildDataRow(
                                                entry.value, entry.key))
                                            .toList(),
                                      ),
                                    ),
                            ),
                            if (pagination != null && pagination.total! > 0)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15.0),
                                child: PaginationControl(
                                  currentPage: pagination.currentPage ?? 1,
                                  totalPages: pagination.lastPage ?? 1,
                                  onPageChanged: (page) {
                                    loadInitData(page: page);
                                  },
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
        _buildTableCell(item.product ?? ""),
        _buildTableCell(item.store ?? ""),
        _buildTableCell(item.quantityWithdrawn ?? ""),
        _buildTableCell("${item.newQuantity}"),
        _buildTableCell(item.withdrawnBy ?? ""),
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
