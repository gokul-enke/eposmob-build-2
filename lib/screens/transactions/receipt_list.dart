import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/utils/search_debouncer.dart';
import 'package:provider/provider.dart';

import '../../components/build_calendar_selection.dart';
import '../../components/build_dialog_box.dart';
import '../../controllers/sidebar_controller.dart';
import '../../helpers/date_helper.dart';
import '../../helpers/ui_code_labels.dart';
import '../../models/list_receipt.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/auth_model.dart';
import '../../providers/invoice_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import '../../services/list_excel_export_service.dart';
import 'create_receipt_modal.dart';
import 'widgets/common_details_dialog.dart';
import 'widgets/share_helper.dart';

/// The receipts list: header, filters, table/cards and pagination, built on
/// the shared [ListPageScaffold]. Receipts are paged locally from the
/// complete cache in [InvoiceProvider].
class ReceiptListScreen extends StatefulWidget {
  const ReceiptListScreen({super.key, this.export});

  /// Replaces the export controller (tests).
  final ExportController? export;

  static const filtersKey = ValueKey('receipt-desktop-filters');
  static const filterToggleKey = ValueKey('receipt-list-filter-toggle');
  static const exportKey = ValueKey('receipt-list-export');
  static const refreshKey = ValueKey('receipt-list-refresh');

  @override
  State<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  final TextEditingController searchTextController = TextEditingController();
  final TextEditingController receiptNumberController = TextEditingController();
  final TextEditingController paymentReferenceController =
      TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController dateFromController = TextEditingController();
  final TextEditingController dateToController = TextEditingController();
  String? selectedStatus;
  String? paymentMethod;

  bool isInitialized = false;
  bool _showFilters = true;
  bool _visibilityInitialized = false;
  late final SearchDebouncer _search =
      SearchDebouncer(searchReceipts, delay: const Duration(milliseconds: 350));
  late final ExportController _export = widget.export ?? ExportController();
  final _tableScroll = ScrollController();

