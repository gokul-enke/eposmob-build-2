import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/purchase_price_permission.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/report_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:provider/provider.dart';
import '../../domain/models/stock_report.dart';
import '../../domain/stock_report_query.dart';
import '../export/stock_report_export.dart';
import '../state/stock_report_controller.dart';
import '../widgets/report_error_bar.dart';
import '../widgets/stock_report/stock_report_filters.dart';
import '../widgets/stock_report/stock_report_results.dart';

/// Listing only. Directories remain the shell's existing cached directories.
class StockReportPage extends StatefulWidget {
  const StockReportPage({super.key, this.export});
  final ExportController? export;
  static const filterToggleKey = ValueKey('stock-report-filter-toggle');
  static const filtersKey = ValueKey('stock-report-filters');
  static const exportKey = ValueKey('stock-report-export');
  @override
  State<StockReportPage> createState() => _StockReportPageState();
}

class _StockReportPageState extends State<StockReportPage> {
  late final StockReportController _report;
  late final ExportController _export = widget.export ?? ExportController();
  late final StoreSessionProvider _stores;
  late final CategoryProvider _categories;
  late final LocalProductProvider _products;
  late final RoleProvider _roles;
  final _scroll = ScrollController();
  bool _visibilityInitialized = false;
  String _tr(String key) => 'stock_report.$key'.tr;
  bool get _showCosts =>
      _roles.currentUserHasPermissionSync(purchaseOrdersAccessPermission);
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthModel>(),
        reports = context.read<ReportsProvider>();
    _stores = context.read<StoreSessionProvider>();
    _categories = context.read<CategoryProvider>();
    _products = context.read<LocalProductProvider>();
    _roles = context.read<RoleProvider>();
    _report = StockReportController(
        readScope: () => reports.stockReportApi.scope(auth.token ?? ''),
        fetch: (q, page, perPage) => reports.fetchStockReportSnapshot(
            accessToken: auth.token ?? '',
            product: q.product,
            storeId: q.storeId,
            categoryId: q.categoryId,
            stockLevel: q.stockLevelParameter,
            expiringWithin: q.expiryParameter,
            snapshotDate: StockReportQuery.date(q.snapshot),
            from: StockReportQuery.date(q.from),
            until: StockReportQuery.date(q.until),
            page: page,
            perPage: perPage));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _report.load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_visibilityInitialized) {
      _report.showFilters =
          MediaQuery.sizeOf(context).width >= ListLayoutBreakpoints.mobileBelow;
      _visibilityInitialized = true;
    }
  }

  @override
  void dispose() {
    _report.dispose();
    _scroll.dispose();
    if (widget.export == null) _export.dispose();
    super.dispose();
  }

  Future<File> _createExport() {
    final showCosts = _showCosts;
    return _report.export(
        build: (rows) => StockReportExport.build(rows, showCosts: showCosts),
        permissionUnchanged: () => _showCosts == showCosts,
        progress: (page, total) {
          if (mounted) {
            _export.setStage(_tr('export_fetching')
                .replaceAll('@page', '$page')
                .replaceAll('@total', '$total'));
          }
        });
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
        final showCosts = _showCosts, summary = _report.report?.summary;
        final rows = _report.report?.data ?? <StockReportData>[];
        return ListPageScaffold<StockReportData>(
          header: PageHeader(
              icon: Icons.inventory_2_outlined,
              title: _tr('title'),
              subtitle: _tr('subtitle'),
              actions: [
                HeaderAction(
                    key: StockReportPage.filterToggleKey,
                    icon: Icons.filter_alt_outlined,
                    label: _report.showFilters
                        ? 'list.hide_filters'.tr
                        : 'list.filters'.tr,
                    active: _report.showFilters,
                    badge: !_report.showFilters && _report.query.active,
                    onPressed: () => _report.setFilters(!_report.showFilters)),
                HeaderAction(
                    key: StockReportPage.exportKey,
                    icon: Icons.ios_share_rounded,
                    label: _export.busy
                        ? (_export.stage ?? 'list.exporting'.tr)
                        : 'list.export'.tr,
                    busy: _export.busy,
                    onPressed:
                        _report.canExport && !_export.busy ? _runExport : null),
                HeaderAction(
                    icon: Icons.refresh_rounded,
                    label: 'list.refresh'.tr,
                    onPressed: _report.loading ? null : _report.retry),
              ]),
          showFilters: _report.showFilters,
          mobileFilterTexts: CollapsedFilterTexts(
              title: _tr('find'),
              collapsedSubtitle: _tr('filter_hint'),
              expandedSubtitle: _tr('filter_hint')),
          filters: StockReportFilters(
              key: StockReportPage.filtersKey,
              query: _report.query,
              revision: _report.resetRevision,
              stores: [
                for (final s in _stores.availableStores)
                  if (s.storeId != null)
                    StockReportOption('${s.storeId}', s.storeName ?? '')
              ],
              categories: [
                for (final c in _categories.category ?? [])
                  if (c.categoryId != null)
                    StockReportOption('${c.categoryId}', c.categoryName ?? '')
              ],
              products: [
                for (final p in _products.products)
                  if (p.productName?.isNotEmpty == true)
                    StockReportOption(p.productName!, p.productName!)
              ],
              store: _report.store,
              category: _report.category,
              product: _report.product,
              onStore: _report.setStore,
              onCategory: _report.setCategory,
              onProduct: _report.setProduct,
              onLevel: _report.setLevel,
              onExpiry: _report.setExpiry,
              onDate: _report.setDate,
              onReset: _report.reset),
          toolbar: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_report.errorKey != null) ...[
              ReportErrorBar(
                  message: _report.errorKey!.tr,
                  retryLabel: _tr('retry'),
                  onRetry: _report.retry),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (summary != null)
              StockReportTotals(summary: summary, showCosts: showCosts),
          ]),
          isLoading: _report.loading,
          items: rows,
          columns: stockReportColumns(showCosts: showCosts),
          cardBuilder: (r, number) =>
              StockReportCard(row: r, number: number, showCosts: showCosts),
          minTableWidth: ListLayoutBreakpoints.maxContentWidth,
          tableScrollController: _scroll,
          emptyState: AppEmptyState(
              icon: Icons.inventory_2_outlined, title: _tr('no_data_found')),
          onRefresh: _report.retry,
          pagination: ListPagination(
              currentPage: _report.page,
              totalPages: _report.totalPages,
              itemsPerPage: _report.perPage,
              onPageChanged: _report.goToPage,
              countLabel: _tr('count').replaceAll('@count', '${rows.length}')),
        );
      });
}
