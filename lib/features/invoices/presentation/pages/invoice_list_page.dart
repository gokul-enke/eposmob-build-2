import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../../data/invoice_list_repository.dart';
import '../state/invoice_list_controller.dart';
import '../export/invoice_list_excel.dart';
import '../widgets/invoice_list_rows.dart';
import '../widgets/invoice_list_filters.dart';
import 'package:pos_machine/models/list_invoice.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/screens/transactions/create_invoice_modal.dart';
import 'package:pos_machine/screens/transactions/invoice_list/invoice_row_actions.dart';
import 'package:pos_machine/screens/transactions/invoice_list/invoice_zatca_toolbar.dart';

/// The invoices list: header, filters, ZATCA bulk-sync bar, table/cards and
/// pagination, built on the shared [ListPageScaffold]. Pages come from the
/// API through [InvoiceProvider].
class InvoiceListPage extends StatefulWidget {
  const InvoiceListPage({super.key, this.export});

  /// Replaces the export controller (tests).
  final ExportController? export;

  static const filtersKey = ValueKey('invoice-desktop-filters');
  static const filterToggleKey = ValueKey('invoice-list-filter-toggle');
  static const exportKey = ValueKey('invoice-list-export');
  static const refreshKey = ValueKey('invoice-list-refresh');

  @override
  State<InvoiceListPage> createState() => _InvoiceListPageState();
}

class _InvoiceListPageState extends State<InvoiceListPage>
    with InvoiceRowActions<InvoiceListPage> {
  final SideBarController sideBarController = Get.put(SideBarController());
  Worker? _sidebarIndexWorker;
  late final InvoiceListController _list;
  TextEditingController get searchTextController => _list.name;
  TextEditingController get invoiceNumberController => _list.invoiceNumber;
  TextEditingController get phoneController => _list.phone;
  TextEditingController get dateFromController => _list.fromDate;
  TextEditingController get dateToController => _list.toDate;
  String? get selectedStatus => _list.status;
  set selectedStatus(String? value) => _list.status = value;
  String? get selectedZatcaStatus => _list.zatcaStatus;
  set selectedZatcaStatus(String? value) => _list.zatcaStatus = value;
  Set<int> get selectedInvoiceIds => _list.selectedIds;
  bool isBulkSending = false;
  String? activeBulkSyncType;
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
  List<TextEditingController> get _filterInputs => _list.inputs;

  @override
  void initState() {
    super.initState();
    _list = InvoiceListController(
        InvoiceListRepository(context.read<InvoiceProvider>()),
        readToken: () => context.read<AuthModel>().token);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Applied when the user arrives from the dashboard ZATCA alert, so the
      // list opens already showing the failed invoices. Consumed once, so
      // navigating here normally later is unfiltered.
      final pendingZatcaStatus = _list.repository.consumePendingZatcaStatus();
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
      _showFilters =
          MediaQuery.sizeOf(context).width >= ListLayoutBreakpoints.mobileBelow;
      _visibilityInitialized = true;
    }
  }

  void _resetInvoiceFilters({
    bool reloadProvider = false,
    bool notifyProvider = true,
  }) {
    _list.reset(reload: reloadProvider, notifyProvider: notifyProvider);
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
    if (widget.export == null) _export.dispose();
    _sidebarIndexWorker?.dispose();
    _tableScrollController.dispose();
    _list.reset(reload: false, notifyProvider: false);
    _list.dispose();

    dateFromFocusNode.removeListener(_handleDateFromFocusChange);
    dateToFocusNode.removeListener(_handleDateToFocusChange);
    dateFromFocusNode.dispose();
    dateToFocusNode.dispose();
    super.dispose();
  }

  Future<void> loadInvoices() async {
    if (_list.initialized) return;

    try {
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null || accessToken.isEmpty) {
        AppToast.error(context, 'invoice.auth_token_missing'.tr);
        return;
      }

      await _list.load();
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
          context,
          'invoice.error_loading_invoices'
              .tr
              .replaceAll('@error', error.toString()));
    }
  }

  void searchInvoices() => _list.apply();
  void resetSearch() => _list.reset();
  Future<void> refreshData() => _list.refresh();

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

  bool get _hasActiveFilters => _list.query.isActive;

  Future<File> _createExport() async {
    final currency =
        context.read<AppSettingsProvider>().appSettings?.currency ?? 'INR';
    final showZatca = _lastVerifiedPhase2Enabled;
    _export.setStage('invoice.export_creating'.tr);
    final items = await _list.export(
        showZatca: showZatca,
        onProgress: (page, total) {
          if (mounted) {
            _export.setStage('invoice.export_fetching'
                .trParams({'page': '$page', 'total': '$total'}));
          }
        });
    if (mounted) _export.setStage('invoice.export_creating'.tr);
    return exportInvoiceList(items, currency: currency, showZatca: showZatca);
  }

  Future<void> _runExport() async {
    final exported = await _export.run(context, createFile: _createExport);
    if (!exported && mounted) {
      AppToast.error(context, 'invoice.export_failed'.tr);
    }
  }

  // ---------------------------------------------------------------- filters

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

  Widget _filters(InvoiceProvider provider, bool showZatca) =>
      InvoiceListFilters(
          panelKey: InvoiceListPage.filtersKey,
          invoiceNumberController: invoiceNumberController,
          searchTextController: searchTextController,
          phoneController: phoneController,
          showZatca: showZatca,
          selectedStatus: selectedStatus,
          selectedZatcaStatus: selectedZatcaStatus,
          statusOptions: provider.getStatusOptions(),
          zatcaOptions: provider.getZatcaStatusOptions(),
          fromField: _dateFilter(true),
          toField: _dateFilter(false),
          onSearch: _list.search.schedule,
          onSubmit: _list.search.flush,
          onReset: resetSearch,
          onStatusChanged: (v) {
            setState(() => selectedStatus = v);
            _list.search.cancel();
            searchInvoices();
          },
          onZatcaChanged: (v) {
            setState(() => selectedZatcaStatus = v);
            _list.search.cancel();
            searchInvoices();
          });

  // ------------------------------------------------------------ list cells

  InvoiceListRows get _rows => InvoiceListRows(
      selectedInvoiceIds: selectedInvoiceIds,
      isBulkSending: isBulkSending,
      onSelect: _list.select,
      onCopy: (invoice) {
        Clipboard.setData(ClipboardData(text: invoice.invoiceNumber));
        AppToast.success(context, 'invoice.invoice_number_copied'.tr);
      },
      onView: showInvoiceDetails,
      onMore: showInvoiceActionsSheet);

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
    if (!mounted || shouldSend != true || !canRunPhase2Action()) return;

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
            key: InvoiceListPage.filterToggleKey,
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
            key: InvoiceListPage.exportKey,
            icon: Icons.ios_share_rounded,
            label: _export.busy
                ? (_export.stage ?? 'invoice.export_creating'.tr)
                : 'invoice.export_tooltip'.tr,
            onPressed: canExport ? _runExport : null,
            busy: _export.busy),
        HeaderAction(
            key: InvoiceListPage.refreshKey,
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
        listenable: Listenable.merge([_list, _export, ..._filterInputs]),
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
              columns: _rows.columns(showZatca),
              cardBuilder: (v, _) => _rows.card(v, showZatca),
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
                  onPageChanged: _list.goToPage),
            ));
  }
}
