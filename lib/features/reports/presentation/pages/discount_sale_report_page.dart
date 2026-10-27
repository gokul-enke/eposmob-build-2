import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import '../../data/discount_sale_report_api.dart';
import '../../domain/discount_sale_report_query.dart';
import '../../domain/models/discount_sale_report.dart';
import '../export/discount_sale_report_export.dart';
import '../state/discount_sale_report_controller.dart';
import '../widgets/discount_sale_report/discount_sale_report_filters.dart';
import '../widgets/discount_sale_report/discount_sale_report_results.dart';
import '../widgets/report_error_bar.dart';

/// Discount Sale Report as in the web admin panel: discounted orders with the
/// cart-items and overall-order discount. Listing and export only.
class DiscountSaleReportPage extends StatefulWidget {
  const DiscountSaleReportPage({super.key, this.api, this.export});

  /// Injected in tests.
  final DiscountSaleReportApi? api;
  final ExportController? export;

  static const filterToggleKey = ValueKey('discount-sale-report-filter-toggle');
  static const exportKey = ValueKey('discount-sale-report-export');
  static const refreshKey = ValueKey('discount-sale-report-refresh');

  @override
  State<DiscountSaleReportPage> createState() => _DiscountSaleReportPageState();
}

class _DiscountSaleReportPageState extends State<DiscountSaleReportPage> {
  late final DiscountSaleReportApi _api = widget.api ?? DiscountSaleReportApi();
  late final ExportController _export = widget.export ?? ExportController();
  late final AuthModel _auth;
  late final RoleProvider _roles;
  late final AppSettingsProvider _settings;
  late final StoreSessionProvider _stores;
  late DiscountSaleReportController _report;
  ({String? token, int? user, int? store, String? role})? _session;
  final _scroll = ScrollController();
  bool? _showFilters;

