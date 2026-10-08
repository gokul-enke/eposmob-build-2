import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/report_provider.dart';
import '../../domain/models/product_sales_report.dart';
import '../../domain/product_sales_query.dart';
import '../export/product_sales_report_export.dart';
import '../state/product_sales_report_controller.dart';
import '../widgets/product_sales/product_sales_filters.dart';
import '../widgets/product_sales/product_sales_results.dart';
import '../widgets/report_error_bar.dart';

class ProductSalesReportPage extends StatefulWidget {
  const ProductSalesReportPage({super.key, this.exportController});
  final ExportController? exportController;
  static const filterToggleKey = ValueKey('product-sales-report-filter-toggle');
  static const exportKey = ValueKey('product-sales-report-export');
  @override
  State<ProductSalesReportPage> createState() => _ProductSalesReportPageState();
}

class _ProductSalesReportPageState extends State<ProductSalesReportPage> {
  late final ProductSalesReportController _report;
  late final ExportController _export;
  final _tableScroll = ScrollController();
  int _shownError = 0;
  String _tr(String key) => 'product_sales_report.$key'.tr;
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthModel>();
    final reports = context.read<ReportsProvider>();
    final categories = context.read<CategoryProvider>();
    final products = context.read<GridSelectionProvider>();
    final customers = context.read<CustomerProvider>();
    _export = widget.exportController ?? ExportController();
    _report = ProductSalesReportController(
      readScope: () => reports.productSalesApi.scope(auth.token ?? ''),
      fetch: (query, page, perPage) => reports.fetchProductSalesReport(
          accessToken: auth.token ?? '',
          categoryId: query.categoryId,
          productId: query.productId,
          customerId: query.customerId,
          startDate: query.from,
          endDate: query.to,
          page: page,
          perPage: perPage,
          updateState: false),
      fetchCategories: () async {
        await categories.listAllCategory();
        return [
          for (final category in categories.category ?? [])
            if ((category.categoryId ?? 0) > 0)
              ProductSalesOption(
                  id: '${category.categoryId}',
                  label: category.categoryName ?? '')
        ];
      },
      fetchProducts: () async => [
        for (final product in await products.listAllProductsForReportFilter())
          ProductSalesOption(
              id: product.productId?.toString() ?? '',
              label: product.productName ?? '',
              categoryId: product.categoryId?.toString())
      ],
      fetchCustomers: () async => [
        for (final customer in await customers.fetchAllCustomersSnapshot(
            accessToken: auth.token ?? ''))
          ProductSalesOption(
              id: customer.id?.toString() ?? '', label: customer.displayLabel)
      ],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _run(_report.initialize());
    });
  }

  bool _layoutInitialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Before the first frame, so mobile never flashes the expanded filters.
    if (_layoutInitialized) return;
    _layoutInitialized = true;
    _report.setFilters(
        MediaQuery.sizeOf(context).width >= ListLayoutBreakpoints.mobileBelow);
  }

  Future<void> _run(Future<void> operation) async {
    await operation;
    if (!mounted ||
        _report.errorKey == null ||
        _shownError == _report.errorRevision) {
      return;
    }
    _shownError = _report.errorRevision;
    AppToast.error(context, _report.errorKey!.tr);
  }

  Future<void> _exportReport() async {
    final success = await _export.run(context,
        shareText: _tr('share_text'),
        createFile: () => _report.export(
            build: ProductSalesReportExport.build,
            progress: (page, total) {
              if (mounted) {
                _export.setStage(_tr('export_fetching')
                    .replaceAll('@page', '$page')
                    .replaceAll('@total', '$total'));
              }
            }));
    if (!success && mounted) AppToast.error(context, _tr('export_error'));
  }

  Widget? _toolbar() {
    final data = _report.report?.data;
    if (data == null && _report.errorKey == null && !_report.optionsFailed) {
      return null;
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_report.optionsFailed)
        ReportErrorBar(
            key: const ValueKey('product-sales-filter-options-error'),
            message: _tr('filter_load_error'),
            retryLabel: _tr('retry'),
            onRetry: _report.optionsLoading
                ? null
                : () => _run(_report.loadOptions())),
      if (_report.errorKey != null)
        ReportErrorBar(
            key: const ValueKey('product-sales-report-error'),
            message: _report.errorKey!.tr,
            retryLabel: _tr('retry'),
            onRetry: () => _run(_report.retry())),
      if (data != null)
        ProductSalesTotals(
            key: const ValueKey('product-sales-report-summary'), data: data),
    ]);
  }

  @override
  void dispose() {
    _report.dispose();
    _tableScroll.dispose();
    if (widget.exportController == null) _export.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([_report, _export]),
      builder: (context, _) {
        final data = _report.report?.data;
        return ListPageScaffold<ProductSalesReportEntry>(
          minTableWidth: ListLayoutBreakpoints.cardsBelow,
          tableScrollController: _tableScroll,
          header: PageHeader(
              icon: Icons.bar_chart_rounded,
              title: _tr('page_title'),
              subtitle: _tr('subtitle'),
              actions: [
                HeaderAction(
                    key: ProductSalesReportPage.filterToggleKey,
                    icon: Icons.filter_alt_rounded,
                    label: _report.showFilters
                        ? 'list.hide_filters'.tr
                        : 'list.filters'.tr,
                    active: _report.showFilters,
                    badge: !_report.showFilters && _report.query.active,
                    onPressed: () => _report.setFilters(!_report.showFilters)),
                HeaderAction(
                    key: ProductSalesReportPage.exportKey,
                    icon: Icons.ios_share_rounded,
                    label: _export.busy
                        ? (_export.stage ?? 'list.exporting'.tr)
                        : 'list.export'.tr,
                    busy: _export.busy,
                    onPressed: _report.canExport && !_export.busy
                        ? _exportReport
                        : null),
                HeaderAction(
                    icon: Icons.refresh_rounded,
                    label: 'list.refresh'.tr,
                    onPressed: () => _run(_report.retry())),
              ]),
          showFilters: _report.showFilters,
          filters: ProductSalesFilters(
              resetRevision: _report.filterResetRevision,
              categories: _report.categories,
              products: _report.visibleProducts,
              customers: _report.customers,
              category: _report.category,
              product: _report.product,
              customer: _report.customer,
              from: _report.from,
              to: _report.to,
              onCategory: (v) => _run(_report.selectCategory(v)),
              onProduct: (v) => _run(_report.selectProduct(v)),
              onCustomer: (v) => _run(_report.selectCustomer(v)),
              onDate: (v, start) => _run(_report.selectDate(v, start)),
              onReset: () => _run(_report.reset())),
          toolbar: _toolbar(),
          isLoading: _report.loading,
          items: data?.entries ?? const [],
          columns: productSalesColumns(data?.currency ?? ''),
          cardBuilder: (row, _) =>
              ProductSalesCard(entry: row, currency: data?.currency ?? ''),
          emptyState: AppEmptyState(
              icon: Icons.bar_chart_rounded, title: _tr('no_data')),
          onRefresh: () => _run(_report.retry()),
          pagination: data == null
              ? null
              : ListPagination(
                  currentPage: data.pagination.currentPage,
                  totalPages: data.pagination.lastPage,
                  itemsPerPage: data.pagination.perPage,
                  onPageChanged: (page) => _run(_report.goToPage(page)),
                  countLabel: _tr('count')
                      .replaceAll('@count', '${data.entries.length}')),
        );
      });
}
