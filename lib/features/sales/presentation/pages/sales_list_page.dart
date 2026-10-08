import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/models/list_sales_order.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/screens/sales/widgets/sales_order_actions.dart';
import '../../data/sales_list_repository.dart';
import '../state/sales_list_controller.dart';
import '../widgets/sales_list_filters.dart';
import '../widgets/sales_list_rows.dart';
import '../export/sales_list_excel.dart';

class SalesListPage extends StatefulWidget {
  const SalesListPage(
      {super.key,
      this.isOnlineSales = false,
      this.source,
      this.exportController,
      this.actions,
      this.createWorkbook});
  final bool isOnlineSales;
  final SalesListSource? source;
  final ExportController? exportController;
  final Widget Function(ListOrderModelData)? actions;
  final Future<File> Function(List<ListOrderModelData>)? createWorkbook;
  static const exportKey = ValueKey('sales-list-export');
  static const filterKey = ValueKey('sales-list-filters');
  static const refreshKey = ValueKey('sales-list-refresh');
  @override
  State<SalesListPage> createState() => _SalesListPageState();
}

class _SalesListPageState extends State<SalesListPage>
    with SalesOrderActions<SalesListPage> {
  late final AuthModel _auth;
  late final SalesProvider _sales;
  late final StoreSessionProvider _stores;
  late final AppSettingsProvider _settings;
  late final SalesListController _controller;
  late final ExportController _export;
  final _scroll = ScrollController();
  bool _preparing = false, _wasBootstrapping = false;
  String? _sessionKey;
  int _sessionRevision = 0;
  @override
  bool get onlineSales => widget.isOnlineSales;
  @override
  bool get useSharedSalesActions => true;
  @override
  Future<void> refreshSalesOrders({bool preserveOnlineFilter = false}) =>
      _refresh();
  Future<void> _refresh() async {
    if (!mounted || _stores.isBootstrapping) return;
    await _controller.refresh();
  }

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthModel>();
    _sales = context.read<SalesProvider>();
    _stores = context.read<StoreSessionProvider>();
    _settings = context.read<AppSettingsProvider>();
    _sales.isOnlineSalesNavigation = widget.isOnlineSales;
    _controller = SalesListController(
        widget.source ?? SalesListRepository(), () => _auth.token ?? '',
        isOnlineSales: widget.isOnlineSales);
    _controller.storeId = _stores.activeStore?.storeId;
    _export = widget.exportController ?? ExportController();
    _export.addListener(_rebuild);
    _settings.addListener(_rebuild);
    _sessionKey = '${_auth.token}:${_stores.activeStore?.storeId}';
    _wasBootstrapping = _stores.isBootstrapping;
    _stores.addListener(_sessionChanged);
    _auth.addListener(_sessionChanged);
    _sales.attachListRefresh(this, _refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.showFilters =
          MediaQuery.sizeOf(context).width >= ListLayoutBreakpoints.mobileBelow;
      if (!_stores.isBootstrapping) _controller.search();
    });
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant SalesListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOnlineSales != widget.isOnlineSales) {
      _sessionRevision++;
      _sales.isOnlineSalesNavigation = widget.isOnlineSales;
      _controller.isOnlineSales = widget.isOnlineSales;
      _controller.clearFilters();
      _controller.invalidateSession(_stores.activeStore?.storeId);
      if (!_stores.isBootstrapping) _controller.search();
    }
  }

  void _sessionChanged() {
    if (!mounted) return;
    final key = '${_auth.token}:${_stores.activeStore?.storeId}';
    final changed =
        key != _sessionKey || (!_wasBootstrapping && _stores.isBootstrapping);
    final finished = _wasBootstrapping && !_stores.isBootstrapping;
    _sessionKey = key;
    _wasBootstrapping = _stores.isBootstrapping;
    if (changed) {
      _sessionRevision++;
      _controller.invalidateSession(_stores.activeStore?.storeId);
    }
    if ((changed || finished) && !_stores.isBootstrapping) _controller.search();
    _rebuild();
  }

  @override
  void dispose() {
    _sales.detachListRefresh(this);
    _export.removeListener(_rebuild);
    _settings.removeListener(_rebuild);
    _stores.removeListener(_sessionChanged);
    _auth.removeListener(_sessionChanged);
    if (widget.exportController == null) _export.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _copy(ListOrderModelData row) async {
    await Clipboard.setData(
        ClipboardData(text: row.customerReceiptNumber ?? ''));
    if (mounted) AppToast.success(context, 'sales.order_number_copied'.tr);
  }

  Future<void> _runExport() async {
    if (_export.busy || _preparing || _stores.isBootstrapping) return;
    _preparing = true;
    try {
      await _controller.prepareExport();
      if (!mounted || !_controller.canExport) return;
      final query = _controller.applied!, token = _auth.token ?? '';
      final revision = _sessionRevision;
      void checkSession() {
        if (!mounted ||
            revision != _sessionRevision ||
            _stores.isBootstrapping) {
          throw StateError('Sales export context changed');
        }
      }

      int? failedPage;
      final ok = await _export.run(context, createFile: () async {
        late final List<ListOrderModelData> rows;
        try {
          rows = await _controller.source.snapshot(token, query,
              progress: (page, last) {
            checkSession();
            _export.setStage(
                'sales.list_export_progress'.trParams({'page': '$page'}));
          });
        } on SalesListExportPageException catch (failure) {
          failedPage = failure.page;
          rethrow;
        }
        checkSession();
        final file = await (widget.createWorkbook?.call(rows) ??
            exportSalesListExcel(rows, isOnlineSales: query.isOnlineSales));
        checkSession();
        return file;
      });
      if (!ok && mounted) {
        AppToast.error(
            context,
            failedPage == null
                ? 'sales.list_export_error'.tr
                : 'sales.list_export_page_error'
                    .trParams({'page': '$failedPage'}));
      }
    } finally {
      _preparing = false;
    }
  }

  Widget _actions(ListOrderModelData row) =>
      widget.actions?.call(row) ?? buildSalesOrderActions(row, context);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final currency = _settings.appSettings?.currency ?? 'INR';
        return ListPageScaffold<ListOrderModelData>(
            header: PageHeader(
                icon: Icons.shopping_cart_outlined,
                title: (widget.isOnlineSales
                        ? 'sales.online_orders_list'
                        : 'sales.orders_list')
                    .tr,
                subtitle: 'sales.list_subtitle'.tr,
                actions: [
                  HeaderAction(
                      key: SalesListPage.filterKey,
                      icon: _controller.showFilters
                          ? Icons.filter_alt_rounded
                          : Icons.filter_alt_outlined,
                      label: 'list.filters'.tr,
                      active: _controller.showFilters,
                      badge:
                          !_controller.showFilters && _controller.query.active,
                      onPressed: _controller.toggleFilters),
                  HeaderAction(
                      key: SalesListPage.exportKey,
                      icon: Icons.ios_share_rounded,
                      label: _export.stage ??
                          (_export.busy
                              ? 'list.exporting'.tr
                              : 'list.export'.tr),
                      busy: _export.busy,
                      onPressed: _controller.loading ||
                              _controller.error != null ||
                              _controller.rows.isEmpty
                          ? null
                          : _runExport),
                  HeaderAction(
                      key: SalesListPage.refreshKey,
                      icon: Icons.refresh_rounded,
                      label: 'list.refresh'.tr,
                      onPressed: _refresh),
                ]),
            filters: salesListFilters(_controller),
            showFilters: _controller.showFilters,
            mobileFilterTexts: CollapsedFilterTexts(
                title: 'list.filters'.tr,
                collapsedSubtitle: 'sales.list_filter_hint'.tr,
                expandedSubtitle: 'sales.list_filter_hint'.tr),
            toolbar: _controller.error == null
                ? null
                : AppSurface(
                    child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                        Text('sales.list_load_error'.tr,
                            style: AppTextStyles.sectionHint),
                        AppOutlinedButton(
                            label: 'sales.retry'.tr,
                            icon: Icons.refresh,
                            onPressed: () =>
                                _controller.load(_controller.requestedPage))
                      ])),
            isLoading: _controller.loading,
            items: _controller.rows,
            columns: salesListColumns(_actions, _copy, currency),
            cardBuilder: (row, _) =>
                salesListCard(row, _actions(row), _copy, currency),
            emptyState: AppEmptyState(
                icon: Icons.shopping_cart_outlined,
                title: (_controller.query.active
                        ? 'sales.no_orders_match_filters'
                        : 'sales.no_orders_available')
                    .tr),
            minTableWidth: 1130,
            tableScrollController: _scroll,
            onRefresh: _refresh,
            pagination: ListPagination(
                currentPage: _controller.current,
                totalPages: _controller.last,
                totalPagesKnown: _controller.data?.totalPagesKnown ?? true,
                enabled: _controller.error == null && _controller.matchesInputs,
                itemsPerPage: _controller.data?.perPage ?? 10,
                countLabel: 'sales.list_count'
                    .trParams({'count': '${_controller.rows.length}'}),
                onPageChanged: _controller.load));
      });
}
