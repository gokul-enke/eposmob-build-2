import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/app_url.dart';
import '../../data/admin_day_close_repository.dart';
import '../../domain/admin_day_close_list.dart';
import '../state/admin_day_close_controller.dart';
import '../export/day_close_list_excel.dart';
import '../widgets/admin_day_close_rows.dart';

class AdminDayCloseListPage extends StatefulWidget {
  const AdminDayCloseListPage(
      {super.key,
      this.readSource,
      this.exportController,
      required this.onView});
  final Future<AdminDayCloseSource> Function()? readSource;
  final ExportController? exportController;
  final void Function(BuildContext, DailySalesCloseData) onView;
  static const exportKey = ValueKey('admin-day-close-export');
  @override
  State<AdminDayCloseListPage> createState() => _AdminDayCloseListPageState();
}

class _AdminDayCloseListPageState extends State<AdminDayCloseListPage> {
  late final AdminDayCloseController _controller;
  late final ExportController _export;
  final _scroll = ScrollController();
  AuthModel? _auth;
  StoreSessionProvider? _stores;
  String? _token;
  int? _actorId, _storeId;
  bool _showFilters = true;
  @override
  void initState() {
    super.initState();
    _controller = AdminDayCloseController(widget.readSource ?? _readSource);
    _export = widget.exportController ?? ExportController();
    _export.addListener(_rebuild);
    if (widget.readSource == null) {
      _auth = context.read<AuthModel>();
      _stores = context.read<StoreSessionProvider>();
      _token = _auth!.token;
      _actorId = _auth!.userId;
      _storeId = _stores!.activeStore?.storeId;
      _auth!.addListener(_sessionChanged);
      _stores!.addListener(_sessionChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.refresh(firstPage: true);
    });
  }

  Future<AdminDayCloseSource> _readSource() async {
    final tenant = await const TenantSession().apiKey();
    if (!mounted) throw StateError('Admin day close list closed');
    return AdminDayCloseRepository(AdminDayCloseScope(
        token: _auth!.token ?? '',
        tenant: tenant ?? '',
        storeId: _stores!.activeStore?.storeId ?? 0,
        actorId: _auth!.userId ?? 0,
        endpoint: APPUrl.listDailySalesClose,
        executivesEndpoint: APPUrl.listSalesExecutives));
  }

  void _sessionChanged() {
    if (!mounted) return;
    final token = _auth!.token,
        actorId = _auth!.userId,
        storeId = _stores!.activeStore?.storeId;
    if (token == _token && actorId == _actorId && storeId == _storeId) return;
    _token = token;
    _actorId = actorId;
    _storeId = storeId;
    _controller.invalidate();
    _controller.refresh(firstPage: true);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _exportRows() async {
    if (!_controller.canExport || _export.busy) return;
    final captured = _controller.query, revision = _controller.revision;
    final currency =
        context.read<AppSettingsProvider>().appSettings?.currency ?? 'INR';
    final readSource = widget.readSource ?? _readSource;
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final succeeded =
        await _export.run(context, shareOrigin: origin, createFile: () async {
      final source = await readSource();
      Future<bool> isCurrent() async {
        if (!mounted) return false;
        final current = await readSource();
        return mounted &&
            _controller.matches(source.scope, captured, revision) &&
            source.scope.sameAs(current.scope);
      }

      final rows = await adminDayCloseSnapshot(source, captured,
          isCurrent: isCurrent,
          onPage: (page, total) => _export.setStage(
              'daily_sales_close.list_export_fetching'
                  .trParams({'page': '$page', 'total': '$total'})));
      final file = await exportDayCloseList(rows, currency,
          fileNamePrefix: 'admin-daily-sales-records',
          includeExecutiveId: true);
      if (!await isCurrent()) {
        throw StateError('Admin day close export changed');
      }
      return file;
    });
    if (!succeeded && mounted) {
      AppToast.error(context, 'daily_sales_close.list_export_error'.tr);
    }
  }

  Future<void> _pickDate() async {
    final date = await showAutoDismissDatePicker(
        context: context,
        initialDate:
            DateTime.tryParse(_controller.query.date ?? '') ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2101));
    if (mounted && date != null) {
      _controller.setQuery(AdminDayCloseQuery(
          date: DateFormat('yyyy-MM-dd').format(date),
          executiveId: _controller.query.executiveId));
    }
  }

