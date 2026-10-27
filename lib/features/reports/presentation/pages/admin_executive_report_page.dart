import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/sales_executive_report.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/resources/app_url.dart';
import '../../data/admin_executive_repository.dart';
import '../../domain/admin_executive_report.dart';
import '../../domain/report_date_range.dart';
import '../state/admin_executive_controller.dart';
import '../state/report_load_error.dart';
import '../widgets/admin_executive_rows.dart';
import '../export/admin_executive_excel.dart';

class AdminExecutiveReportPage extends StatefulWidget {
  const AdminExecutiveReportPage(
      {super.key,
      this.readSource,
      this.exportController,
      required this.onView});
  final Future<AdminExecutiveSource> Function()? readSource;
  final ExportController? exportController;
  final void Function(SalesExecutiveReportData, String) onView;
  static const exportKey = ValueKey('admin-executive-export');
  static const fromKey = ValueKey('admin-executive-from');
  static const toKey = ValueKey('admin-executive-to');
  static const nameKey = ValueKey('admin-executive-name');
  @override
  State<AdminExecutiveReportPage> createState() =>
      _AdminExecutiveReportPageState();
}

class _AdminExecutiveReportPageState extends State<AdminExecutiveReportPage> {
  late final AdminExecutiveController _report;
  late final ExportController _export;
  final _name = TextEditingController(), _scroll = ScrollController();
  AuthModel? _auth;
  StoreSessionProvider? _stores;
  RoleProvider? _roles;
  String? _token, _role;
  int? _actor, _store;
  bool _showFilters = true;

