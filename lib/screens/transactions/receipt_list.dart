import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../components/build_calendar_selection.dart';
import '../../components/build_dialog_box.dart';
import '../../components/filter_toggle_button.dart';
import '../../components/export_share_button.dart';
import '../../core/ui/app_colors.dart';
import '../../core/ui/app_surface.dart';
import '../../core/ui/list_page/filter_panel.dart';
import '../../core/ui/list_page/list_page_header.dart';
import '../../core/ui/list_page/list_page_scaffold.dart';
import '../../controllers/sidebar_controller.dart';
import '../../helpers/date_helper.dart';
import '../../helpers/ui_code_labels.dart';
import '../../models/list_receipt.dart';
import '../../providers/auth_model.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import '../../services/list_excel_export_service.dart';
import 'create_receipt_modal.dart';
import 'widgets/common_details_dialog.dart';
import 'widgets/share_helper.dart';

class ReceiptListScreen extends StatefulWidget {
  const ReceiptListScreen({super.key});

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

  final FocusNode receiptNoFocusNode = FocusNode();
  final FocusNode referenceNoFocusNode = FocusNode();
  final FocusNode nameFocusNode = FocusNode();
  final FocusNode phoneFocusNode = FocusNode();
  final FocusNode emailFocusNode = FocusNode();
  final FocusNode statusFocusNode = FocusNode();
  final FocusNode paymentMethodFocusNode = FocusNode();

