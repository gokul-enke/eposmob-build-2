import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/models/daily_sales_close.dart';
import 'package:pos_machine/models/day_close_pending_status.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/app_url.dart';
import '../../data/day_close_list_repository.dart';
import '../../domain/day_close_list.dart';
import '../state/day_close_list_controller.dart';
import '../export/day_close_list_excel.dart';
import '../widgets/day_close_list_rows.dart';

class DayCloseListPage extends StatefulWidget {
  const DayCloseListPage(
      {super.key,
      this.readSource,
      this.exportController,
      required this.onView,
      required this.onOpenShift,
      required this.onDayClose});
  final Future<DayCloseListSource> Function()? readSource;
  final ExportController? exportController;
  final void Function(BuildContext, DailySalesCloseData) onView;
  final void Function(BuildContext, VoidCallback) onOpenShift;
  final void Function(BuildContext, VoidCallback, OpenDraftModel?) onDayClose;
  static const exportKey = ValueKey('day-close-list-export');
  static const refreshKey = ValueKey('day-close-list-refresh');
  @override
  State<DayCloseListPage> createState() => _DayCloseListPageState();
}

class _DayCloseListPageState extends State<DayCloseListPage> {
  late final DayCloseListController _controller;
  late final ExportController _export;
  final _scroll = ScrollController();
  AuthModel? _auth;
  StoreSessionProvider? _stores;
  String? _token;
  int? _storeId, _userId;
  bool _showFilters = true;
  @override
  void initState() {
    super.initState();
    _controller = DayCloseListController(widget.readSource ?? _readSource);
    _export = widget.exportController ?? ExportController();
    _export.addListener(_rebuild);
    if (widget.readSource == null) {
      _auth = context.read<AuthModel>();
      _stores = context.read<StoreSessionProvider>();
      _token = _auth!.token;
      _userId = _auth!.userId;
      _storeId = _stores!.activeStore?.storeId;
      _auth!.addListener(_sessionChanged);
      _stores!.addListener(_sessionChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.refresh(firstPage: true);
    });
  }