  /// The session changed while another route covered this page.
  bool _initPending = false;
  String get _token => _auth.token ?? '';
  String get _currency => _settings.appSettings?.currency ?? 'INR';
  String _tr(String key) => 'discount_sale_report.$key'.tr;
  bool get _permission => _roles.currentUserCanAccessDiscountSaleReportSync();

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthModel>();
    _roles = context.read<RoleProvider>();
    _settings = context.read<AppSettingsProvider>();
    _stores = context.read<StoreSessionProvider>();
    _session = _readSession();
    _report = _createReport();
    _auth.addListener(_sessionChanged);
    _stores.addListener(_sessionChanged);
    _roles.addListener(_sessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _report.initialize();
    });
  }

  DiscountSaleReportController _createReport() {
    final locked = _locked();
    return DiscountSaleReportController(
        readScope: () => _api.scope(_token),
        fetch: (params, page, perPage) => _api.fetch(
            accessToken: _token,
            parameters: params,
            page: page,
            perPage: perPage),
        locked: locked,
        // A locked filter with its name needs no list.
        loaders: _loaders()
          ..removeWhere(
              (filter, _) => locked[filter]?.label.trim().isNotEmpty ?? false));
  }

  /// Who is using the report: a change starts it over (see [_sessionChanged]).
  ({String? token, int? user, int? store, String? role}) _readSession() => (
        token: _auth.token,
        user: _auth.userId,
        store: _stores.activeStore?.storeId,
        role: _roles.currentUserRole
      );

  /// Another user switching in, or a store or role change, while the report
  /// is open: start over with that session's filters and locks, as the Admin
  /// Executive report does, so nobody keeps someone else's locks.
  void _sessionChanged() {
    if (!mounted) return;
    final session = _readSession();
    if (session == _session) return;
    _session = session;
    final old = _report;
    setState(() => _report = _createReport());
    old.dispose();
    // A page left under another route (e.g. after a store switch) loads when
    // it is shown again, not in the background.
    if (ModalRoute.of(context)?.isCurrent ?? true) {
      _report.initialize();
    } else {
      _initPending = true;
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
    _roles.removeListener(_sessionChanged);
    _report.dispose();
    _scroll.dispose();
    if (widget.export == null) _export.dispose();
    super.dispose();
  }

  /// A sales executive sees only their own discounts in the store they are
  /// logged into: those two filters are fixed for them, with their names
  /// known up front.
  Map<DiscountSaleReportFilter, DiscountSaleReportOption> _locked() {
    if (_roles.currentUserRole != 'sales_executive') return const {};
    final user = _auth.userId;
    final store = _stores.activeStore;
    return {
      if (user != null)
        DiscountSaleReportFilter.salesExecutive: DiscountSaleReportOption(
            '$user',
            context
                    .read<SalesExecutiveProvider>()
                    .getCurrentUser(context)
                    ?.name ??
                ''),
      if (store?.storeId case final int id)
        DiscountSaleReportFilter.store:
            DiscountSaleReportOption('$id', store!.storeName ?? ''),
    };
  }

  static List<DiscountSaleReportOption> _clean(
          Iterable<DiscountSaleReportOption> all) =>
      [
        for (final o in all)
          if (o.id.isNotEmpty && o.id != 'null' && o.label.trim().isNotEmpty) o
      ];

  /// Picker options from the app's existing directories. Providers are read
  /// once, when the page is created.
  Map<DiscountSaleReportFilter, DiscountSaleReportOptionsLoader> _loaders() {
    final stores = context.read<StoreSessionProvider>();
    final customers = context.read<CustomerProvider>();
    return {
      DiscountSaleReportFilter.store: () async => _clean(stores.availableStores
          .map((s) =>
              DiscountSaleReportOption('${s.storeId}', s.storeName ?? ''))),
      DiscountSaleReportFilter.salesExecutive: () =>
          _api.salesExecutives(_token),
      DiscountSaleReportFilter.customer: () async => _clean(
          (await customers.fetchAllCustomersSnapshot(accessToken: _token))
              .map((c) => DiscountSaleReportOption('${c.id}', c.displayLabel))),
    };
  }

  Future<void> _runExport() async {
    // The export stops if the filters change, so they describe every row.
    final filters = DiscountSaleReportExport.describe(_report.appliedFilters);
    final ok = await _export.run(context,
        shareText: _tr('title'),
        createFile: () => _report.export(
            build: (rows) => DiscountSaleReportExport.build(rows, filters),
            permissionUnchanged: () => mounted && _permission,
            progress: (page, total) => _export.setStage(
                'discount_sale_report.export_fetching_page'
                    .trParams({'page': '$page', 'total': '$total'}))));
    if (!ok && mounted) AppToast.error(context, _tr('export_error'));
  }

  Widget? _toolbar() {
    final bars = [
      if (_report.errorKey != null)
        ReportErrorBar(
            message: _report.errorKey!.tr,
            retryLabel: _tr('retry'),
            onRetry: _report.canRetry ? _report.retry : null,
            retryEnabled: !_report.loading),
      if (_report.optionsFailed)
        ReportErrorBar(
            message: _tr('options_unavailable'),
            retryLabel: _tr('retry'),
            onRetry: _report.retryOptions),
    ];
    if (bars.isEmpty) return null;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (final bar in bars) ...[
        bar,
        if (bar != bars.last) const SizedBox(height: AppSpacing.sm),
      ]
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // Depends on the route, so a covered page rebuilds when shown again.
    if (_initPending && (ModalRoute.of(context)?.isCurrent ?? true)) {
      _initPending = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _report.initialize();
      });
    }
    return ListenableBuilder(
        listenable: Listenable.merge([_report, _export, _roles, _settings]),
        builder: (context, _) {
          final show = _showFilters ?? true;
          return ListPageScaffold<DiscountSaleReportRow>(
            header: PageHeader(
                icon: Icons.discount_outlined,
                title: _tr('title'),
                subtitle: _tr('subtitle'),
                actions: [
                  HeaderAction(
                      key: DiscountSaleReportPage.filterToggleKey,
                      icon: Icons.filter_alt_rounded,
                      label: show ? 'list.hide_filters'.tr : 'list.filters'.tr,
                      active: show,
                      badge: !show && _report.hasActiveFilters,
                      onPressed: () => setState(() => _showFilters = !show)),
                  HeaderAction(
                      key: DiscountSaleReportPage.exportKey,
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
                      key: DiscountSaleReportPage.refreshKey,
                      icon: Icons.refresh_rounded,
                      label: 'list.refresh'.tr,
                      onPressed: _report.retry),
                ]),
            showFilters: show,
            filters: discountSaleReportFilters(_report),
            mobileFilterTexts: CollapsedFilterTexts(
                title: 'list.filters'.tr,
                collapsedSubtitle: _tr('show_filters_hint'),
                expandedSubtitle: _tr('hide_filters_hint')),
            toolbar: _toolbar(),
            isLoading: _report.loading,
            items: _report.rows,
            columns: discountSaleReportColumns(_currency),
            cardBuilder: (row, n) => DiscountSaleReportCard(
                row: row, number: n, currency: _currency),
            minTableWidth: 1400,
            tableScrollController: _scroll,
            emptyState: AppEmptyState(
                icon: Icons.discount_outlined, title: _tr('no_data')),
            onRefresh: _report.retry,
            pagination: ListPagination(
                currentPage: _report.page,
                totalPages: _report.totalPages,
                itemsPerPage: DiscountSaleReportController.pageSize,
                enabled: _report.canPage,
                onPageChanged: _report.goToPage,
                countLabel: discountSaleReportCountLabel(_report, _currency)),
          );
        });
  }
}
