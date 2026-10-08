import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/quotations_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';
import 'package:pos_machine/models/quotation_model.dart';
import '../../data/quotation_list_repository.dart';
import '../state/quotation_list_controller.dart';
import '../navigation/quotation_list_navigation.dart';
import '../export/quotation_list_excel.dart';
import '../widgets/list/quotation_list_filters.dart';
import '../widgets/list/quotation_list_rows.dart';
import 'quotation_list_actions.dart';

class QuotationsListScreen extends StatefulWidget {
  const QuotationsListScreen(
      {super.key,
      this.source,
      this.exportController,
      this.onView,
      this.onConvert,
      this.onPrint,
      this.onAdd});
  final QuotationListSource? source;
  final ExportController? exportController;
  final ValueChanged<Quotation>? onView, onConvert, onPrint;
  final VoidCallback? onAdd;
  static const filterToggleKey = ValueKey('quotation-list-filter-toggle');
  static const exportKey = ValueKey('quotation-list-export');
  static const refreshKey = ValueKey('quotation-list-refresh');
  @override
  State<QuotationsListScreen> createState() => _QuotationsListScreenState();
}

class _QuotationsListScreenState extends State<QuotationsListScreen>
    with QuotationListActions<QuotationsListScreen> {
  @override
  late final AuthModel auth;
  @override
  late final QuotationsProvider quotationProvider;
  @override
  late final QuotationListNavigation quotationNavigation;
  LocalProductProvider? _products;
  @override
  LocalProductProvider get localProducts => _products!;
  late final CustomerProvider _customers;
  late final StoreSessionProvider _stores;
  late final QuotationListController _controller;
  late final ExportController _export;
  final _tableScroll = ScrollController();
  bool _exportPreparing = false;
  String? _sessionKey;
  int _sessionRevision = 0;
  bool _storeWasBootstrapping = false;

  @override
  void initState() {
    super.initState();
    auth = context.read<AuthModel>();
    quotationProvider = context.read<QuotationsProvider>();
    _customers = context.read<CustomerProvider>();
    _stores = context.read<StoreSessionProvider>();
    if (widget.onConvert == null) {
      _products = context.read<LocalProductProvider>();
    }
    quotationNavigation = QuotationListNavigation(
        Get.put(SideBarController()), quotationProvider);
    _controller = QuotationListController(
        widget.source ?? QuotationListRepository(), () => auth.token ?? '');
    _export = widget.exportController ?? ExportController();
    _export.addListener(_rebuild);
    _customers.addListener(_rebuild);
    _sessionKey = '${auth.token}:${_stores.activeStore?.storeId}';
    _storeWasBootstrapping = _stores.isBootstrapping;
    _stores.addListener(_sessionChanged);
    auth.addListener(_sessionChanged);
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

  void _sessionChanged() {
    if (!mounted) return;
    final key = '${auth.token}:${_stores.activeStore?.storeId}';
    final changed = key != _sessionKey;
    final finished = _storeWasBootstrapping && !_stores.isBootstrapping;
    _sessionKey = key;
    _storeWasBootstrapping = _stores.isBootstrapping;
    if (changed) {
      _sessionRevision++;
      _controller.invalidateSession();
    }
    if ((changed || finished) && !_stores.isBootstrapping) _controller.search();
    _rebuild();
  }

  @override
  void dispose() {
    _export.removeListener(_rebuild);
    _customers.removeListener(_rebuild);
    _stores.removeListener(_sessionChanged);
    auth.removeListener(_sessionChanged);
    if (widget.exportController == null) _export.dispose();
    _controller.dispose();
    _tableScroll.dispose();
    super.dispose();
  }

  Future<void> _copy(Quotation row) async {
    await Clipboard.setData(ClipboardData(text: row.quotationNumber ?? ''));
    if (mounted) AppToast.success(context, 'quotations.copy_success'.tr);
  }

  Future<void> _runExport() async {
    if (_export.busy || _exportPreparing) return;
    _exportPreparing = true;
    try {
      await _controller.prepareExport();
      if (!mounted) return;
      if (!_controller.canExport) {
        // The refreshed list failed or is empty; say why nothing was exported.
        if (_controller.error != null) {
          AppToast.error(context, 'quotations.list_export_error'.tr);
        } else if (!_controller.loading && _controller.rows.isEmpty) {
          AppToast.error(context, 'quotations.list_export_empty'.tr);
        }
        return;
      }
      final query = _controller.applied!;
      final token = auth.token ?? '';
      final source = _controller.source;
      final sessionRevision = _sessionRevision;
      final ok = await _export.run(context, createFile: () async {
        final rows =
            await source.snapshot(token, query, progress: (page, last) {
          if (!mounted || sessionRevision != _sessionRevision) {
            throw StateError('Quotation export context changed');
          }
          _export.setStage(
              'quotations.list_export_progress'.trParams({'page': '$page'}));
        });
        if (!mounted || sessionRevision != _sessionRevision) {
          throw StateError('Quotation export context changed');
        }
        final file = await exportQuotationListExcel(rows);
        // Encoding and writing the workbook are asynchronous too. Recheck
        // before handing it to Save As/share, including a switch away and back.
        if (!mounted || sessionRevision != _sessionRevision) {
          throw StateError('Quotation export context changed');
        }
        return file;
      });
      if (!ok && mounted) {
        AppToast.error(context, 'quotations.list_export_error'.tr);
      }
    } finally {
      _exportPreparing = false;
    }
  }

  Widget _actions(Quotation row) => QuotationRowActions(
      row: row,
      converting: isConvertingQuotation,
      printing: isPrintingQuotation,
      onView: widget.onView ?? (q) => quotationNavigation.openView(q.id),
      onConvert: widget.onConvert ?? convertQuotationToOrder,
      onPrint: widget.onPrint ?? printQuotation);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => ListPageScaffold<Quotation>(
            header: PageHeader(
                icon: Icons.description_outlined,
                title: 'quotations.title'.tr,
                subtitle: 'quotations.subtitle'.tr,
                addLabel: 'quotations.new_quotation'.tr,
                addShortLabel: 'quotations.list_new_short'.tr,
                onAdd: widget.onAdd ?? quotationNavigation.openNew,
                actions: [
                  HeaderAction(
                      key: QuotationsListScreen.filterToggleKey,
                      icon: _controller.showFilters
                          ? Icons.filter_alt_rounded
                          : Icons.filter_alt_outlined,
                      label: 'list.filters'.tr,
                      active: _controller.showFilters,
                      badge:
                          !_controller.showFilters && _controller.query.active,
                      onPressed: _controller.toggleFilters),
                  HeaderAction(
                      key: QuotationsListScreen.exportKey,
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
                      key: QuotationsListScreen.refreshKey,
                      icon: Icons.refresh_rounded,
                      label: 'list.refresh'.tr,
                      onPressed: () => _controller.load(_controller.current)),
                ]),
            filters: quotationListFilters(_controller, [
              for (final customer in _customers.allCustomers ?? [])
                if (customer.id != null)
                  QuotationFilterOption('${customer.id}',
                      '${customer.name ?? ''} (${customer.phone ?? ''})')
            ], [
              for (final store in _stores.availableStores)
                if (store.storeId != null)
                  QuotationFilterOption(
                      '${store.storeId}', store.storeName ?? '')
            ]),
            showFilters: _controller.showFilters,
            toolbar: _controller.error == null
                ? null
                : AppSurface(
                    child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                        Text('quotations.list_load_error'.tr,
                            style: AppTextStyles.sectionHint),
                        AppOutlinedButton(
                            label: 'quotations.list_retry'.tr,
                            icon: Icons.refresh,
                            onPressed: () =>
                                _controller.load(_controller.requestedPage))
                      ])),
            isLoading: _controller.loading,
            items: _controller.rows,
            columns: quotationListColumns(_actions, _copy),
            cardBuilder: (row, _) =>
                quotationListCard(row, _actions(row), _copy),
            emptyState: AppEmptyState(
                icon: Icons.description_outlined,
                title: (_controller.query.active
                        ? 'quotations.no_quotations_filtered'
                        : 'quotations.no_quotations')
                    .tr),
            minTableWidth: 1040,
            tableScrollController: _tableScroll,
            onRefresh: () => _controller.load(_controller.current),
            pagination: ListPagination(
                currentPage: _controller.current,
                totalPages: _controller.last,
                totalPagesKnown: _controller.data?.totalPagesKnown ?? true,
                itemsPerPage: _controller.data?.perPage ?? 20,
                countLabel: 'quotations.list_count'
                    .trParams({'count': '${_controller.rows.length}'}),
                enabled: !_controller.loading,
                onPageChanged: _controller.load),
          ));
}
