import 'dart:io';
import '../../core/ui/app_surface.dart';
import '../../core/ui/app_colors.dart';
import '../../core/ui/list_page/list_page_header.dart';
import '../../core/ui/list_page/list_page_scaffold.dart';
import '../../core/ui/list_page/filter_panel.dart';
import '../../components/export_share_button.dart';
import '../../services/list_excel_export_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:ui';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';

import 'package:pos_machine/models/list_invoice.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../components/build_calendar_selection.dart';

import '../../components/filter_toggle_button.dart';
import '../transactions/create_invoice_modal.dart';

import '../../controllers/sidebar_controller.dart';
import '../../providers/auth_model.dart';
import '../../providers/app_settings_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'widgets/common_details_dialog.dart';
import 'widgets/share_helper.dart';

import '../../helpers/ui_code_labels.dart';

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
  bool _zatcaCleanupScheduled = false;
  bool _lastVerifiedPhase2Enabled = false;
  bool _showFilters = true;
  bool _visibilityInitialized = false;
  final _tableScrollController = ScrollController();
  final _exportProgress = ValueNotifier<String?>(null);

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
    if (!_visibilityInitialized) {
      _showFilters =
          MediaQuery.sizeOf(context).width >= ListLayoutBreakpoints.mobile;
      _visibilityInitialized = true;
    }
  }

  void _resetInvoiceFilters({
    required bool clearProviderFilters,
    bool reloadProvider = false,
    bool notifyProvider = true,
  }) {
    _invoiceSearchDebounce?.cancel();
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

  void _debounceInvoiceSearch() {
    _invoiceSearchDebounce?.cancel();
    _invoiceSearchDebounce =
        Timer(const Duration(milliseconds: 350), searchInvoices);
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
    _invoiceSearchDebounce?.cancel();
    _sidebarIndexWorker?.dispose();
    _exportProgress.dispose();
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
    invoiceNoFocusNode.dispose();
    nameFocusNode.dispose();
    phoneFocusNode.dispose();
    zatcaFocusNode.dispose();
    statusFocusNode.dispose();
    dateFromFocusNode.dispose();
    dateToFocusNode.dispose();
    super.dispose();
  }

  bool _canRunPhase2Action() {
    if (!mounted) return false;
    final settings = context.read<AppSettingsProvider>();
    if (settings.isReady && (settings.appSettings?.zatcaPhase2Enabled ?? false))
      return true;
    showScaffoldError(
        context: context, message: 'invoice.settings_unverified'.tr);
    return false;
  }

  Future<void> _performZatcaPhase2SendWithPdf(Invoice invoice) async {
    if (!_canRunPhase2Action()) return;
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

      showScaffold(
          context: context, message: 'invoice.processing_zatca_phase2'.tr);
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
          message: 'invoice.processed_phase2'
              .tr
              .replaceAll('@number', invoiceNumber),
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
      showScaffoldError(
          context: context,
          message:
              'invoice.error_generic'.tr.replaceAll('@error', e.toString()));
    } finally {
      hideLoadingOverlay();
    }
  }

  Future<void> _performZatcaPhase2Resync(Invoice invoice) async {
    if (!_canRunPhase2Action()) return;
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
            message: 'invoice.resynced_with_status'
                .tr
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
              : (result['message']?.toString() ??
                  'invoice.resync_failed_generic'.tr);
          if (detail.length > 220) detail = '${detail.substring(0, 220)}...';
          final errMsg = 'invoice.resync_failed_detail'
              .tr
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
      showScaffoldError(
          context: context,
          message:
              'invoice.error_generic'.tr.replaceAll('@error', e.toString()));
    } finally {
      hideLoadingOverlay();
    }
  }

  Future<void> _showInvoiceActionsSheet(Invoice invoice) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        final appSettings = Provider.of<AppSettingsProvider>(ctx).appSettings;
        final bool phase1 = appSettings?.zatcaPhase1Enabled ?? false;
        final bool phase2 = context.read<AppSettingsProvider>().isReady &&
            (appSettings?.zatcaPhase2Enabled ?? false);

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
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
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
    if (!_canRunPhase2Action()) return;
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
          message: 'invoice.already_sent_zatca'
              .tr
              .replaceAll('@number', invoice.invoiceNumber),
        );
        return;
      }

      // 2. Show stylized confirmation dialog
      final shouldSend = await _showZatcaConfirmationDialog(count: 1);
      if (shouldSend != true || !_canRunPhase2Action()) return;

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
          message: 'invoice.submitted_to_zatca'
              .tr
              .replaceAll('@number', invoiceNumber),
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
      showScaffoldError(
          context: context,
          message:
              'invoice.error_generic'.tr.replaceAll('@error', e.toString()));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('invoice.error_loading_invoices'
                .tr
                .replaceAll('@error', error.toString()))),
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
    if (pickedDate != null && mounted) {
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
      invoiceNumberController.text.isNotEmpty ||
      searchTextController.text.isNotEmpty ||
      phoneController.text.isNotEmpty ||
      dateFromController.text.isNotEmpty ||
      dateToController.text.isNotEmpty ||
      selectedStatus != null ||
      selectedZatcaStatus != null;

  Future<File> _createExport() async {
    final pendingSearch = _invoiceSearchDebounce?.isActive ?? false;
    _invoiceSearchDebounce?.cancel();
    if (pendingSearch) searchInvoices();
    final token = context.read<AuthModel>().token;
    if (token == null || token.isEmpty)
      throw StateError('Missing access token.');
    // Capture the controls before awaiting; export never updates list state.
    final currency =
        context.read<AppSettingsProvider>().appSettings?.currency ?? 'INR';
    final showZatca = _lastVerifiedPhase2Enabled;
    _exportProgress.value = 'invoice.export_creating'.tr;
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
            if (mounted)
              _exportProgress.value = 'invoice.export_fetching'
                  .trParams({'page': '$page', 'total': '$total'});
          },
        );
    if (mounted) _exportProgress.value = 'invoice.export_creating'.tr;
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
              value: (v, _) => _localizedInvoiceType(v.type)),
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

  Widget _textFilter(TextEditingController controller, FocusNode focus,
          String label, IconData icon,
          {TextInputType keyboardType = TextInputType.text}) =>
      TextField(
          controller: controller,
          focusNode: focus,
          keyboardType: keyboardType,
          decoration: listFilterDecoration(label, icon),
          onChanged: (_) => _debounceInvoiceSearch(),
          onSubmitted: (_) {
            _invoiceSearchDebounce?.cancel();
            searchInvoices();
          });

  Widget _dateFilter(bool from) => TextField(
      controller: from ? dateFromController : dateToController,
      focusNode: from ? dateFromFocusNode : dateToFocusNode,
      readOnly: true,
      decoration: listFilterDecoration(
          from ? 'invoice.from_date'.tr : 'invoice.to_date'.tr,
          Icons.calendar_today_outlined),
      onTap: () {
        if (!_isPickerOpen) _openDatePicker(isFromDate: from);
      });

  Widget _filters(InvoiceProvider provider, bool showZatca) => FilterPanel(
          key: const ValueKey('invoice-desktop-filters'),
          title: 'invoice.find'.tr,
          hint: 'invoice.filter_hint'.tr,
          onReset: resetSearch,
          fields: [
            _textFilter(invoiceNumberController, invoiceNoFocusNode,
                'invoice.invoice_no'.tr, Icons.receipt_long_outlined),
            _textFilter(searchTextController, nameFocusNode, 'invoice.name'.tr,
                Icons.person_outline),
            _textFilter(phoneController, phoneFocusNode, 'invoice.phone'.tr,
                Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            if (showZatca)
              DropdownButtonFormField<String>(
                  key: ValueKey('zatca-$selectedZatcaStatus'),
                  initialValue: selectedZatcaStatus,
                  focusNode: zatcaFocusNode,
                  isExpanded: true,
                  decoration: listFilterDecoration(
                      'invoice.col_zatca_status'.tr, Icons.cloud_sync_outlined),
                  items: [
                    DropdownMenuItem<String>(
                        value: null,
                        child: Text('invoice.all_zatca_status'.tr)),
                    for (final value in provider
                        .getZatcaStatusOptions()
                        .where((v) => v != 'All ZATCA Status'))
                      DropdownMenuItem(
                          value: value, child: Text(UiCodeLabels.zatca(value)))
                  ],
                  onChanged: (v) {
                    setState(() => selectedZatcaStatus = v);
                    _invoiceSearchDebounce?.cancel();
                    searchInvoices();
                  }),
            DropdownButtonFormField<String>(
                key: ValueKey('status-$selectedStatus'),
                initialValue: selectedStatus,
                focusNode: statusFocusNode,
                isExpanded: true,
                decoration: listFilterDecoration(
                    'invoice.field_status'.tr, Icons.check_circle_outline),
                items: [
                  DropdownMenuItem<String>(
                      value: null, child: Text('invoice.all_status'.tr)),
                  for (final value in {
                    ...provider
                        .getStatusOptions()
                        .where((v) => v != 'All Status'),
                    if (selectedStatus != null) selectedStatus!
                  })
                    DropdownMenuItem(
                        value: value, child: Text(UiCodeLabels.status(value)))
                ],
                onChanged: (v) {
                  setState(() => selectedStatus = v);
                  _invoiceSearchDebounce?.cancel();
                  searchInvoices();
                }),
            _dateFilter(true),
            _dateFilter(false),
          ]);

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

  Widget _reference(Invoice invoice) => Row(children: [
        Expanded(child: TableCells.text(invoice.invoiceNumber)),
        IconButton(
            icon: const Icon(Icons.copy_outlined, size: 16),
            tooltip: 'invoice.field_invoice_number'.tr,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: invoice.invoiceNumber));
              showScaffold(
                  context: context,
                  message: 'invoice.invoice_number_copied'.tr);
            })
      ]);

  Widget _actions(Invoice invoice) => Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TableCells.viewButton(() => _showInvoiceDetails(invoice)),
          SizedBox(
            width: 36,
            height: 36,
            child: IconButton.outlined(
              style: IconButton.styleFrom(
                foregroundColor: ColorManager.kPrimaryColor,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.control)),
              ),
              icon: const Icon(Icons.more_vert, size: 18),
              tooltip: 'general.more'.tr,
              onPressed: () => _showInvoiceActionsSheet(invoice),
            ),
          ),
        ],
      );

  Widget _card(Invoice invoice, bool showZatca) => AppSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: TableCells.identity(invoice.customer.user.name)),
          if (showZatca) _selection(invoice)
        ]),
        _reference(invoice),
        Text('${'invoice.col_amount'.tr}: ${invoice.amount}'),
        Text('${'invoice.field_invoice_date'.tr}: ${invoice.invoiceDate}'),
        Text('${'invoice.field_due_date'.tr}: ${invoice.dueDate}'),
        Text(
            '${'invoice.field_type'.tr}: ${_localizedInvoiceType(invoice.type)}'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _buildStatusChip(invoice.status),
          if (showZatca) _buildZatcaStatusChip(invoice)
        ]),
        const SizedBox(height: 8),
        _actions(invoice),
      ]));

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
    return LayoutBuilder(
        builder: (context, bounds) => ListPageScaffold<Invoice>(
              header: ListPageHeader(
                  icon: Icons.receipt_long_outlined,
                  title: 'invoice.list_title'.tr,
                  subtitle: 'invoice.subtitle'.tr,
                  onRefresh: refreshData,
                  onAdd: () async {
                    final result = await showCreateInvoiceModal(
                        context, MediaQuery.sizeOf(context));
                    if (result == true && mounted) await refreshData();
                  },
                  addLabel: 'invoice.create_invoice_button'.tr,
                  addShortLabel: 'invoice.create'.tr,
                  extraActions: [
                    FilterToggleButton(
                        showFilters: _showFilters,
                        hasActiveFilters: _hasActiveFilters,
                        activeFiltersListenable: Listenable.merge([
                          invoiceNumberController,
                          searchTextController,
                          phoneController,
                          dateFromController,
                          dateToController
                        ]),
                        activeFiltersBuilder: () => _hasActiveFilters,
                        showTooltip: 'invoice.show_filters'.tr,
                        hideTooltip: 'invoice.hide_filters'.tr,
                        onPressed: () =>
                            setState(() => _showFilters = !_showFilters)),
                    ExportShareButton(
                        createFile: _createExport,
                        label: 'supplier_transactions.export'.tr,
                        loadingLabel: 'invoice.export_creating'.tr,
                        progressLabel: _exportProgress,
                        tooltip: 'invoice.export_tooltip'.tr,
                        errorMessage: 'invoice.export_failed'.tr,
                        enabled: !provider.isLoading &&
                            !isBulkSending &&
                            (provider.invoiceListDetails?.isNotEmpty ?? false),
                        compact: bounds.maxWidth < ListLayoutBreakpoints.header,
                        mimeType:
                            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
                  ]),
              filters: _filters(provider, showZatca),
              showFilters: _showFilters,
              toolbar: showZatca ? _buildSelectionActions() : null,
              tableScrollController: _tableScrollController,
              isLoading: provider.isLoading,
              items: provider.invoiceListDetails ?? [],
              tableMinWidth: showZatca ? 1350 : 1150,
              columns: [
                if (showZatca)
                  TableColumnDef(
                      label: '',
                      flex: .5,
                      cellBuilder: (v, _) => _selection(v)),
                TableColumnDef(
                    label: 'invoice.field_invoice_number'.tr,
                    flex: 1.7,
                    cellBuilder: (v, _) => _reference(v)),
                TableColumnDef(
                    label: 'invoice.col_amount'.tr,
                    cellBuilder: (v, _) => TableCells.text(v.amount)),
                TableColumnDef(
                    label: 'invoice.col_name'.tr,
                    flex: 1.8,
                    cellBuilder: (v, _) =>
                        TableCells.identity(v.customer.user.name)),
                TableColumnDef(
                    label: 'invoice.field_invoice_date'.tr,
                    flex: 1.3,
                    cellBuilder: (v, _) => TableCells.text(v.invoiceDate)),
                TableColumnDef(
                    label: 'invoice.field_type'.tr,
                    cellBuilder: (v, _) =>
                        TableCells.text(_localizedInvoiceType(v.type))),
                TableColumnDef(
                    label: 'invoice.field_due_date'.tr,
                    flex: 1.3,
                    cellBuilder: (v, _) => TableCells.text(v.dueDate)),
                TableColumnDef(
                    label: 'invoice.field_status'.tr,
                    cellBuilder: (v, _) => _buildStatusChip(v.status)),
                if (showZatca)
                  TableColumnDef(
                      label: 'invoice.col_zatca_status'.tr,
                      flex: 1.4,
                      cellBuilder: (v, _) => _buildZatcaStatusChip(v)),
                TableColumnDef(
                    label: 'invoice.col_action'.tr,
                    flex: 1.6,
                    cellBuilder: (v, _) => _actions(v))
              ],
              cardBuilder: (v, _) => _card(v, showZatca),
              emptyState: Center(child: Text('invoice.no_invoices_found'.tr)),
              onRefresh: refreshData,
              currentPage: provider.currentPage,
              totalPages: provider.totalPages,
              itemsPerPage: provider.itemsPerPage,
              countLabel: 'invoice.page_count'.trParams(
                  {'count': '${provider.invoiceListDetails?.length ?? 0}'}),
              onPageChanged: (page) {
                _invoiceSearchDebounce?.cancel();
                _clearSelectedInvoices();
                provider.goToPage(page);
              },
            ));
  }

  Future<void> _performBulkZatcaSync({
    required List<int> idsToSync,
    required String syncType, // 'selected', 'all', 'failed', 'not_sent'
    required String accessToken,
  }) async {
    if (!_canRunPhase2Action()) return;
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
    final shouldSend = await _showZatcaConfirmationDialog(
      count: idsToSync.length,
      message: confirmationMessage,
    );
    if (shouldSend != true || !_canRunPhase2Action()) return;

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
        final errorMsg =
            result?['message'] ?? 'invoice.sync_failed_fallback'.tr;
        showScaffoldError(context: context, message: errorMsg);
      }
    } catch (e) {
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

  Widget _buildSelectionActions() {
    final provider = context.read<InvoiceProvider>();
    final token = context.read<AuthModel>().token;
    final settings = context.read<AppSettingsProvider>();
    final disabled = isBulkSending ||
        provider.isLoading ||
        !settings.isReady ||
        !(settings.appSettings?.zatcaPhase2Enabled ?? false) ||
        token == null ||
        token.isEmpty;
    Widget sync(String mode, String label, Color color) => FilledButton(
        onPressed: disabled ||
                (mode == 'selected' && selectedInvoiceIds.isEmpty)
            ? null
            : () => _performBulkZatcaSync(
                idsToSync:
                    mode == 'selected' ? selectedInvoiceIds.toList() : const [],
                syncType: mode,
                accessToken: token),
        style: FilledButton.styleFrom(
            backgroundColor: color,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
        child: Text(isBulkSending && activeBulkSyncType == mode
            ? 'invoice.sending'.tr
            : label));
    final syncActions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        sync('all', 'invoice.sync_all_button'.tr, Colors.blueAccent),
        sync('failed', 'invoice.sync_failed_button'.tr, Colors.redAccent),
        sync('not_sent', 'invoice.sync_not_send_button'.tr, Colors.orange),
        sync('selected', 'invoice.sync_selected_button'.tr, Colors.blueAccent),
      ],
    );
    final selectionActions = Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('invoice.records_selected'
            .trParams({'count': '${selectedInvoiceIds.length}'})),
        TextButton(
            onPressed: disabled
                ? null
                : () => setState(() {
                      selectedInvoiceIds.addAll(
                          (provider.invoiceListDetails ?? []).map((v) => v.id));
                    }),
            style: TextButton.styleFrom(
                foregroundColor: ColorManager.kPrimaryColor),
            child: Text('invoice.select_page'.tr)),
        TextButton(
            onPressed: isBulkSending
                ? null
                : () => setState(() => selectedInvoiceIds.clear()),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: Text('invoice.unselect'.tr)),
      ],
    );
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 1000) {
        return Row(
          children: [
            Expanded(flex: 3, child: syncActions),
            const SizedBox(width: 16),
            Flexible(
              flex: 2,
              child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: selectionActions),
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          syncActions,
          const SizedBox(height: 8),
          Align(
              alignment: AlignmentDirectional.centerEnd,
              child: selectionActions),
        ],
      );
    });
  }

  Future<void> _showInvoiceDetails(Invoice invoice) async {
    final String? token = Provider.of<AuthModel>(context, listen: false).token;
    if (token == null || token.isEmpty) {
      showScaffoldError(context: context, message: 'invoice.missing_token'.tr);
      return;
    }

    showLoadingOverlay(context, message: 'invoice.loading_details'.tr);
    try {
      final provider = Provider.of<InvoiceProvider>(context, listen: false);
      await provider.callDetailsOfInvoice(id: invoice.id, accessToken: token);
      final details = provider.getInvoiceDetails;
      hideLoadingOverlay();

      if (details == null) {
        showScaffoldError(
            context: context, message: 'invoice.failed_load_details'.tr);
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
              CommonDetailsDialog.buildKeyValueRow(
                  'invoice.field_amount'.tr, details.amount),
              CommonDetailsDialog.buildKeyValueRow(
                  'invoice.field_type'.tr, details.type),
            ],
            [
              CommonDetailsDialog.buildKeyValueRow(
                  'invoice.field_invoice_date'.tr, details.invoiceDate),
              CommonDetailsDialog.buildKeyValueRow(
                  'invoice.field_due_date'.tr, details.dueDate),
              CommonDetailsDialog.buildKeyValueRow(
                  'invoice.field_status'.tr, details.status),
              CommonDetailsDialog.buildKeyValueRow(
                  'invoice.field_order_number'.tr,
                  'common_details_dialog.na'.tr),
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
                          item.displayQuantity,
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
          context: context,
          message: 'invoice.error_loading_details'
              .tr
              .replaceAll('@error', e.toString()));
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

      showScaffold(
          context: context, message: 'invoice.processing_zatca_print'.tr);
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
            message: (result['message']?.toString() ??
                'invoice.zatca_print_completed'.tr),
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
      showScaffoldError(
          context: context,
          message:
              'invoice.error_generic'.tr.replaceAll('@error', e.toString()));
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
            context: context, message: 'invoice.opened_pdf_browser'.tr);
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
      showScaffoldError(
          context: context, message: 'invoice.failed_open_pdf'.tr);
    }
  }

  Widget _statusBadge(String label, Color color) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _buildStatusChip(String status) => _statusBadge(
        switch (status.toUpperCase()) {
          'PAID' => 'invoice.status_paid'.tr,
          'PENDING' => 'invoice.status_pending'.tr,
          'FAIL' || 'FAILED' => 'invoice.status_failed'.tr,
          _ => status,
        },
        switch (status.toUpperCase()) {
          'PAID' => AppColors.green,
          'PENDING' => const Color(0xFF9A6700),
          'FAIL' || 'FAILED' => AppColors.red,
          _ => AppColors.muted,
        },
      );

  String _localizedInvoiceType(String type) => switch (type.toLowerCase()) {
        'order' => 'invoice.type_order'.tr,
        'other' => 'invoice.type_other'.tr,
        _ => type,
      };

  Widget _buildZatcaStatusChip(Invoice invoice) {
    final status = invoice.zatcaStatus?.toLowerCase();
    final requestStatus = invoice.zatcaRequestStatus?.toLowerCase();
    if (status == 'pass' || status == 'success' || status == 'sent') {
      return _statusBadge('invoice.zatca_status_sent'.tr, AppColors.green);
    }
    if (requestStatus == 'failed') {
      return _statusBadge('invoice.zatca_status_failed'.tr, AppColors.red);
    }
    if (requestStatus == 'pending' || requestStatus == 'processing') {
      return _statusBadge(
          'invoice.zatca_status_pending'.tr, ColorManager.kPrimaryColor);
    }
    return _statusBadge(
        'invoice.zatca_status_not_sent'.tr, const Color(0xFF9A6700));
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
                        'invoice.send_zatca_confirm_message'
                            .tr
                            .replaceAll('@count', count.toString()),
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
}