  bool isInitialized = false;
  bool _showFilters = true;
  bool _visibilityInitialized = false;
  Timer? _searchDebounce;
  final _tableScroll = ScrollController();
  final _exportProgress = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) loadReceipts();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tableScroll.dispose();
    _exportProgress.dispose();
    searchTextController.dispose();
    receiptNumberController.dispose();
    paymentReferenceController.dispose();
    phoneController.dispose();
    emailController.dispose();
    dateFromController.dispose();
    dateToController.dispose();
    receiptNoFocusNode.dispose();
    referenceNoFocusNode.dispose();
    nameFocusNode.dispose();
    phoneFocusNode.dispose();
    emailFocusNode.dispose();
    statusFocusNode.dispose();
    paymentMethodFocusNode.dispose();
    super.dispose();
  }

  Future<void> loadReceipts() async {
    if (isInitialized) return;

    try {
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null || accessToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('receipt.auth_token_missing'.tr)),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('receipt.auth_token_missing'.tr)),
        );
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
    _searchDebounce?.cancel();
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

  void resetSearch() {
    _searchDebounce?.cancel();
    debugPrint("Resetting all filters");
    setState(() {
      searchTextController.clear();
      receiptNumberController.clear();
      paymentReferenceController.clear();
      phoneController.clear();
      emailController.clear();
      dateFromController.clear();
      dateToController.clear();
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_visibilityInitialized) {
      _showFilters =
          MediaQuery.sizeOf(context).width >= ListLayoutBreakpoints.mobile;
      _visibilityInitialized = true;
    }
  }

  bool get _hasFilters =>
      [
        receiptNumberController,
        paymentReferenceController,
        searchTextController,
        phoneController,
        emailController,
        dateFromController,
        dateToController
      ].any((c) => c.text.isNotEmpty) ||
      selectedStatus != null ||
      paymentMethod != null;

  Widget _text(TextEditingController controller, FocusNode focus, String label,
          IconData icon,
          {TextInputType? keyboardType}) =>
      TextField(
          controller: controller,
          focusNode: focus,
          keyboardType: keyboardType,
          decoration: listFilterDecoration(label, icon),
          onChanged: (_) {
            _searchDebounce?.cancel();
            _searchDebounce =
                Timer(const Duration(milliseconds: 350), searchReceipts);
          },
          onSubmitted: (_) => searchReceipts());

  Widget _date(bool from) => TextField(
      controller: from ? dateFromController : dateToController,
      readOnly: true,
      decoration: listFilterDecoration(
          from ? 'receipt.from_date'.tr : 'receipt.to_date'.tr,
          Icons.calendar_today_outlined),
      onTap: () => _selectDate(context, isFromDate: from));

  Widget _filters(InvoiceProvider p) => FilterPanel(
          key: const ValueKey('receipt-desktop-filters'),
          title: 'receipt.find'.tr,
          hint: 'receipt.filter_hint'.tr,
          onReset: resetSearch,
          fields: [
            _text(receiptNumberController, receiptNoFocusNode,
                'receipt.receipt_no_hint'.tr, Icons.receipt_long_outlined),
            _text(paymentReferenceController, referenceNoFocusNode,
                'receipt.reference_no_hint'.tr, Icons.tag_outlined),
            _text(searchTextController, nameFocusNode, 'receipt.name_hint'.tr,
                Icons.person_outline),
            _text(phoneController, phoneFocusNode, 'receipt.phone_hint'.tr,
                Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            _text(emailController, emailFocusNode, 'receipt.email_hint'.tr,
                Icons.email_outlined,
                keyboardType: TextInputType.emailAddress),
            DropdownButtonFormField<String>(
                key: ValueKey('receipt-status-$selectedStatus'),
                initialValue: selectedStatus,
                focusNode: statusFocusNode,
                isExpanded: true,
                decoration: listFilterDecoration(
                    'receipt.col_status'.tr, Icons.check_circle_outline),
                items: [
                  DropdownMenuItem<String>(
                      value: null, child: Text('receipt.hint_all_status'.tr)),
                  for (final v in {
                    ...p
                        .getReceiptStatusOptions()
                        .where((v) => v != 'All Status'),
                    if (selectedStatus != null) selectedStatus!
                  })
                    DropdownMenuItem(
                        value: v, child: Text(UiCodeLabels.status(v)))
                ],
                onChanged: (v) {
                  setState(() => selectedStatus = v);
                  searchReceipts();
                }),
            DropdownButtonFormField<String>(
                key: ValueKey('receipt-method-$paymentMethod'),
                initialValue: paymentMethod,
                focusNode: paymentMethodFocusNode,
                isExpanded: true,
                decoration: listFilterDecoration(
                    'receipt.col_method'.tr, Icons.payment_outlined),
                items: [
                  DropdownMenuItem<String>(
                      value: null, child: Text('receipt.hint_all_payment'.tr)),
                  for (final v in {
                    ...p
                        .getPaymentMethodOptions()
                        .where((v) => v != 'All Payment Methods'),
                    if (paymentMethod != null) paymentMethod!
                  })
                    DropdownMenuItem(
                        value: v, child: Text(UiCodeLabels.payment(v)))
                ],
                onChanged: (v) {
                  setState(() => paymentMethod = v);
                  searchReceipts();
                }),
            _date(true),
            _date(false),
          ]);

  Widget _badge(String text, Color color) => Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(8)),
          child: Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600))));

  Widget _status(Receipt r) => _badge(
      UiCodeLabels.status(r.receiptStatus),
      switch (r.receiptStatus.toLowerCase()) {
        'paid' => AppColors.green,
        'pending' => const Color(0xFF9A6700),
        'fail' || 'failed' => AppColors.red,
        _ => AppColors.muted
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

  Widget _typeBadge(Receipt r) => _badge(
      _type(r),
      r.receiptPayments.any((p) => p.invoiceId != null)
          ? (r.receiptPayments.any((p) => p.invoiceId == null)
              ? const Color(0xFF9A6700)
              : ColorManager.kPrimaryColor)
          : AppColors.green);

  Widget _copy(String text) => Row(children: [
        Expanded(child: TableCells.text(text)),
        if (text.isNotEmpty)
          IconButton(
              icon: const Icon(Icons.copy_outlined, size: 16),
              tooltip: 'receipt.copy'.tr,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                showScaffold(
                    context: context,
                    message: 'receipt.copied_to_clipboard'.tr);
              })
      ]);

  Widget _actions(Receipt r) => Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TableCells.viewButton(() => _showReceiptDetails(r)),
            SizedBox(
                width: 36,
                height: 36,
                child: IconButton.outlined(
                    tooltip: 'receipt.share_action'.tr,
                    style: IconButton.styleFrom(
                        foregroundColor: ColorManager.kPrimaryColor,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    icon: const Icon(Icons.share_outlined, size: 18),
                    onPressed: () => ShareHelper.showShareReceiptSheet(
                        context: context, receipt: r))),
          ]);

  Widget _card(Receipt r) => AppSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TableCells.identity(r.customer.user.name),
        _copy(r.receiptNumber),
        Text('${'receipt.field_amount'.tr}: ${r.amount}'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [_typeBadge(r), _status(r)]),
        _copy(r.paymentReference),
        _actions(r),
      ]));

  Future<File> _createExport() async {
    if (_searchDebounce?.isActive ?? false) searchReceipts();
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
          if (mounted)
            _exportProgress.value = 'receipt.export_fetching'
                .trParams({'page': '$page', 'total': '$total'});
        });
    if (mounted) _exportProgress.value = 'receipt.export_creating'.tr;
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

  @override
  Widget build(BuildContext context) {
    final p = context.watch<InvoiceProvider>();
    final rows = p.getListReceipt ?? <Receipt>[];
    return LayoutBuilder(
        builder: (context, bounds) => ListPageScaffold<Receipt>(
              header: ListPageHeader(
                  icon: Icons.receipt_long_outlined,
                  title: 'receipt.list_title'.tr,
                  subtitle: 'receipt.subtitle'.tr,
                  onRefresh: refreshData,
                  onAdd: () async {
                    final result = await showCreateReceiptModal(
                        context, MediaQuery.sizeOf(context));
                    if (mounted && result == true) await refreshReceipts();
                  },
                  addLabel: 'receipt.create_receipt_button'.tr,
                  addShortLabel: 'receipt.mobile_create_button'.tr,
                  extraActions: [
                    FilterToggleButton(
                        showFilters: _showFilters,
                        hasActiveFilters: _hasFilters,
                        activeFiltersListenable: Listenable.merge([
                          receiptNumberController,
                          paymentReferenceController,
                          searchTextController,
                          phoneController,
                          emailController,
                          dateFromController,
                          dateToController
                        ]),
                        activeFiltersBuilder: () => _hasFilters,
                        onPressed: () =>
                            setState(() => _showFilters = !_showFilters),
                        showTooltip: 'receipt.show_filters'.tr,
                        hideTooltip: 'receipt.hide_filters'.tr),
                    ExportShareButton(
                        createFile: _createExport,
                        label: 'supplier_transactions.export'.tr,
                        loadingLabel: 'receipt.export_creating'.tr,
                        progressLabel: _exportProgress,
                        tooltip: 'receipt.export_tooltip'.tr,
                        errorMessage: 'receipt.export_failed'.tr,
                        mimeType:
                            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                        compact: bounds.maxWidth < 560,
                        enabled: !p.isLoading && rows.isNotEmpty)
                  ]),
              filters: _filters(p),
              showFilters: _showFilters,
              isLoading: p.isLoading,
              items: rows,
              tableScrollController: _tableScroll,
              tableMinWidth: 1100,
              columns: [
                TableColumnDef(
                    label: 'receipt.col_receipt_number'.tr,
                    flex: 1.6,
                    cellBuilder: (r, _) => _copy(r.receiptNumber)),
                TableColumnDef(
                    label: 'receipt.col_customer_name'.tr,
                    flex: 1.8,
                    cellBuilder: (r, _) =>
                        TableCells.identity(r.customer.user.name)),
                TableColumnDef(
                    label: 'receipt.field_amount'.tr,
                    cellBuilder: (r, _) => TableCells.text(r.amount)),
                TableColumnDef(
                    label: 'receipt.col_type'.tr,
                    flex: 1.6,
                    cellBuilder: (r, _) => _typeBadge(r)),
                TableColumnDef(
                    label: 'receipt.col_status'.tr,
                    cellBuilder: (r, _) => _status(r)),
                TableColumnDef(
                    label: 'receipt.col_payment_reference'.tr,
                    flex: 1.6,
                    cellBuilder: (r, _) => _copy(r.paymentReference)),
                TableColumnDef(
                    label: 'receipt.col_action'.tr,
                    flex: 1.6,
                    cellBuilder: (r, _) => _actions(r)),
              ],
              cardBuilder: (r, _) => _card(r),
              emptyState:
                  Center(child: Text('receipt.no_receipts_available'.tr)),
              onRefresh: refreshData,
              currentPage: p.receiptCurrentPage,
              totalPages: p.receiptTotalPages,
              itemsPerPage: p.receiptItemsPerPage,
              countLabel:
                  'receipt.page_count'.trParams({'count': '${rows.length}'}),
              onPageChanged: (page) {
                if (_searchDebounce?.isActive ?? false) {
                  searchReceipts();
                  return;
                }
                p.goToReceiptPage(page);
              },
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
            }).toList(),
          ],
        ),
      ),
    );
  }
}
