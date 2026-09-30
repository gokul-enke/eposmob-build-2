import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../components/build_calendar_selection.dart';
import '../../../components/build_dialog_box.dart';
import '../../../components/build_container_border.dart';
import '../../../components/build_container_box.dart';
import '../../../components/build_dropdown_with_search.dart';
import '../../../components/build_pagination_control.dart';
import '../../../components/export_share_button.dart';
import '../../../components/filter_toggle_button.dart';
import '../../../models/category_list.dart';
import '../../../models/customer_list.dart';
import '../../../models/get_product.dart';
import '../../../models/get_product_sales_report_model.dart';
import '../../../providers/auth_model.dart';
import '../../../providers/category_providers.dart';
import '../../../providers/customer_provider.dart';
import '../../../providers/grid_provider.dart';
import '../../../providers/report_provider.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';
import '../../../services/list_excel_export_service.dart';

class ProductSalesReportScreen extends StatefulWidget {
  const ProductSalesReportScreen({super.key});

  @override
  State<ProductSalesReportScreen> createState() =>
      _ProductSalesReportScreenState();
}

class _ProductSalesReportRequest {
  const _ProductSalesReportRequest({
    required this.generation,
    required this.page,
    required this.categoryId,
    required this.productId,
    required this.customerId,
    required this.startDate,
    required this.endDate,
  });

  final int generation;
  final int page;
  final String? categoryId;
  final String? productId;
  final String? customerId;
  final String startDate;
  final String endDate;
}

class _ProductSalesReportScreenState extends State<ProductSalesReportScreen> {
  static const int _pageSize = 25;

  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _tableScrollController = ScrollController();
  final _categoryFocus = FocusNode(debugLabel: 'product-sales-category');
  final _productFocus = FocusNode(debugLabel: 'product-sales-product');
  late final FocusNode _fromDateFocus;
  late final FocusNode _toDateFocus;
  final _customerFocus = FocusNode(debugLabel: 'product-sales-customer');
  final _resetFocus = FocusNode(debugLabel: 'product-sales-reset');

  Category? _selectedCategory;
  GetProduct? _selectedProduct;
  CustomerListModelData? _selectedCustomer;
  GetProductSalesReportResponse? _report;
  List<GetProduct> _productOptions = const [];
  List<CustomerListModelData> _customerOptions = const [];
  bool _isLoading = false;
  bool _loadFailed = false;
  bool _filterOptionsLoadFailed = false;
  bool _isLoadingFilterOptions = false;
  bool _invalidDateRange = false;
  bool _requestWorkerRunning = false;
  int _requestGeneration = 0;
  _ProductSalesReportRequest? _pendingRequest;
  bool _showFilters = true;
  bool _layoutInitialized = false;
  int _currentPage = 1;

  bool _isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 768;

  @override
  void initState() {
    super.initState();
    _fromDateFocus = FocusNode(debugLabel: 'product-sales-from-date');
    _toDateFocus = FocusNode(debugLabel: 'product-sales-to-date');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future.wait([_loadReport(), _loadFilterOptions()]);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_layoutInitialized) {
      _showFilters = !_isMobile(context);
      _layoutInitialized = true;
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _tableScrollController.dispose();
    _categoryFocus.dispose();
    _productFocus.dispose();
    _fromDateFocus.dispose();
    _toDateFocus.dispose();
    _customerFocus.dispose();
    _resetFocus.dispose();
    super.dispose();
  }

  Future<void> _loadFilterOptions() async {
    if (_isLoadingFilterOptions) return;
    setState(() {
      _isLoadingFilterOptions = true;
      _filterOptionsLoadFailed = false;
    });
    try {
      final token = context.read<AuthModel>().token ?? '';
      await Future.wait([
        context.read<CategoryProvider>().listAllCategory(),
        context
            .read<CustomerProvider>()
            .fetchAllCustomersSnapshot(accessToken: token)
            .then((customers) {
          if (mounted) setState(() => _customerOptions = customers);
        }),
        context
            .read<GridSelectionProvider>()
            .listAllProductsForReportFilter()
            .then((products) {
          if (mounted) setState(() => _productOptions = products);
        }),
      ]);
    } catch (error) {
      debugPrint('Could not load product report filter options: $error');
      if (mounted) setState(() => _filterOptionsLoadFailed = true);
    } finally {
      if (mounted) setState(() => _isLoadingFilterOptions = false);
    }
  }