  Widget _executiveField() {
    final selectedId = _controller.query.executiveId;
    final choices = [
      AdminExecutiveOption(0, 'daily_sales_close.admin_all_executives'.tr),
      ..._controller.executives
    ];
    final selected =
        choices.where((e) => e.id == (selectedId ?? 0)).firstOrNull;
    return DropdownSearch<AdminExecutiveOption>(
        key: const ValueKey('admin-day-close-executive'),
        enabled: !_export.busy && !_controller.executivesLoading,
        selectedItem: selected,
        items: (_, __) => choices,
        itemAsString: (e) => e.name,
        compareFn: (a, b) => a.id == b.id,
        popupProps: AppSearchDropdownPopup.menu(
            searchHint: 'daily_sales_close.search_hint_name'.tr,
            itemLabel: (AdminExecutiveOption e) => e.name),
        decoratorProps: DropDownDecoratorProps(
            baseStyle: AppTextStyles.input,
            decoration: AppInputDecoration.filter(
                label: 'daily_sales_close.sales_executive'.tr,
                hint: 'daily_sales_close.admin_all_executives'.tr,
                icon: Icons.person_outline)),
        onChanged: (e) {
          if (e == null) return;
          _controller.setQuery(AdminDayCloseQuery(
              date: _controller.query.date,
              executiveId: e.id == 0 ? null : e.id));
        });
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        context.watch<AppSettingsProvider>().appSettings?.currency ?? 'INR';
    return ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final data = _controller.data, failed = _controller.error != null;
          final retry = AppOutlinedButton(
              label: 'restaurant.retry'.tr,
              icon: Icons.refresh_rounded,
              onPressed: () => _controller.load());
          return ListPageScaffold<DailySalesCloseData>(
            header: PageHeader(
                icon: Icons.receipt_long_outlined,
                title: 'daily_sales_close.admin_title'.tr,
                subtitle: 'daily_sales_close.admin_list_subtitle'.tr,
                actions: [
                  HeaderAction(
                      key: const ValueKey('admin-day-close-filter-toggle'),
                      icon: Icons.filter_alt_outlined,
                      label: 'list.filters'.tr,
                      active: _showFilters,
                      badge: _controller.query.date != null ||
                          _controller.query.executiveId != null,
                      onPressed: () =>
                          setState(() => _showFilters = !_showFilters)),
                  HeaderAction(
                      key: AdminDayCloseListPage.exportKey,
                      icon: Icons.ios_share_rounded,
                      label:
                          _export.stage ?? 'daily_sales_close.list_export'.tr,
                      busy: _export.busy,
                      onPressed: _controller.canExport ? _exportRows : null),
                  HeaderAction(
                      key: const ValueKey('admin-day-close-refresh'),
                      icon: Icons.refresh_rounded,
                      label: 'list.refresh'.tr,
                      onPressed: _controller.loading || _export.busy
                          ? null
                          : () => _controller.refresh()),
                ]),
            filters: FilterPanel(
                key: const ValueKey('admin-day-close-filters'),
                title: 'daily_sales_close.admin_list_find'.tr,
                hint: 'daily_sales_close.admin_list_filter_hint'.tr,
                resetLabel: 'list.reset'.tr,
                onSearch: () {},
                onReset: () => _controller.reset(),
                fields: [
                  CustomFilterField(
                      child: InkWell(
                          key: const ValueKey('admin-day-close-date'),
                          onTap: _export.busy ? null : _pickDate,
                          borderRadius:
                              BorderRadius.circular(AppRadius.control),
                          child: InputDecorator(
                              isEmpty: _controller.query.date == null,
                              decoration: AppInputDecoration.filter(
                                  label: 'daily_sales_close.filter_date'.tr,
                                  hint: 'daily_sales_close.select_date'.tr,
                                  icon: Icons.calendar_today_outlined),
                              child: Text(_controller.query.date ?? '',
                                  style: AppTextStyles.input)))),
                  CustomFilterField(child: _executiveField()),
                ]),
            showFilters: _showFilters,
            mobileFilterTexts: CollapsedFilterTexts(
                title: 'list.filters'.tr,
                collapsedSubtitle:
                    'daily_sales_close.admin_list_filter_hint'.tr,
                expandedSubtitle:
                    'daily_sales_close.admin_list_filter_hint'.tr),
            toolbar: _controller.executivesError != null ||
                    (failed && data?.rows.isNotEmpty == true)
                ? AppSurface(
                    child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                        if (_controller.executivesError != null) ...[
                          Text('daily_sales_close.admin_executives_failed'.tr,
                              style: AppTextStyles.body),
                          AppOutlinedButton(
                              label: 'restaurant.retry'.tr,
                              icon: Icons.refresh_rounded,
                              onPressed: _controller.executivesLoading
                                  ? null
                                  : () => _controller.loadExecutives()),
                        ],
                        if (failed && data?.rows.isNotEmpty == true) ...[
                          Text('daily_sales_close.list_load_failed'.tr,
                              style: AppTextStyles.body),
                          retry,
                        ],
                      ]))
                : null,
            isLoading: _controller.loading,
            items: data?.rows ?? const [],
            columns: adminDayCloseColumns(
                currency: currency, onView: (r) => widget.onView(context, r)),
            cardBuilder: (r, _) => adminDayCloseCard(r,
                currency: currency, onView: (r) => widget.onView(context, r)),
            minTableWidth: 1780,
            tableScrollController: _scroll,
            emptyState: AppEmptyState(
                icon:
                    failed ? Icons.error_outline : Icons.receipt_long_outlined,
                title: failed
                    ? 'daily_sales_close.list_load_error'.tr
                    : 'daily_sales_close.no_closes_found'.tr,
                subtitle:
                    failed ? null : 'daily_sales_close.adjust_filters_hint'.tr,
                action: failed ? retry : null),
            onRefresh: () => _controller.refresh(),
            pagination: ListPagination(
                currentPage: data?.page ?? 1,
                totalPages: data?.pages ?? 1,
                itemsPerPage: data?.perPage ?? 20,
                enabled: !failed && !_export.busy,
                onPageChanged: (page) => _controller.load(page: page),
                countLabel: 'daily_sales_close.admin_list_count'
                    .trParams({'count': '${data?.rows.length ?? 0}'})),
          );
        });
  }

  @override
  void dispose() {
    _auth?.removeListener(_sessionChanged);
    _stores?.removeListener(_sessionChanged);
    _controller.dispose();
    _export.removeListener(_rebuild);
    if (widget.exportController == null) _export.dispose();
    _scroll.dispose();
    super.dispose();
  }
}