  @override
  void initState() {
    super.initState();
    _report = AdminExecutiveController(widget.readSource ?? _readSource);
    _export = widget.exportController ?? ExportController();
    if (widget.readSource == null) {
      _auth = context.read<AuthModel>();
      _stores = context.read<StoreSessionProvider>();
      _roles = context.read<RoleProvider>();
      _rememberSession();
      _auth!.addListener(_sessionChanged);
      _stores!.addListener(_sessionChanged);
      _roles!.addListener(_sessionChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_redirectExecutive()) return;
      _report.load();
    });
  }

  void _rememberSession() {
    _token = _auth!.token;
    _actor = _auth!.userId;
    _store = _stores!.activeStore?.storeId;
    _role = _roles!.currentUserRole;
  }

  bool _redirectExecutive() {
    if (_roles?.currentUserRole != 'sales_executive') return false;
    final sidebar = Get.isRegistered<SideBarController>()
        ? Get.find<SideBarController>()
        : Get.put(SideBarController());
    sidebar.index.value = 58;
    return true;
  }

  void _sessionChanged() {
    if (!mounted) return;
    if (_token == _auth!.token &&
        _actor == _auth!.userId &&
        _store == _stores!.activeStore?.storeId &&
        _role == _roles!.currentUserRole) {
      return;
    }
    _rememberSession();
    _report.invalidate();
    if (!_redirectExecutive()) _report.load();
  }

  Future<AdminExecutiveSource> _readSource() async {
    const session = TenantSession();
    final tenant = await session.apiKey();
    // Like the legacy provider, fall back to the persisted store and role when
    // the in-memory session has not been restored yet.
    final storeId =
        _stores!.activeStore?.storeId ?? await session.activeStoreId();
    final role = _roles!.currentUserRole ??
        (await SharedPreferences.getInstance()).getString('userRole');
    if (!mounted) throw StateError('Admin executive report closed');
    return AdminExecutiveRepository(AdminExecutiveScope(
        token: _auth!.token ?? '',
        tenant: tenant ?? '',
        storeId: storeId ?? 0,
        actorId: _auth!.userId ?? 0,
        role: role ?? '',
        endpoint: APPUrl.getAdminSalesExecutiveReport));
  }

  Future<void> _pickDate(bool from) async {
    final revision = _report.revision;
    final current = from ? _report.range.from : _report.range.to;
    final date = await showAutoDismissDatePicker(
        context: context,
        initialDate: current ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (!mounted || date == null || revision != _report.revision) return;
    // A new pick starts at the whole day: 00:00 (From) or 23:59 (To).
    final time = await showTimePicker(
        context: context,
        initialTime: current == null
            ? TimeOfDay(hour: from ? 0 : 23, minute: from ? 0 : 59)
            : TimeOfDay.fromDateTime(current));
    if (!mounted || time == null || revision != _report.revision) return;
    // The picker has no seconds; a To covers its whole minute.
    final value = DateTime(
        date.year, date.month, date.day, time.hour, time.minute, from ? 0 : 59);
    await _report.setRange(_report.range.copyWith(
        from: from ? () => value : null, to: from ? null : () => value));
  }

  FilterFieldDef _date(bool from) {
    final value = from ? _report.range.from : _report.range.to;
    return CustomFilterField(
        child: InkWell(
            key: from
                ? AdminExecutiveReportPage.fromKey
                : AdminExecutiveReportPage.toKey,
            onTap: _export.busy ? null : () => _pickDate(from),
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: InputDecorator(
                isEmpty: value == null,
                decoration: AppInputDecoration.filter(
                        label: 'exec_report.${from ? 'filter_from_date' : 'filter_to_date'}'
                            .tr,
                        hint: 'general.datetime_format_hint'.tr,
                        icon: Icons.calendar_today_outlined)
                    .copyWith(
                        suffixIcon: value == null
                            ? null
                            : IconButton(
                                tooltip: 'list.reset'.tr,
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: _export.busy
                                    ? null
                                    : () => _report.setRange(_report.range.copyWith(
                                        from: from ? () => null : null,
                                        to: from ? null : () => null)))),
                child: Text(value == null ? '' : ReportDateRange.formatApi(value),
                    style: AppTextStyles.input,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr))));
  }

  void _view(SalesExecutiveReportData row) {
    final range = _report.loadedRange;
    final label = range?.apiFrom != null && range?.apiTo != null
        ? '${range!.apiFrom} - ${range.apiTo}'
        : range?.apiFrom ??
            range?.apiTo ??
            DateFormat('MMMM dd, yyyy')
                .format(_report.loadedAt ?? DateTime.now());
    widget.onView(row, label);
  }

  Future<void> _runExport() async {
    if (!_report.canExport || _export.busy) return;
    final rows = _report.rows,
        range = _report.loadedRange!,
        loadedAt = _report.loadedAt!;
    final revision = _report.revision, name = _report.name;
    final currency =
        context.read<AppSettingsProvider>().appSettings?.currency ?? 'INR';
    final readSource = widget.readSource ?? _readSource;
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final success =
        await _export.run(context, shareOrigin: origin, createFile: () async {
      final source = await readSource();
      Future<bool> current() async {
        final now = await readSource();
        return mounted &&
            _report.matches(source.scope, revision) &&
            name == _report.name &&
            source.scope.sameAs(now.scope);
      }

      if (!await current()) throw StateError('Admin report export changed');
      final file = await exportAdminExecutives(rows,
          currency: currency, range: range, loadedAt: loadedAt);
      if (!await current()) throw StateError('Admin report export changed');
      return file;
    });
    if (!success && mounted) {
      AppToast.error(context, 'exec_report.list_export_error'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        context.watch<AppSettingsProvider>().appSettings?.currency ?? 'INR';
    return ListenableBuilder(
        listenable: Listenable.merge([_report, _export]),
        builder: (context, _) {
          final failed = _report.error != null, rows = _report.rows;
          final message = _report.error == ReportLoadError.invertedRange
              ? 'exec_report.error_date_range'.tr
              : 'exec_report.list_load_error'.tr;
          final retry = AppOutlinedButton(
              label: 'exec_report.btn_retry'.tr,
              icon: Icons.refresh_rounded,
              onPressed: () => _report.load());
          return ListPageScaffold<SalesExecutiveReportData>(
            header: PageHeader(
                icon: Icons.assessment_outlined,
                title: 'exec_report.title'.tr,
                subtitle: 'exec_report.list_subtitle'.tr,
                actions: [
                  HeaderAction(
                      key: const ValueKey('admin-executive-filter-toggle'),
                      icon: Icons.filter_alt_outlined,
                      label: 'list.filters'.tr,
                      active: _showFilters,
                      badge: !_report.range.isEmpty ||
                          _report.name.trim().isNotEmpty,
                      onPressed: () =>
                          setState(() => _showFilters = !_showFilters)),
                  HeaderAction(
                      key: AdminExecutiveReportPage.exportKey,
                      icon: Icons.ios_share_rounded,
                      label: _export.stage ?? 'list.export'.tr,
                      busy: _export.busy,
                      onPressed: _report.canExport && !_export.busy
                          ? _runExport
                          : null),
                  HeaderAction(
                      icon: Icons.refresh_rounded,
                      label: 'list.refresh'.tr,
                      onPressed: _report.loading || _export.busy
                          ? null
                          : () => _report.load()),
                ]),
            filters: FilterPanel(
                title: 'exec_report.list_find'.tr,
                hint: 'exec_report.list_filter_hint'.tr,
                resetLabel: 'list.reset'.tr,
                onSearch: () => _report.setName(_name.text),
                onReset: () {
                  _name.clear();
                  _report.reset();
                },
                fields: [
                  _date(true),
                  _date(false),
                  CustomFilterField(
                      child: TextFormField(
                          key: AdminExecutiveReportPage.nameKey,
                          controller: _name,
                          onChanged: (value) => _report.setName(value),
                          textInputAction: TextInputAction.search,
                          style: AppTextStyles.input,
                          decoration: AppInputDecoration.filter(
                              label: 'exec_report.filter_search_executive'.tr,
                              hint: 'exec_report.filter_name_hint'.tr,
                              icon: Icons.search))),
                ]),
            showFilters: _showFilters,
            mobileFilterTexts: CollapsedFilterTexts(
                title: 'list.filters'.tr,
                collapsedSubtitle: 'exec_report.list_filter_hint'.tr,
                expandedSubtitle: 'exec_report.list_filter_hint'.tr),
            toolbar: failed && rows.isNotEmpty
                ? AppSurface(
                    child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                        Text(message, style: AppTextStyles.body),
                        if (_report.error != ReportLoadError.invertedRange)
                          retry
                      ]))
                : !failed &&
                        !_report.loading &&
                        rows.isNotEmpty &&
                        !_report.canExport
                    ? AppSurface(
                        child: Text('exec_report.list_incomplete'.tr,
                            style: AppTextStyles.body))
                    : null,
            isLoading: _report.loading,
            items: rows,
            minTableWidth: 1450,
            tableScrollController: _scroll,
            columns: adminExecutiveColumns(currency: currency, onView: _view),
            cardBuilder: (row, _) =>
                adminExecutiveCard(row, currency: currency, onView: _view),
            onRefresh: () => _report.load(),
            emptyState: AppEmptyState(
                icon: failed ? Icons.error_outline : Icons.assessment_outlined,
                title: failed
                    ? 'exec_report.error_title'.tr
                    : 'exec_report.no_data'.tr,
                subtitle: failed ? message : 'exec_report.no_data_hint'.tr,
                action: failed && _report.error != ReportLoadError.invertedRange
                    ? retry
                    : null),
          );
        });
  }

  @override
  void dispose() {
    _auth?.removeListener(_sessionChanged);
    _stores?.removeListener(_sessionChanged);
    _roles?.removeListener(_sessionChanged);
    _report.dispose();
    if (widget.exportController == null) _export.dispose();
    _name.dispose();
    _scroll.dispose();
    super.dispose();
  }
}