  Future<void> _loadReport({int page = 1}) async {
    if (!_isDateRangeValid()) {
      _requestGeneration++;
      _pendingRequest = null;
      if (mounted) {
        setState(() {
          _report = null;
          _loadFailed = false;
          _invalidDateRange = true;
          _isLoading = false;
        });
      }
      return;
    }

    final request = _ProductSalesReportRequest(
      generation: ++_requestGeneration,
      page: page,
      categoryId: _selectedCategory?.categoryId?.toString(),
      productId: _selectedProduct?.productId?.toString(),
      customerId: _selectedCustomer?.id?.toString(),
      startDate: _fromController.text,
      endDate: _toController.text,
    );
    _pendingRequest = request;
    setState(() {
      _report = null;
      _isLoading = true;
      _loadFailed = false;
      _invalidDateRange = false;
    });
    if (_requestWorkerRunning) return;
    await _drainReportRequests();
  }

  Future<void> _drainReportRequests() async {
    _requestWorkerRunning = true;
    try {
      while (mounted && _pendingRequest != null) {
        final request = _pendingRequest!;
        _pendingRequest = null;
        try {
          final report =
              await context.read<ReportsProvider>().fetchProductSalesReport(
                    accessToken: context.read<AuthModel>().token ?? '',
                    categoryId: request.categoryId,
                    productId: request.productId,
                    customerId: request.customerId,
                    startDate: request.startDate,
                    endDate: request.endDate,
                    page: request.page,
                    perPage: _pageSize,
                    updateState: false,
                  );
          if (!mounted || request.generation != _requestGeneration) continue;
          setState(() {
            _report = report;
            _currentPage = request.page;
            _loadFailed = false;
          });
        } catch (error) {
          debugPrint('Product sales report unavailable: $error');
          if (!mounted || request.generation != _requestGeneration) continue;
          setState(() {
            _report = null;
            _loadFailed = true;
          });
          showScaffoldError(
            context: context,
            message: 'product_sales_report.error_unavailable'.tr,
          );
        }
      }
    } finally {
      _requestWorkerRunning = false;
      if (mounted && _pendingRequest == null) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isDateRangeValid({bool showError = true}) {
    if (_fromController.text.isEmpty || _toController.text.isEmpty) return true;
    final from = DateTime.tryParse(_fromController.text);
    final to = DateTime.tryParse(_toController.text);
    if (from == null || to == null || !from.isAfter(to)) return true;
    if (showError) {
      showScaffoldError(
        context: context,
        message: 'product_sales_report.invalid_date_range'.tr,
      );
    }
    return false;
  }

  bool _hasActiveFilters() =>
      _selectedCategory != null ||
      _selectedProduct != null ||
      _selectedCustomer != null ||
      _fromController.text.isNotEmpty ||
      _toController.text.isNotEmpty;

  void _resetFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedProduct = null;
      _selectedCustomer = null;
      _fromController.clear();
      _toController.clear();
      _currentPage = 1;
    });
    _loadReport();
  }

  Future<File> _createExportFile() async {
    if (!_isDateRangeValid(showError: false)) {
      throw StateError('Invalid date range.');
    }

    final provider = context.read<ReportsProvider>();
    final token = context.read<AuthModel>().token ?? '';
    final categoryId = _selectedCategory?.categoryId?.toString();
    final productId = _selectedProduct?.productId?.toString();
    final customerId = _selectedCustomer?.id?.toString();
    final startDate = _fromController.text;
    final endDate = _toController.text;
    const exportPageSize = 250;
    final entries = <ProductSalesReportEntry>[];
    var page = 1;
    var lastPage = 1;

    do {
      final response = await provider.fetchProductSalesReport(
        accessToken: token,
        categoryId: categoryId,
        productId: productId,
        customerId: customerId,
        startDate: startDate,
        endDate: endDate,
        page: page,
        perPage: exportPageSize,
        updateState: false,
      );
      entries.addAll(response.data.entries);
      lastPage = response.data.pagination.lastPage;
      page++;
    } while (page <= lastPage);

    return ListExcelExportService.export<ProductSalesReportEntry>(
      items: entries,
      fileNamePrefix: 'product-sales-report',
      sheetName: 'Product Sales',
      columns: [
        ListExportColumn(
          label: 'product_sales_report.col_category_name'.tr,
          value: (item, _) => item.category,
        ),
        ListExportColumn(
          label: 'product_sales_report.col_product_name'.tr,
          value: (item, _) => item.productName,
        ),
        ListExportColumn(
          label: 'product_sales_report.col_price'.tr,
          value: (item, _) => item.price,
        ),
        ListExportColumn(
          label: 'product_sales_report.col_total_amount'.tr,
          value: (item, _) => item.totalPrice,
        ),
        ListExportColumn(
          label: 'product_sales_report.col_products_sold'.tr,
          value: (item, _) => item.salesCount,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(report),
        if (_showFilters) ...[
          const SizedBox(height: 16),
          KeyedSubtree(
            key: const ValueKey('product-sales-report-filters'),
            child: _buildFilters(),
          ),
        ],
        if (report != null) ...[
          const SizedBox(height: 18),
          _buildSummary(report),
          const SizedBox(height: 14),
        ] else
          const SizedBox(height: 18),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else
          _buildResults(report),
        const SizedBox(height: 12),
        if (report != null && report.data.pagination.lastPage > 1)
          PaginationControl(
            currentPage: report.data.pagination.currentPage,
            totalPages: report.data.pagination.lastPage,
            onPageChanged: (page) => _loadReport(page: page),
          ),
      ],
    );

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => _loadReport(page: _currentPage),
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: _isMobile(context) ? 5 : 10,
            vertical: _isMobile(context) ? 10 : 20,
          ),
          padding: EdgeInsets.all(_isMobile(context) ? 12 : 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: ColorManager.boxShadowColor,
                blurRadius: 6,
                offset: Offset(1, 1),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(GetProductSalesReportResponse? report) {
    final exportButton = ExportShareButton(
      createFile: _createExportFile,
      label: 'product_sales_report.export'.tr,
      loadingLabel: 'product_sales_report.exporting'.tr,
      tooltip: 'product_sales_report.export'.tr,
      errorMessage: 'product_sales_report.export_error'.tr,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      shareText: 'product_sales_report.share_text'.tr,
      compact: _isMobile(context),
      enabled: !_isLoading &&
          !_invalidDateRange &&
          (report?.data.entries.isNotEmpty ?? false),
    );

    return Row(
      children: [
        Expanded(
          child: Text(
            'product_sales_report.page_title'.tr,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s20,
              0.30,
              ColorManager.textColor,
            ),
          ),
        ),
        FilterToggleButton(
          key: const ValueKey('product-sales-report-filter-toggle'),
          showFilters: _showFilters,
          hasActiveFilters: _hasActiveFilters(),
          onPressed: () => setState(() => _showFilters = !_showFilters),
          showTooltip: 'product_sales_report.show_filters'.tr,
          hideTooltip: 'product_sales_report.hide_filters'.tr,
        ),
        const SizedBox(width: 8),
        exportButton,
      ],
    );
  }

  Widget _buildFilters() {
    final categories = context.watch<CategoryProvider>().category ?? const [];
    final allProducts = _productOptions;
    final products = _selectedCategory == null
        ? allProducts
        : allProducts
            .where((item) => item.categoryId == _selectedCategory?.categoryId)
            .toList();
    final customers = _customerOptions;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _isMobile(context)
            ? constraints.maxWidth >= 600
                ? 2
                : 1
            : 4;
        const gap = 12.0;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap * (columns - 1)) / columns;

        return FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Wrap(
            key: const ValueKey('product-sales-report-filter-fields'),
            spacing: gap,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              if (_filterOptionsLoadFailed)
                SizedBox(
                  width: constraints.maxWidth,
                  child: Container(
                    key: const ValueKey('product-sales-filter-options-error'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'product_sales_report.filter_load_error'.tr,
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s12,
                              0.15,
                              ColorManager.textColor,
                            ),
                          ),
                        ),
                        TextButton(
                          key: const ValueKey(
                            'product-sales-filter-options-retry',
                          ),
                          onPressed: _isLoadingFilterOptions
                              ? null
                              : _loadFilterOptions,
                          child: Text('product_sales_report.retry'.tr),
                        ),
                      ],
                    ),
                  ),
                ),
              FocusTraversalOrder(
                order: const NumericFocusOrder(1),
                child: SizedBox(
                  key: const ValueKey('product-sales-report-category-filter'),
                  width: width,
                  child: _buildLabeledFilter(
                    label: 'product_sales_report.filter_category'.tr,
                    child: BuildDropDownWithSearch<Category>(
                      title: null,
                      hintText: 'product_sales_report.all'.tr,
                      value: _selectedCategory,
                      items: categories
                          .where((item) => (item.categoryId ?? 0) > 0)
                          .toList(),
                      displayText: (item) => item.categoryName ?? '',
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                          if (_selectedProduct?.categoryId !=
                              value?.categoryId) {
                            _selectedProduct = null;
                          }
                        });
                        _loadReport();
                      },
                      width: width,
                      height: 45,
                      margin: EdgeInsets.zero,
                      focusNode: _categoryFocus,
                    ),
                  ),
                ),
              ),
              FocusTraversalOrder(
                order: const NumericFocusOrder(2),
                child: SizedBox(
                  key: const ValueKey('product-sales-report-product-filter'),
                  width: width,
                  child: _buildLabeledFilter(
                    label: 'product_sales_report.filter_product'.tr,
                    child: BuildDropDownWithSearch<GetProduct>(
                      title: null,
                      hintText: 'product_sales_report.all'.tr,
                      value: _selectedProduct,
                      items: products,
                      displayText: (item) => item.productName ?? '',
                      onChanged: (value) {
                        setState(() => _selectedProduct = value);
                        _loadReport();
                      },
                      width: width,
                      height: 45,
                      margin: EdgeInsets.zero,
                      focusNode: _productFocus,
                    ),
                  ),
                ),
              ),
              FocusTraversalOrder(
                order: const NumericFocusOrder(3),
                child: SizedBox(
                  key: const ValueKey('product-sales-report-from-filter'),
                  width: width,
                  child: _buildDateField(
                    label: 'product_sales_report.filter_from'.tr,
                    controller: _fromController,
                    focusNode: _fromDateFocus,
                  ),
                ),
              ),
              FocusTraversalOrder(
                order: const NumericFocusOrder(4),
                child: SizedBox(
                  key: const ValueKey('product-sales-report-to-filter'),
                  width: width,
                  child: _buildDateField(
                    label: 'product_sales_report.filter_to'.tr,
                    controller: _toController,
                    focusNode: _toDateFocus,
                  ),
                ),
              ),
              FocusTraversalOrder(
                order: const NumericFocusOrder(5),
                child: SizedBox(
                  key: const ValueKey('product-sales-report-customer-filter'),
                  width: width,
                  child: _buildLabeledFilter(
                    label: 'product_sales_report.filter_customer'.tr,
                    child: BuildDropDownWithSearch<CustomerListModelData>(
                      title: null,
                      hintText: 'product_sales_report.select_customer'.tr,
                      value: _selectedCustomer,
                      items: customers,
                      displayText: (item) => item.displayLabel,
                      onChanged: (value) {
                        setState(() => _selectedCustomer = value);
                        _loadReport();
                      },
                      width: width,
                      height: 45,
                      margin: EdgeInsets.zero,
                      focusNode: _customerFocus,
                    ),
                  ),
                ),
              ),
              FocusTraversalOrder(
                order: const NumericFocusOrder(6),
                child: SizedBox(
                  key: const ValueKey('product-sales-report-reset-button'),
                  width: width,
                  height: 45,
                  child: OutlinedButton(
                    focusNode: _resetFocus,
                    onPressed: _isLoading ? null : _resetFilters,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColorManager.kPrimaryColor,
                      side: const BorderSide(color: ColorManager.kPrimaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    child: Text('general.reset'.tr),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
  }) {
    return _buildLabeledFilter(
      label: label,
      child: BuildBorderContainer(
        height: 45,
        width: double.infinity,
        child: CalendarPickerTableCell(
          key: ValueKey('product-sales-$label-${controller.text}'),
          initialDate: DateTime.tryParse(controller.text),
          focusNode: focusNode,
          openOnFocus: false,
          onDateSelected: (date) {
            setState(() {
              controller.text = DateFormat('yyyy-MM-dd').format(date);
            });
            _loadReport();
          },
        ),
      ),
    );
  }

  Widget _buildLabeledFilter({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.27,
              Colors.black.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildSummary(GetProductSalesReportResponse? report) {
    final data = report?.data;
    return Container(
      key: const ValueKey('product-sales-report-summary'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 32,
        runSpacing: 12,
        children: [
          _buildSummaryMetric(
            title: 'product_sales_report.total_revenue'.tr,
            value: _money(
              data?.summary.totalRevenue ?? 0,
              data?.currency,
            ),
            icon: Icons.monetization_on_outlined,
          ),
          _buildSummaryMetric(
            title: 'product_sales_report.total_quantity'.tr,
            value: _quantity(data?.summary.totalQuantity ?? 0),
            icon: Icons.inventory_2_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String title,
    required String value,
    required IconData icon,
  }) {
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

  Widget _buildResults(GetProductSalesReportResponse? report) {
    if (_invalidDateRange) {
      return Padding(
        key: const ValueKey('product-sales-report-invalid-date'),
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Text('product_sales_report.invalid_date_range'.tr),
        ),
      );
    }
    if (report == null && _loadFailed) {
      return Padding(
        key: const ValueKey('product-sales-report-error'),
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Text('product_sales_report.error_unavailable'.tr),
        ),
      );
    }
    final entries = report?.data.entries ?? const <ProductSalesReportEntry>[];
    if (entries.isEmpty) {
      return Padding(
        key: const ValueKey('product-sales-report-empty'),
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(child: Text('product_sales_report.no_data'.tr)),
      );
    }

    if (_isMobile(context)) {
      return Column(
        children: [
          for (final item in entries)
            _buildMobileCard(item, report?.data.currency),
        ],
      );
    }

    return BuildBoxShadowContainer(
      margin: const EdgeInsets.only(top: 5),
      circleRadius: 7,
      offsetValue: const Offset(2, 2),
      blurRadius: 8,
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth =
              constraints.maxWidth > 700 ? constraints.maxWidth : 700.0;
          const columnWidths = <int, TableColumnWidth>{
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(1.6),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1),
            4: FlexColumnWidth(1.1),
          };

          return Scrollbar(
            controller: _tableScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: _tableScrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                key: const ValueKey('product-sales-report-table-width'),
                width: tableWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: ColorManager.tableBGColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            offset: Offset(0, 2),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: Table(
                        columnWidths: columnWidths,
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            children: [
                              _buildReportHeader(
                                  'product_sales_report.col_category_name'.tr),
                              _buildReportHeader(
                                  'product_sales_report.col_product_name'.tr),
                              _buildReportHeader(
                                  'product_sales_report.col_price'.tr),
                              _buildReportHeader(
                                  'product_sales_report.col_total_amount'.tr),
                              _buildReportHeader(
                                  'product_sales_report.col_products_sold'.tr),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Table(
                      columnWidths: columnWidths,
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      children: [
                        for (final entry in entries.asMap().entries)
                          TableRow(
                            decoration: BoxDecoration(
                              color: entry.key.isEven
                                  ? Colors.white
                                  : Colors.grey.withValues(alpha: 0.05),
                            ),
                            children: [
                              _buildReportCell(entry.value.category),
                              _buildReportCell(entry.value.productName),
                              _buildReportCell(_money(
                                  entry.value.price, report?.data.currency)),
                              _buildReportCell(_money(entry.value.totalPrice,
                                  report?.data.currency)),
                              _buildReportCell(
                                  _quantity(entry.value.salesCount)),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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

  Widget _buildReportCell(String value) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SelectableText(
        value,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s9,
          0.13,
          Colors.black,
        ),
      ),
    );
  }

  Widget _buildMobileCard(ProductSalesReportEntry item, String? currency) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.productName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _mobileRow(
                'product_sales_report.col_category_name'.tr, item.category),
            _mobileRow(
              'product_sales_report.col_price'.tr,
              _money(item.price, currency),
            ),
            _mobileRow(
              'product_sales_report.col_total_amount'.tr,
              _money(item.totalPrice, currency),
            ),
            _mobileRow(
              'product_sales_report.col_products_sold'.tr,
              _quantity(item.salesCount),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
              child:
                  Text(label, style: const TextStyle(color: Colors.black54))),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  String _money(double value, String? currency) {
    final code = (currency == null || currency.isEmpty) ? '' : '$currency ';
    return '$code${value.toStringAsFixed(2)}';
  }

  String _quantity(double value) {
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(3);
  }
}
