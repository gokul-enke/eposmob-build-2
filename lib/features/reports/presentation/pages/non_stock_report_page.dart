import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/report_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import '../../domain/models/non_stock_report.dart';
import '../export/non_stock_report_export.dart';
import '../state/non_stock_report_controller.dart';
import '../widgets/non_stock_report/non_stock_report_filters.dart';
import '../widgets/non_stock_report/non_stock_report_results.dart';
import '../widgets/report_error_bar.dart';

/// Listing only: no edit, details, purchasing or stock-write workflows.
class NonStockReportPage extends StatefulWidget {
  const NonStockReportPage({super.key, this.export});
  final ExportController? export;
  static const filterToggleKey = ValueKey('non-stock-report-filter-toggle');
  static const exportKey = ValueKey('non-stock-report-export');
  static const refreshKey = ValueKey('non-stock-report-refresh');
  @override
  State<NonStockReportPage> createState() => _NonStockReportPageState();
}

class _NonStockReportPageState extends State<NonStockReportPage> {
  late final NonStockReportController _report;
  late final AuthModel _auth;
  late final RoleProvider _roles;
  late final StoreSessionProvider _stores;
  late final CategoryProvider _categories;
  late final LocalProductProvider _products;
  late final ExportController _export = widget.export ?? ExportController();
  final _scroll = ScrollController();
  bool _showFilters = true;
  String _tr(String key) => 'non_stock_report.$key'.tr;
  bool get _permission =>
      _roles.currentUserHasPermissionSync('menu.reports.non_stock.access');
  @override
  void initState() {
    super.initState();
    final reports = context.read<ReportsProvider>();
    _auth = context.read<AuthModel>();
    _roles = context.read<RoleProvider>();
    _stores = context.read<StoreSessionProvider>();
    _categories = context.read<CategoryProvider>();
    _products = context.read<LocalProductProvider>();
    _report = NonStockReportController(
        readScope: () => reports.nonStockReportScope(_auth.token ?? ''),
        fetch: (q, page) => reports.fetchNonStockReportSnapshot(
            accessToken: _auth.token ?? '',
            store: q.store,
            category: q.category,
            product: q.product,
            barcode: q.barcode,
            page: page));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _report.load();
    });
  }

  @override
  void dispose() {
    _report.dispose();
    _scroll.dispose();
    if (widget.export == null) _export.dispose();
    super.dispose();
  }

  Future<File> _createExport() {
    final query = _report.query;
    return _report.export(
        build: (rows) => NonStockReportExport.build(rows, query),
        permissionUnchanged: () => mounted && _permission,
        progress: (page, total) => _export.setStage(
            'non_stock_report.export_fetching_page'
                .trParams({'page': '$page', 'total': '$total'})));
  }

  Future<void> _runExport() async {
    final result = await _export.run(context,
        createFile: _createExport, shareText: _tr('title'));
    if (!result && mounted) AppToast.error(context, _tr('export_error'));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge(
          [_report, _export, _stores, _categories, _products, _roles]),
      builder: (context, _) {
        final rows = _report.report?.data ?? <NonStockReportData>[];
        Map<String, String> names(Iterable<String?> source) => {
              for (final name in source)
                if (name != null && name.isNotEmpty) name: name
            };
        return ListPageScaffold<NonStockReportData>(
          header: PageHeader(
              icon: Icons.inventory_2_outlined,
              title: _tr('title'),
              subtitle: _tr('subtitle'),
              actions: [
                HeaderAction(
                    key: NonStockReportPage.filterToggleKey,
                    icon: Icons.filter_alt_rounded,
                    label: _showFilters
                        ? 'list.hide_filters'.tr
                        : 'list.filters'.tr,
                    active: _showFilters,
                    badge: !_showFilters && _report.hasActiveFilters,
                    onPressed: () =>
                        setState(() => _showFilters = !_showFilters)),
                HeaderAction(
                    key: NonStockReportPage.exportKey,
                    icon: Icons.ios_share_rounded,
                    label: _export.busy
                        ? (_export.stage ?? 'list.exporting'.tr)
                        : 'list.export'.tr,
                    busy: _export.busy,
                    onPressed: _permission && _report.canExport && !_export.busy
                        ? _runExport
                        : null),
                HeaderAction(
                    key: NonStockReportPage.refreshKey,
                    icon: Icons.refresh_rounded,
                    label: 'list.refresh'.tr,
                    onPressed: _report.retry),
              ]),
          showFilters: _showFilters,
          filters: nonStockReportFilters(
              barcode: _report.barcode,
              store: _report.store,
              category: _report.category,
              product: _report.product,
              resetRevision: _report.resetRevision,
              onSubmit: _report.submit,
              onReset: _report.reset,
              onStore: _report.setStore,
              onCategory: _report.setCategory,
              onProduct: _report.setProduct,
              stores: names(_stores.availableStores.map((s) => s.storeName)),
              categories: names(
                  (_categories.category ?? []).map((c) => c.categoryName)),
              products: names(_products.products.map((p) => p.productName))),
          mobileFilterTexts: CollapsedFilterTexts(
              title: 'list.filters'.tr,
              collapsedSubtitle: 'non_stock_report.show_filters_hint'.tr,
              expandedSubtitle: 'non_stock_report.hide_filters_hint'.tr),
          toolbar: _report.errorKey == null
              ? null
              : ReportErrorBar(
                  message: _report.errorKey!.tr,
                  retryLabel: 'non_stock_report.retry'.tr,
                  onRetry: _report.retry),
          isLoading: _report.loading,
          items: rows,
          columns: nonStockReportColumns(),
          cardBuilder: (row, n) => NonStockReportCard(row: row, number: n),
          minTableWidth: 1250,
          tableScrollController: _scroll,
          emptyState: AppEmptyState(
              icon: Icons.inventory_2_outlined, title: _tr('no_data_found')),
          onRefresh: _report.retry,
          pagination: ListPagination(
              currentPage: _report.page,
              totalPages: _report.totalPages,
              itemsPerPage: _report.perPage,
              onPageChanged: _report.goToPage,
              countLabel:
                  _tr('page_count').replaceAll('@count', '${rows.length}')),
        );
      });
}
