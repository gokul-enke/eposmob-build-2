import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/payment_method_registry.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import '../../data/sales_report_api.dart';
import '../../domain/models/sales_report.dart';
import '../../domain/sales_report_query.dart';
import '../export/sales_report_export.dart';
import '../state/sales_report_controller.dart';
import '../widgets/report_error_bar.dart';
import '../widgets/sales_report/sales_report_filters.dart';
import '../widgets/sales_report/sales_report_results.dart';

/// Sales Report as in the web admin panel: one row per order with its value,
/// payment methods, delivery method and sales executive.
class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key, this.api, this.export});

  /// Injected in tests.
  final SalesReportApi? api;
  final ExportController? export;

  static const filterToggleKey = ValueKey('sales-report-filter-toggle');
  static const exportKey = ValueKey('sales-report-export');
  static const refreshKey = ValueKey('sales-report-refresh');

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  late final SalesReportApi _api = widget.api ?? SalesReportApi();
  late final ExportController _export = widget.export ?? ExportController();
  late SalesReportController _report;
  ({String? token, int? user, int? store, String? role})? _session;
  late final AuthModel _auth;
  late final RoleProvider _roles;
  late final AppSettingsProvider _settings;
  late final StoreSessionProvider _stores;
  late final CategoryProvider _categories;
  late final CustomerProvider _customers;
  late final DeliveryMethodsProvider _delivery;
  late final MasterDataProvider _masterData;
  late final LocalProductProvider _catalog;
  late final GridSelectionProvider _products;
  final _scroll = ScrollController();
  bool? _showFilters;

  /// The session changed while another route covered this page.
  bool _initPending = false;
  String _tr(String key) => 'order_sales_report.$key'.tr;
  String get _token => _auth.token ?? '';
  String get _currency => _settings.appSettings?.currency ?? 'INR';
  bool get _permission => _roles.currentUserCanAccessSalesReportSync();

  @override
  void initState() {
    super.initState();
    // Providers are read once, when the page is created.
    _auth = context.read<AuthModel>();
    _roles = context.read<RoleProvider>();
    _settings = context.read<AppSettingsProvider>();
    _stores = context.read<StoreSessionProvider>();
    _categories = context.read<CategoryProvider>();
    _customers = context.read<CustomerProvider>();
    _delivery = context.read<DeliveryMethodsProvider>();
    _masterData = context.read<MasterDataProvider>();
    _catalog = context.read<LocalProductProvider>();
    _products = context.read<GridSelectionProvider>();
    _session = _readSession();
    _report = _createReport();
    _auth.addListener(_sessionChanged);
    _stores.addListener(_sessionChanged);
    _roles.addListener(_sessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _report.initialize();
    });
  }

  SalesReportController _createReport() {
    final locked = _locked();
    return SalesReportController(
        readScope: () => _api.scope(_token),
        fetch: (params, page, perPage) => _api.fetch(
            accessToken: _token,
            parameters: params,
            page: page,
            perPage: perPage),
        locked: locked,
        loaders: {
          for (final filter in SalesReportFilter.values)
            // A locked filter with its name needs no list.
            if (!(locked[filter]?.label.trim().isNotEmpty ?? false))
              filter: () => _options(filter)
        });
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

  /// A sales executive sees only their own sales in the store they are
  /// logged into: those two filters are fixed for them, with their names
  /// known up front.
  Map<SalesReportFilter, SalesReportOption> _locked() {
    if (_roles.currentUserRole != 'sales_executive') return const {};
    final user = _auth.userId;
    final store = _stores.activeStore;
    return {
      if (user != null)
        SalesReportFilter.salesExecutive: SalesReportOption(
            '$user',
            context
                    .read<SalesExecutiveProvider>()
                    .getCurrentUser(context)
                    ?.name ??
                ''),
      if (store?.storeId case final int id)
        SalesReportFilter.store:
            SalesReportOption('$id', store!.storeName ?? ''),
    };
  }

  static List<SalesReportOption> _clean(Iterable<SalesReportOption> all) => [
        for (final o in all)
          if (o.id.isNotEmpty && o.id != 'null' && o.label.trim().isNotEmpty) o
      ];

  /// Options of one picker, from the app's existing directories.
  Future<List<SalesReportOption>> _options(SalesReportFilter filter) async {
    switch (filter) {
      case SalesReportFilter.store:
        return _clean(_stores.availableStores
            .map((s) => SalesReportOption('${s.storeId}', s.storeName ?? '')));
      case SalesReportFilter.salesExecutive:
        return _api.salesExecutives(_token);
      case SalesReportFilter.paymentMethod:
        // Loaded at startup into the registry, quietly empty if that failed:
        // fetch them then (every company has some), else report the failure
        // so the page offers Retry. Filtered by the master-data id.
        if (PaymentMethodRegistry.methods.isEmpty) {
          await _masterData.fetchPaymentMethods();
        }
        final payments = _clean(PaymentMethodRegistry.methods
            .where((m) => m.enabled)
            .map((m) => SalesReportOption(m.id, m.label)));
        if (payments.isEmpty) throw StateError('Payment methods not loaded');
        return payments;
      case SalesReportFilter.deliveryMethod:
        if (!_delivery.hasMethods) await _delivery.fetchDeliveryMethods();
        // A store may have no delivery modes; empty is only a failure when
        // the list never loaded.
        if (!_delivery.hasMethods && !_delivery.loadedForStore) {
          throw StateError('Delivery methods not loaded');
        }
        return _clean(_delivery.deliveryMethods
            .map((m) => SalesReportOption(m.id, m.name)));
      case SalesReportFilter.category:
        await _categories.listAllCategory();
        return _clean((_categories.category ?? []).map(
            (c) => SalesReportOption('${c.categoryId}', c.categoryName ?? '')));
      case SalesReportFilter.product:
        // The catalog the device keeps for billing, as the Stock and Non-Stock
        // reports use: instant and offline. The server's list (one page after
        // another, slow on big catalogs) only while that is still empty.
        SalesReportOption option(GetProduct p) =>
            SalesReportOption('${p.productId}', p.productName ?? '');
        await _catalog.hydrated;
        final local = _clean(_catalog.products.map(option));
        if (local.isNotEmpty) return local;
        return _clean(
            (await _products.listAllProductsForReportFilter()).map(option));
      case SalesReportFilter.customer:
        return _clean(
            (await _customers.fetchAllCustomersSnapshot(accessToken: _token))
                .map((c) => SalesReportOption('${c.id}', c.displayLabel)));
    }
  }

  Future<void> _runExport() async {
    // The export stops if the filters change, so they describe every row.
    final filters = SalesReportExport.describe(_report.appliedFilters);
    final ok = await _export.run(context,
        shareText: _tr('title'),
        createFile: () => _report.export(
            build: (rows) => SalesReportExport.build(rows, filters),
            permissionUnchanged: () => mounted && _permission,
            progress: (page, total) => _export.setStage(
                'order_sales_report.export_fetching_page'
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
          return ListPageScaffold<SalesReportRow>(
            header: PageHeader(
                icon: Icons.point_of_sale_outlined,
                title: _tr('title'),
                subtitle: _tr('subtitle'),
                actions: [
                  HeaderAction(
                      key: SalesReportPage.filterToggleKey,
                      icon: Icons.filter_alt_rounded,
                      label: show ? 'list.hide_filters'.tr : 'list.filters'.tr,
                      active: show,
                      badge: !show && _report.hasActiveFilters,
                      onPressed: () => setState(() => _showFilters = !show)),
                  HeaderAction(
                      key: SalesReportPage.exportKey,
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
                      key: SalesReportPage.refreshKey,
                      icon: Icons.refresh_rounded,
                      label: 'list.refresh'.tr,
                      onPressed: _report.retry),
                ]),
            showFilters: show,
            filters: salesReportFilters(_report),
            mobileFilterTexts: CollapsedFilterTexts(
                title: 'list.filters'.tr,
                collapsedSubtitle: _tr('show_filters_hint'),
                expandedSubtitle: _tr('hide_filters_hint')),
            toolbar: _toolbar(),
            isLoading: _report.loading,
            items: _report.rows,
            columns: salesReportColumns(_currency),
            cardBuilder: (row, n) =>
                SalesReportCard(row: row, number: n, currency: _currency),
            minTableWidth: 1100,
            tableScrollController: _scroll,
            emptyState: AppEmptyState(
                icon: Icons.point_of_sale_outlined, title: _tr('no_data')),
            onRefresh: _report.retry,
            pagination: ListPagination(
                currentPage: _report.page,
                totalPages: _report.totalPages,
                itemsPerPage: SalesReportController.pageSize,
                enabled: _report.canPage,
                onPageChanged: _report.goToPage,
                countLabel: salesReportCountLabel(_report, _currency)),
          );
        });
  }
}
