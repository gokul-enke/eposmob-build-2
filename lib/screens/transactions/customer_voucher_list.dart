import 'dart:io';
import '../../components/export_share_button.dart';
import '../../core/ui/app_surface.dart';
import '../../core/ui/list_page/filter_panel.dart';
import '../../core/ui/list_page/list_page_header.dart';
import '../../core/ui/list_page/list_page_scaffold.dart';
import '../../services/list_excel_export_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:intl/intl.dart';
import '../../components/build_calendar_selection.dart';

import 'package:pos_machine/newcomponents/custom_dialog_box.dart';

import 'package:pos_machine/models/customer_voucher.dart';
import 'package:pos_machine/providers/customer_voucher_provider.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter/foundation.dart';

import '../../components/filter_toggle_button.dart';

import '../../controllers/sidebar_controller.dart';
import '../../providers/auth_model.dart';
import '../../providers/app_settings_provider.dart';

import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'widgets/customer_voucher_print.dart';
import 'widgets/common_details_dialog.dart';
import 'widgets/share_helper.dart';

class CustomerVoucherListScreen extends StatefulWidget {
  const CustomerVoucherListScreen({super.key});

  @override
  State<CustomerVoucherListScreen> createState() =>
      _CustomerVoucherListScreenState();
}

class _CustomerVoucherListScreenState extends State<CustomerVoucherListScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  bool isInitialized = false;
  bool _visibilityInitialized = false;
  final _nameKey = GlobalKey<TextFilterFieldState>();
  final _numberKey = GlobalKey<TextFilterFieldState>();
  final _tableController = ScrollController();
  final TextEditingController searchTextController = TextEditingController();
  final TextEditingController voucherNumberController = TextEditingController();
  final TextEditingController dateFromController = TextEditingController();
  final TextEditingController dateToController = TextEditingController();
  String? selectedType;
  String? selectedStatus;
  bool _showFilters = true;

  final FocusNode nameFocusNode = FocusNode();
  final FocusNode voucherNoFocusNode = FocusNode();
  final FocusNode typeFocusNode = FocusNode();
  final FocusNode statusFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) loadVouchers();
    });
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

  @override
  void dispose() {
    _tableController.dispose();
    searchTextController.dispose();
    voucherNumberController.dispose();
    dateFromController.dispose();
    dateToController.dispose();
    nameFocusNode.dispose();
    voucherNoFocusNode.dispose();
    typeFocusNode.dispose();
    statusFocusNode.dispose();
    super.dispose();
  }

  Future<void> loadVouchers() async {
    if (isInitialized) return;

    try {
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null || accessToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('customer_voucher.auth_token_missing'.tr)),
        );
        return;
      }

      await Provider.of<CustomerVoucherProvider>(context, listen: false)
          .listAllCustomerVouchers(accessToken: accessToken);
      if (!mounted) return;
      final error = context.read<CustomerVoucherProvider>().loadError;
      if (error != null) throw error;
      setState(() {
        isInitialized = true;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('customer_voucher.error_loading_vouchers'
                .tr
                .replaceAll('@error', error.toString()))),
      );
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
    if (pickedDate != null && mounted && context.mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
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
      searchVouchers();
    }
  }

  void searchVouchers() {
    debugPrint("Searching with filters");
    CustomerVoucherProvider provider =
        Provider.of<CustomerVoucherProvider>(context, listen: false);
    provider.applyFilters(
      customerName: searchTextController.text,
      voucherNumber: voucherNumberController.text,
      type: selectedType,
      status: selectedStatus,
      dateFrom:
          dateFromController.text.isEmpty ? null : dateFromController.text,
      dateTo: dateToController.text.isEmpty ? null : dateToController.text,
    );
  }

  void resetSearch() {
    _nameKey.currentState?.cancelPendingSearch();
    _numberKey.currentState?.cancelPendingSearch();
    setState(() {
      searchTextController.clear();
      voucherNumberController.clear();
      dateFromController.clear();
      dateToController.clear();
      selectedType = null;
      selectedStatus = null;
    });

    Provider.of<CustomerVoucherProvider>(context, listen: false).resetFilters();
  }

  Future<void> refreshData() async {
    isInitialized = false;
    await loadVouchers();
  }

  Future<void> _showVoucherActionsSheet(CustomerVoucher voucher) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final appSettings =
            Provider.of<AppSettingsProvider>(context, listen: false)
                .appSettings;
        final bool phase2 = appSettings?.zatcaPhase2Enabled ?? false;

        final List<Widget> dynamicItems = [];

        // Always add the Share option
        dynamicItems.add(
          ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: ColorManager.kPrimaryColor.withOpacity(0.12),
              child: const Icon(Icons.share, color: ColorManager.kPrimaryColor),
            ),
            title: Text('customer_voucher.share_action'.tr),
            onTap: () {
              Navigator.pop(ctx);
              ShareHelper.showShareCustomerVoucherSheet(
                context: context,
                voucher: voucher,
              );
            },
          ),
        );

        // Only render ZATCA options when Phase 2 is enabled in settings
        if (phase2) {
          dynamicItems.addAll([
            // ZATCA Phase 2 (with PDF download/open)
            ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.orange.withOpacity(0.12),
                child: const Icon(Icons.description, color: Colors.orange),
              ),
              title: Text('customer_voucher.zatca_phase2_action'.tr),
              onTap: () async {
                Navigator.pop(ctx);
                await _performZatcaPhase2SendWithPdf(voucher);
              },
            ),
            // Send Credit Note to ZATCA (no PDF open)
            ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: ColorManager.kPrimaryColor.withOpacity(0.12),
                child:
                    const Icon(Icons.send, color: ColorManager.kPrimaryColor),
              ),
              title: Text('customer_voucher.send_credit_note_action'.tr),
              onTap: () async {
                Navigator.pop(ctx);
                await _performZatcaPhase2Send(voucher);
              },
            ),
          ]);
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'customer_voucher.more_options_title'.tr,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                ...dynamicItems,
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _performZatcaPhase2SendWithPdf(CustomerVoucher voucher) async {
    try {
      final String? token =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint(
          '[ZATCA][Phase2 Send With PDF] Start for voucher ${voucher.voucherNumber} (ID: ${voucher.id})');
      if (token == null || token.isEmpty) {
        debugPrint(
            '[ZATCA][Phase2 Send With PDF] ERROR: Missing authentication token');
        showScaffoldError(
            context: context, message: 'customer_voucher.missing_token'.tr);
        return;
      }

      showScaffold(
          context: context,
          message: 'customer_voucher.processing_zatca_phase2'.tr);
      showLoadingOverlay(context, message: 'customer_voucher.processing'.tr);

      final provider =
          Provider.of<CustomerVoucherProvider>(context, listen: false);
      final result = await provider.zatcaPhase2VoucherPrint(
        id: voucher.id,
        accessToken: token,
      );

      debugPrint('[ZATCA][Phase2 Send With PDF] Response: $result');
      if (result is Map &&
          ((result['status'] == 'success') ||
              (result['success'] == true) ||
              (result['status'] == true))) {
        final data = result['data'] ?? {};
        final String voucherNumber =
            (data['voucher_number']?.toString() ?? voucher.voucherNumber);
        final String? downloadUrl = data['download_url']?.toString();
        final String? fileName = data['filename']?.toString();
        if (downloadUrl != null && downloadUrl.isNotEmpty) {
          await _downloadAndOpenPdf(downloadUrl, suggestedFileName: fileName);
        }
        showScaffold(
          context: context,
          message: 'customer_voucher.processed_phase2'
              .tr
              .replaceAll('@number', voucherNumber),
        );
      } else {
        final msg = (result is Map ? result['message'] : null) ??
            'customer_voucher.process_phase2_failed'.tr;
        debugPrint('[ZATCA][Phase2 Send With PDF] ERROR: $msg');
        showScaffoldError(context: context, message: msg.toString());
      }
    } catch (e) {
      debugPrint('[ZATCA][Phase2 Send With PDF] EXCEPTION: $e');
      showScaffoldError(
          context: context,
          message: 'customer_voucher.error_generic'
              .tr
              .replaceAll('@error', e.toString()));
    } finally {
      hideLoadingOverlay();
    }
  }

  Future<void> _performZatcaPhase2Send(CustomerVoucher voucher) async {
    try {
      final String? token =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint(
          '[ZATCA][Phase2 Send] Start for voucher ${voucher.voucherNumber} (ID: ${voucher.id})');
      if (token == null || token.isEmpty) {
        debugPrint('[ZATCA][Phase2 Send] ERROR: Missing authentication token');
        showScaffoldError(
            context: context, message: 'customer_voucher.missing_token'.tr);
        return;
      }

      showScaffold(
          context: context, message: 'customer_voucher.sending_to_zatca'.tr);
      showLoadingOverlay(context, message: 'customer_voucher.sending'.tr);

      final provider =
          Provider.of<CustomerVoucherProvider>(context, listen: false);
      final result = await provider.zatcaPhase2VoucherPrint(
        id: voucher.id,
        accessToken: token,
      );

      debugPrint('[ZATCA][Phase2 Send] Response: $result');
      if (result is Map &&
          ((result['status'] == 'success') ||
              (result['success'] == true) ||
              (result['status'] == true))) {
        final data = result['data'] ?? {};
        final String voucherNumber =
            (data['voucher_number']?.toString() ?? voucher.voucherNumber);
        // Do NOT open PDF here per requirement. Just inform the user.
        showScaffold(
          context: context,
          message: 'customer_voucher.submitted_to_zatca'
              .tr
              .replaceAll('@number', voucherNumber),
        );
      } else {
        final msg = (result is Map ? result['message'] : null) ??
            'customer_voucher.send_to_zatca_failed'.tr;
        debugPrint('[ZATCA][Phase2 Send] ERROR: $msg');
        showScaffoldError(context: context, message: msg.toString());
      }
    } catch (e) {
      debugPrint('[ZATCA][Phase2 Send] EXCEPTION: $e');
      showScaffoldError(
          context: context,
          message: 'customer_voucher.error_generic'
              .tr
              .replaceAll('@error', e.toString()));
    } finally {
      hideLoadingOverlay();
    }
  }

  Future<void> _downloadAndOpenPdf(String url,
      {String? suggestedFileName}) async {
    try {
      if (kIsWeb) {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
        showScaffold(
            context: context,
            message: 'customer_voucher.opened_pdf_browser'.tr);
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final String fileName =
          (suggestedFileName != null && suggestedFileName.trim().isNotEmpty)
              ? suggestedFileName
              : 'voucher_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final String savePath = '${dir.path}/$fileName';

      final dio = Dio();
      await dio.download(
        url,
        savePath,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      await OpenFile.open(savePath);
      showScaffold(
          context: context, message: 'customer_voucher.pdf_downloaded'.tr);
    } catch (e) {
      debugPrint('[ZATCA][PDF] ERROR while downloading/opening: $e');
      try {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
      } catch (_) {}
      showScaffoldError(
          context: context, message: 'customer_voucher.failed_open_pdf'.tr);
    }
  }

  Widget _filters(CustomerVoucherProvider provider) => FilterPanel(
        key: const ValueKey('customer-voucher-desktop-filters'),
        title: 'customer_voucher.find'.tr,
        hint: 'customer_voucher.filter_hint'.tr,
        onReset: resetSearch,
        fields: [
          TextFilterField(
              key: _nameKey,
              controller: searchTextController,
              label: 'customer_voucher.customer_name_hint'.tr,
              icon: Icons.person_outline,
              onSearch: searchVouchers),
          TextFilterField(
              key: _numberKey,
              controller: voucherNumberController,
              label: 'customer_voucher.voucher_no_hint'.tr,
              icon: Icons.receipt_long_outlined,
              onSearch: searchVouchers),
          _dropdown(
              'customer_voucher.col_type'.tr,
              selectedType,
              {
                ...provider.getTypeOptions().where((v) => v != 'All Types'),
                if (selectedType != null) selectedType!
              }.toList(),
              UiCodeLabels.voucherType, (v) {
            setState(() => selectedType = v);
            searchVouchers();
          }),
          _dropdown(
              'customer_voucher.col_status'.tr,
              selectedStatus,
              provider
                  .getStatusOptions()
                  .where((v) => v != 'All Status')
                  .toList(),
              UiCodeLabels.status, (v) {
            setState(() => selectedStatus = v);
            searchVouchers();
          }),
          for (final from in [true, false])
            TextField(
                controller: from ? dateFromController : dateToController,
                readOnly: true,
                decoration: listFilterDecoration(
                    from
                        ? 'customer_voucher.from_date'.tr
                        : 'customer_voucher.to_date'.tr,
                    Icons.calendar_today_outlined),
                onTap: () => _selectDate(context, isFromDate: from)),
        ],
      );
  Widget _dropdown(String label, String? value, List<String> options,
          String Function(String) display, ValueChanged<String?> onChanged) =>
      DropdownButtonFormField<String>(
          key: ValueKey('$label:$value'),
          initialValue: value,
          isExpanded: true,
          decoration: listFilterDecoration(label, Icons.swap_vert),
          items: [
            DropdownMenuItem<String>(
                value: null,
                child: Text(label == 'customer_voucher.col_type'.tr
                    ? 'customer_voucher.hint_all_types'.tr
                    : 'customer_voucher.hint_all_status'.tr)),
            for (final option in options)
              DropdownMenuItem(value: option, child: Text(display(option)))
          ],
          onChanged: onChanged);

  Future<File> _createExport() {
    _nameKey.currentState?.cancelPendingSearch();
    _numberKey.currentState?.cancelPendingSearch();
    final provider = context.read<CustomerVoucherProvider>();
    if (provider.isLoading || provider.loadError != null) {
      throw StateError('Refresh vouchers before exporting.');
    }
    // Apply pending edits to the visible list and provider filters as well.
    // Name/number/type/status are local filters, so this makes no extra request.
    provider.applyFilters(
      customerName: searchTextController.text,
      voucherNumber: voucherNumberController.text,
      type: selectedType,
      status: selectedStatus,
      dateFrom:
          dateFromController.text.isEmpty ? null : dateFromController.text,
      dateTo: dateToController.text.isEmpty ? null : dateToController.text,
      page: provider.currentPage,
    );
    final items = provider.filterForExport(
        customerName: searchTextController.text,
        voucherNumber: voucherNumberController.text,
        type: selectedType,
        status: selectedStatus);
    final currency =
        context.read<AppSettingsProvider>().appSettings?.currency ?? 'INR';
    return ListExcelExportService.export<CustomerVoucher>(
        items: items,
        fileNamePrefix: 'customer-vouchers',
        sheetName: 'customer_voucher.list_title'.tr,
        columns: [
          ListExportColumn(
              label: 'customer_voucher.col_voucher_number'.tr,
              value: (v, _) => v.voucherNumber),
          ListExportColumn(
              label: 'customer_voucher.col_customer_name'.tr,
              value: (v, _) => v.customer.user.name),
          ListExportColumn(
              label: 'customer_voucher.col_type'.tr,
              value: (v, _) => UiCodeLabels.voucherType(v.type)),
          ListExportColumn(
              label: 'customer_voucher.col_voucher_date'.tr,
              value: (v, _) => v.voucherDate),
          ListExportColumn(
              label: 'customer_voucher.col_due_date'.tr,
              value: (v, _) => v.dueDate),
          ListExportColumn(
              label: 'customer_voucher.col_payment_method'.tr,
              value: (v, _) => UiCodeLabels.payment(v.paymentMethod)),
          ListExportColumn(
              label: 'customer_voucher.col_paid_amount'.tr,
              value: (v, _) => ListExcelExportService.numericValue(v.amount)),
          ListExportColumn(
              label: 'supplier_transactions.currency'.tr,
              value: (_, __) => currency),
          ListExportColumn(
              label: 'customer_voucher.col_status'.tr,
              value: (v, _) => UiCodeLabels.status(v.status)),
        ]);
  }

  Widget _buildStatusChip(String status) {
    final color = status.toLowerCase() == 'paid'
        ? const Color(0xff2c6e49)
        : status.toLowerCase() == 'pending'
            ? Colors.orange.shade800
            : status.toLowerCase() == 'cancelled'
                ? const Color(0xffb42318)
                : Colors.grey;
    return Align(
        alignment: Alignment.centerLeft,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Text(UiCodeLabels.status(status),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600))));
  }

  Widget _reference(CustomerVoucher voucher) => Row(children: [
        Expanded(child: TableCells.text(voucher.voucherNumber)),
        IconButton(
            icon: const Icon(Icons.copy_outlined, size: 16),
            tooltip: 'customer_voucher.copy_voucher_number'.tr,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: voucher.voucherNumber));
              showScaffold(
                  context: context,
                  message: 'customer_voucher.voucher_number_copied'.tr);
            }),
      ]);

  Widget _actions(CustomerVoucher voucher) =>
      Wrap(spacing: 6, runSpacing: 6, children: [
        TableCells.viewButton(() => _showVoucherDetails(voucher)),
        _action(
            Icons.print_outlined,
            'general.print'.tr,
            () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CustomerVoucherPrintPage(
                        voucher: voucher, returnToPreviousRoute: true)))),
        _action(Icons.more_vert, 'customer_voucher.more_options_title'.tr,
            () => _showVoucherActionsSheet(voucher)),
      ]);

  Widget _action(IconData icon, String tooltip, VoidCallback onPressed) =>
      IconButton.outlined(
          icon: Icon(icon, size: 18),
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
              foregroundColor: ColorManager.kPrimaryColor,
              side: const BorderSide(color: Color(0xFFE1E3E5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))));

  String _amount(CustomerVoucher voucher) =>
      '${context.read<AppSettingsProvider>().appSettings?.currency ?? 'INR'} ${voucher.amount}';

  Widget _card(CustomerVoucher voucher, int number) => AppSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TableCells.identity(voucher.customer.user.name),
        const SizedBox(height: 10),
        _reference(voucher),
        Text(
            '${'customer_voucher.col_type'.tr}: ${UiCodeLabels.voucherType(voucher.type)}'),
        Text(
            '${'customer_voucher.col_voucher_date'.tr}: ${voucher.voucherDate}'),
        Text('${'customer_voucher.col_due_date'.tr}: ${voucher.dueDate}'),
        Text(
            '${'customer_voucher.col_payment_method'.tr}: ${UiCodeLabels.payment(voucher.paymentMethod)}'),
        Text('${'customer_voucher.col_paid_amount'.tr}: ${_amount(voucher)}'),
        const SizedBox(height: 10),
        _buildStatusChip(voucher.status),
        const SizedBox(height: 10),
        _actions(voucher),
      ]));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerVoucherProvider>();
    return LayoutBuilder(
        builder: (context, bounds) => ListPageScaffold<CustomerVoucher>(
              header: ListPageHeader(
                  icon: Icons.receipt_long_outlined,
                  title: 'customer_voucher.mobile_header_title'.tr,
                  subtitle: 'customer_voucher.subtitle'.tr,
                  onRefresh: refreshData,
                  onAdd: () {
                    final controller = Get.put(SideBarController());
                    controller.index.value = 71;
                  },
                  addLabel: 'customer_voucher.create_voucher_button'.tr,
                  addShortLabel: 'customer_voucher.mobile_create_button'.tr,
                  extraActions: [
                    FilterToggleButton(
                        showFilters: _showFilters,
                        hasActiveFilters:
                            searchTextController.text.isNotEmpty ||
                                dateFromController.text.isNotEmpty ||
                                dateToController.text.isNotEmpty ||
                                selectedType != null ||
                                selectedStatus != null ||
                                voucherNumberController.text.isNotEmpty,
                        activeFiltersListenable: Listenable.merge([
                          searchTextController,
                          voucherNumberController,
                          dateFromController,
                          dateToController
                        ]),
                        activeFiltersBuilder: () =>
                            searchTextController.text.isNotEmpty ||
                            dateFromController.text.isNotEmpty ||
                            dateToController.text.isNotEmpty ||
                            selectedType != null ||
                            selectedStatus != null ||
                            voucherNumberController.text.isNotEmpty,
                        showTooltip: 'customer_voucher.show_filters'.tr,
                        hideTooltip: 'customer_voucher.hide_filters'.tr,
                        onPressed: () =>
                            setState(() => _showFilters = !_showFilters)),
                    ExportShareButton(
                        createFile: _createExport,
                        label: 'supplier_transactions.export'.tr,
                        tooltip: 'customer_voucher.export_tooltip'.tr,
                        loadingLabel: 'customer_voucher.export_creating'.tr,
                        errorMessage: 'customer_voucher.export_failed'.tr,
                        enabled: !provider.isLoading &&
                            provider.loadError == null &&
                            (provider.allVouchers?.isNotEmpty ?? false),
                        compact: bounds.maxWidth < ListLayoutBreakpoints.header,
                        mimeType:
                            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
                  ]),
              toolbar: provider.loadError == null
                  ? null
                  : AppSurface(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('customer_voucher.stale_rows_warning'.tr,
                                style:
                                    const TextStyle(color: Color(0xffb42318))),
                            TextButton.icon(
                                onPressed:
                                    provider.isLoading ? null : refreshData,
                                icon: const Icon(Icons.refresh),
                                label:
                                    Text('customer_voucher.retry_loading'.tr)),
                          ]),
                    ),
              filters: _filters(provider),
              showFilters: _showFilters,
              isLoading: provider.isLoading,
              items: provider.voucherListDetails ?? [],
              tableMinWidth: 1440,
              tableScrollController: _tableController,
              columns: [
                TableColumnDef(
                    label: 'customer_voucher.col_voucher_number'.tr,
                    flex: 1.6,
                    cellBuilder: (v, _) => _reference(v)),
                TableColumnDef(
                    label: 'customer_voucher.col_customer_name'.tr,
                    flex: 2,
                    cellBuilder: (v, _) =>
                        TableCells.identity(v.customer.user.name)),
                TableColumnDef(
                    label: 'customer_voucher.col_type'.tr,
                    cellBuilder: (v, _) =>
                        TableCells.text(UiCodeLabels.voucherType(v.type))),
                TableColumnDef(
                    label: 'customer_voucher.col_voucher_date'.tr,
                    flex: 1.3,
                    cellBuilder: (v, _) => TableCells.text(v.voucherDate)),
                TableColumnDef(
                    label: 'customer_voucher.col_due_date'.tr,
                    flex: 1.3,
                    cellBuilder: (v, _) => TableCells.text(v.dueDate)),
                TableColumnDef(
                    label: 'customer_voucher.col_payment_method'.tr,
                    flex: 1.2,
                    cellBuilder: (v, _) =>
                        TableCells.text(UiCodeLabels.payment(v.paymentMethod))),
                TableColumnDef(
                    label: 'customer_voucher.col_paid_amount'.tr,
                    flex: 1.4,
                    cellBuilder: (v, _) => TableCells.text(_amount(v))),
                TableColumnDef(
                    label: 'customer_voucher.col_status'.tr,
                    cellBuilder: (v, _) => _buildStatusChip(v.status)),
                TableColumnDef(
                    label: 'customer_voucher.col_action'.tr,
                    flex: 2.5,
                    cellBuilder: (v, _) => _actions(v)),
              ],
              cardBuilder: _card,
              emptyState:
                  Center(child: Text('customer_voucher.no_vouchers_found'.tr)),
              onRefresh: refreshData,
              currentPage: provider.currentPage,
              totalPages: provider.totalPages,
              itemsPerPage: provider.itemsPerPage,
              countLabel: 'customer_voucher.page_count'.trParams(
                  {'count': '${provider.voucherListDetails?.length ?? 0}'}),
              onPageChanged: provider.goToPage,
            ));
  }

  void _showVoucherDetails(CustomerVoucher voucher) {
    showDialog(
      context: context,
      builder: (context) => CommonDetailsDialog(
        title: 'customer_voucher.details_title'.tr,
        gridColumns: [
          [
            CommonDetailsDialog.buildKeyValueRow(
                'customer_voucher.col_voucher_number'.tr, voucher.voucherNumber,
                copyable: true),
            CommonDetailsDialog.buildKeyValueRow(
                'customer_voucher.customer_name_hint'.tr,
                voucher.customer.user.name),
            CommonDetailsDialog.buildKeyValueRow(
                'customer_voucher.field_customer_phone'.tr,
                voucher.customer.user.phone,
                copyable: true),
            CommonDetailsDialog.buildKeyValueRow('customer_voucher.col_type'.tr,
                UiCodeLabels.voucherType(voucher.type)),
          ],
          [
            CommonDetailsDialog.buildKeyValueRow(
                'customer_voucher.col_voucher_date'.tr, voucher.voucherDate),
            CommonDetailsDialog.buildKeyValueRow(
                'customer_voucher.col_due_date'.tr, voucher.dueDate),
            CommonDetailsDialog.buildKeyValueRow(
                'customer_voucher.col_status'.tr, voucher.status),
            CommonDetailsDialog.buildKeyValueRow(
                'customer_voucher.col_payment_method'.tr,
                UiCodeLabels.payment(voucher.paymentMethod)),
          ],
        ],
        sectionTitle: 'customer_voucher.items_section_title'.tr,
        tableContent: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table Header
            Container(
              decoration: BoxDecoration(
                color: ColorManager.tableBGColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1.5),
                  4: FlexColumnWidth(1),
                  5: FlexColumnWidth(1.5),
                },
                children: [
                  TableRow(
                    children: [
                      _buildTableHeaderCell('customer_voucher.col_voucher'.tr),
                      _buildTableHeaderCell(
                          'customer_voucher.col_item_name'.tr),
                      _buildTableHeaderCell(
                          'customer_voucher.col_quantity_upper'.tr),
                      _buildTableHeaderCell(
                          'customer_voucher.col_unit_amount_upper'.tr),
                      _buildTableHeaderCell(
                          'customer_voucher.col_tax_upper'.tr),
                      _buildTableHeaderCell(
                          'customer_voucher.col_total_amount_upper'.tr),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Table Body
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1.5),
                4: FlexColumnWidth(1),
                5: FlexColumnWidth(1.5),
              },
              children: voucher.items.asMap().entries.map((entry) {
                final item = entry.value;
                final index = entry.key;
                return TableRow(
                  decoration: BoxDecoration(
                    color: index % 2 == 0
                        ? Colors.white
                        : Colors.grey.withOpacity(0.05),
                  ),
                  children: [
                    _buildTableBodyCell(voucher.voucherNumber),
                    _buildTableBodyCell(item.itemName),
                    _buildTableBodyCell(item.quantity),
                    _buildTableBodyCell(item.unitAmount),
                    _buildTableBodyCell(item.tax),
                    _buildTableBodyCell(item.totalAmount),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
        totalsContent: Align(
          alignment: Alignment.centerRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'customer_voucher.grand_total_label'.tr,
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s12,
                  0.27,
                  Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? "INR"} ${voucher.amount}',
                style: buildCustomStyle(
                  FontWeightManager.bold,
                  FontSize.s18,
                  0.27,
                  ColorManager.kPrimaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s11,
          0.18,
          ColorManager.kTitleTextColor,
        ),
      ),
    );
  }

  Widget _buildTableBodyCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s10,
          0.15,
          Colors.black,
        ),
      ),
    );
  }
}
