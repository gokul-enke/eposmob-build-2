import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import '../../../reports/presentation/widgets/report_error_bar.dart';
import '../../data/general_payment_api.dart';
import '../../domain/models/general_payment.dart';
import '../export/general_payment_export.dart';
import '../navigation/general_payment_navigation.dart';
import '../state/general_payment_list_controller.dart';
import '../widgets/general_payment_details_dialog.dart';
import '../widgets/general_payment_filters.dart';
import '../widgets/general_payment_results.dart';
import '../widgets/general_payment_totals_strip.dart';

/// General Payments as in the web admin panel (Accounts → General
/// Payments): expenses, assets, income and loans in one list, with the four
/// type totals, export and New Entry.
class GeneralPaymentListPage extends StatefulWidget {
  const GeneralPaymentListPage({super.key, this.api, this.export});

  /// Injected in tests.
  final GeneralPaymentApi? api;
  final ExportController? export;

  static const filterToggleKey = ValueKey('general-payments-filter-toggle');
  static const exportKey = ValueKey('general-payments-export');
  static const refreshKey = ValueKey('general-payments-refresh');

  @override
  State<GeneralPaymentListPage> createState() => _GeneralPaymentListPageState();
}

class _GeneralPaymentListPageState extends State<GeneralPaymentListPage> {
  late final GeneralPaymentApi _api = widget.api ?? GeneralPaymentApi();
  late final ExportController _export = widget.export ?? ExportController();
  late final AuthModel _auth;
  late final AppSettingsProvider _settings;
  late final StoreSessionProvider _stores;
  late final GeneralPaymentListController _list;
  ({String? token, int? user, int? store})? _session;
  final _scroll = ScrollController();
  bool? _showFilters;

  /// The session changed while another route covered this page.
  bool _loadPending = false;
  String get _currency => _settings.appSettings?.currency ?? '';
  String _tr(String key) => 'general_payments.$key'.tr;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthModel>();
    _settings = context.read<AppSettingsProvider>();
    _stores = context.read<StoreSessionProvider>();
    _list = GeneralPaymentListController(fetch: (isCurrent) {
      final token = _auth.token ?? '';
      if (token.isEmpty) throw StateError('Not signed in.');
      return _api.fetchAll(accessToken: token, isCurrent: isCurrent);
    });
    _session = _readSession();
    _auth.addListener(_sessionChanged);
    _stores.addListener(_sessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _list.load();
    });
  }

  ({String? token, int? user, int? store}) _readSession() => (
        token: _auth.token,
        user: _auth.userId,
        store: _stores.activeStore?.storeId
      );

  /// Another user or store while the page is open: the entries on screen
  /// belong to the old one, so they are dropped and loaded again.
  void _sessionChanged() {
    if (!mounted) return;
    final session = _readSession();
    if (session == _session) return;
    _session = session;
    // A page left under another route loads when it is shown again.
    if (ModalRoute.of(context)?.isCurrent ?? true) {
      _list.load(clear: true);
    } else {
      setState(() => _loadPending = true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Before the first frame, so phones never flash the expanded filters.
    _showFilters ??=
        MediaQuery.sizeOf(context).width >= ListLayoutBreakpoints.mobileBelow;
  }

  @override
  void dispose() {
    _auth.removeListener(_sessionChanged);
    _stores.removeListener(_sessionChanged);
    _list.dispose();
    _scroll.dispose();
    if (widget.export == null) _export.dispose();
    super.dispose();
  }

  void _view(GeneralPayment row) =>
      showGeneralPaymentDetails(context, row, _currency);

  Future<void> _runExport() async {
    // A snapshot of what is on screen, described by the filters it used.
    final rows = List<GeneralPayment>.of(_list.filteredRows);
    final filters = GeneralPaymentExport.describe(_list.appliedFilters);
    final currency = _currency;
    final ok = await _export.run(context,
        shareText: _tr('title'),
        createFile: () =>
            GeneralPaymentExport.build(rows, filters, currency: currency));
    if (!ok && mounted) AppToast.error(context, _tr('export_error'));
  }

  Widget? _toolbar() {
    final children = [
      if (_list.errorKey case final key?)
        ReportErrorBar(
            message: key.tr,
            retryLabel: _tr('retry'),
            onRetry: _list.load,
            retryEnabled: !_list.loading),
      if (_list.filterErrorKey case final key?)
        ReportErrorBar(message: key.tr, retryLabel: _tr('retry')),
      if (_list.loaded)
        GeneralPaymentTotalsStrip(totals: _list.totals, currency: _currency),
    ];
    if (children.isEmpty) return null;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (final child in children) ...[
        child,
        if (child != children.last) const SizedBox(height: AppSpacing.sm),
      ]
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // Depends on the route, so a covered page rebuilds when shown again.
    if (_loadPending && (ModalRoute.of(context)?.isCurrent ?? true)) {
      _loadPending = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _list.load(clear: true);
      });
    }
    return ListenableBuilder(
        listenable: Listenable.merge([_list, _export, _settings]),
        builder: (context, _) {
          final show = _showFilters ?? true;
          return ListPageScaffold<GeneralPayment>(
            header: PageHeader(
                icon: Icons.account_balance_outlined,
                title: _tr('title'),
                subtitle: _tr('subtitle'),
                onAdd: () => GeneralPaymentNavigation.openCreate(
                    type: _list.filter.type,
                    nextReferences: _list.nextReferences),
                addLabel: _tr('new_entry'),
                addShortLabel: _tr('new_entry_short'),
                actions: [
                  HeaderAction.filters(
                      key: GeneralPaymentListPage.filterToggleKey,
                      showFilters: show,
                      showLabel: 'list.filters'.tr,
                      hideLabel: 'list.hide_filters'.tr,
                      badge: !show && _list.hasActiveFilters,
                      onPressed: () => setState(() => _showFilters = !show)),
                  HeaderAction(
                      key: GeneralPaymentListPage.exportKey,
                      icon: Icons.ios_share_rounded,
                      label: _export.busy
                          ? (_export.stage ?? 'list.exporting'.tr)
                          : 'list.export'.tr,
                      busy: _export.busy,
                      onPressed:
                          _list.canExport && !_export.busy ? _runExport : null),
                  HeaderAction(
                      key: GeneralPaymentListPage.refreshKey,
                      icon: Icons.refresh_rounded,
                      label: 'list.refresh'.tr,
                      onPressed: _list.loading ? null : _list.load),
                ]),
            showFilters: show,
            filters: generalPaymentFilters(_list),
            mobileFilterTexts: CollapsedFilterTexts(
                title: 'list.filters'.tr,
                collapsedSubtitle: _tr('show_filters_hint'),
                expandedSubtitle: _tr('hide_filters_hint')),
            toolbar: _toolbar(),
            isLoading: _list.loading,
            items: _list.pageRows,
            columns: generalPaymentColumns(_currency, onView: _view),
            cardBuilder: (row, _) => GeneralPaymentCard(
                row: row, currency: _currency, onView: _view),
            onRowTap: _view,
            minTableWidth: 1300,
            tableScrollController: _scroll,
            emptyState: AppEmptyState(
                icon: Icons.account_balance_outlined,
                title: _list.hasActiveFilters
                    ? _tr('no_matches')
                    : _tr('no_data')),
            onRefresh: _list.load,
            pagination: ListPagination(
                currentPage: _list.page,
                totalPages: _list.totalPages,
                itemsPerPage: GeneralPaymentListController.pageSize,
                enabled: !_list.loading,
                onPageChanged: _list.goToPage,
                countLabel: generalPaymentCountLabel(_list)),
          );
        });
  }
}
