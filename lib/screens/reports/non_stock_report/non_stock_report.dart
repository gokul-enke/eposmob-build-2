import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
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
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/get_non_stock_report_model.dart';
import 'dart:ui';

class NonStockReportScreen extends StatefulWidget {
  const NonStockReportScreen({super.key});

  @override
  State<NonStockReportScreen> createState() => _NonStockReportScreenState();
}

class _NonStockReportScreenState extends State<NonStockReportScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  bool initLoading = false;
  bool _showFilters = true;

  bool _isMobile(BuildContext ctx) => MediaQuery.of(ctx).size.width < 768;

  // Controllers for filters
  final TextEditingController _barcodeController = TextEditingController();

  // Filter variables
  String? selectedStoreName;
  String? selectedCategoryName;
  String? selectedProductName;
  String? searchBarcode;

  // Pagination
  int _currentPage = 1;

  int get _pageSize =>
      Provider.of<ReportsProvider>(context, listen: false)
          .nonStockReport
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
    _barcodeController.dispose();
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

      await reportsProvider.fetchNonStockReport(
        accessToken: accessToken ?? "",
        store: selectedStoreName,
        category: selectedCategoryName,
        product: selectedProductName,
        barcode: _barcodeController.text,
        page: page ?? _currentPage,
      );

      if (page != null) {
        _currentPage = page;
      } else if (reportsProvider.nonStockReport?.pagination?.currentPage !=
          null) {
        _currentPage = reportsProvider.nonStockReport!.pagination!.currentPage!;
      }
    } catch (error) {
      debugPrint('Error loading non-stock report: $error');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('non_stock_report.unavailable'.tr),
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
    _barcodeController.clear();
    setState(() {
      selectedStoreName = null;
      selectedCategoryName = null;
      selectedProductName = null;
      _currentPage = 1;
    });
    loadInitData();
  }

  @override
  Widget build(BuildContext context) {
    ReportsProvider reportsProvider = Provider.of<ReportsProvider>(context);

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 15),
                if (_showFilters) _buildFilters(),
                if (_showFilters) const SizedBox(height: 20),
                _buildReportTable(reportsProvider),
                const SizedBox(height: 10),
                _buildPagination(reportsProvider),
              ],
            ),
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
            'non_stock_report.title'.tr,
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
              _showFilters ? 'non_stock_report.hide'.tr : 'non_stock_report.filters'.tr,
              style: const TextStyle(
                  color: ColorManager.kPrimaryColor, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildFilters() {
    final storeProvider = Provider.of<StoreSessionProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final productProvider = Provider.of<LocalProductProvider>(context);

    final storeDropdown = _buildFilterDropdown<Store>(
      label: 'non_stock_report.store'.tr,
      hint: 'non_stock_report.select_store'.tr,
      value: selectedStoreName != null
          ? storeProvider.availableStores
              .firstWhereOrNull((s) => s.storeName == selectedStoreName)
          : null,
      items: storeProvider.availableStores,
      displayText: (s) => s.storeName ?? "",
      onChanged: (s) {
        setState(() {
          selectedStoreName = s?.storeName;
          _currentPage = 1;
        });
        loadInitData();
      },
    );

    final categoryDropdown = _buildFilterDropdown<Category>(
      label: 'non_stock_report.category'.tr,
      hint: 'non_stock_report.select_category'.tr,
      value: selectedCategoryName != null
          ? categoryProvider.category
              ?.firstWhereOrNull((c) => c.categoryName == selectedCategoryName)
          : null,
      items: categoryProvider.category ?? [],
      displayText: (c) => c.categoryName ?? "",
      onChanged: (c) {
        setState(() {
          selectedCategoryName = c?.categoryName;
          _currentPage = 1;
        });
        loadInitData();
      },
    );

    final productDropdown = _buildFilterDropdown<GetProduct>(
      label: 'non_stock_report.product'.tr,
      hint: 'non_stock_report.select_product'.tr,
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

    final barcodeField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'non_stock_report.barcode'.tr,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.27,
              Colors.black.withOpacity(0.6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        BuildBoxShadowContainer(
          height: 45,
          width: double.infinity,
          circleRadius: 7,
          child: TextField(
            controller: _barcodeController,
            onSubmitted: (value) {
              setState(() {
                _currentPage = 1;
              });
              loadInitData();
            },
            decoration: InputDecoration(
              hintText: 'non_stock_report.filter_by_barcode'.tr,
              hintStyle: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s12,
                0.18,
                Colors.grey,
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            ),
          ),
        ),
      ],
    );

    if (_isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: storeDropdown),
            const SizedBox(width: 8),
            Expanded(child: categoryDropdown),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: productDropdown),
            const SizedBox(width: 8),
            Expanded(child: barcodeField),
          ]),
          const SizedBox(height: 8),
          CustomRoundButton(
            title: 'general.reset'.tr,
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
            Expanded(flex: 1, child: storeDropdown),
            const SizedBox(width: 10),
            Expanded(flex: 1, child: categoryDropdown),
            const SizedBox(width: 10),
            Expanded(flex: 1, child: productDropdown),
            const SizedBox(width: 10),
            Expanded(flex: 1, child: barcodeField),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 45),
              child: CustomRoundButton(
                title: 'general.reset'.tr,
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
          searchHintText: 'non_stock_report.search_hint'.tr,
          width: double.infinity,
        ),
      ],
    );
  }

  Widget _buildMobileNonStockCard(int index, NonStockReportData item) {
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
                _buildStatusTag(item.status ?? ""),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMobileCardStat('non_stock_report.category_stat'.tr, item.categoryName ?? 'general.dash_placeholder'.tr,
                    selectable: true),
                _buildMobileCardStat('non_stock_report.store_stat'.tr, item.store ?? 'general.dash_placeholder'.tr),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMobileCardStat('non_stock_report.barcode_stat'.tr, item.barcode ?? 'general.dash_placeholder'.tr,
                    copyable: true),
                _buildMobileCardStat('non_stock_report.unit_stat'.tr, item.unit ?? 'general.dash_placeholder'.tr),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMobileCardStat(
                    'non_stock_report.stock_stat'.tr, item.totalQuantity?.toString() ?? 'general.zero_placeholder'.tr),
                _buildMobileCardStat(
                    'non_stock_report.reorder_stat'.tr, item.reorderLevel?.toString() ?? 'general.zero_placeholder'.tr),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCardStat(String label, String value,
      {bool copyable = false, bool selectable = false}) {
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
              if (copyable && value.isNotEmpty && value != '-') ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    showScaffold(
                      context: context,
                      message: 'non_stock_report.copied_to_clipboard'.tr.replaceAll('@label', label),
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
        ],
      ),
    );
  }

  Widget _buildReportTable(ReportsProvider reportsProvider) {
    if (initLoading) {
      return const Expanded(
          child: Center(child: CircularProgressIndicator.adaptive()));
    }

    if (_isMobile(context)) {
      return Expanded(
        child: reportsProvider.nonStockReport == null ||
                reportsProvider.nonStockReport!.data.isEmpty
            ? _buildNoDataFoundUI()
            : ListView.builder(
                itemCount: reportsProvider.nonStockReport!.data.length,
                itemBuilder: (ctx, i) => _buildMobileNonStockCard(
                    i, reportsProvider.nonStockReport!.data[i]),
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
                  0: FlexColumnWidth(0.5), // No
                  1: FlexColumnWidth(2.0), // Product Name
                  2: FlexColumnWidth(1.5), // Category
                  3: FlexColumnWidth(1.2), // Store
                  4: FlexColumnWidth(1.2), // Barcode
                  5: FlexColumnWidth(1.0), // Current Stock
                  6: FlexColumnWidth(1.0), // Reorder Level
                  7: FlexColumnWidth(0.8), // Unit
                  8: FlexColumnWidth(1.2), // Status
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    children: [
                      _buildTableHeaderCell('non_stock_report.col_no'.tr),
                      _buildTableHeaderCell('non_stock_report.col_product_name'.tr),
                      _buildTableHeaderCell('non_stock_report.col_category'.tr),
                      _buildTableHeaderCell('non_stock_report.col_store'.tr),
                      _buildTableHeaderCell('non_stock_report.col_barcode'.tr),
                      _buildTableHeaderCell('non_stock_report.col_current_stock'.tr),
                      _buildTableHeaderCell('non_stock_report.col_reorder_level'.tr),
                      _buildTableHeaderCell('non_stock_report.col_unit'.tr),
                      _buildTableHeaderCell('non_stock_report.col_status'.tr),
                    ],
                  ),
                ],
              ),
            ),
            // Table Body
            Expanded(
              child: reportsProvider.nonStockReport == null ||
                      reportsProvider.nonStockReport!.data.isEmpty
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
                            0: FlexColumnWidth(0.5),
                            1: FlexColumnWidth(2.0),
                            2: FlexColumnWidth(1.5),
                            3: FlexColumnWidth(1.2),
                            4: FlexColumnWidth(1.2),
                            5: FlexColumnWidth(1.0),
                            6: FlexColumnWidth(1.0),
                            7: FlexColumnWidth(0.8),
                            8: FlexColumnWidth(1.2),
                          },
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: reportsProvider.nonStockReport!.data
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
      int index, NonStockReportData item, BuildContext context) {
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
                item.categoryName ?? 'general.dash_placeholder'.tr,
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
        _buildTableCell(item.store ?? 'general.dash_placeholder'.tr),
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
                      item.barcode ?? 'general.dash_placeholder'.tr,
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
                      item.barcode != 'general.dash_placeholder'.tr) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: item.barcode!));
                        showScaffold(
                          context: context,
                          message: 'non_stock_report.barcode_copied'.tr,
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
        _buildTableCell(item.totalQuantity?.toString() ?? 'general.zero_placeholder'.tr),
        _buildTableCell(item.reorderLevel?.toString() ?? 'general.zero_placeholder'.tr),
        _buildTableCell(item.unit ?? 'general.dash_placeholder'.tr),
        _buildStatusTag(item.status ?? ""),
      ],
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

  Widget _buildStatusTag(String status) {
    Color bgColor;
    Color textColor;

    if (status.toLowerCase().contains("out of stock")) {
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade700;
    } else if (status.toLowerCase().contains("low stock")) {
      bgColor = Colors.orange.shade50;
      textColor = Colors.orange.shade700;
    } else {
      bgColor = Colors.grey.shade100;
      textColor = Colors.grey.shade700;
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: textColor.withOpacity(0.2)),
        ),
        child: Text(
          UiCodeLabels.stockStatus(status),
          style: buildCustomStyle(
            FontWeightManager.bold,
            FontSize.s8,
            0.12,
            textColor,
          ),
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
            'non_stock_report.no_data_found'.tr,
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
    int totalPages = reportsProvider.nonStockReport?.pagination?.lastPage ?? 1;
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
