import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:ui';
import 'package:pos_machine/components/build_dialog_box.dart'
    hide
        showScaffold,
        showScaffoldError,
        showLoadingOverlay,
        hideLoadingOverlay;
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/models/list_invoice.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../components/build_calendar_selection.dart';
import '../../components/build_container_box.dart';
import '../transactions/create_invoice_modal.dart';
import '../../components/build_dropdown_with_search.dart';
import '../../components/build_round_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../providers/auth_model.dart';
import '../../providers/app_settings_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'widgets/common_details_dialog.dart';
import 'widgets/share_helper.dart';
import 'invoice_list_mobile.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
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
  Timer? _invoiceSearchDebounce;

  final FocusNode invoiceNoFocusNode = FocusNode();
  final FocusNode nameFocusNode = FocusNode();
  final FocusNode phoneFocusNode = FocusNode();
  final FocusNode zatcaFocusNode = FocusNode();
  final FocusNode statusFocusNode = FocusNode();
  final FocusNode dateFromFocusNode = FocusNode();
  final FocusNode dateToFocusNode = FocusNode();

  bool _isPickerOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
      loadInvoices();
    });

    _sidebarIndexWorker = ever<int>(sideBarController.index, (currentIndex) {
      if (currentIndex != 21) {
        _resetInvoiceFilters(
          clearProviderFilters: true,
          reloadProvider: false,
        );
      }
    });

    dateFromFocusNode.addListener(_handleDateFromFocusChange);
    dateToFocusNode.addListener(_handleDateToFocusChange);
  }

  void _resetInvoiceFilters({
    required bool clearProviderFilters,
    bool reloadProvider = false,
    bool notifyProvider = true,
  }) {
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
    FocusScope.of(context).nextFocus();
    Future.delayed(const Duration(milliseconds: 300), () {
      _isPickerOpen = false;
    });
  }

  void _debounceInvoiceSearch() {
    _invoiceSearchDebounce?.cancel();
    _invoiceSearchDebounce =
        Timer(const Duration(milliseconds: 350), searchInvoices);
  }

  @override
  void dispose() {
    _invoiceSearchDebounce?.cancel();
    _sidebarIndexWorker?.dispose();
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
    invoiceNoFocusNode.dispose();
    nameFocusNode.dispose();
    phoneFocusNode.dispose();
    zatcaFocusNode.dispose();
    statusFocusNode.dispose();
    dateFromFocusNode.dispose();
    dateToFocusNode.dispose();
    super.dispose();
  }

  Future<void> _performZatcaPhase2SendWithPdf(Invoice invoice) async {
    try {
      final String? token =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint(
          '[ZATCA][Phase2 Send With PDF] Start for invoice ${invoice.invoiceNumber} (ID: ${invoice.id})');
      if (token == null || token.isEmpty) {
        debugPrint(
            '[ZATCA][Phase2 Send With PDF] ERROR: Missing authentication token');
        showScaffoldError(
            context: context, message: 'invoice.missing_token'.tr);
        return;
      }

      showScaffold(context: context, message: 'invoice.processing_zatca_phase2'.tr);
      showLoadingOverlay(context, message: 'invoice.processing'.tr);

      final provider = Provider.of<InvoiceProvider>(context, listen: false);
      final result = await provider.zatcaPhase2InvoicePrint(
        id: invoice.id,
        accessToken: token,
      );

      debugPrint('[ZATCA][Phase2 Send With PDF] Response: $result');
      if (result is Map &&
          ((result['status'] == 'success') ||
              (result['success'] == true) ||
              (result['status'] == true))) {
        final data = result['data'] ?? {};
        final String invoiceNumber =
            (data['invoice_number']?.toString() ?? invoice.invoiceNumber);
        final String? downloadUrl = data['download_url']?.toString();
        final String? fileName = data['filename']?.toString();
        if (downloadUrl != null && downloadUrl.isNotEmpty) {
          await _downloadAndOpenPdf(downloadUrl, suggestedFileName: fileName);
        }
        showScaffold(
          context: context,
          message: 'invoice.processed_phase2'.tr.replaceAll('@number', invoiceNumber),
        );
        // Flip row UI immediately
        Provider.of<InvoiceProvider>(context, listen: false)
            .updateInvoiceZatcaStatus(invoice.id, 'success');
        // Also refresh this invoice from server without resetting filters/pagination
        final String? accessToken =
            Provider.of<AuthModel>(context, listen: false).token;
        if (accessToken != null && accessToken.isNotEmpty) {
          await Provider.of<InvoiceProvider>(context, listen: false)
              .refreshSingleInvoiceFromServer(
            accessToken: accessToken,
            invoiceId: invoice.id,
          );
        }
      } else {
        final msg = (result is Map ? result['message'] : null) ??
            'invoice.process_phase2_failed'.tr;
        debugPrint('[ZATCA][Phase2 Send With PDF] ERROR: $msg');
        showScaffoldError(context: context, message: msg.toString());
      }
    } catch (e) {
      debugPrint('[ZATCA][Phase2 Send With PDF] EXCEPTION: $e');
      showScaffoldError(context: context, message: 'invoice.error_generic'.tr.replaceAll('@error', e.toString()));
    } finally {
      hideLoadingOverlay();
    }
  }

  Future<void> _performZatcaPhase2Resync(Invoice invoice) async {
    try {
      final String? token =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint(
          '[ZATCA][Phase2 Resync] Start for invoice ${invoice.invoiceNumber} (ID: ${invoice.id})');
      if (token == null || token.isEmpty) {
        debugPrint(
            '[ZATCA][Phase2 Resync] ERROR: Missing authentication token');
        showScaffoldError(
            context: context, message: 'invoice.missing_token'.tr);
        return;
      }

      showScaffold(
          context: context, message: 'invoice.resyncing_with_zatca'.tr);
      showLoadingOverlay(context, message: 'invoice.resyncing'.tr);

      final provider = Provider.of<InvoiceProvider>(context, listen: false);
      final result = await provider.zatcaPhase2InvoiceResync(
        id: invoice.id,
        accessToken: token,
      );

      debugPrint('[ZATCA][Phase2 Resync] Response: $result');
      if (result is Map) {
        final bool ok = (result['status'] == 'success') ||
            (result['success'] == true) ||
            (result['status'] == true);
        final data = (result['data'] is Map) ? result['data'] as Map : null;
        final String invoiceNumber =
            data?['invoice_number']?.toString() ?? invoice.invoiceNumber;
        final String resyncStatus =
            data?['resync_status']?.toString() ?? (ok ? 'success' : 'failed');
        final String? rawError = data?['error']?.toString();
        if (ok) {
          showScaffold(
            context: context,
            message: 'invoice.resynced_with_status'.tr
                .replaceAll('@number', invoiceNumber)
                .replaceAll('@status', resyncStatus),
          );
          // Flip row UI immediately if resync is successful
          Provider.of<InvoiceProvider>(context, listen: false)
              .updateInvoiceZatcaStatus(invoice.id, 'success');
          // Also refresh this invoice from server without resetting filters/pagination
          final String? accessToken =
              Provider.of<AuthModel>(context, listen: false).token;
          if (accessToken != null && accessToken.isNotEmpty) {
            await Provider.of<InvoiceProvider>(context, listen: false)
                .refreshSingleInvoiceFromServer(
              accessToken: accessToken,
              invoiceId: invoice.id,
            );
          }
        } else {
          String detail = rawError != null
              ? rawError
                  .replaceAll(RegExp(r'<[^>]*>'), ' ')
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim()
              : (result['message']?.toString() ?? 'invoice.resync_failed_generic'.tr);
          if (detail.length > 220) detail = '${detail.substring(0, 220)}...';
          final errMsg = 'invoice.resync_failed_detail'.tr
              .replaceAll('@number', invoiceNumber)
              .replaceAll('@status', resyncStatus)
              .replaceAll('@detail', detail);
          debugPrint('[ZATCA][Phase2 Resync] ERROR: $errMsg');
          showScaffoldError(context: context, message: errMsg);
        }
      } else {
        showScaffoldError(
            context: context, message: 'invoice.resync_failed_generic'.tr);
      }
    } catch (e) {
      debugPrint('[ZATCA][Phase2 Resync] EXCEPTION: $e');
      showScaffoldError(context: context, message: 'invoice.error_generic'.tr.replaceAll('@error', e.toString()));
    } finally {
      hideLoadingOverlay();
    }
  }

  Future<void> _showInvoiceActionsSheet(Invoice invoice) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        final appSettings =
            Provider.of<AppSettingsProvider>(context, listen: false)
                .appSettings;
        final bool phase1 = appSettings?.zatcaPhase1Enabled ?? false;
        final bool phase2 = appSettings?.zatcaPhase2Enabled ?? false;

        // Read both ZATCA status fields
        final String? zatcaStatus = invoice.zatcaStatus?.toLowerCase();
        final String? zatcaRequestStatus =
            invoice.zatcaRequestStatus?.toLowerCase();

        // Determine states
        final bool isZatcaPass = (zatcaStatus == 'pass' ||
            zatcaStatus == 'success' ||
            zatcaStatus == 'sent');
        final bool isZatcaWarning = (zatcaStatus == 'warning');
        final bool isRequestFailed = (zatcaRequestStatus == 'failed');
        final bool isRequestPending = (zatcaRequestStatus == 'pending' ||
            zatcaRequestStatus == 'processing');
        final bool neverRequested =
            (zatcaRequestStatus == null || zatcaRequestStatus == 'not_sent');

        final List<Widget> dynamicItems = [];

        // Always show Share option
        dynamicItems.add(
          ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: ColorManager.kPrimaryColor.withOpacity(0.12),
              child: const Icon(Icons.share, color: ColorManager.kPrimaryColor),
            ),
            title: Text('invoice.share_action'.tr),
            onTap: () async {
              Navigator.pop(ctx);
              await ShareHelper.showShareInvoiceSheet(
                context: context,
                invoiceId: invoice.id,
                invoiceNumber: invoice.invoiceNumber,
                customerName: invoice.customer.user.name,
                customerPhone: invoice.customer.user.phone,
                customerEmail: invoice.customer.user.email,
                amount: invoice.amount,
                invoiceHash: null,
              );
            },
          ),
        );

        // Always show Phase 1 print when enabled, regardless of status
        if (phase1) {
          dynamicItems.add(
            ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.green.withOpacity(0.12),
                child: const Icon(Icons.qr_code, color: Colors.green),
              ),
              title: Text('invoice.phase1_print_action'.tr),
              onTap: () async {
                Navigator.pop(ctx);
                await _performZatcaPhase1Print(invoice);
              },
            ),
          );
        }

        // ===== SCENARIO 1: Already ZATCA compliant =====
        if (isZatcaPass) {
          if (phase2) {
            dynamicItems.add(
              ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.orange.withOpacity(0.12),
                  child: const Icon(Icons.description, color: Colors.orange),
                ),
                title: Text('invoice.phase2_print_action'.tr),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _performZatcaPhase2SendWithPdf(invoice);
                },
              ),
            );
          }
        }
        // ===== SCENARIO 2: Warning =====
        else if (isZatcaWarning) {
          if (phase2) {
            dynamicItems.add(
              ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.purple.withOpacity(0.12),
                  child: const Icon(Icons.sync, color: Colors.purple),
                ),
                title: Text('invoice.resync_warning_action'.tr),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _performZatcaPhase2Resync(invoice);
                },
              ),
            );
          }
        }
        // ===== SCENARIO 3: Sent but status not set =====
        else if (!isZatcaPass &&
            !isZatcaWarning &&
            zatcaRequestStatus == 'success') {
          if (phase2) {
            dynamicItems.add(
              ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.purple.withOpacity(0.12),
                  child: const Icon(Icons.sync, color: Colors.purple),
                ),
                title: Text('invoice.resync_action'.tr),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _performZatcaPhase2Resync(invoice);
                },
              ),
            );
          }
        }
        // ===== SCENARIO 4: Failed =====
        else if (isRequestFailed) {
          if (phase2) {
            dynamicItems.add(
              ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.purple.withOpacity(0.12),
                  child: const Icon(Icons.sync, color: Colors.purple),
                ),
                title: Text('invoice.resync_failed_action'.tr),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _performZatcaPhase2Resync(invoice);
                },
              ),
            );
          }
        }
        // ===== SCENARIO 5: Pending =====
        else if (isRequestPending) {
          if (phase2) {
            dynamicItems.add(
              ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.purple.withOpacity(0.12),
                  child: const Icon(Icons.sync, color: Colors.purple),
                ),
                title: Text('invoice.resync_pending_action'.tr),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _performZatcaPhase2Resync(invoice);
                },
              ),
            );
          }
        }
        // ===== SCENARIO 6: Never requested =====
        else if (neverRequested) {
          if (phase2) {
            dynamicItems.add(
              ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: ColorManager.kPrimaryColor.withOpacity(0.12),
                  child:
                      const Icon(Icons.send, color: ColorManager.kPrimaryColor),
                ),
                title: Text('invoice.send_to_zatca_action'.tr),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _performZatcaPhase2Send(invoice);
                },
              ),
            );
          }
        }

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'invoice.more_options_title'.tr,
                      style:
                          const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                ...dynamicItems,
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _performZatcaPhase2Send(Invoice invoice) async {
    try {
      final String? token =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint(
          '[ZATCA][Phase2 Send] Start for invoice ${invoice.invoiceNumber} (ID: ${invoice.id})');
      if (token == null || token.isEmpty) {
        debugPrint('[ZATCA][Phase2 Send] ERROR: Missing authentication token');
        showScaffoldError(
            context: context, message: 'invoice.missing_token'.tr);
        return;
      }

      // 1. Check if already successfully sent
      if (invoice.zatcaStatus?.toLowerCase() == 'pass' ||
          invoice.zatcaStatus?.toLowerCase() == 'success' ||
          invoice.zatcaStatus?.toLowerCase() == 'sent') {
        showScaffold(
          context: context,
          message: 'invoice.already_sent_zatca'.tr.replaceAll('@number', invoice.invoiceNumber),
        );
        return;
      }

      // 2. Show stylized confirmation dialog
      final shouldSend = await _showZatcaConfirmationDialog(count: 1);
      if (shouldSend != true) return;

      showScaffold(context: context, message: 'invoice.sending_to_zatca'.tr);
      showLoadingOverlay(context, message: 'invoice.sending'.tr);

      final provider = Provider.of<InvoiceProvider>(context, listen: false);
      final result = await provider.zatcaPhase2InvoicePrint(
        id: invoice.id,
        accessToken: token,
      );

      debugPrint('[ZATCA][Phase2 Send] Response: $result');
      if (result is Map &&
          ((result['status'] == 'success') ||
              (result['success'] == true) ||
              (result['status'] == true))) {
        final data = result['data'] ?? {};
        final String invoiceNumber =
            (data['invoice_number']?.toString() ?? invoice.invoiceNumber);
        // Do NOT open PDF here per requirement. Just inform the user.
        showScaffold(
          context: context,
          message: 'invoice.submitted_to_zatca'.tr.replaceAll('@number', invoiceNumber),
        );
        // Flip row UI immediately
        Provider.of<InvoiceProvider>(context, listen: false)
            .updateInvoiceZatcaStatus(invoice.id, 'success');
        // Also refresh this invoice from server without resetting filters/pagination
        final String? accessToken =
            Provider.of<AuthModel>(context, listen: false).token;
        if (accessToken != null && accessToken.isNotEmpty) {
          await Provider.of<InvoiceProvider>(context, listen: false)
              .refreshSingleInvoiceFromServer(
            accessToken: accessToken,
            invoiceId: invoice.id,
          );
        }
      } else {
        final msg = (result is Map ? result['message'] : null) ??
            'invoice.send_to_zatca_failed'.tr;
        debugPrint('[ZATCA][Phase2 Send] ERROR: $msg');
        showScaffoldError(context: context, message: msg.toString());
      }
    } catch (e) {
      debugPrint('[ZATCA][Phase2 Send] EXCEPTION: $e');
      showScaffoldError(context: context, message: 'invoice.error_generic'.tr.replaceAll('@error', e.toString()));
    } finally {
      hideLoadingOverlay();
    }
  }

  Future<void> loadInvoices() async {
    if (isInitialized) return;

    try {
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null || accessToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('invoice.auth_token_missing'.tr)),
        );
        return;
      }

      await Provider.of<InvoiceProvider>(context, listen: false)
          .listAllInvoices(accessToken: accessToken);
      setState(() {
        isInitialized = true;
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('invoice.error_loading_invoices'.tr.replaceAll('@error', error.toString()))),
      );
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
    _invoiceSearchDebounce?.cancel();
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

  Future<void> refreshData() async {
    debugPrint("Refreshing data");
    final String? accessToken =
        Provider.of<AuthModel>(context, listen: false).token;
    if (accessToken == null || accessToken.isEmpty) return;

    _invoiceSearchDebounce?.cancel();
    _clearSelectedInvoices();

    await Provider.of<InvoiceProvider>(context, listen: false).listAllInvoices(
      accessToken: accessToken,
      page: Provider.of<InvoiceProvider>(context, listen: false).currentPage,
    );
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
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: ColorManager.kPrimaryColor,
              ),
              dialogBackgroundColor: Colors.white,
            ),
            child: child!,
          );
        },
      );
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

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 700;

    if (isMobile) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Consumer<InvoiceProvider>(
            builder: (context, invoiceProvider, child) {
              return InvoiceMobileView(
                invoices:
                    invoiceProvider.invoiceListDetails ?? const <Invoice>[],
                isLoading: invoiceProvider.isLoading,
                selectedInvoiceIds: selectedInvoiceIds,
                onToggleSelect: (id, selected) => setState(() {
                  if (selected)
                    selectedInvoiceIds.add(id);
                  else
                    selectedInvoiceIds.remove(id);
                }),
                onViewDetails: _showInvoiceDetails,
                onShowActions: _showInvoiceActionsSheet,
                searchTextController: searchTextController,
                invoiceNumberController: invoiceNumberController,
                phoneController: phoneController,
                dateFromController: dateFromController,
                dateToController: dateToController,
                invoiceNoFocusNode: invoiceNoFocusNode,
                nameFocusNode: nameFocusNode,
                phoneFocusNode: phoneFocusNode,
                dateFromFocusNode: dateFromFocusNode,
                dateToFocusNode: dateToFocusNode,
                onSearchChanged: _debounceInvoiceSearch,
                onReset: resetSearch,
                onSelectDate: ({required isFromDate}) =>
                    _selectDate(context, isFromDate: isFromDate),
                selectedStatus: selectedStatus,
                selectedZatcaStatus: selectedZatcaStatus,
                statusOptions: invoiceProvider.getStatusOptions(),
                zatcaStatusOptions: invoiceProvider.getZatcaStatusOptions(),
                onStatusChanged: (v) {
                  setState(() => selectedStatus = v);
                  searchInvoices();
                },
                onZatcaStatusChanged: (v) {
                  setState(() => selectedZatcaStatus = v);
                  searchInvoices();
                },
                currentPage: invoiceProvider.currentPage,
                totalPages: invoiceProvider.totalPages,
                onPageChanged: (page) {
                  _invoiceSearchDebounce?.cancel();
                  _clearSelectedInvoices();
                  invoiceProvider.goToPage(page);
                },
                isBulkSending: isBulkSending,
                activeBulkSyncType: activeBulkSyncType,
                onBulkSync: (syncType, ids) async {
                  final token =
                      Provider.of<AuthModel>(context, listen: false).token;
                  if (token == null || token.isEmpty) return;
                  await _performBulkZatcaSync(
                    idsToSync: ids,
                    syncType: syncType,
                    accessToken: token,
                  );
                },
                onSelectPage: () => setState(() {
                  for (final inv in invoiceProvider.invoiceListDetails ??
                      const <Invoice>[]) {
                    selectedInvoiceIds.add(inv.id);
                  }
                }),
                onUnselectAll: () => setState(() => selectedInvoiceIds.clear()),
                onCreateInvoice: () async {
                  final result = await showCreateInvoiceModal(context, size);
                  if (result == true) {
                    await refreshData();
                    if (mounted) setState(() {});
                  }
                },
                onRefresh: refreshData,
              );
            },
          ),
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshData,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: ColorManager.boxShadowColor,
                blurRadius: 6,
                offset: Offset(1, 1),
              ),
            ],
            color: Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(size),
                const SizedBox(height: 10),
                _buildSearchBar(size),
                // const SizedBox(height: 10),
                _buildInvoiceTable(),
                const SizedBox(height: 10),
                _buildPaginationControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Size size) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'invoice.list_title'.tr,
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
              0.30, ColorManager.textColor),
        ),
        CustomRoundButton(
          title: 'invoice.create_invoice_button'.tr,
          fct: () async {
            final result = await showCreateInvoiceModal(context, size);
            debugPrint("[InvoiceList] Modal closed with result: $result");
            // Refresh invoice list if a new invoice was created
            if (result == true) {
              debugPrint("[InvoiceList] Refreshing invoice list...");
              await refreshData();
              if (mounted) setState(() {});
              debugPrint("[InvoiceList] Invoice list refreshed");
            }
          },
          fontSize: 12,
          height: 45,
          width: 120,
        ),
      ],
    );
  }

  Widget _buildSearchBar(Size size) {
    return Column(
      children: [
        // First row of search fields
        SizedBox(
          height: 55,
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildInvoiceNumberSearch(),
              ),
              // Name Search Field
              Expanded(
                flex: 1,
                child: _buildSearchTextField(),
              ),

              // Invoice Number Search Field

              // // Order Number Search Field
              // Expanded(
              //   flex: 1,
              //   child: _buildOrderNumberSearch(),
              // ),

              // Phone Search Field
              Expanded(
                flex: 1,
                child: _buildPhoneSearch(),
              ),

              // Email Search Field
              Expanded(
                flex: 1,
                child: _buildZatcaStatusFilter(),
              ),
            ],
          ),
        ),
        // Second row of search fields
        SizedBox(
          height: 55,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Filter
              Expanded(
                flex: 1,
                child: _buildStatusFilter(),
              ),

              // Date Range Search
              Expanded(
                flex: 2,
                child: _buildDateRangeSearch(),
              ),

              //SizedBox(width: 10),

              // Reset Button
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: CustomRoundButton(
                    title: 'general.reset'.tr,
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    fct: resetSearch,
                    height: 45,
                    width: double.infinity,
                    fontSize: FontSize.s12,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildSelectionActions(),
        const SizedBox(height: 10),
      ],
    );
  }

  Future<void> _performBulkZatcaSync({
    required List<int> idsToSync,
    required String syncType, // 'selected', 'all', 'failed', 'not_sent'
    required String accessToken,
  }) async {
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
        confirmationMessage = 'invoice.confirm_sync_selected'.tr
            .replaceAll('@count', idsToSync.length.toString());
    }

    // Show confirmation dialog
    final shouldSend = await _showZatcaConfirmationDialog(
      count: idsToSync.length,
      message: confirmationMessage,
    );
    if (shouldSend != true) return;

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
        final errorMsg = result?['message'] ?? 'invoice.sync_failed_fallback'.tr;
        showScaffoldError(context: context, message: errorMsg);
      }
    } catch (e) {
      showScaffoldError(context: context, message: 'invoice.bulk_sync_error'.tr.replaceAll('@error', e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          isBulkSending = false;
          activeBulkSyncType = null;
        });
      }
    }
  }

  List<int> _getFailedInvoiceIds() {
    final allInvoices = Provider.of<InvoiceProvider>(context, listen: false)
            .invoiceListDetails ??
        <Invoice>[];
    return allInvoices
        .where((inv) => inv.zatcaRequestStatus?.toLowerCase() == 'failed')
        .map((inv) => inv.id)
        .toList();
  }

  List<int> _getNotSentInvoiceIds() {
    final allInvoices = Provider.of<InvoiceProvider>(context, listen: false)
            .invoiceListDetails ??
        <Invoice>[];
    return allInvoices
        .where((inv) =>
            inv.zatcaStatus?.toLowerCase() != 'pass' &&
            inv.zatcaStatus?.toLowerCase() != 'success' &&
            inv.zatcaStatus?.toLowerCase() != 'sent')
        .map((inv) => inv.id)
        .toList();
  }

  List<int> _getAllInvoiceIds() {
    final allInvoices = Provider.of<InvoiceProvider>(context, listen: false)
            .invoiceListDetails ??
        <Invoice>[];
    return allInvoices.map((inv) => inv.id).toList();
  }

  Widget _buildSelectionActions() {
    final provider = Provider.of<InvoiceProvider>(context);
    final String? token = Provider.of<AuthModel>(context, listen: false).token;
    final hasSelection = selectedInvoiceIds.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Single row: 4 sync buttons + selection info
          Row(
            children: [
              CustomRoundButton(
                title: 'invoice.sync_all_button'.tr,
                boxColor: Colors.blueAccent,
                textColor: Colors.white,
                borderColor: Colors.transparent,
                isLoading: isBulkSending && activeBulkSyncType == 'all',
                fct: isBulkSending || token == null || token.isEmpty
                    ? () {}
                    : () async {
                        await _performBulkZatcaSync(
                          idsToSync: const <int>[],
                          syncType: 'all',
                          accessToken: token,
                        );
                      },
                height: 40,
                width: 110,
                fontSize: FontSize.s10,
              ),
              const SizedBox(width: 8),
              CustomRoundButton(
                title: 'invoice.sync_failed_button'.tr,
                boxColor: Colors.redAccent,
                textColor: Colors.white,
                borderColor: Colors.transparent,
                isLoading: isBulkSending && activeBulkSyncType == 'failed',
                fct: isBulkSending || token == null || token.isEmpty
                    ? () {}
                    : () async {
                        await _performBulkZatcaSync(
                          idsToSync: const <int>[],
                          syncType: 'failed',
                          accessToken: token,
                        );
                      },
                height: 40,
                width: 110,
                fontSize: FontSize.s10,
              ),
              const SizedBox(width: 8),
              CustomRoundButton(
                title: 'invoice.sync_not_send_button'.tr,
                boxColor: Colors.orangeAccent,
                textColor: Colors.white,
                borderColor: Colors.transparent,
                isLoading: isBulkSending && activeBulkSyncType == 'not_sent',
                fct: isBulkSending || token == null || token.isEmpty
                    ? () {}
                    : () async {
                        await _performBulkZatcaSync(
                          idsToSync: const <int>[],
                          syncType: 'not_sent',
                          accessToken: token,
                        );
                      },
                height: 40,
                width: 130,
                fontSize: FontSize.s10,
              ),
              const SizedBox(width: 8),
              CustomRoundButton(
                title: 'invoice.sync_selected_button'.tr,
                boxColor: hasSelection ? Colors.lightBlue : Colors.grey,
                textColor: Colors.white,
                borderColor: Colors.transparent,
                isLoading: isBulkSending && activeBulkSyncType == 'selected',
                fct: (isBulkSending ||
                        !hasSelection ||
                        token == null ||
                        token.isEmpty)
                    ? () {}
                    : () async {
                        final selectedList = selectedInvoiceIds.toList();
                        await _performBulkZatcaSync(
                          idsToSync: selectedList,
                          syncType: 'selected',
                          accessToken: token,
                        );
                      },
                height: 40,
                width: 130,
                fontSize: FontSize.s10,
              ),
              const Spacer(),
              // Selection info on the right
              Text(
                'invoice.records_selected'.tr.replaceAll('@count', selectedInvoiceIds.length.toString()),
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s14,
                  0.20,
                  ColorManager.textColor,
                ),
              ),
              if ((provider.invoiceListDetails?.isNotEmpty ?? false) &&
                  selectedInvoiceIds.length <
                      (provider.invoiceListDetails?.length ?? 0)) ...[
                const SizedBox(width: 15),
                InkWell(
                  onTap: () {
                    final currentInvoices =
                        provider.invoiceListDetails ?? const <Invoice>[];
                    setState(() {
                      for (final inv in currentInvoices) {
                        selectedInvoiceIds.add(inv.id);
                      }
                    });
                    debugPrint(
                        "[DEBUG] Bulk Select: Found ${currentInvoices.length}, Selected ${selectedInvoiceIds.length}");
                  },
                  child: Text(
                    'invoice.select_page'.tr,
                    style: buildCustomStyle(
                      FontWeightManager.bold,
                      FontSize.s11,
                      0.18,
                      ColorManager.kPrimaryColor,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 15),
              InkWell(
                onTap: () {
                  setState(() {
                    selectedInvoiceIds.clear();
                  });
                },
                child: Text(
                  'invoice.unselect'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s11,
                    0.18,
                    const Color.fromARGB(255, 198, 78, 78),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceNumberSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Padding(
        //   padding: const EdgeInsets.all(8.0),
        //   child: Text(
        //     "Invoice No",
        //     style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
        //         0.27, Colors.black.withOpacity(0.6)),
        //   ),
        // ),
        // const SizedBox(height: 8),
        BuildBoxShadowContainer(
          height: 45,
          width: double.infinity,
          circleRadius: 7,
          child: TextFormField(
            controller: invoiceNumberController,
            focusNode: invoiceNoFocusNode,
            autofocus: true,
            onChanged: (value) => _debounceInvoiceSearch(),
            cursorColor: ColorManager.kPrimaryColor,
            cursorHeight: 13,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                0.18, ColorManager.textColor),
            decoration: decoration.copyWith(
              hintText: 'invoice.search_invoice_no_hint'.tr,
              hintStyle: buildCustomStyle(FontWeightManager.medium,
                  FontSize.s10, 0.18, ColorManager.textColor),
              prefixIconColor: Colors.black,
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(
                    color: ColorManager.kPrimaryColor, width: 1.2),
                borderRadius: BorderRadius.circular(7),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneSearch() {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Padding(
          //   padding: const EdgeInsets.all(8.0),
          //   child: Text(
          //     "Phone",
          //     style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
          //         0.27, Colors.black.withOpacity(0.6)),
          //   ),
          // ),
          // const SizedBox(height: 8),
          BuildBoxShadowContainer(
            height: 45,
            width: double.infinity,
            circleRadius: 7,
            child: TextFormField(
              controller: phoneController,
              focusNode: phoneFocusNode,
              onChanged: (value) => _debounceInvoiceSearch(),
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                  0.18, ColorManager.textColor),
              decoration: decoration.copyWith(
                hintText: 'invoice.search_phone_hint'.tr,
                hintStyle: buildCustomStyle(FontWeightManager.medium,
                    FontSize.s10, 0.18, ColorManager.textColor),
                prefixIconColor: Colors.black,
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                      color: ColorManager.kPrimaryColor, width: 1.2),
                  borderRadius: BorderRadius.circular(7),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailSearch() {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Padding(
          //   padding: const EdgeInsets.all(8.0),
          //   child: Text(
          //     "Email",
          //     style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
          //         0.27, Colors.black.withOpacity(0.6)),
          //   ),
          // ),
          // const SizedBox(height: 8),
          BuildBoxShadowContainer(
            height: 45,
            width: double.infinity,
            circleRadius: 7,
            child: TextFormField(
              controller: emailController,
              onChanged: (value) => searchInvoices(),
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              keyboardType: TextInputType.emailAddress,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                  0.18, ColorManager.textColor),
              decoration: decoration.copyWith(
                hintText: "Email",
                hintStyle: buildCustomStyle(FontWeightManager.medium,
                    FontSize.s10, 0.18, ColorManager.textColor),
                prefixIconColor: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSearch() {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Padding(
                //   padding: const EdgeInsets.all(8.0),
                //   child: Text(
                //     "From Date",
                //     style: buildCustomStyle(FontWeightManager.regular,
                //         FontSize.s14, 0.27, Colors.black.withOpacity(0.6)),
                //   ),
                // ),
                // const SizedBox(height: 8),
                BuildBoxShadowContainer(
                  height: 45,
                  width: double.infinity,
                  circleRadius: 7,
                  child: TextFormField(
                    controller: dateFromController,
                    focusNode: dateFromFocusNode,
                    onTap: () => _selectDate(context, isFromDate: true),
                    readOnly: true,
                    cursorColor: ColorManager.kPrimaryColor,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        _selectDate(context, isFromDate: true),
                    style: buildCustomStyle(FontWeightManager.medium,
                        FontSize.s10, 0.18, ColorManager.textColor),
                    decoration: decoration.copyWith(
                      hintText: 'invoice.date_range_hint'.tr,
                      hintStyle: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s10,
                          0.18,
                          ColorManager.textColor.withOpacity(.5)),
                      prefixIcon: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: ColorManager.kPrimaryColor,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                            color: ColorManager.kPrimaryColor, width: 1.2),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Padding(
                //   padding: const EdgeInsets.all(8.0),
                //   child: Text(
                //     "To Date",
                //     style: buildCustomStyle(FontWeightManager.regular,
                //         FontSize.s14, 0.27, Colors.black.withOpacity(0.6)),
                //   ),
                // ),
                // const SizedBox(height: 8),
                BuildBoxShadowContainer(
                  height: 45,
                  width: double.infinity,
                  circleRadius: 7,
                  child: TextFormField(
                    controller: dateToController,
                    focusNode: dateToFocusNode,
                    onTap: () => _selectDate(context, isFromDate: false),
                    readOnly: true,
                    cursorColor: ColorManager.kPrimaryColor,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        _selectDate(context, isFromDate: false),
                    style: buildCustomStyle(FontWeightManager.medium,
                        FontSize.s10, 0.18, ColorManager.textColor),
                    decoration: decoration.copyWith(
                      hintText: 'invoice.date_range_hint'.tr,
                      hintStyle: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s10,
                          0.18,
                          ColorManager.textColor.withOpacity(.5)),
                      prefixIcon: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: ColorManager.kPrimaryColor,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                            color: ColorManager.kPrimaryColor, width: 1.2),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Padding(
        //   padding: const EdgeInsets.all(8.0),
        //   child: Text(
        //     "Status",
        //     style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
        //         0.27, Colors.black.withOpacity(0.6)),
        //   ),
        // ),
        // const SizedBox(height: 8),
        Consumer<InvoiceProvider>(
          builder: (context, invoiceProvider, child) {
            List<String> statusOptions = invoiceProvider.getStatusOptions();

            // Find the display text for the currently selected status
            String? selectedStatusDisplay;
            if (selectedStatus != null) {
              selectedStatusDisplay = statusOptions.contains(selectedStatus)
                  ? selectedStatus
                  : "All Status";
            }

            return BuildDropDownWithSearch<String>(
              title: null,
              showName: false,
              hintText: 'All Status',
              value: selectedStatus,
              items: statusOptions
                  .where((status) => status != "All Status")
                  .toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedStatus = newValue;
                });
                searchInvoices();
              },
              displayText: (status) => status.toUpperCase(),
              height: 45,
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              focusNode: statusFocusNode,
            );
          },
        ),
      ],
    );
  }

  Widget _buildZatcaStatusFilter() {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Consumer<InvoiceProvider>(
        builder: (context, invoiceProvider, child) {
          final zatcaStatusOptions = invoiceProvider.getZatcaStatusOptions();

          return BuildDropDownWithSearch<String>(
            title: null,
            showName: false,
            hintText: 'All ZATCA Status',
            value: selectedZatcaStatus,
            items: zatcaStatusOptions
                .where((status) => status != "All ZATCA Status")
                .toList(),
            onChanged: (String? newValue) {
              setState(() {
                selectedZatcaStatus = newValue;
              });
              searchInvoices();
            },
            displayText: (status) => status.toUpperCase(),
            height: 45,
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            focusNode: zatcaFocusNode,
          );
        },
      ),
    );
  }

  //   Widget _buildOrderNumberSearch() {
  //   return Padding(
  //     padding: const EdgeInsets.only(left: 10.0),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Padding(
  //           padding: const EdgeInsets.all(8.0),
  //           child: Text(
  //             "Order No",
  //             style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
  //                 0.27, Colors.black.withOpacity(0.6)),
  //           ),
  //         ),
  //         const SizedBox(height: 8),
  //         BuildBoxShadowContainer(
  //           height: 45,
  //           width: double.infinity,
  //           circleRadius: 7,
  //           child: TextFormField(
  //             controller: orderNumberController,
  //             onChanged: (value) => searchInvoices(),
  //             cursorColor: ColorManager.kPrimaryColor,
  //             cursorHeight: 13,
  //             style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
  //                 0.18, ColorManager.textColor),
  //             decoration: decoration.copyWith(
  //               hintText: "Order No",
  //               hintStyle: buildCustomStyle(FontWeightManager.medium,
  //                   FontSize.s10, 0.18, ColorManager.textColor),
  //               prefixIconColor: Colors.black,
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Future<void> _showInvoiceDetails(Invoice invoice) async {
    final String? token = Provider.of<AuthModel>(context, listen: false).token;
    if (token == null || token.isEmpty) {
      showScaffoldError(
          context: context, message: 'invoice.missing_token'.tr);
      return;
    }

    showLoadingOverlay(context, message: 'invoice.loading_details'.tr);
    try {
      final provider = Provider.of<InvoiceProvider>(context, listen: false);
      await provider.callDetailsOfInvoice(id: invoice.id, accessToken: token);
      final details = provider.getInvoiceDetails;
      hideLoadingOverlay();

      if (details == null) {
        showScaffoldError(context: context, message: 'invoice.failed_load_details'.tr);
        return;
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => CommonDetailsDialog(
          title: 'invoice.details_title'.tr,
          gridColumns: [
            [
              CommonDetailsDialog.buildKeyValueRow(
                  'invoice.field_invoice_number'.tr, details.invoiceNumber,
                  copyable: true),
              CommonDetailsDialog.buildKeyValueRow(
                  'invoice.field_customer_name'.tr, details.customer.name),
              CommonDetailsDialog.buildKeyValueRow(
                  'invoice.field_customer_phone'.tr, details.customer.phone,
                  copyable: true),
              CommonDetailsDialog.buildKeyValueRow('invoice.field_amount'.tr, details.amount),
              CommonDetailsDialog.buildKeyValueRow('invoice.field_type'.tr, details.type),
            ],
            [
              CommonDetailsDialog.buildKeyValueRow(
                  'invoice.field_invoice_date'.tr, details.invoiceDate),
              CommonDetailsDialog.buildKeyValueRow('invoice.field_due_date'.tr, details.dueDate),
              CommonDetailsDialog.buildKeyValueRow('invoice.field_status'.tr, details.status),
              CommonDetailsDialog.buildKeyValueRow('invoice.field_order_number'.tr, 'common_details_dialog.na'.tr),
            ],
          ],
          sectionTitle: 'invoice.items_title'.tr,
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
                      flex: 4,
                      child: Text(
                        'invoice.col_item'.tr,
                        style: TextStyle(
                          fontWeight: FontWeightManager.bold,
                          fontSize: FontSize.s12,
                          color: ColorManager.kTitleTextColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'invoice.col_quantity'.tr,
                        style: TextStyle(
                          fontWeight: FontWeightManager.bold,
                          fontSize: FontSize.s12,
                          color: ColorManager.kTitleTextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'invoice.col_price'.tr,
                        style: TextStyle(
                          fontWeight: FontWeightManager.bold,
                          fontSize: FontSize.s12,
                          color: ColorManager.kTitleTextColor,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'invoice.col_total'.tr,
                        style: TextStyle(
                          fontWeight: FontWeightManager.bold,
                          fontSize: FontSize.s12,
                          color: ColorManager.kTitleTextColor,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              // Table Rows
              ...details.invoiceItems.map((item) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade100, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          item.itemName,
                          style: TextStyle(
                            fontSize: FontSize.s12,
                            color: ColorManager.textColor,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.quantity.toString(),
                          style: TextStyle(
                            fontSize: FontSize.s12,
                            color: ColorManager.textColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.unitAmount,
                          style: TextStyle(
                            fontSize: FontSize.s12,
                            color: ColorManager.textColor,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.totalAmount,
                          style: TextStyle(
                            fontSize: FontSize.s12,
                            color: ColorManager.textColor,
                          ),
                          textAlign: TextAlign.right,
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
    } catch (e) {
      hideLoadingOverlay();
      showScaffoldError(
          context: context, message: 'invoice.error_loading_details'.tr.replaceAll('@error', e.toString()));
    }
  }

//------------------------------------------------------debug-------------------------------------------
//
//
//
// void _showInvoiceDetails(Invoice invoice) async {
//   debugPrint('\n--- DEBUG START ---');
//   debugPrint('Attempting to fetch details for invoice ID: ${invoice.id}');

//   // 1. Verify token exists
//   final token = Provider.of<AuthModel>(context, listen: false).token;
//   if (token == null) {
//     debugPrint('❌ ERROR: No authentication token found');
//     return;
//   }
//   debugPrint('✅ Token exists: ${token.substring(0, 10)}...');

//   // 2. Verify API endpoint and parameters
//   final apiUrl = 'YOUR_API_ENDPOINT/invoices/${invoice.id}';
//   debugPrint('🔍 API Endpoint: $apiUrl');

//   try {
//     // 3. Make the API call directly for debugging
//     debugPrint('🌐 Making API call...');
//     final response = await http.get(
//       Uri.parse(apiUrl),
//       headers: {'Authorization': 'Bearer $token'},
//     );

//     debugPrint('🔄 Response Status: ${response.statusCode}');
//     debugPrint('📦 Response Body: ${response.body}');

//     if (response.statusCode == 200) {
//       final jsonData = jsonDecode(response.body);
//       debugPrint('✅ API Response Data:');
//       debugPrint(jsonData.toString());

//       // 4. Verify the response structure matches your model
//       if (jsonData['data'] != null) { // or whatever your response structure is
//         debugPrint('🔍 Data exists in response');
//         final invoiceDetails = InvoiceDetails.fromJson(jsonData['data']);
//         debugPrint('📊 Parsed Invoice:');
//         debugPrint('- Number: ${invoiceDetails.invoiceNumber}');
//         debugPrint('- Customer: ${invoiceDetails.customer?.name}');
//         // ... print other fields
//       } else {
//         debugPrint('❌ No data field in API response');
//       }
//     } else {
//       debugPrint('❌ API Error: ${response.statusCode}');
//     }
//   } catch (e) {
//     debugPrint('❌ Exception during API call: $e');
//   }
// }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              title,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.21,
                Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.21,
                Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTextField() {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Padding(
          //   padding: const EdgeInsets.all(8.0),
          //   child: Text(
          //     "Name",
          //     style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
          //         0.27, Colors.black.withOpacity(0.6)),
          //   ),
          // ),
          // const SizedBox(
          //   height: 8,
          // ),
          BuildBoxShadowContainer(
            height: 45,
            width: double.infinity,
            circleRadius: 7,
            child: TextFormField(
              controller: searchTextController,
              focusNode: nameFocusNode,
              onChanged: (value) {
                _debounceInvoiceSearch();
              },
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                  0.18, ColorManager.textColor),
              decoration: decoration.copyWith(
                hintText: 'invoice.search_name_hint'.tr,
                hintStyle: buildCustomStyle(FontWeightManager.medium,
                    FontSize.s10, 0.18, ColorManager.textColor),
                prefixIconColor: Colors.black,
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                      color: ColorManager.kPrimaryColor, width: 1.2),
                  borderRadius: BorderRadius.circular(7),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceTable() {
    return Expanded(
      child:
          Consumer<InvoiceProvider>(builder: (context, invoiceProvider, child) {
        final isLoading = invoiceProvider.isLoading;
        final invoiceList = invoiceProvider.invoiceListDetails;

        return Column(
          children: [
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : BuildBoxShadowContainer(
                      margin: const EdgeInsets.only(top: 5),
                      circleRadius: 7,
                      offsetValue: const Offset(2, 2),
                      blurRadius: 8.0,
                      color: Colors.white,
                      child: Column(
                        children: [
                          // Fixed table header
                          Container(
                            decoration: const BoxDecoration(
                              color: ColorManager.tableBGColor,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  offset: Offset(0, 2),
                                  blurRadius: 2.0,
                                ),
                              ],
                            ),
                            child: Table(
                              columnWidths: {
                                0: const FixedColumnWidth(40), // Checkbox
                                1: const FlexColumnWidth(1.2), // Invoice Number
                                2: const FlexColumnWidth(0.8), // Amount
                                3: const FlexColumnWidth(1.4), // Name
                                4: const FlexColumnWidth(1.1), // Invoice Date
                                5: const FlexColumnWidth(0.7), // Type
                                6: const FlexColumnWidth(1.1), // Due Date
                                7: const FlexColumnWidth(0.8), // Status
                                8: const FlexColumnWidth(1.2), // ZATCA Status
                                9: FlexColumnWidth(
                                    MediaQuery.of(context).size.width < 900
                                        ? 1.8
                                        : 1.4),
                              },
                              border: null,
                              defaultVerticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              children: [
                                TableRow(
                                  children: [
                                    _buildTableHeader(""), // Selection Checkbox
                                    _buildTableHeader('invoice.field_invoice_number'.tr),
                                    _buildTableHeader('invoice.col_amount'.tr),
                                    _buildTableHeader('invoice.col_name'.tr),
                                    _buildTableHeader('invoice.field_invoice_date'.tr),
                                    _buildTableHeader('invoice.field_type'.tr),
                                    _buildTableHeader('invoice.field_due_date'.tr),
                                    _buildTableHeader('invoice.field_status'.tr),
                                    _buildTableHeader('invoice.col_zatca_status'.tr),
                                    _buildTableHeader('invoice.col_action'.tr),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Scrollable table body
                          Expanded(
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: ScrollConfiguration(
                                behavior:
                                    ScrollConfiguration.of(context).copyWith(
                                  dragDevices: {
                                    PointerDeviceKind.mouse,
                                    PointerDeviceKind.touch,
                                    PointerDeviceKind.stylus,
                                    PointerDeviceKind.trackpad,
                                  },
                                ),
                                child: invoiceList == null ||
                                        invoiceList.isEmpty
                                    ? _buildNoInvoicesFoundUI()
                                    : SingleChildScrollView(
                                        physics: const BouncingScrollPhysics(),
                                        scrollDirection: Axis.vertical,
                                        child: Table(
                                          columnWidths: {
                                            0: const FixedColumnWidth(
                                                40), // Checkbox
                                            1: const FlexColumnWidth(
                                                1.2), // Invoice Number
                                            2: const FlexColumnWidth(
                                                0.8), // Amount
                                            3: const FlexColumnWidth(
                                                1.4), // Name
                                            4: const FlexColumnWidth(
                                                1.1), // Invoice Date
                                            5: const FlexColumnWidth(
                                                0.7), // Type
                                            6: const FlexColumnWidth(
                                                1.1), // Due Date
                                            7: const FlexColumnWidth(
                                                0.8), // Status
                                            8: const FlexColumnWidth(
                                                1.2), // ZATCA Status
                                            9: FlexColumnWidth(
                                                MediaQuery.of(context)
                                                            .size
                                                            .width <
                                                        900
                                                    ? 1.8
                                                    : 1.4),
                                          },
                                          border: null,
                                          defaultVerticalAlignment:
                                              TableCellVerticalAlignment.middle,
                                          children: invoiceList
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                            final int index = entry.key;
                                            final invoice = entry.value;
                                            final isSelected =
                                                selectedInvoiceIds
                                                    .contains(invoice.id);
                                            return TableRow(
                                              decoration: BoxDecoration(
                                                color: index % 2 == 0
                                                    ? Colors.white
                                                    : Colors.grey
                                                        .withOpacity(0.1),
                                              ),
                                              children: [
                                                TableCell(
                                                  verticalAlignment:
                                                      TableCellVerticalAlignment
                                                          .middle,
                                                  child: Checkbox(
                                                    value: isSelected,
                                                    activeColor: ColorManager
                                                        .kPrimaryColor,
                                                    onChanged: (bool? value) {
                                                      setState(() {
                                                        if (value == true) {
                                                          selectedInvoiceIds
                                                              .add(invoice.id);
                                                        } else {
                                                          selectedInvoiceIds
                                                              .remove(
                                                                  invoice.id);
                                                        }
                                                      });
                                                    },
                                                  ),
                                                ),
                                                TableCell(
                                                  verticalAlignment:
                                                      TableCellVerticalAlignment
                                                          .middle,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            8.0),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Text(
                                                          invoice.invoiceNumber,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style:
                                                              buildCustomStyle(
                                                            FontWeightManager
                                                                .medium,
                                                            FontSize.s9,
                                                            0.13,
                                                            Colors.black,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 6),
                                                        GestureDetector(
                                                          onTap: () {
                                                            Clipboard.setData(
                                                                ClipboardData(
                                                                    text: invoice
                                                                        .invoiceNumber));
                                                            showScaffold(
                                                              context: context,
                                                              message:
                                                                  'invoice.invoice_number_copied'.tr,
                                                            );
                                                          },
                                                          child: Icon(
                                                            Icons.copy,
                                                            size: 14,
                                                            color: ColorManager
                                                                .textColor
                                                                .withOpacity(
                                                                    0.6),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                _buildTableCell(
                                                    invoice.amount.toString()),
                                                TableCell(
                                                  verticalAlignment:
                                                      TableCellVerticalAlignment
                                                          .middle,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            8.0),
                                                    child: Center(
                                                      child: SelectableText(
                                                        invoice
                                                            .customer.user.name
                                                            .toString(),
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: buildCustomStyle(
                                                          FontWeightManager
                                                              .medium,
                                                          FontSize.s9,
                                                          0.13,
                                                          Colors.black,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                _buildTableCell(
                                                    invoice.invoiceDate),
                                                _buildTableCell(invoice.type),
                                                _buildTableCell(
                                                    invoice.dueDate),
                                                Center(
                                                    child: _buildStatusChip(
                                                        invoice.status)),
                                                Center(
                                                    child:
                                                        _buildZatcaStatusChip(
                                                            invoice)),
                                                Center(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            8.0),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const SizedBox(
                                                            width: 8),
                                                        BuildBoxShadowContainer(
                                                          margin:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 5,
                                                                  right: 5),
                                                          circleRadius: 5,
                                                          child: IconButton(
                                                            icon: Icon(
                                                              Icons.visibility,
                                                              size: 18,
                                                              color: ColorManager
                                                                  .kPrimaryColor
                                                                  .withOpacity(
                                                                      0.9),
                                                            ),
                                                            onPressed: () =>
                                                                _showInvoiceDetails(
                                                                    invoice),
                                                            constraints:
                                                                const BoxConstraints(
                                                              minWidth: 36,
                                                              minHeight: 36,
                                                            ),
                                                            padding:
                                                                EdgeInsets.zero,
                                                          ),
                                                        ),
                                                        Builder(
                                                          builder: (context) {
                                                            final appSettings =
                                                                Provider.of<AppSettingsProvider>(
                                                                        context,
                                                                        listen:
                                                                            false)
                                                                    .appSettings;
                                                            final bool phase1 =
                                                                appSettings
                                                                        ?.zatcaPhase1Enabled ??
                                                                    false;
                                                            final bool phase2 =
                                                                appSettings
                                                                        ?.zatcaPhase2Enabled ??
                                                                    false;
                                                            final bool
                                                                showZatcaMenu =
                                                                phase1 ||
                                                                    phase2;
                                                            if (!showZatcaMenu) {
                                                              return const SizedBox
                                                                  .shrink();
                                                            }
                                                            return BuildBoxShadowContainer(
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      left: 5,
                                                                      right: 5),
                                                              circleRadius: 5,
                                                              child: IconButton(
                                                                icon: Icon(
                                                                  Icons
                                                                      .more_vert,
                                                                  size: 18,
                                                                  color: ColorManager
                                                                      .kPrimaryColor
                                                                      .withOpacity(
                                                                          0.9),
                                                                ),
                                                                onPressed: () =>
                                                                    _showInvoiceActionsSheet(
                                                                        invoice),
                                                                constraints:
                                                                    const BoxConstraints(
                                                                  minWidth: 36,
                                                                  minHeight: 36,
                                                                ),
                                                                padding:
                                                                    EdgeInsets
                                                                        .zero,
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _performZatcaPhase1Print(Invoice invoice) async {
    try {
      final String? token =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint(
          '[ZATCA][Phase1 Print] Start for invoice ${invoice.invoiceNumber} (ID: ${invoice.id})');
      if (token == null || token.isEmpty) {
        debugPrint('[ZATCA][Phase1 Print] ERROR: Missing authentication token');
        showScaffoldError(
            context: context, message: 'invoice.missing_token'.tr);
        return;
      }

      showScaffold(context: context, message: 'invoice.processing_zatca_print'.tr);
      showLoadingOverlay(context, message: 'invoice.processing'.tr);

      final provider = Provider.of<InvoiceProvider>(context, listen: false);
      final result = await provider.zatcaPhase1InvoicePrint(
        id: invoice.id,
        accessToken: token,
      );

      debugPrint('[ZATCA][Phase1 Print] Response: $result');
      if (result is Map &&
          ((result['status'] == 'success') ||
              (result['success'] == true) ||
              (result['status'] == true))) {
        final data = result['data'] ?? {};
        final String? downloadUrl = data['download_url']?.toString();
        final String? fileName = data['filename']?.toString();
        if (downloadUrl != null && downloadUrl.isNotEmpty) {
          await _downloadAndOpenPdf(downloadUrl, suggestedFileName: fileName);
        } else {
          showScaffold(
            context: context,
            message: (result['message']?.toString() ?? 'invoice.zatca_print_completed'.tr),
          );
        }
      } else {
        final msg = (result is Map ? result['message'] : null) ??
            'invoice.zatca_print_failed'.tr;
        debugPrint('[ZATCA][Phase1 Print] ERROR: $msg');
        showScaffoldError(context: context, message: msg.toString());
      }
    } catch (e) {
      debugPrint('[ZATCA][Phase1 Print] EXCEPTION: $e');
      showScaffoldError(context: context, message: 'invoice.error_generic'.tr.replaceAll('@error', e.toString()));
    } finally {
      hideLoadingOverlay();
    }
  }

  Future<void> _downloadAndOpenPdf(String url,
      {String? suggestedFileName}) async {
    try {
      if (kIsWeb) {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
        showScaffold(context: context, message: 'invoice.opened_pdf_browser'.tr);
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final String fileName =
          (suggestedFileName != null && suggestedFileName.trim().isNotEmpty)
              ? suggestedFileName
              : 'invoice_${DateTime.now().millisecondsSinceEpoch}.pdf';
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
      showScaffold(context: context, message: 'invoice.pdf_downloaded'.tr);
    } catch (e) {
      debugPrint('[ZATCA][PDF] ERROR while downloading/opening: $e');
      try {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
      } catch (_) {}
      showScaffoldError(context: context, message: 'invoice.failed_open_pdf'.tr);
    }
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toUpperCase()) {
      case 'paid':
      case 'PAID':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        break;
      case 'pending':
      case 'PENDING':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        break;
      case 'FAIL':
      case 'FAILED':
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildZatcaStatusChip(Invoice invoice) {
    String label = 'invoice.zatca_status_not_sent'.tr;
    Color backgroundColor = Colors.orange.withOpacity(0.12);
    Color textColor = Colors.orange;

    final String? zatcaStatus = invoice.zatcaStatus?.toLowerCase();
    final String? zatcaRequestStatus =
        invoice.zatcaRequestStatus?.toLowerCase();

    // Determine states based on backend values
    final bool isZatcaPass = (zatcaStatus == 'pass' ||
        zatcaStatus == 'success' ||
        zatcaStatus == 'sent');
    final bool isRequestFailed = (zatcaRequestStatus == 'failed');
    final bool isRequestPending =
        (zatcaRequestStatus == 'pending' || zatcaRequestStatus == 'processing');

    if (isZatcaPass) {
      label = 'invoice.zatca_status_sent'.tr;
      backgroundColor = Colors.green.withOpacity(0.12);
      textColor = Colors.green;
    } else if (isRequestFailed) {
      label = 'invoice.zatca_status_failed'.tr;
      backgroundColor = Colors.red.withOpacity(0.12);
      textColor = Colors.red;
    } else if (isRequestPending) {
      label = 'invoice.zatca_status_pending'.tr;
      backgroundColor = Colors.blue.withOpacity(0.12);
      textColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<bool> _showZatcaConfirmationDialog({
    required int count,
    String? message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.blue,
                            size: 40,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context, false),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'invoice.send_invoices_to_zatca_title'.tr,
                    style: buildCustomStyle(
                      FontWeightManager.bold,
                      FontSize.s18,
                      0,
                      Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message ??
                        'invoice.send_zatca_confirm_message'.tr.replaceAll('@count', count.toString()),
                    textAlign: TextAlign.center,
                    softWrap: true,
                    maxLines: null,
                    overflow: TextOverflow.visible,
                    style: buildCustomStyle(
                      FontWeightManager.regular,
                      FontSize.s14,
                      0,
                      Colors.grey[600]!,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            'general.cancel'.tr,
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s14,
                              0,
                              Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                          ),
                          child: Text(
                            'invoice.send_to_zatca_action'.tr,
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s14,
                              0,
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  Widget _buildNoInvoicesFoundUI() {
    return Container(
      height: double.infinity,
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 60,
            color: ColorManager.kPrimaryColor.withOpacity(0.7),
          ),
          const SizedBox(height: 15),
          Text(
            'invoice.no_invoices_found'.tr,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s18,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'invoice.try_adjusting_search'.tr,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.20,
              Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.18,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  List<TableRow> _buildTableRows(List<Invoice>? invoices) {
    return invoices?.asMap().entries.map((entry) {
          final int index = entry.key;
          final invoice = entry.value;
          return TableRow(
            decoration: BoxDecoration(
              color:
                  index % 2 == 0 ? Colors.white : Colors.grey.withOpacity(0.1),
            ),
            children: [
              TableCell(
                verticalAlignment: TableCellVerticalAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: SelectableText(
                      invoice.customer.user.name.toString(),
                      textAlign: TextAlign.center,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s9,
                        0.13,
                        Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
              TableCell(
                verticalAlignment: TableCellVerticalAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        invoice.invoiceNumber,
                        textAlign: TextAlign.center,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s9,
                          0.13,
                          Colors.black,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: invoice.invoiceNumber));
                          showScaffold(
                            context: context,
                            message: 'Invoice number copied to clipboard',
                          );
                        },
                        child: Icon(
                          Icons.copy,
                          size: 14,
                          color: ColorManager.textColor.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildTableCell(invoice.type),
              _buildTableCell(invoice.invoiceDate),
              _buildTableCell(invoice.dueDate),
              _buildTableCell(invoice.amount.toString()),
              _buildTableCell(invoice.status),
              _buildActionCell(invoice.id),
            ],
          );
        }).toList() ??
        [];
  }

  TableCell _buildTableCell(String content) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          content,
          textAlign: TextAlign.center,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s9,
            0.13,
            Colors.black,
          ),
        ),
      ),
    );
  }

  TableCell _buildActionCell(int transactionId) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: BuildBoxShadowContainer(
            margin: const EdgeInsets.only(left: 5, right: 5),
            circleRadius: 5,
            child: IconButton(
              icon: Icon(
                Icons.visibility,
                size: 18,
                color: ColorManager.kPrimaryColor.withOpacity(0.9),
              ),
              onPressed: () {
                String? token =
                    Provider.of<AuthModel>(context, listen: false).token;
                InvoiceProvider invoiceProvider =
                    Provider.of<InvoiceProvider>(context, listen: false);
                invoiceProvider.callDetailsOfInvoice(
                    id: transactionId, accessToken: token ?? "");
                sideBarController.index.value = 31;
              },
              constraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Consumer<InvoiceProvider>(
        builder: (context, invoiceProvider, child) {
      debugPrint(
          "Building pagination controls: currentPage=${invoiceProvider.currentPage}, totalPages=${invoiceProvider.totalPages}");
      return PaginationControl(
        currentPage: invoiceProvider.currentPage,
        totalPages: invoiceProvider.totalPages,
        onPageChanged: (int page) {
          debugPrint("Page changed to: $page");
          _invoiceSearchDebounce?.cancel();
          _clearSelectedInvoices();
          invoiceProvider.goToPage(page);
        },
      );
    });
  }
}
