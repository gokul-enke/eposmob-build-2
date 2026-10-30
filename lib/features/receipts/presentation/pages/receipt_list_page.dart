import 'package:pos_machine/features/receipts/presentation/state/receipt_details_action.dart';
import '../../data/receipt_list_repository.dart';
import '../state/receipt_list_controller.dart';
import '../widgets/receipt_list_filters.dart';
import '../widgets/receipt_list_rows.dart';
import '../export/receipt_list_excel.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/list_receipt.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/features/receipts/presentation/widgets/receipt_create_dialog.dart';
import 'package:pos_machine/screens/transactions/widgets/share_helper.dart';

/// The receipts list: header, filters, table/cards and pagination, built on
/// the shared [ListPageScaffold]. Receipts are paged locally from the
/// complete cache in [InvoiceProvider].
class ReceiptListPage extends StatefulWidget {
  const ReceiptListPage({super.key, this.export});

  /// Replaces the export controller (tests).
  final ExportController? export;

  static const filtersKey = ValueKey('receipt-desktop-filters');
  static const filterToggleKey = ValueKey('receipt-list-filter-toggle');
  static const exportKey = ValueKey('receipt-list-export');
  static const refreshKey = ValueKey('receipt-list-refresh');

  @override
  State<ReceiptListPage> createState() => _ReceiptListPageState();
}