  List<TextEditingController> get _textInputs => [
        receiptNumberController,
        paymentReferenceController,
        searchTextController,
        phoneController,
        emailController,
        dateFromController,
        dateToController,
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) loadReceipts();
    });
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

  @override
  void dispose() {
    _search.dispose();
    if (widget.export == null) _export.dispose();
    _tableScroll.dispose();
    for (final input in _textInputs) {
      input.dispose();
    }
    super.dispose();
  }

  Future<void> loadReceipts() async {
    if (isInitialized) return;

    try {
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null || accessToken.isEmpty) {
        AppToast.error(context, 'receipt.auth_token_missing'.tr);
        return;
      }

      // Load all receipts for local pagination
      await Provider.of<InvoiceProvider>(context, listen: false)
          .loadAllReceipts(accessToken);
      if (!mounted) return;
      setState(() {
        isInitialized = true;
      });
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
      await Provider.of<InvoiceProvider>(context, listen: false)
          .loadAllReceipts(accessToken);
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
      searchReceipts();
    }
  }

  void searchReceipts() {
    _search.cancel();
    final String searchText = searchTextController.text.trim();
    debugPrint("Searching for receipts with name: '$searchText'");

    InvoiceProvider provider =
        Provider.of<InvoiceProvider>(context, listen: false);
    provider.applyReceiptFilters(
        name: searchText,
        receiptNumber: receiptNumberController.text,
        paymentReference: paymentReferenceController.text,
        receiptStatus: selectedStatus,
        phone: phoneController.text,
        email: emailController.text,
        paymentMethod: paymentMethod,
        dateFrom:
            dateFromController.text.isEmpty ? null : dateFromController.text,
        dateTo: dateToController.text.isEmpty ? null : dateToController.text,
        page: 1);
  }

  /// Clears every input; the provider reloads the complete receipt cache.
  void resetSearch() {
    _search.cancel();
    debugPrint("Resetting all filters");
    setState(() {
      for (final input in _textInputs) {
        input.clear();
      }
      selectedStatus = null;
      paymentMethod = null;
    });

    Provider.of<InvoiceProvider>(context, listen: false).resetReceiptFilters();
  }

  Future<void> refreshData() async {
    final String? accessToken =
        Provider.of<AuthModel>(context, listen: false).token;
    if (accessToken == null || accessToken.isEmpty) return;

    try {
      await context.read<InvoiceProvider>().loadAllReceipts(accessToken);
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

  bool get _hasFilters =>
      _textInputs.any((c) => c.text.isNotEmpty) ||
      selectedStatus != null ||
      paymentMethod != null;

  // ---------------------------------------------------------------- filters

  FilterFieldDef _text(
          TextEditingController controller, String label, IconData icon,
          {TextInputType keyboardType = TextInputType.text}) =>
      TextFilterField(
          controller: controller,
          label: label,
          hint: label,
          icon: icon,
          keyboardType: keyboardType);

  FilterFieldDef _date(bool from) {
    final label = from ? 'receipt.from_date'.tr : 'receipt.to_date'.tr;
    return CustomFilterField(
        child: TextField(
            controller: from ? dateFromController : dateToController,
            readOnly: true,
            textAlignVertical: TextAlignVertical.center,
            style: AppTextStyles.input,
            decoration: AppInputDecoration.filter(
                label: label, hint: label, icon: Icons.calendar_today_outlined),
            onTap: () => _selectDate(context, isFromDate: from)));
  }

  /// The provider's options plus the current value, without the "All"
  /// placeholder (shown as the `null` option instead).
  List<FilterOption<String?>> _options(String allLabel, List<String> values,
          String placeholder, String? current, String Function(String) label) =>
      [
        FilterOption<String?>(null, allLabel),
        for (final v in {
          ...values.where((v) => v != placeholder),
          if (current != null) current,
        })
          FilterOption<String?>(v, label(v)),
      ];

  Widget _filters(InvoiceProvider p) => FilterPanel(
          key: ReceiptListScreen.filtersKey,
          title: 'receipt.find'.tr,
          hint: 'receipt.filter_hint'.tr,
          resetLabel: 'list.reset'.tr,
          onSearch: _search.schedule,
          onSubmit: _search.flush,
          onReset: resetSearch,
          fields: [
            _text(receiptNumberController, 'receipt.receipt_no_hint'.tr,
                Icons.receipt_long_outlined),
            _text(paymentReferenceController, 'receipt.reference_no_hint'.tr,
                Icons.tag_outlined),
            _text(searchTextController, 'receipt.name_hint'.tr,
                Icons.person_outline),
            _text(phoneController, 'receipt.phone_hint'.tr,
                Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            _text(emailController, 'receipt.email_hint'.tr,
                Icons.email_outlined,
                keyboardType: TextInputType.emailAddress),
            DropdownFilterField<String?>(
                label: 'receipt.col_status'.tr,
                icon: Icons.check_circle_outline,
                value: selectedStatus,
                options: _options(
                    'receipt.hint_all_status'.tr,
                    p.getReceiptStatusOptions(),
                    'All Status',
                    selectedStatus,
                    UiCodeLabels.status),
                onChanged: (v) {
                  setState(() => selectedStatus = v);
                  searchReceipts();
                }),
            DropdownFilterField<String?>(
                label: 'receipt.col_method'.tr,
                icon: Icons.payment_outlined,
                value: paymentMethod,
                options: _options(
                    'receipt.hint_all_payment'.tr,
                    p.getPaymentMethodOptions(),
                    'All Payment Methods',
                    paymentMethod,
                    UiCodeLabels.payment),
                onChanged: (v) {
                  setState(() => paymentMethod = v);
                  searchReceipts();
                }),
            _date(true),
            _date(false),
          ]);

  // ------------------------------------------------------------ list cells

  static String _orDash(String value) => value.trim().isEmpty ? '—' : value;

  Widget _status(Receipt r) => AppBadge(
      label: UiCodeLabels.status(r.receiptStatus),
      tone: switch (r.receiptStatus.toLowerCase()) {
        'paid' => AppBadgeTone.success,
        'pending' => AppBadgeTone.warning,
        'fail' || 'failed' => AppBadgeTone.danger,
        _ => AppBadgeTone.neutral,
      });

  String _type(Receipt r) {
    final invoice = r.receiptPayments.any((p) => p.invoiceId != null);
    final general = r.receiptPayments.any((p) => p.invoiceId == null);
    return (invoice && general
            ? 'receipt.type_mixed'
            : invoice
                ? 'receipt.type_invoice_payment'
                : 'receipt.type_general_payment')
        .tr;
  }

  Widget _typeBadge(Receipt r) {
    final invoice = r.receiptPayments.any((p) => p.invoiceId != null);
    final general = r.receiptPayments.any((p) => p.invoiceId == null);
    return AppBadge(
        label: _type(r),
        tone: invoice
            ? (general ? AppBadgeTone.warning : AppBadgeTone.info)
            : AppBadgeTone.success);
  }

  Widget _copyButton(String text) => IconButton(
      icon: const Icon(Icons.copy_outlined, size: 16),
      color: AppColors.muted,
      tooltip: 'receipt.copy'.tr,
      onPressed: () {
        Clipboard.setData(ClipboardData(text: text));
        AppToast.success(context, 'receipt.copied_to_clipboard'.tr);
      });

  /// Table cell: the value with a copy button (when there is a value).
  Widget _copyCell(String text) => Row(children: [
        Expanded(child: TableCells.text(_orDash(text))),
        if (text.isNotEmpty) _copyButton(text),
      ]);

  /// Card line: label, value and a copy button (when there is a value).
  Widget _copyInfo(String label, String text) => InfoRow(
      label: label,
      value: _orDash(text),
      trailing: text.isEmpty ? null : _copyButton(text));

  Widget _actionButtons(Receipt r) => Wrap(
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
                onPressed: () => _showReceiptDetails(r)),
            AppSquareIconButton(
                icon: Icons.share_outlined,
                tooltip: 'receipt.share_action'.tr,
                size: AppSizes.compactControl,
                iconSize: 18,
                radius: AppRadius.tile,
                foreground: AppColors.primary,
                onPressed: () => ShareHelper.showShareReceiptSheet(
                    context: context, receipt: r)),
          ]);

  Widget _card(Receipt r) => AppListCard(
      title: _orDash(r.customer.user.name),
      leading: AppAvatar(
          name: r.customer.user.name, semanticLabel: r.customer.user.name),
      trailing: _status(r),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _copyInfo('receipt.col_receipt_number'.tr, r.receiptNumber),
        InfoRow(label: 'receipt.field_amount'.tr, value: _orDash(r.amount)),
        _copyInfo('receipt.col_payment_reference'.tr, r.paymentReference),
        const SizedBox(height: AppSpacing.sm),
        _typeBadge(r),
        const SizedBox(height: AppSpacing.md),
        _actionButtons(r),
      ]));

  List<TableColumnDef<Receipt>> _columns() => [
        TableColumnDef(
            label: 'receipt.col_receipt_number'.tr,
            flex: 1.6,
            cellBuilder: (r, _) => _copyCell(r.receiptNumber)),
        TableColumnDef(
            label: 'receipt.col_customer_name'.tr,
            flex: 1.8,
            cellBuilder: (r, _) => TableCells.avatarName(
                name: _orDash(r.customer.user.name),
                avatar: AppAvatar(
                    name: r.customer.user.name,
                    semanticLabel: r.customer.user.name,
                    size: 36))),
        TableColumnDef(
            label: 'receipt.field_amount'.tr,
            cellBuilder: (r, _) => TableCells.text(_orDash(r.amount))),
        TableColumnDef(
            label: 'receipt.col_type'.tr,
            flex: 1.6,
            cellBuilder: (r, _) => TableCells.widget(_typeBadge(r))),
        TableColumnDef(
            label: 'receipt.col_status'.tr,
            cellBuilder: (r, _) => TableCells.widget(_status(r))),
        TableColumnDef(
            label: 'receipt.col_payment_reference'.tr,
            flex: 1.6,
            cellBuilder: (r, _) => _copyCell(r.paymentReference)),
        TableColumnDef(
            label: 'receipt.col_action'.tr,
            flex: 1.6,
            cellBuilder: (r, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _actionButtons(r)))),
      ];

  // ---------------------------------------------------------------- export

  Future<File> _createExport() async {
    _search.flushPending();
    final token = context.read<AuthModel>().token;
    if (token == null || token.isEmpty) {
      throw StateError('Missing access token');
    }
    final currency =
        context.read<AppSettingsProvider>().appSettings?.currency ?? 'INR';
    final rows = await context.read<InvoiceProvider>().fetchReceiptsForExport(
        accessToken: token,
        name: searchTextController.text,
        receiptNumber: receiptNumberController.text,
        paymentReference: paymentReferenceController.text,
        phone: phoneController.text,
        email: emailController.text,
        status: selectedStatus,
        paymentMethod: paymentMethod,
        fromDate: dateFromController.text,
        toDate: dateToController.text,
        onProgress: (page, total) {
          if (mounted) {
            _export.setStage('receipt.export_fetching'
                .trParams({'page': '$page', 'total': '$total'}));
          }
        });
    if (mounted) _export.setStage('receipt.export_creating'.tr);
    return ListExcelExportService.export<Receipt>(
        items: rows,
        fileNamePrefix: 'receipts',
        sheetName: 'receipt.list_title'.tr,
        columns: [
          ListExportColumn(
              label: 'receipt.col_receipt_number'.tr,
              value: (r, _) => r.receiptNumber),
          ListExportColumn(
              label: 'receipt.col_customer_name'.tr,
              value: (r, _) => r.customer.user.name),
          ListExportColumn(
              label: 'receipt.phone_hint'.tr,
              value: (r, _) => r.customer.user.phone),
          ListExportColumn(
              label: 'receipt.email_hint'.tr,
              value: (r, _) => r.customer.user.email),
          ListExportColumn(
              label: 'receipt.field_amount'.tr,
              value: (r, _) => ListExcelExportService.numericValue(r.amount)),
          ListExportColumn(
              label: 'supplier_transactions.currency'.tr,
              value: (r, _) => currency),
          ListExportColumn(
              label: 'receipt.col_type'.tr, value: (r, _) => _type(r)),
          ListExportColumn(
              label: 'receipt.col_status'.tr,
              value: (r, _) => UiCodeLabels.status(r.receiptStatus)),
          ListExportColumn(
              label: 'receipt.col_payment_reference'.tr,
              value: (r, _) => r.paymentReference),
          ListExportColumn(
              label: 'receipt.col_method'.tr,
              value: (r, _) => r.paymentMethods.join(', ')),
          ListExportColumn(
              label: 'receipt.col_date'.tr,
              value: (r, _) => r.createdAt.toIso8601String()),
        ]);
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
            key: ReceiptListScreen.filterToggleKey,
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
            key: ReceiptListScreen.exportKey,
            icon: Icons.ios_share_rounded,
            label: _export.busy
                ? (_export.stage ?? 'receipt.export_creating'.tr)
                : 'receipt.export_tooltip'.tr,
            onPressed: canExport ? _runExport : null,
            busy: _export.busy),
        HeaderAction(
            key: ReceiptListScreen.refreshKey,
            icon: Icons.refresh_rounded,
            label: 'list.refresh'.tr,
            onPressed: refreshData),
      ];

  @override
  Widget build(BuildContext context) {
    final p = context.watch<InvoiceProvider>();
    final rows = p.getListReceipt ?? <Receipt>[];
    return ListenableBuilder(
        listenable: Listenable.merge([_export, ..._textInputs]),
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
              columns: _columns(),
              cardBuilder: (r, _) => _card(r),
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
                  onPageChanged: (page) {
                    // A search still waiting on the debounce wins: it goes
                    // back to page 1 with the typed filters.
                    if (_search.isPending) {
                      _search.flush();
                      return;
                    }
                    p.goToReceiptPage(page);
                  }),
            ));
  }

  void _showReceiptDetails(Receipt receipt) {
    showDialog(
      context: context,
      builder: (context) => CommonDetailsDialog(
        title: 'receipt.receipt_details_title'.tr,
        gridColumns: [
          [
            CommonDetailsDialog.buildKeyValueRow(
                'receipt.field_receipt_number'.tr, receipt.receiptNumber,
                copyable: true),
            CommonDetailsDialog.buildKeyValueRow(
                'receipt.field_customer'.tr, receipt.customer.user.name),
            CommonDetailsDialog.buildKeyValueRow(
                'receipt.field_amount'.tr, receipt.amount),
          ],
          [
            CommonDetailsDialog.buildKeyValueRow(
                'receipt.field_company'.tr, receipt.company.name),
            CommonDetailsDialog.buildKeyValueRow(
                'receipt.field_status'.tr, receipt.receiptStatus),
            CommonDetailsDialog.buildKeyValueRow(
                'receipt.field_payment_reference'.tr, receipt.paymentReference),
          ],
        ],
        sectionTitle: 'receipt.payments_section_title'.tr,
        tableContent: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'receipt.col_date'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s11,
                        0.15,
                        ColorManager.kTextColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'receipt.col_invoice'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s11,
                        0.15,
                        ColorManager.kTextColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'receipt.col_method'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s11,
                        0.15,
                        ColorManager.kTextColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'receipt.field_amount'.tr,
                      textAlign: TextAlign.right,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s11,
                        0.15,
                        ColorManager.kTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Table Rows
            ...receipt.receiptPayments.map((p) {
              final dateStr = DateHelper.formatDate(
                DateTime.tryParse(p.paymentDate) ?? receipt.createdAt,
              );
              final invStr = p.invoiceId != null
                  ? 'INV-${p.invoiceId}'
                  : (p.description?.isNotEmpty == true
                      ? p.description!
                      : 'receipt.type_general_payment'.tr);
              return Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        dateStr,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s13,
                          0.19,
                          ColorManager.kTitleTextColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        invStr,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s13,
                          0.19,
                          ColorManager.kTitleTextColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        p.paymentMethod,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s13,
                          0.19,
                          ColorManager.kTitleTextColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        p.paidAmount,
                        textAlign: TextAlign.right,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s13,
                          0.19,
                          ColorManager.kTitleTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
