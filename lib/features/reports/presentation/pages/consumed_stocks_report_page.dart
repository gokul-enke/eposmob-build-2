import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/report_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import '../../data/consumed_stocks_store_directory.dart';
import '../../domain/models/consumed_stocks_report.dart';
import '../export/consumed_stocks_report_export.dart';
import '../state/consumed_stocks_report_controller.dart';
import '../widgets/consumed_stocks_report/consumed_stocks_report_filters.dart';
import '../widgets/consumed_stocks_report/consumed_stocks_report_results.dart';
import '../widgets/report_error_bar.dart';

class ConsumedStocksReportPage extends StatefulWidget {
  const ConsumedStocksReportPage({super.key, this.export});
  final ExportController? export;
  static const filterToggleKey =
          ValueKey('consumed-stocks-report-filter-toggle'),
      exportKey = ValueKey('consumed-stocks-report-export'),
      refreshKey = ValueKey('consumed-stocks-report-refresh');
  @override
  State<ConsumedStocksReportPage> createState() =>
      _ConsumedStocksReportPageState();
}

class _ConsumedStocksReportPageState extends State<ConsumedStocksReportPage> {
  late final ConsumedStocksReportController _report;
  late final AuthModel _auth;
  late final RoleProvider _roles;
  late final LocalProductProvider _products;
  late final ExportController _export = widget.export ?? ExportController();
  final _scroll = ScrollController();
  bool _showFilters = true, _cancelled = false;
  // Built once per product-list change, not on every report/export notify:
  // the same instance lets the picker skip its 10k-entry comparison.
  Map<String, String>? _productOptions;
  Map<String, String> get _productMap => _productOptions ??= {
        for (final p in _products.products)
          if (p.productId != null && p.productName != null)
            '${p.productId}': p.productName!
      };
  void _productsChanged() => _productOptions = null;
  String _tr(String key) => 'consumed_stocks_report.$key'.tr;
  bool get _permission =>
      _roles.currentUserHasPermissionSync('menu.reports.consumed_stock.access');
  @override
  void initState() {
    super.initState();
    final reports = context.read<ReportsProvider>();
    _auth = context.read<AuthModel>();
    _roles = context.read<RoleProvider>();
    _products = context.read<LocalProductProvider>()
      ..addListener(_productsChanged);
    _report = ConsumedStocksReportController(
        readScope: () => reports.consumedStocksReportScope(_auth.token ?? ''),
        loadStores: consumedStocksStores,
        fetch: (q, page) => reports.fetchConsumedStocksReportSnapshot(
            accessToken: _auth.token ?? '',
            productId: q.productId,
            storeId: q.storeId,
            from: q.apiFrom,
            until: q.apiUntil,
            page: page));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _report.initialize();
    });
  }

  @override
  void dispose() {
    _products.removeListener(_productsChanged);
    _report.dispose();
    _scroll.dispose();
    if (widget.export == null) _export.dispose();
    super.dispose();
  }

  Future<File> _createExport() async {
    final query = _report.query;
    try {
      return await _report.export(
          build: (rows) => ConsumedStocksReportExport.build(rows, query),
          permissionUnchanged: () => mounted && _permission,
          progress: (page, total) => _export.setStage(
              'consumed_stocks_report.export_fetching_page'
                  .trParams({'page': '$page', 'total': '$total'})));
    } on ConsumedStocksExportCancelled {
      _cancelled = true;
      rethrow;
    }
  }

  Future<void> _runExport() async {
    _cancelled = false;
    final success = await _export.run(context,
        createFile: _createExport, shareText: _tr('title'));
    if (!success && mounted) {
      if (_cancelled) {
        AppToast.info(context, _tr('export_cancelled'));
      } else {
        AppToast.error(context, _tr('export_error'));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([_report, _export, _roles, _products]),
      builder: (context, _) {
        final rows = _report.report?.data?.data ?? <ConsumedStockData>[];
        return ListPageScaffold<ConsumedStockData>(
            header: PageHeader(
                icon: Icons.inventory_2_outlined,
                title: _tr('title'),
                subtitle: _tr('subtitle'),
                actions: [
                  HeaderAction(
                      key: ConsumedStocksReportPage.filterToggleKey,
                      icon: Icons.filter_alt_rounded,
                      label: _showFilters
                          ? 'list.hide_filters'.tr
                          : 'list.filters'.tr,
                      active: _showFilters,
                      badge: !_showFilters && !_report.query.isEmpty,
                      onPressed: () =>
                          setState(() => _showFilters = !_showFilters)),
                  HeaderAction(
                      key: ConsumedStocksReportPage.exportKey,
                      icon: Icons.ios_share_rounded,
                      label: _export.busy
                          ? (_export.stage ?? 'list.exporting'.tr)
                          : 'list.export'.tr,
                      busy: _export.busy,
                      onPressed:
                          _permission && _report.canExport && !_export.busy
                              ? _runExport
                              : null),
                  HeaderAction(
                      key: ConsumedStocksReportPage.refreshKey,
                      icon: Icons.refresh_rounded,
                      label: 'list.refresh'.tr,
                      onPressed: _report.retry),
                ]),
            showFilters: _showFilters,
            mobileFilterTexts: CollapsedFilterTexts(
                title: 'list.filters'.tr,
                collapsedSubtitle: _tr('show_filters_hint'),
                expandedSubtitle: _tr('hide_filters_hint')),
            filters: consumedStocksReportFilters(
                productId: _report.productId,
                storeId: _report.storeId,
                from: _report.from,
                until: _report.until,
                resetRevision: _report.resetRevision,
                products: _productMap,
                stores: _report.stores,
                onProduct: _report.setProduct,
                onStore: _report.setStore,
                onFrom: _report.setFrom,
                onUntil: _report.setUntil,
                onReset: _report.reset),
            toolbar: _report.errorKey == null
                ? null
                : ReportErrorBar(
                    message: _report.errorKey!.tr,
                    retryLabel: 'consumed_stocks_report.retry'.tr,
                    onRetry: _report.retry),
            isLoading: _report.loading,
            items: rows,
            columns: consumedStocksColumns(),
            cardBuilder: (row, n) => ConsumedStocksCard(row: row, number: n),
            minTableWidth: 1100,
            tableScrollController: _scroll,
            emptyState: AppEmptyState(
                icon: Icons.inventory_2_outlined,
                title: _tr('no_records_found'),
                subtitle: _tr('try_adjusting_filters')),
            onRefresh: _report.retry,
            pagination: ListPagination(
                currentPage: _report.page,
                totalPages: _report.totalPages,
                itemsPerPage: _report.perPage,
                onPageChanged: _report.goToPage,
                countLabel:
                    _tr('page_count').replaceAll('@count', '${rows.length}')));
      });
}