  Future<DayCloseListSource> _readSource() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) throw StateError('Day close list closed');
    return DayCloseListRepository(DayCloseListScope(
        token: _auth!.token ?? '',
        tenant: preferences.getString('api_key') ?? '',
        storeId: _stores!.activeStore?.storeId ?? 0,
        userId: _auth!.userId ?? 0,
        endpoint: APPUrl.listDailySalesClose,
        pendingEndpoint: APPUrl.dailySalesClosePendingStatus));
  }

  void _sessionChanged() {
    if (!mounted) return;
    final token = _auth!.token,
        userId = _auth!.userId,
        storeId = _stores!.activeStore?.storeId;
    if (token == _token && userId == _userId && storeId == _storeId) return;
    _token = token;
    _userId = userId;
    _storeId = storeId;
    _controller.invalidate();
    _controller.refresh(firstPage: true);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _afterAction() {
    if (mounted) _controller.refresh(firstPage: true);
  }

  Future<void> _exportRows() async {
    if (!_controller.canExport || _export.busy) return;
    final date = _controller.date, revision = _controller.revision;
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
            _controller.matches(source.scope, date, revision) &&
            source.scope.sameAs(current.scope);
      }

      final rows = await dayCloseListSnapshot(source,
          date: date,
          isCurrent: isCurrent,
          onPage: (page, total) => _export.setStage(
              'daily_sales_close.list_export_fetching'
                  .trParams({'page': '$page', 'total': '$total'})));
      final file = await exportDayCloseList(rows, currency);
      if (!await isCurrent()) {
        throw StateError('Day close export scope changed');
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
            DateTime.tryParse(_controller.date ?? '') ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2101));
    if (mounted && date != null) {
      _controller.setDate(DateFormat('yyyy-MM-dd').format(date));
    }
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
          final ready = !_controller.pendingLoading &&
              _controller.pending != null &&
              !_export.busy;
          return ListPageScaffold<DailySalesCloseData>(
            header: PageHeader(
                icon: Icons.receipt_long_outlined,
                title: 'daily_sales_close.title'.tr,
                subtitle: 'daily_sales_close.list_subtitle'.tr,
                primaryActions: [
                  AppOutlinedButton(
                      key: const ValueKey('day-close-open-shift'),
                      label: 'daily_sales_close.btn_open_shift'.tr,
                      icon: Icons.lock_open_outlined,
                      onPressed: ready && _controller.pending!.canOpenShift
                          ? () => widget.onOpenShift(context, _afterAction)
                          : null),
                  AppPrimaryButton(
                      key: const ValueKey('day-close-submit'),
                      label: 'daily_sales_close.btn_day_close'.tr,
                      icon: Icons.access_time,
                      busy: _controller.pendingLoading,
                      onPressed: ready
                          ? () => widget.onDayClose(context, _afterAction,
                              _controller.pending!.openDraft)
                          : null),
                ],
                actions: [
                  HeaderAction(
                      key: const ValueKey('day-close-filter-toggle'),
                      icon: Icons.filter_alt_outlined,
                      label: 'list.filters'.tr,
                      active: _showFilters,
                      badge: _controller.date != null,
                      onPressed: () =>
                          setState(() => _showFilters = !_showFilters)),
                  HeaderAction(
                      key: DayCloseListPage.exportKey,
                      icon: Icons.ios_share_rounded,
                      label:
                          _export.stage ?? 'daily_sales_close.list_export'.tr,
                      busy: _export.busy,
                      onPressed: _controller.canExport ? _exportRows : null),
                  HeaderAction(
                      key: DayCloseListPage.refreshKey,
                      icon: Icons.refresh_rounded,
                      label: 'list.refresh'.tr,
                      onPressed: _controller.loading ||
                              _controller.pendingLoading ||
                              _export.busy
                          ? null
                          : () => _controller.refresh()),
                ]),
            filters: FilterPanel(
                key: const ValueKey('day-close-filters'),
                title: 'daily_sales_close.list_find'.tr,
                hint: 'daily_sales_close.list_filter_hint'.tr,
                resetLabel: 'list.reset'.tr,
                onSearch: () {},
                onReset: () {
                  _controller.reset();
                },
                fields: [
                  CustomFilterField(
                      child: InkWell(
                    key: const ValueKey('day-close-date'),
                    onTap: _export.busy ? null : _pickDate,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    child: InputDecorator(
                        isEmpty: _controller.date == null,
                        decoration: AppInputDecoration.filter(
                            label: 'daily_sales_close.date'.tr,
                            hint: 'daily_sales_close.select_date'.tr,
                            icon: Icons.calendar_today_outlined),
                        child: Text(_controller.date ?? '',
                            style: AppTextStyles.input)),
                  ))
                ]),
            showFilters: _showFilters,
            mobileFilterTexts: CollapsedFilterTexts(
                title: 'list.filters'.tr,
                collapsedSubtitle: 'daily_sales_close.list_filter_hint'.tr,
                expandedSubtitle: 'daily_sales_close.list_filter_hint'.tr),
            toolbar: _controller.pendingError != null ||
                    (failed && data?.rows.isNotEmpty == true)
                ? AppSurface(
                    child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                        if (_controller.pendingError != null) ...[
                          Text('daily_sales_close.list_shift_failed'.tr,
                              style: AppTextStyles.body),
                          AppOutlinedButton(
                              label: 'restaurant.retry'.tr,
                              icon: Icons.refresh_rounded,
                              onPressed: () => _controller.loadPending()),
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
            columns: dayCloseListColumns(
                currency: currency,
                onView: (row) => widget.onView(context, row)),
            cardBuilder: (row, _) => dayCloseListCard(row,
                currency: currency,
                onView: (row) => widget.onView(context, row)),
            minTableWidth: 1720,
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
                countLabel: 'daily_sales_close.list_count'
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