class _ReceiptListPageState extends State<ReceiptListPage>
    with ReceiptRowActions<ReceiptListPage> {
  final SideBarController sideBarController = Get.put(SideBarController());
  late final ReceiptListController controller;
  TextEditingController get dateFromController => controller.fromDate;
  TextEditingController get dateToController => controller.toDate;
  bool _showFilters = true;
  bool _visibilityInitialized = false;
  late final ExportController _export = widget.export ?? ExportController();
  final _tableScroll = ScrollController();

  List<TextEditingController> get _textInputs => controller.inputs;

  @override
  void initState() {
    super.initState();
    controller = ReceiptListController(
        ReceiptListRepository(context.read<InvoiceProvider>()),
        readToken: () => context.read<AuthModel>().token);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) loadReceipts();
    });
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

  @override
  void dispose() {
    controller.dispose();
    if (widget.export == null) _export.dispose();
    _tableScroll.dispose();
    super.dispose();
  }

  Future<void> loadReceipts() async {
    if (controller.initialized) return;

    try {
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null || accessToken.isEmpty) {
        AppToast.error(context, 'receipt.auth_token_missing'.tr);
        return;
      }

      // Load all receipts for local pagination
      await controller.load();
      if (!mounted) return;
    } catch (error) {
      if (!mounted) return;
      debugPrint("Error loading receipts: $error");
      showScaffold(
          context: context,
          message: 'receipt.error_fetching_receipts'
              .tr
              .replaceAll('@error', error.toString()));
    }
  }

  Future<void> refreshReceipts() async {
    try {
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null || accessToken.isEmpty) {
        AppToast.error(context, 'receipt.auth_token_missing'.tr);
        return;
      }

      // Reload all receipts
      await controller.refresh();
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      debugPrint("Error refreshing receipts: $error");
      showScaffold(
          context: context,
          message: 'receipt.error_refreshing_receipts'
              .tr
              .replaceAll('@error', error.toString()));
    }
  }

  Future<void> _selectDate(BuildContext context,
      {required bool isFromDate}) async {
    final DateTime? pickedDate = await showAutoDismissDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    // The time starts at the whole day: 00:00 (From) or 23:59 (To).
    final defaultTime = isFromDate
        ? const TimeOfDay(hour: 0, minute: 0)
        : const TimeOfDay(hour: 23, minute: 59);
    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: this.context,
        initialTime: defaultTime,
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
      final TimeOfDay resolvedTime = pickedTime ?? defaultTime;
      final DateTime fullDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        resolvedTime.hour,
        resolvedTime.minute,
        // The picker has no seconds; a To covers its whole minute.
        isFromDate ? 0 : 59,
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
      searchReceipts();
    }
  }

  void searchReceipts() => controller.apply();

  Future<void> refreshData() async {
    final String? accessToken =
        Provider.of<AuthModel>(context, listen: false).token;
    if (accessToken == null || accessToken.isEmpty) return;

    try {
      await controller.refresh();
    } catch (error) {
      if (!mounted) return;
      showScaffoldError(
          context: context,
          message: 'receipt.error_refreshing_receipts'
              .tr
              .replaceAll('@error', error.toString()));
    }
  }

  Future<void> _createReceipt() async {
    final result =
        await showCreateReceiptModal(context, MediaQuery.sizeOf(context));
    if (mounted && result == true) await refreshReceipts();
  }

  bool get _hasFilters => controller.query.isActive;

  Widget _filters(InvoiceProvider p) => ReceiptListFilters(
      controller: controller,
      filtersKey: ReceiptListPage.filtersKey,
      statusOptions: p.getReceiptStatusOptions(),
      methodOptions: p.getPaymentMethodOptions(),
      onSelectDate: (from) => _selectDate(context, isFromDate: from)).build();

  ReceiptListRows get _rows => ReceiptListRows(
      onCopy: (text) {
        Clipboard.setData(ClipboardData(text: text));
        AppToast.success(context, 'receipt.copied_to_clipboard'.tr);
      },
      onView: showReceiptDetails,
      onShare: (r) =>
          ShareHelper.showShareReceiptSheet(context: context, receipt: r));

  // ---------------------------------------------------------------- export

  Future<File> _createExport() async {
    final currency =
        context.read<AppSettingsProvider>().appSettings?.currency ?? 'INR';
    final rows = await controller.export(onProgress: (page, total) {
      if (mounted) {
        _export.setStage('receipt.export_fetching'
            .trParams({'page': '$page', 'total': '$total'}));
      }
    });
    if (mounted) _export.setStage('receipt.export_creating'.tr);
    return exportReceiptListExcel(rows, currency: currency);
  }

  Future<void> _runExport() async {
    final exported = await _export.run(context, createFile: _createExport);
    if (!exported && mounted) {
      AppToast.error(context, 'receipt.export_failed'.tr);
    }
  }

  // ----------------------------------------------------------------- build

  /// Filters, Export, Refresh — left to right, before Add.
  List<HeaderAction> _headerActions({required bool canExport}) => [
        HeaderAction(
            key: ReceiptListPage.filterToggleKey,
            icon: _showFilters
                ? Icons.filter_alt_rounded
                : Icons.filter_alt_outlined,
            label: _showFilters
                ? 'receipt.hide_filters'.tr
                : 'receipt.show_filters'.tr,
            onPressed: () => setState(() => _showFilters = !_showFilters),
            active: _showFilters,
            badge: !_showFilters && _hasFilters),
        HeaderAction(
            key: ReceiptListPage.exportKey,
            icon: Icons.ios_share_rounded,
            label: _export.busy
                ? (_export.stage ?? 'receipt.export_creating'.tr)
                : 'receipt.export_tooltip'.tr,
            onPressed: canExport ? _runExport : null,
            busy: _export.busy),
        HeaderAction(
            key: ReceiptListPage.refreshKey,
            icon: Icons.refresh_rounded,
            label: 'list.refresh'.tr,
            onPressed: refreshData),
      ];

  @override
  Widget build(BuildContext context) {
    final p = context.watch<InvoiceProvider>();
    final rows = p.getListReceipt ?? <Receipt>[];
    return ListenableBuilder(
        listenable: Listenable.merge([controller, _export, ..._textInputs]),
        builder: (context, _) => ListPageScaffold<Receipt>(
              header: PageHeader(
                  icon: Icons.receipt_long_outlined,
                  title: 'receipt.list_title'.tr,
                  subtitle: 'receipt.subtitle'.tr,
                  actions: _headerActions(
                      canExport: !p.isLoading && rows.isNotEmpty),
                  onAdd: _createReceipt,
                  addLabel: 'receipt.create_receipt_button'.tr,
                  addShortLabel: 'receipt.mobile_create_button'.tr),
              filters: _filters(p),
              showFilters: _showFilters,
              isLoading: p.isLoading,
              items: rows,
              tableScrollController: _tableScroll,
              minTableWidth: 1100,
              columns: _rows.columns(),
              cardBuilder: (r, _) => _rows.card(r),
              emptyState: AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'receipt.no_receipts_available'.tr,
                  subtitle: 'receipt.try_adjusting_filters'.tr),
              onRefresh: refreshData,
              pagination: ListPagination(
                  currentPage: p.receiptCurrentPage,
                  totalPages: p.receiptTotalPages,
                  itemsPerPage: p.receiptItemsPerPage,
                  countLabel: 'receipt.page_count'
                      .trParams({'count': '${rows.length}'}),
                  onPageChanged: controller.goToPage),
            ));
  }
}
