import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_machine/models/list_invoice.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../providers/app_settings_provider.dart';
import '../../../providers/auth_model.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';
import '../widgets/common_details_dialog.dart';
import '../widgets/share_helper.dart';

/// Per-invoice actions of the invoice list: the details dialog, the "more"
/// sheet (share, ZATCA Phase 1 print, Phase 2 send / resync / print) and
/// the ZATCA confirmation dialog shared with the bulk sync.
mixin InvoiceRowActions<W extends StatefulWidget> on State<W> {
  bool canRunPhase2Action() {
    if (!mounted) return false;
    final settings = context.read<AppSettingsProvider>();
    if (settings.isReady &&
        (settings.appSettings?.zatcaPhase2Enabled ?? false)) {
      return true;
    }
    showScaffoldError(
        context: context, message: 'invoice.settings_unverified'.tr);
    return false;
  }

  Future<void> _performZatcaPhase2SendWithPdf(Invoice invoice) async {
    if (!canRunPhase2Action()) return;
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
    if (!canRunPhase2Action()) return;
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

  Future<void> showInvoiceActionsSheet(Invoice invoice) async {
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
              backgroundColor: ColorManager.kPrimaryColor.withValues(alpha: 0.12),
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
                backgroundColor: Colors.green.withValues(alpha: 0.12),
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
                  backgroundColor: Colors.orange.withValues(alpha: 0.12),
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
                  backgroundColor: Colors.purple.withValues(alpha: 0.12),
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
                  backgroundColor: Colors.purple.withValues(alpha: 0.12),
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
                  backgroundColor: Colors.purple.withValues(alpha: 0.12),
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
                  backgroundColor: Colors.purple.withValues(alpha: 0.12),
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
                  backgroundColor: ColorManager.kPrimaryColor.withValues(alpha: 0.12),
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
    if (!canRunPhase2Action()) return;
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
      final shouldSend = await showZatcaConfirmationDialog(count: 1);
      if (shouldSend != true || !canRunPhase2Action()) return;

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

  Future<void> showInvoiceDetails(Invoice invoice) async {
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
                        style: const TextStyle(
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
                        style: const TextStyle(
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
                        style: const TextStyle(
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
                        style: const TextStyle(
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
                          style: const TextStyle(
                            fontSize: FontSize.s12,
                            color: ColorManager.textColor,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.displayQuantity,
                          style: const TextStyle(
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
                          style: const TextStyle(
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
                          style: const TextStyle(
                            fontSize: FontSize.s12,
                            color: ColorManager.textColor,
                          ),
                          textAlign: TextAlign.right,
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
    } catch (e) {
      hideLoadingOverlay();
      showScaffoldError(
          context: context,
          message: 'invoice.error_loading_details'
              .tr
              .replaceAll('@error', e.toString()));
    }
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

  Future<bool> showZatcaConfirmationDialog({
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
                            color: Colors.blue.withValues(alpha: 0.1),
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
