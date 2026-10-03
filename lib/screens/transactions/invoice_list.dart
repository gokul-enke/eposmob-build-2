import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/utils/search_debouncer.dart';
import 'package:pos_machine/models/list_invoice.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:provider/provider.dart';

import '../../components/build_calendar_selection.dart';
import '../../controllers/sidebar_controller.dart';
import '../../helpers/ui_code_labels.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/auth_model.dart';
import '../../resources/color_manager.dart';
import '../../services/list_excel_export_service.dart';
import '../transactions/create_invoice_modal.dart';
import 'invoice_list/invoice_list_cells.dart';
import 'invoice_list/invoice_row_actions.dart';
import 'invoice_list/invoice_zatca_toolbar.dart';

/// The invoices list: header, filters, ZATCA bulk-sync bar, table/cards and
/// pagination, built on the shared [ListPageScaffold]. Pages come from the
/// API through [InvoiceProvider].
class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key, this.export});

  /// Replaces the export controller (tests).
  final ExportController? export;

  static const filtersKey = ValueKey('invoice-desktop-filters');
  static const filterToggleKey = ValueKey('invoice-list-filter-toggle');
  static const exportKey = ValueKey('invoice-list-export');
  static const refreshKey = ValueKey('invoice-list-refresh');

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen>
    with InvoiceRowActions<InvoiceListScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  InvoiceProvider? _invoiceProvider;
  Worker? _sidebarIndexWorker;
  bool isInitialized = false;
  final TextEditingController searchTextController = TextEditingController();
  final TextEditingController invoiceNumberController = TextEditingController();
  final TextEditingController orderNumberController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController dateFromController = TextEditingController();
  final TextEditingController dateToController = TextEditingController();
  String? selectedStatus; // For the status dropdown
  String? selectedZatcaStatus; // For the ZATCA status dropdown
  final Set<int> selectedInvoiceIds = {};
  bool isBulkSending = false;
  String? activeBulkSyncType;
  late final SearchDebouncer _search =
      SearchDebouncer(searchInvoices, delay: const Duration(milliseconds: 350));
  late final ExportController _export = widget.export ?? ExportController();
  bool _zatcaCleanupScheduled = false;
  bool _lastVerifiedPhase2Enabled = false;
  bool _showFilters = true;
  bool _visibilityInitialized = false;
  final _tableScrollController = ScrollController();

  final FocusNode dateFromFocusNode = FocusNode();
  final FocusNode dateToFocusNode = FocusNode();

  bool _isPickerOpen = false;

  /// Inputs that count as an active filter (the filter toggle's dot).
  List<TextEditingController> get _filterInputs => [
        invoiceNumberController,
        searchTextController,
        phoneController,
        dateFromController,
        dateToController,
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);

      // Applied when the user arrives from the dashboard ZATCA alert, so the
      // list opens already showing the failed invoices. Consumed once, so
      // navigating here normally later is unfiltered.
      final pendingZatcaStatus =
          _invoiceProvider!.consumePendingZatcaStatusFilter();
      if (pendingZatcaStatus != null && mounted) {
        setState(() {
          selectedZatcaStatus = pendingZatcaStatus;
        });
      }

      loadInvoices();
    });

    _sidebarIndexWorker = ever<int>(sideBarController.index, (currentIndex) {
      if (currentIndex != SideBarController.invoiceListScreenIndex) {
        _resetInvoiceFilters(
          clearProviderFilters: true,
          reloadProvider: false,
        );
      }
    });

    dateFromFocusNode.addListener(_handleDateFromFocusChange);
    dateToFocusNode.addListener(_handleDateToFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Filters start open on wide screens and closed on phones.
    if (!_visibilityInitialized) {
      _showFilters = MediaQuery.sizeOf(context).width >=
          ListLayoutBreakpoints.mobileBelow;
      _visibilityInitialized = true;
    }
  }

  void _resetInvoiceFilters({
    required bool clearProviderFilters,
    bool reloadProvider = false,
    bool notifyProvider = true,
  }) {
    _search.cancel();
    searchTextController.clear();
    invoiceNumberController.clear();
    orderNumberController.clear();
    phoneController.clear();
    // emailController.clear(); // Email filter commented for now
    dateFromController.clear();
    dateToController.clear();
    selectedStatus = null;
    selectedZatcaStatus = null;
    selectedInvoiceIds.clear();

    if (clearProviderFilters) {
      _invoiceProvider?.resetFilters(
        reload: reloadProvider,
        notify: notifyProvider,
      );
    }
  }

  void _clearSelectedInvoices() {
    if (selectedInvoiceIds.isEmpty || !mounted) {
      return;
    }

    setState(() {
      selectedInvoiceIds.clear();
    });
  }

  void _handleDateFromFocusChange() {
    if (dateFromFocusNode.hasFocus && !_isPickerOpen) {
      _openDatePicker(isFromDate: true);
    }
  }

  void _handleDateToFocusChange() {
    if (dateToFocusNode.hasFocus && !_isPickerOpen) {
      _openDatePicker(isFromDate: false);
    }
  }

  Future<void> _openDatePicker({required bool isFromDate}) async {
    _isPickerOpen = true;
    await _selectDate(context, isFromDate: isFromDate);
    // Advance focus so when date dialog dismisses, it doesn't land back and loop
    if (!mounted) return;
    FocusScope.of(context).nextFocus();
    Future.delayed(const Duration(milliseconds: 300), () {
      _isPickerOpen = false;
    });
  }

  void _clearUnavailableZatcaStateAfterBuild(
    AppSettingsProvider appSettingsProvider,
  ) {
    final bool phase2VerifiedEnabled = appSettingsProvider.isReady &&
        (appSettingsProvider.appSettings?.zatcaPhase2Enabled ?? false);

    // Do not clear a user's filter during an in-flight settings refresh. Wait
    // until a successful response has verified that Phase 2 is disabled.
    if (!appSettingsProvider.isReady ||
        phase2VerifiedEnabled ||
        _zatcaCleanupScheduled ||
        (selectedZatcaStatus == null && selectedInvoiceIds.isEmpty)) {
      return;
    }

    _zatcaCleanupScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _zatcaCleanupScheduled = false;
      if (!mounted) return;

      final latestSettings = context.read<AppSettingsProvider>();
      final bool latestPhase2VerifiedEnabled = latestSettings.isReady &&
          (latestSettings.appSettings?.zatcaPhase2Enabled ?? false);
      if (!latestSettings.isReady || latestPhase2VerifiedEnabled) return;

      final bool hadZatcaFilter = selectedZatcaStatus != null;
      setState(() {
        selectedZatcaStatus = null;
        selectedInvoiceIds.clear();
      });

      if (hadZatcaFilter) {
        searchInvoices();
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    if (widget.export == null) _export.dispose();
    _sidebarIndexWorker?.dispose();
    _tableScrollController.dispose();
    // Do not notify a provider while this route is being disposed. The
    // Flutter tree is locked during disposal and an eager notification can
    // trigger "markNeedsBuild called when widget tree was locked".
    _resetInvoiceFilters(
      clearProviderFilters: true,
      reloadProvider: false,
      notifyProvider: false,
    );
    searchTextController.dispose();
    invoiceNumberController.dispose();
    orderNumberController.dispose();
    phoneController.dispose();
    emailController.dispose();
    dateFromController.dispose();
    dateToController.dispose();
    dateFromFocusNode.removeListener(_handleDateFromFocusChange);
    dateToFocusNode.removeListener(_handleDateToFocusChange);
    dateFromFocusNode.dispose();
    dateToFocusNode.dispose();
    super.dispose();
  }

  Future<void> loadInvoices() async {
    if (isInitialized) return;

    try {
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null || accessToken.isEmpty) {
        AppToast.error(context, 'invoice.auth_token_missing'.tr);
        return;
      }

      await Provider.of<InvoiceProvider>(context, listen: false)
          .listAllInvoices(
        accessToken: accessToken,
        // Normally null; set when arriving from the dashboard ZATCA alert so
        // the first request is already filtered rather than loading everything
        // and then re-fetching.
        zatcaStatus: selectedZatcaStatus,
      );
      if (!mounted) return;
      setState(() {
        isInitialized = true;
      });
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
          context,
          'invoice.error_loading_invoices'
              .tr
              .replaceAll('@error', error.toString()));
    }
  }

  void searchInvoices() {
    debugPrint("Searching with filters");
    _clearSelectedInvoices();
    InvoiceProvider provider =
        Provider.of<InvoiceProvider>(context, listen: false);
    provider.applyFilters(
      name: searchTextController.text,
      invoiceNumber: invoiceNumberController.text,
      // orderNumber: orderNumberController.text,
      phone: phoneController.text,
      // email: emailController.text, // Email filter commented for now
      fromDate: dateFromController.text,
      toDate: dateToController.text,
      status: selectedStatus,
      zatcaStatus: selectedZatcaStatus,
    );
  }

  void resetSearch() {
    debugPrint("Resetting all filters");
    _search.cancel();
    setState(() {
      searchTextController.clear();
      invoiceNumberController.clear();
      orderNumberController.clear();
      phoneController.clear();
      // emailController.clear(); // Email filter commented for now
      dateFromController.clear();
      dateToController.clear();
      selectedStatus = null;
      selectedZatcaStatus = null;
      selectedInvoiceIds.clear();
    });

    Provider.of<InvoiceProvider>(context, listen: false).resetFilters();
  }

  /// Reloads the current page with the applied filters; a search still
  /// waiting on the debounce is dropped.
  Future<void> refreshData() async {
    debugPrint("Refreshing data");
    final String? accessToken =
        Provider.of<AuthModel>(context, listen: false).token;
    if (accessToken == null || accessToken.isEmpty) return;

    _search.cancel();
    _clearSelectedInvoices();

    await Provider.of<InvoiceProvider>(context, listen: false).listAllInvoices(
      accessToken: accessToken,
      page: Provider.of<InvoiceProvider>(context, listen: false).currentPage,
    );
  }

  Future<void> _createInvoice() async {
    final result =
        await showCreateInvoiceModal(context, MediaQuery.sizeOf(context));
    if (result == true && mounted) await refreshData();
  }

  // Date selection method
  Future<void> _selectDate(BuildContext context,
      {required bool isFromDate}) async {
    final DateTime? pickedDate = await showAutoDismissDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: this.context,
        initialTime: TimeOfDay.now(),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: ColorManager.kPrimaryColor,
              ),
              dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
            ),
            child: child!,
          );
        },
      );
      if (!mounted) return;
      // Time is optional — use picked time or default
      final TimeOfDay resolvedTime = pickedTime ??
          (isFromDate
              ? const TimeOfDay(hour: 0, minute: 0)
              : const TimeOfDay(hour: 23, minute: 59));

      final DateTime fullDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        resolvedTime.hour,
        resolvedTime.minute,
      );
      final formattedDateTime =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(fullDateTime);
      setState(() {
        if (isFromDate) {
          dateFromController.text = formattedDateTime;
        } else {
          dateToController.text = formattedDateTime;
        }
      });
      searchInvoices();
    }
  }

  bool get _hasActiveFilters =>
      _filterInputs.any((input) => input.text.isNotEmpty) ||
      selectedStatus != null ||
      selectedZatcaStatus != null;

  // ---------------------------------------------------------------- export

  Future<File> _createExport() async {
    _search.flushPending();
    final token = context.read<AuthModel>().token;
    if (token == null || token.isEmpty) {
      throw StateError('Missing access token.');
    }
    // Capture the controls before awaiting; export never updates list state.
    final currency =
        context.read<AppSettingsProvider>().appSettings?.currency ?? 'INR';
    final showZatca = _lastVerifiedPhase2Enabled;
    _export.setStage('invoice.export_creating'.tr);
    final items = await context.read<InvoiceProvider>().fetchInvoicesForExport(
          accessToken: token,
          name: searchTextController.text,
          invoiceNumber: invoiceNumberController.text,
          phone: phoneController.text,
          fromDate: dateFromController.text,
          toDate: dateToController.text,
          status: selectedStatus,
          zatcaStatus: showZatca ? selectedZatcaStatus : null,
          onProgress: (page, total) {
            if (mounted) {
              _export.setStage('invoice.export_fetching'
                  .trParams({'page': '$page', 'total': '$total'}));
            }
          },
        );
    if (mounted) _export.setStage('invoice.export_creating'.tr);
    return ListExcelExportService.export<Invoice>(
        items: items,
        fileNamePrefix: 'invoices',
        sheetName: 'invoice.list_title'.tr,
        columns: [
          ListExportColumn(
              label: 'invoice.field_invoice_number'.tr,
              value: (v, _) => v.invoiceNumber),
          ListExportColumn(
              label: 'invoice.col_amount'.tr,
              value: (v, _) => ListExcelExportService.numericValue(v.amount)),
          ListExportColumn(
              label: 'supplier_transactions.currency'.tr,
              value: (_, __) => currency),
          ListExportColumn(
              label: 'invoice.col_name'.tr,
              value: (v, _) => v.customer.user.name),
          ListExportColumn(
              label: 'invoice.phone'.tr,
              value: (v, _) => v.customer.user.phone),
          ListExportColumn(
              label: 'invoice.field_invoice_date'.tr,
              value: (v, _) => v.invoiceDate),
          ListExportColumn(
              label: 'invoice.field_type'.tr,
              value: (v, _) => InvoiceListLabels.type(v.type)),
          ListExportColumn(
              label: 'invoice.field_due_date'.tr, value: (v, _) => v.dueDate),
          ListExportColumn(
              label: 'invoice.field_status'.tr,
              value: (v, _) => UiCodeLabels.status(v.status)),
          if (showZatca)
            ListExportColumn(
                label: 'invoice.col_zatca_status'.tr,
                value: (v, _) =>
                    v.zatcaStatus ?? v.zatcaRequestStatus ?? 'not_sent'),
        ]);
  }

  Future<void> _runExport() async {
    final exported = await _export.run(context, createFile: _createExport);
    if (!exported && mounted) {
      AppToast.error(context, 'invoice.export_failed'.tr);
    }
  }

  // ---------------------------------------------------------------- filters

  FilterFieldDef _textFilter(
          TextEditingController controller, String label, IconData icon,
          {TextInputType keyboardType = TextInputType.text}) =>
      TextFilterField(
          controller: controller,
          label: label,
          hint: label,
          icon: icon,
          keyboardType: keyboardType);

  FilterFieldDef _dateFilter(bool from) {
    final label = from ? 'invoice.from_date'.tr : 'invoice.to_date'.tr;
    return CustomFilterField(
        child: TextField(
            controller: from ? dateFromController : dateToController,
            focusNode: from ? dateFromFocusNode : dateToFocusNode,
            readOnly: true,
            textAlignVertical: TextAlignVertical.center,
            style: AppTextStyles.input,
            decoration: AppInputDecoration.filter(
                label: label, hint: label, icon: Icons.calendar_today_outlined),
            onTap: () {
              if (!_isPickerOpen) _openDatePicker(isFromDate: from);
            }));
  }

  /// The provider's options plus the current value, without the "All"
  /// placeholder (shown as the `null` option instead).
  List<FilterOption<String?>> _options(String allLabel, List<String> values,
          String placeholder, String? current, String Function(String) label) =>
      [
        FilterOption<String?>(null, allLabel),
        for (final value in {
          ...values.where((v) => v != placeholder),
          if (current != null) current,
        })
          FilterOption<String?>(value, label(value)),
      ];

  Widget _filters(InvoiceProvider provider, bool showZatca) => FilterPanel(
          key: InvoiceListScreen.filtersKey,
          title: 'invoice.find'.tr,
          hint: 'invoice.filter_hint'.tr,
          resetLabel: 'list.reset'.tr,
          onSearch: _search.schedule,
          onSubmit: _search.flush,
          onReset: resetSearch,
          fields: [
            _textFilter(invoiceNumberController, 'invoice.invoice_no'.tr,
                Icons.receipt_long_outlined),
            _textFilter(
                searchTextController, 'invoice.name'.tr, Icons.person_outline),
            _textFilter(
                phoneController, 'invoice.phone'.tr, Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            if (showZatca)
              DropdownFilterField<String?>(
                  label: 'invoice.col_zatca_status'.tr,
                  icon: Icons.cloud_sync_outlined,
                  value: selectedZatcaStatus,
                  options: _options(
                      'invoice.all_zatca_status'.tr,
                      provider.getZatcaStatusOptions(),
                      'All ZATCA Status',
                      selectedZatcaStatus,
                      UiCodeLabels.zatca),
                  onChanged: (v) {
                    setState(() => selectedZatcaStatus = v);
                    _search.cancel();
                    searchInvoices();
                  }),
            DropdownFilterField<String?>(
                label: 'invoice.field_status'.tr,
                icon: Icons.check_circle_outline,
                value: selectedStatus,
                options: _options(
                    'invoice.all_status'.tr,
                    provider.getStatusOptions(),
                    'All Status',
                    selectedStatus,
                    UiCodeLabels.status),
                onChanged: (v) {
                  setState(() => selectedStatus = v);
                  _search.cancel();
                  searchInvoices();
                }),
            _dateFilter(true),
            _dateFilter(false),
          ]);

  // ------------------------------------------------------------ list cells

  Widget _selection(Invoice invoice) => Checkbox(
      value: selectedInvoiceIds.contains(invoice.id),
      onChanged: isBulkSending
          ? null
          : (value) => setState(() {
                if (value == true) {
                  selectedInvoiceIds.add(invoice.id);
                } else {
                  selectedInvoiceIds.remove(invoice.id);
                }
              }));

  Widget _copyButton(Invoice invoice) => IconButton(
      icon: const Icon(Icons.copy_outlined, size: 16),
      color: AppColors.muted,
      tooltip: 'invoice.field_invoice_number'.tr,
      onPressed: () {
        Clipboard.setData(ClipboardData(text: invoice.invoiceNumber));
        AppToast.success(context, 'invoice.invoice_number_copied'.tr);
      });

  Widget _reference(Invoice invoice) => Row(children: [
        Expanded(
            child: TableCells.text(
                InvoiceListLabels.orDash(invoice.invoiceNumber))),
        _copyButton(invoice),
      ]);

  Widget _avatar(Invoice invoice, double size) => AppAvatar(
      name: invoice.customer.user.name,
      semanticLabel: invoice.customer.user.name,
      size: size);

  Widget _actions(Invoice invoice) => Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AppOutlinedButton(
              label: 'list.view'.tr,
              icon: Icons.visibility_outlined,
              iconSize: 15,
              height: AppSizes.compactControl,
              radius: AppRadius.tile,
              onPressed: () => showInvoiceDetails(invoice)),
          AppSquareIconButton(
              icon: Icons.more_vert,
              tooltip: 'general.more'.tr,
              size: AppSizes.compactControl,
              iconSize: 18,
              radius: AppRadius.tile,
              foreground: AppColors.primary,
              onPressed: () => showInvoiceActionsSheet(invoice)),
        ],
      );

  Widget _card(Invoice invoice, bool showZatca) => AppListCard(
      title: InvoiceListLabels.orDash(invoice.customer.user.name),
      leading: _avatar(invoice, 40),
      trailing: showZatca ? _selection(invoice) : null,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InfoRow(
            label: 'invoice.field_invoice_number'.tr,
            value: InvoiceListLabels.orDash(invoice.invoiceNumber),
            trailing: _copyButton(invoice)),
        const SizedBox(height: AppSpacing.xs),
        AppMetricStrip(metrics: [
          AppMetric(
              icon: Icons.payments_outlined,
              label: 'invoice.col_amount'.tr,
              value: InvoiceListLabels.orDash(invoice.amount)),
          AppMetric(
              icon: Icons.event_outlined,
              label: 'invoice.field_invoice_date'.tr,
              value: InvoiceListLabels.orDash(invoice.invoiceDate)),
        ]),
        InfoRow(
            label: 'invoice.field_due_date'.tr,
            value: InvoiceListLabels.orDash(invoice.dueDate)),
        InfoRow(
            label: 'invoice.field_type'.tr,
            value: InvoiceListLabels.orDash(
                InvoiceListLabels.type(invoice.type))),
        const SizedBox(height: AppSpacing.xs),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          InvoiceListLabels.statusBadge(invoice.status),
          if (showZatca) InvoiceListLabels.zatcaBadge(invoice),
        ]),
        const SizedBox(height: AppSpacing.md),
        _actions(invoice),
      ]));

  List<TableColumnDef<Invoice>> _columns(bool showZatca) => [
        if (showZatca)
          TableColumnDef(
              label: '',
              flex: .5,
              cellBuilder: (v, _) => TableCells.widget(_selection(v))),
        TableColumnDef(
            label: 'invoice.field_invoice_number'.tr,
            flex: 1.7,
            cellBuilder: (v, _) => _reference(v)),
        TableColumnDef(
            label: 'invoice.col_amount'.tr,
            cellBuilder: (v, _) =>
                TableCells.text(InvoiceListLabels.orDash(v.amount))),
        TableColumnDef(
            label: 'invoice.col_name'.tr,
            flex: 1.8,
            cellBuilder: (v, _) => TableCells.avatarName(
                name: InvoiceListLabels.orDash(v.customer.user.name),
                avatar: _avatar(v, 36))),
        TableColumnDef(
            label: 'invoice.field_invoice_date'.tr,
            flex: 1.3,
            cellBuilder: (v, _) =>
                TableCells.text(InvoiceListLabels.orDash(v.invoiceDate))),
        TableColumnDef(
            label: 'invoice.field_type'.tr,
            cellBuilder: (v, _) => TableCells.text(
                InvoiceListLabels.orDash(InvoiceListLabels.type(v.type)))),
        TableColumnDef(
            label: 'invoice.field_due_date'.tr,
            flex: 1.3,
            cellBuilder: (v, _) =>
                TableCells.text(InvoiceListLabels.orDash(v.dueDate))),
        TableColumnDef(
            label: 'invoice.field_status'.tr,
            cellBuilder: (v, _) =>
                TableCells.widget(InvoiceListLabels.statusBadge(v.status))),
        if (showZatca)
          TableColumnDef(
              label: 'invoice.col_zatca_status'.tr,
              flex: 1.4,
              cellBuilder: (v, _) =>
                  TableCells.widget(InvoiceListLabels.zatcaBadge(v))),
        TableColumnDef(
            label: 'invoice.col_action'.tr,
            flex: 1.6,
            cellBuilder: (v, _) => Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _actions(v)))),
      ];

  // --------------------------------------------------------- ZATCA toolbar

  Widget _buildSelectionActions(InvoiceProvider provider) {
    final token = context.read<AuthModel>().token;
    final settings = context.read<AppSettingsProvider>();
    final disabled = isBulkSending ||
        provider.isLoading ||
        !settings.isReady ||
        !(settings.appSettings?.zatcaPhase2Enabled ?? false) ||
        token == null ||
        token.isEmpty;
    return InvoiceZatcaToolbar(
      disabled: disabled,
      isBulkSending: isBulkSending,
      activeSyncType: activeBulkSyncType,
      selectedCount: selectedInvoiceIds.length,
      onSync: (mode) => _performBulkZatcaSync(
          idsToSync:
              mode == 'selected' ? selectedInvoiceIds.toList() : const [],
          syncType: mode,
          accessToken: token!),
      onSelectPage: () => setState(() {
        selectedInvoiceIds
            .addAll((provider.invoiceListDetails ?? []).map((v) => v.id));
      }),
      onUnselect: () => setState(() => selectedInvoiceIds.clear()),
    );
  }

  Future<void> _performBulkZatcaSync({
    required List<int> idsToSync,
    required String syncType, // 'selected', 'all', 'failed', 'not_sent'
    required String accessToken,
  }) async {
    if (!canRunPhase2Action()) return;
    // Only selected mode requires explicit IDs from UI selection.
    if (syncType == 'selected' && idsToSync.isEmpty) {
      showScaffold(
        context: context,
        message: 'invoice.no_invoices_to_sync'.tr,
      );
      return;
    }

    String confirmationMessage;
    switch (syncType) {
      case 'all':
        confirmationMessage = 'invoice.confirm_sync_all'.tr;
        break;
      case 'failed':
        confirmationMessage = 'invoice.confirm_sync_failed'.tr;
        break;
      case 'not_sent':
        confirmationMessage = 'invoice.confirm_sync_not_sent'.tr;
        break;
      default:
        confirmationMessage = 'invoice.confirm_sync_selected'
            .tr
            .replaceAll('@count', idsToSync.length.toString());
    }

    // Show confirmation dialog
    final shouldSend = await showZatcaConfirmationDialog(
      count: idsToSync.length,
      message: confirmationMessage,
    );
    if (shouldSend != true || !canRunPhase2Action()) return;

    setState(() {
      isBulkSending = true;
      activeBulkSyncType = syncType;
    });

    try {
      final provider = Provider.of<InvoiceProvider>(context, listen: false);

      // Determine flags based on sync type
      bool bulkNotSend = false;
      bool bulkFailed = false;

      if (syncType == 'all') {
        bulkNotSend = true;
        bulkFailed = true;
      } else if (syncType == 'not_sent') {
        bulkNotSend = true;
        bulkFailed = false;
      } else if (syncType == 'failed') {
        bulkNotSend = false;
        bulkFailed = true;
      }
      // 'selected' has both false (backend syncs all provided IDs)

      // Debug: Print API request body
      debugPrint('[ZATCA][Bulk Sync] API Request Body:');
      debugPrint('  syncType: $syncType');
      debugPrint('  ids: $idsToSync');
      debugPrint('  bulkNotSend: $bulkNotSend');
      debugPrint('  bulkFailed: $bulkFailed');
      debugPrint('  idsCount: ${idsToSync.length}');

      final result = await provider.zatcaBulkSend(
        ids: idsToSync,
        accessToken: accessToken,
        bulkNotSend: bulkNotSend,
        bulkFailed: bulkFailed,
      );

      if (!mounted) return;
      if (result != null && result['status'] == 'success') {
        showScaffold(
          context: context,
          message: result['message'] ?? 'invoice.sync_success_fallback'.tr,
        );
        setState(() {
          selectedInvoiceIds.clear();
        });
        await refreshData();
      } else {
        final errorMsg =
            result?['message'] ?? 'invoice.sync_failed_fallback'.tr;
        showScaffoldError(context: context, message: errorMsg);
      }
    } catch (e) {
      if (!mounted) return;
      showScaffoldError(
          context: context,
          message:
              'invoice.bulk_sync_error'.tr.replaceAll('@error', e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          isBulkSending = false;
          activeBulkSyncType = null;
        });
      }
    }
  }

  // ----------------------------------------------------------------- build

  /// Filters, Export, Refresh — left to right, before Add.
  List<HeaderAction> _headerActions({required bool canExport}) => [
        HeaderAction(
            key: InvoiceListScreen.filterToggleKey,
            icon: _showFilters
                ? Icons.filter_alt_rounded
                : Icons.filter_alt_outlined,
            label: _showFilters
                ? 'invoice.hide_filters'.tr
                : 'invoice.show_filters'.tr,
            onPressed: () => setState(() => _showFilters = !_showFilters),
            active: _showFilters,
            badge: !_showFilters && _hasActiveFilters),
        HeaderAction(
            key: InvoiceListScreen.exportKey,
            icon: Icons.ios_share_rounded,
            label: _export.busy
                ? (_export.stage ?? 'invoice.export_creating'.tr)
                : 'invoice.export_tooltip'.tr,
            onPressed: canExport ? _runExport : null,
            busy: _export.busy),
        HeaderAction(
            key: InvoiceListScreen.refreshKey,
            icon: Icons.refresh_rounded,
            label: 'list.refresh'.tr,
            onPressed: refreshData),
      ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final provider = context.watch<InvoiceProvider>();
    if (settings.isReady) {
      _lastVerifiedPhase2Enabled =
          settings.appSettings?.zatcaPhase2Enabled ?? false;
    }
    final showZatca = _lastVerifiedPhase2Enabled;
    _clearUnavailableZatcaStateAfterBuild(settings);
    final invoices = provider.invoiceListDetails ?? const <Invoice>[];
    return ListenableBuilder(
        listenable: Listenable.merge([_export, ..._filterInputs]),
        builder: (context, _) => ListPageScaffold<Invoice>(
              header: PageHeader(
                  icon: Icons.receipt_long_outlined,
                  title: 'invoice.list_title'.tr,
                  subtitle: 'invoice.subtitle'.tr,
                  actions: _headerActions(
                      canExport: !provider.isLoading &&
                          !isBulkSending &&
                          invoices.isNotEmpty),
                  onAdd: _createInvoice,
                  addLabel: 'invoice.create_invoice_button'.tr,
                  addShortLabel: 'invoice.create'.tr),
              filters: _filters(provider, showZatca),
              showFilters: _showFilters,
              toolbar: showZatca ? _buildSelectionActions(provider) : null,
              tableScrollController: _tableScrollController,
              isLoading: provider.isLoading,
              items: invoices,
              minTableWidth: showZatca ? 1350 : 1150,
              columns: _columns(showZatca),
              cardBuilder: (v, _) => _card(v, showZatca),
              emptyState: AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'invoice.no_invoices_found'.tr,
                  subtitle: 'invoice.adjust_search'.tr),
              onRefresh: refreshData,
              pagination: ListPagination(
                  currentPage: provider.currentPage,
                  totalPages: provider.totalPages,
                  itemsPerPage: provider.itemsPerPage,
                  countLabel: 'invoice.page_count'
                      .trParams({'count': '${invoices.length}'}),
                  onPageChanged: (page) {
                    // A search still waiting on the debounce is dropped.
                    _search.cancel();
                    _clearSelectedInvoices();
                    provider.goToPage(page);
                  }),
            ));
  }
}
