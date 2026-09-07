import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';

import '../../../providers/auth_model.dart';
import '../../../providers/app_settings_provider.dart';
import '../../../providers/document_config_provider.dart';
import '../../../providers/invoice_provider.dart';
import '../../../providers/whatsapp_provider.dart';
import '../../../providers/store_session_provider.dart';
import '../../../resources/app_url.dart';
import '../../../components/build_dialog_box.dart';
import '../../../controllers/sidebar_controller.dart';
import '../../../models/document_configurations.dart';
import '../../../models/invoice_details.dart';
import '../../../models/list_receipt.dart' as lr;
import '../../../models/customer_voucher.dart';
import '../../../models/supplier_voucher.dart';
import 'pdf_builders/invoice_template_pdf_builder.dart';
import 'pdf_builders/receipt_template_pdf_builder.dart';
import 'pdf_builders/customer_voucher_template_pdf_builder.dart';
import 'pdf_builders/supplier_voucher_template_pdf_builder.dart';

/// Reusable helper to share invoices and receipts.
class ShareHelper {
  /// Shows the share options bottom sheet.
  ///
  /// Options:
  /// 1. Share as PDF – generates A4 PDF via [InvoiceTemplatePdfBuilder]
  /// 2. Share to Email – opens mailto with invoice link
  /// 3. Share via WhatsApp – uses [WhatsappProvider] bot integration
  static Future<void> showShareInvoiceSheet({
    required BuildContext context,
    required int invoiceId,
    required String invoiceNumber,
    required String? customerName,
    required String? customerPhone,
    required String? customerEmail,
    required String amount,
    String? invoiceHash,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
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
                  'share_helper.share_invoice'.tr,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),

                // 1. Share as PDF
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0x1AE53E3E),
                    child: Icon(Icons.picture_as_pdf_outlined,
                        color: Color(0xFFE53E3E)),
                  ),
                  title: Text('share_helper.opt_share_pdf'.tr),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _generateAndSharePDF(
                      context: context,
                      invoiceId: invoiceId,
                      invoiceNumber: invoiceNumber,
                    );
                  },
                ),

                // 2. Share to Email
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0x1A1E88E5),
                    child: Icon(Icons.email, color: Color(0xFF1E88E5)),
                  ),
                  title: Text(
                    (customerEmail != null && customerEmail.isNotEmpty)
                        ? 'share_helper.share_to_email_with_address'.trParams(
                            {'email': customerEmail},
                          )
                        : 'share_helper.share_to_email'.tr,
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _shareViaEmail(
                      context: context,
                      invoiceNumber: invoiceNumber,
                      customerEmail: customerEmail,
                    );
                  },
                ),

                // 3. Share via WhatsApp
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0x1A25D366),
                    child: Icon(Icons.message, color: Color(0xFF25D366)),
                  ),
                  title: Text(
                    (customerPhone != null && customerPhone.isNotEmpty)
                        ? 'share_helper.share_via_whatsapp_with_phone'.trParams(
                            {'phone': customerPhone},
                          )
                        : 'share_helper.share_via_whatsapp'.tr,
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _shareViaWhatsApp(
                      context: context,
                      invoiceNumber: invoiceNumber,
                      customerName: customerName,
                      customerPhone: customerPhone,
                      amount: amount,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Share as PDF (Invoice Template from document-configs API) ──────────

  /// 1. Fetches Invoice DocumentConfig via `type=default`
  /// 2. Fetches InvoiceDetails
  /// 3. Builds PDF using [InvoiceTemplatePdfBuilder]
  /// 4. Shares the generated PDF
  static Future<void> _generateAndSharePDF({
    required BuildContext context,
    required int invoiceId,
    required String invoiceNumber,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final String? token =
          Provider.of<AuthModel>(context, listen: false).token;
      if (token == null || token.isEmpty) {
        Navigator.of(context, rootNavigator: true).pop();
        showScaffoldError(
            context: context, message: 'share_helper.msg_missing_token'.tr);
        return;
      }

      // 1. Fetch Invoice template config (type=default maps to Invoice)
      final docConfigProvider =
          Provider.of<DocumentConfigProvider>(context, listen: false);

      DocumentConfig? invoiceConfig =
          docConfigProvider.getDocumentConfig("Invoice");

      // If not cached, fetch from API with type=default
      if (invoiceConfig == null) {
        debugPrint(
            '[ShareInvoice] Fetching Invoice config from API (type=default)...');
        invoiceConfig =
            await docConfigProvider.fetchDocumentConfigByTypeAndLanguage(
          accessToken: token,
          type: 'default',
        );
      }

      if (invoiceConfig == null) {
        Navigator.of(context, rootNavigator: true).pop();
        showScaffoldError(
            context: context,
            message: 'share_helper.msg_invoice_template_not_found'.tr);
        return;
      }

      debugPrint(
          '[ShareInvoice] Using Invoice config: accentColor=${invoiceConfig.accentColor}, '
          'header=${invoiceConfig.header}, template=${invoiceConfig.template}');

      // 2. Fetch invoice details
      final invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);
      await invoiceProvider.callDetailsOfInvoice(
          id: invoiceId, accessToken: token);
      final InvoiceDetails? details = invoiceProvider.getInvoiceDetails;

      if (details == null) {
        Navigator.of(context, rootNavigator: true).pop();
        showScaffoldError(
            context: context,
            message: 'share_helper.msg_failed_load_invoice'.tr);
        return;
      }

      // 3. Get currency
      final currency = Provider.of<AppSettingsProvider>(context, listen: false)
              .appSettings
              ?.currency ??
          'SAR';

      // Get company address from store session if available
      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      final companyAddress = storeSession.activeStore?.location;

      // 4. Generate the Invoice template PDF
      final File? pdfFile = await InvoiceTemplatePdfBuilder.generate(
        details: details,
        config: invoiceConfig,
        currency: currency,
        companyAddress: companyAddress,
      );

      // Close loading
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (pdfFile == null) {
        if (context.mounted) {
          showScaffoldError(
              context: context,
              message: 'share_helper.msg_failed_invoice_pdf'.tr);
        }
        return;
      }

      debugPrint(
          '[ShareInvoice] PDF ready: ${pdfFile.path} (${await pdfFile.length()} bytes)');

      // 5. Share the PDF
      if (Platform.isWindows) {
        try {
          final enhancedXFile = XFile(
            pdfFile.path,
            name: 'Invoice_$invoiceNumber.pdf',
            mimeType: 'application/pdf',
            length: await pdfFile.length(),
          );
          final params = ShareParams(files: [enhancedXFile]);
          final result = await SharePlus.instance.share(params);

          if (result.status == ShareResultStatus.success) {
            debugPrint('Windows file sharing succeeded!');
          } else if (result.status == ShareResultStatus.dismissed) {
            if (context.mounted) {
              showScaffold(
                  context: context,
                  message: 'share_helper.msg_sharing_cancelled'.tr);
            }
            return;
          } else {
            _handleWindowsAlternativeSharing(context, pdfFile, invoiceNumber);
            return;
          }
        } catch (e) {
          debugPrint('ShareParams API failed: $e');
          _handleWindowsAlternativeSharing(context, pdfFile, invoiceNumber);
          return;
        }
      } else {
        final enhancedXFile = XFile(
          pdfFile.path,
          name: 'Invoice_$invoiceNumber.pdf',
          mimeType: 'application/pdf',
        );
        final params = ShareParams(
          text: 'Please find attached the invoice #$invoiceNumber',
          files: [enhancedXFile],
        );
        await SharePlus.instance.share(params);
      }

      if (context.mounted) {
        showScaffold(
            context: context, message: 'share_helper.msg_invoice_shared'.tr);
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      debugPrint('[ShareInvoice] Error: $e');
      if (context.mounted) {
        showScaffoldError(
            context: context, message: 'share_helper.msg_error_invoice_pdf'.tr);
      }
    }
  }

  /// Windows fallback: shows dialog with Open File Location / Open PDF / Copy Path options.
  static void _handleWindowsAlternativeSharing(
      BuildContext context, File pdfFile, String invoiceNumber) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.red),
            const SizedBox(width: 8),
            Text('share_helper.dialog_pdf_ready'.tr),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('share_helper.dialog_invoice_label'
                .trParams({'number': invoiceNumber})),
            const SizedBox(height: 8),
            Text('File: ${pdfFile.path.split('/').last}'),
            const SizedBox(height: 16),
            Text('share_helper.dialog_pdf_choose'.tr,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await Process.start(
                  'explorer.exe',
                  ['/select,', pdfFile.path.replaceAll('/', '\\')],
                  mode: ProcessStartMode.detached,
                );
                if (context.mounted) {
                  showScaffold(
                      context: context,
                      message:
                          'File location opened. PDF saved in Documents/epos folder.');
                }
              } catch (e) {
                debugPrint('Error opening file location: $e');
              }
            },
            icon: const Icon(Icons.folder_open),
            label: Text('ui_codes.open_file_location'.tr),
          ),
          TextButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await Process.start(
                  'cmd',
                  ['/c', 'start', '""', pdfFile.path],
                  mode: ProcessStartMode.detached,
                );
                if (context.mounted) {
                  showScaffold(
                      context: context,
                      message:
                          'PDF opened. You can share from your PDF viewer.');
                }
              } catch (e) {
                debugPrint('Error opening PDF: $e');
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: Text('ui_codes.open_pdf'.tr),
          ),
          TextButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await Clipboard.setData(ClipboardData(text: pdfFile.path));
                if (context.mounted) {
                  showScaffold(
                      context: context,
                      message: 'share_helper.msg_path_copied'.tr);
                }
              } catch (e) {
                debugPrint('Error copying to clipboard: $e');
              }
            },
            icon: const Icon(Icons.copy),
            label: Text('ui_codes.copy_path'.tr),
          ),
        ],
      ),
    );
  }

  // ─── Share to Email ────────────────────────────────────────────────────────

  /// Opens the default mail app with the invoice link in the body
  /// (mirrors sales_order_details.dart `_shareViaEmail`).
  static Future<void> _shareViaEmail({
    required BuildContext context,
    required String invoiceNumber,
    required String? customerEmail,
  }) async {
    final invoiceUrl = '${APPUrl.baseURL}/invoice/$invoiceNumber';
    final message = 'Here is the link for your invoice: $invoiceUrl';

    final uri = Uri(
      scheme: 'mailto',
      path: customerEmail ?? '',
      queryParameters: <String, String>{
        'subject': 'Invoice #$invoiceNumber',
        'body': message,
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        showScaffoldError(
            context: context,
            message: 'share_helper.msg_no_email_app_invoice'.tr);
      }
    }
  }

  // ─── Share via WhatsApp ────────────────────────────────────────────────────

  /// Uses [WhatsappProvider.sendInvoiceMessage] via the WhatsApp bot
  /// (mirrors sales_order_details.dart `_shareViaWhatsApp`).
  static Future<void> _shareViaWhatsApp({
    required BuildContext context,
    required String invoiceNumber,
    required String? customerName,
    required String? customerPhone,
    required String amount,
  }) async {
    try {
      final whatsappProvider =
          Provider.of<WhatsappProvider>(context, listen: false);

      if (!whatsappProvider.isWhatsAppAvailable()) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Text('share_helper.dialog_wa_not_connected'.tr),
              ],
            ),
            content: Text(
              'share_helper.wa_connect_prompt'.trParams(
                {'status': whatsappProvider.connectionStatus},
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('general.cancel'.tr),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Get.find<SideBarController>().index.value = 63;
                },
                child: Text('share_helper.btn_connect_wa'.tr),
              ),
            ],
          ),
        );
        return;
      }

      if (customerPhone == null || customerPhone.isEmpty) {
        showScaffoldError(
            context: context, message: 'share_helper.msg_no_phone'.tr);
        return;
      }

      final currency = Provider.of<AppSettingsProvider>(context, listen: false)
              .appSettings
              ?.currency ??
          'SAR';

      final success = await whatsappProvider.sendInvoiceMessage(
        phoneNumber: customerPhone,
        orderNumber: invoiceNumber,
        customerName: customerName ?? 'Valued Customer',
        totalAmount: '$currency $amount',
        invoiceUrl: '${APPUrl.baseURL}/invoice/$invoiceNumber',
      );

      if (context.mounted) {
        if (success) {
          showScaffold(
              context: context,
              message: 'share_helper.invoice_sent_via_whatsapp'.trParams(
                {'phone': customerPhone},
              ));
        } else {
          showScaffoldError(
              context: context,
              message: 'share_helper.failed_send_whatsapp'.trParams(
                {'error': whatsappProvider.lastError},
              ));
        }
      }
    } catch (e) {
      debugPrint('Error in WhatsApp sharing: $e');
      if (context.mounted) {
        showScaffoldError(
            context: context, message: 'share_helper.msg_wa_error'.tr);
      }
    }
  }

  // ─── Share Receipt ──────────────────────────────────────────────────────────

  /// Shows the share options bottom sheet for receipts.
  static Future<void> showShareReceiptSheet({
    required BuildContext context,
    required lr.Receipt receipt,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
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
                  'share_helper.share_receipt'.tr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),

                // Share options
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0x1AE53E3E),
                    child: Icon(Icons.picture_as_pdf_outlined,
                        color: Color(0xFFE53E3E)),
                  ),
                  title: Text('share_helper.opt_share_pdf'.tr),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _generateAndShareReceiptPDF(
                      context: context,
                      receipt: receipt,
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0x1A1E88E5),
                    child: Icon(Icons.email, color: Color(0xFF1E88E5)),
                  ),
                  title: Text('share_helper.opt_share_email'.tr),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _shareReceiptViaEmail(
                      context: context,
                      receipt: receipt,
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0x1A25D366),
                    child: Icon(Icons.message, color: Color(0xFF25D366)),
                  ),
                  title: Text(
                    (receipt.customer.user.phone.isNotEmpty)
                        ? 'share_helper.share_via_whatsapp_with_phone'.trParams(
                            {'phone': receipt.customer.user.phone},
                          )
                        : 'share_helper.share_via_whatsapp'.tr,
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _shareReceiptViaWhatsApp(
                      context: context,
                      receipt: receipt,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Generates the Receipt PDF and shares / opens it.
  static Future<void> _generateAndShareReceiptPDF({
    required BuildContext context,
    required lr.Receipt receipt,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final String? token =
          Provider.of<AuthModel>(context, listen: false).token;
      if (token == null || token.isEmpty) {
        Navigator.of(context, rootNavigator: true).pop();
        showScaffoldError(
            context: context, message: 'share_helper.msg_missing_token'.tr);
        return;
      }

      // 1. Fetch Receipt template config
      final docConfigProvider =
          Provider.of<DocumentConfigProvider>(context, listen: false);

      DocumentConfig? receiptConfig =
          docConfigProvider.getDocumentConfig("Receipt");

      // If not cached, fetch from API with type=receipt
      if (receiptConfig == null) {
        debugPrint(
            '[ShareReceipt] Fetching Receipt config from API (type=receipt)...');
        receiptConfig =
            await docConfigProvider.fetchDocumentConfigByTypeAndLanguage(
          accessToken: token,
          type: 'receipt',
        );
      }

      if (receiptConfig == null) {
        Navigator.of(context, rootNavigator: true).pop();
        showScaffoldError(
            context: context,
            message: 'share_helper.msg_receipt_template_not_found'.tr);
        return;
      }

      debugPrint(
          '[ShareReceipt] Using Receipt config: accentColor=${receiptConfig.accentColor}, '
          'header=${receiptConfig.header}, template=${receiptConfig.template}');

      // 2. Get currency
      final currency = Provider.of<AppSettingsProvider>(context, listen: false)
              .appSettings
              ?.currency ??
          'SAR';

      // Get company address from store session if available
      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      final companyAddress = storeSession.activeStore?.location;

      // 3. Generate the Receipt template PDF
      final File? pdfFile = await ReceiptTemplatePdfBuilder.generate(
        details: receipt,
        config: receiptConfig,
        currency: currency,
        companyAddress: companyAddress,
      );

      // Close loading
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (pdfFile == null) {
        if (context.mounted) {
          showScaffoldError(
              context: context,
              message: 'share_helper.msg_failed_receipt_pdf'.tr);
        }
        return;
      }

      debugPrint(
          '[ShareReceipt] PDF ready: ${pdfFile.path} (${await pdfFile.length()} bytes)');

      // 4. Share the PDF
      if (Platform.isWindows) {
        try {
          final enhancedXFile = XFile(
            pdfFile.path,
            name: 'Receipt_${receipt.receiptNumber}.pdf',
            mimeType: 'application/pdf',
            length: await pdfFile.length(),
          );
          final params = ShareParams(files: [enhancedXFile]);
          final result = await SharePlus.instance.share(params);

          if (result.status == ShareResultStatus.success) {
            debugPrint('Windows file sharing succeeded!');
          } else if (result.status == ShareResultStatus.dismissed) {
            if (context.mounted) {
              showScaffold(
                  context: context,
                  message: 'share_helper.msg_sharing_cancelled'.tr);
            }
            return;
          } else {
            _handleWindowsAlternativeSharing(
                context, pdfFile, receipt.receiptNumber);
            return;
          }
        } catch (e) {
          debugPrint('ShareParams API failed: $e');
          _handleWindowsAlternativeSharing(
              context, pdfFile, receipt.receiptNumber);
          return;
        }
      } else {
        final enhancedXFile = XFile(
          pdfFile.path,
          name: 'Receipt_${receipt.receiptNumber}.pdf',
          mimeType: 'application/pdf',
        );
        final params = ShareParams(
          text: 'Please find attached the receipt #${receipt.receiptNumber}',
          files: [enhancedXFile],
        );
        await SharePlus.instance.share(params);
      }

      if (context.mounted) {
        showScaffold(
            context: context, message: 'share_helper.receipt_pdf_shared'.tr);
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      debugPrint('[ShareReceipt] Error: $e');
      if (context.mounted) {
        showScaffoldError(
            context: context,
            message: 'share_helper.error_generating_receipt_pdf'.tr);
      }
    }
  }

  /// Opens mailto client with Receipt details
  static Future<void> _shareReceiptViaEmail({
    required BuildContext context,
    required lr.Receipt receipt,
  }) async {
    try {
      final String email = receipt.customer.user.email;
      final String subject = Uri.encodeComponent(
          'Receipt Payment Reference: ${receipt.receiptNumber}');
      final String body = Uri.encodeComponent(
          'Dear ${receipt.customer.user.name},\n\n'
          'Thank you for your payment. Please find your receipt details below:\n\n'
          'Receipt Number: ${receipt.receiptNumber}\n'
          'Amount: ${receipt.amount}\n'
          'Payment Reference: ${receipt.paymentReference}\n'
          'Payment Method: ${receipt.paymentMethod}\n\n'
          'Best regards,\n'
          '${receipt.company.name}');
      final Uri mailtoUri =
          Uri.parse('mailto:$email?subject=$subject&body=$body');

      if (await canLaunchUrl(mailtoUri)) {
        await launchUrl(mailtoUri);
      } else {
        if (context.mounted) {
          showScaffoldError(
              context: context, message: 'share_helper.msg_no_email_app'.tr);
        }
      }
    } catch (e) {
      debugPrint('Error launching email: $e');
      if (context.mounted) {
        showScaffoldError(
            context: context,
            message: 'share_helper.msg_failed_share_receipt_email'.tr);
      }
    }
  }

  /// Sends Receipt PDF + details via WhatsApp bot
  static Future<void> _shareReceiptViaWhatsApp({
    required BuildContext context,
    required lr.Receipt receipt,
  }) async {
    try {
      final whatsappProvider =
          Provider.of<WhatsappProvider>(context, listen: false);

      if (!whatsappProvider.isWhatsAppAvailable()) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Text('share_helper.dialog_wa_not_connected'.tr),
              ],
            ),
            content: Text(
              'share_helper.wa_connect_prompt'.trParams(
                {'status': whatsappProvider.connectionStatus},
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('general.cancel'.tr),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Get.find<SideBarController>().index.value = 63;
                },
                child: Text('share_helper.btn_connect_wa'.tr),
              ),
            ],
          ),
        );
        return;
      }

      final customerPhone = receipt.customer.user.phone;
      if (customerPhone.isEmpty) {
        showScaffoldError(
            context: context, message: 'share_helper.msg_no_phone'.tr);
        return;
      }

      // Generate the PDF file first so we can attach it
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final String? token =
          Provider.of<AuthModel>(context, listen: false).token;
      if (token == null || token.isEmpty) {
        Navigator.of(context, rootNavigator: true).pop();
        showScaffoldError(
            context: context, message: 'share_helper.msg_missing_token'.tr);
        return;
      }

      // 1. Fetch Receipt config
      final docConfigProvider =
          Provider.of<DocumentConfigProvider>(context, listen: false);
      DocumentConfig? receiptConfig =
          docConfigProvider.getDocumentConfig("Receipt");
      if (receiptConfig == null) {
        receiptConfig =
            await docConfigProvider.fetchDocumentConfigByTypeAndLanguage(
          accessToken: token,
          type: 'receipt',
        );
      }

      if (receiptConfig == null) {
        Navigator.of(context, rootNavigator: true).pop();
        showScaffoldError(
            context: context,
            message: 'share_helper.msg_receipt_template_not_found'.tr);
        return;
      }

      final currency = Provider.of<AppSettingsProvider>(context, listen: false)
              .appSettings
              ?.currency ??
          'SAR';

      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      final companyAddress = storeSession.activeStore?.location;

      final File? pdfFile = await ReceiptTemplatePdfBuilder.generate(
        details: receipt,
        config: receiptConfig,
        currency: currency,
        companyAddress: companyAddress,
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (pdfFile == null) {
        if (context.mounted) {
          showScaffoldError(
              context: context,
              message: 'share_helper.failed_generate_pdf_whatsapp'.tr);
        }
        return;
      }

      final messageText = 'Dear ${receipt.customer.user.name},\n\n'
          'Thank you for your payment. Please find your receipt ${receipt.receiptNumber} attached.\n\n'
          'Total Amount: $currency ${receipt.amount}\n'
          'Payment Reference: ${receipt.paymentReference}\n'
          'Payment Method: ${receipt.paymentMethod}\n\n'
          'Best regards,\n'
          '${receipt.company.name}';

      final success = await whatsappProvider.sendPDFFile(
        phoneNumber: customerPhone,
        pdfFile: pdfFile,
        caption: messageText,
      );

      if (context.mounted) {
        if (success) {
          showScaffold(
              context: context,
              message: 'share_helper.receipt_sent_via_whatsapp'.trParams(
                {'phone': customerPhone},
              ));
        } else {
          showScaffoldError(
              context: context,
              message: 'share_helper.failed_send_whatsapp'.trParams(
                {'error': whatsappProvider.lastError},
              ));
        }
      }
    } catch (e) {
      debugPrint('Error in WhatsApp sharing: $e');
      if (context.mounted) {
        showScaffoldError(
            context: context, message: 'share_helper.msg_wa_error'.tr);
      }
    }
  }

  // ─── Share Customer Voucher ──────────────────────────────────────────────────

  /// Shows the share options bottom sheet for Customer Vouchers.
  static Future<void> showShareCustomerVoucherSheet({
    required BuildContext context,
    required CustomerVoucher voucher,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Indicator
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
                  'share_helper.share_voucher'.tr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),

                // 1. Share as PDF
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0x1AE53E3E),
                    child: Icon(Icons.picture_as_pdf_outlined,
                        color: Color(0xFFE53E3E)),
                  ),
                  title: Text('share_helper.opt_share_pdf'.tr),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _generateAndShareVoucherPDF(
                      context: context,
                      voucher: voucher,
                    );
                  },
                ),

                // 2. Share to Email
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0x1A1E88E5),
                    child: Icon(Icons.email, color: Color(0xFF1E88E5)),
                  ),
                  title: Text(
                    (voucher.customer.user.email != null &&
                            voucher.customer.user.email!.isNotEmpty)
                        ? 'share_helper.share_to_email_with_address'.trParams(
                            {'email': voucher.customer.user.email!},
                          )
                        : 'share_helper.share_to_email'.tr,
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final email = voucher.customer.user.email ?? '';
                    final subject = Uri.encodeComponent(
                        'Voucher #${voucher.voucherNumber}');
                    final body = Uri.encodeComponent(
                        'Dear ${voucher.customer.user.name},\n\n'
                        'Please find details of your voucher #${voucher.voucherNumber}.\n'
                        'Total Amount: ${voucher.amount}\n'
                        'Status: ${voucher.status.toUpperCase()}\n\n'
                        'Best regards,');
                    final mailtoUrl =
                        'mailto:$email?subject=$subject&body=$body';
                    try {
                      await launchUrl(Uri.parse(mailtoUrl));
                    } catch (e) {
                      if (context.mounted) {
                        showScaffoldError(
                            context: context,
                            message: 'share_helper.msg_no_email_app'.tr);
                      }
                    }
                  },
                ),

                // 3. Share via WhatsApp
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0x1A25D366),
                    child: Icon(Icons.message, color: Color(0xFF25D366)),
                  ),
                  title: Text(
                    voucher.customer.user.phone.isNotEmpty
                        ? 'share_helper.opt_send_whatsapp_to_number'.trParams(
                            {'phone': voucher.customer.user.phone},
                          )
                        : 'share_helper.opt_send_whatsapp'.tr,
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _sendVoucherWhatsAppMessage(
                      context: context,
                      voucher: voucher,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _generateAndShareVoucherPDF({
    required BuildContext context,
    required CustomerVoucher voucher,
  }) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 1. Fetch document config for type 'Voucher'
      final docConfigProvider =
          Provider.of<DocumentConfigProvider>(context, listen: false);
      String? token = Provider.of<AuthModel>(context, listen: false).token;

      DocumentConfig? voucherConfig =
          docConfigProvider.getDocumentConfig('Voucher');
      if (voucherConfig == null && token != null) {
        debugPrint('[ShareVoucher] Fetching config from API (type=Voucher)...');
        voucherConfig =
            await docConfigProvider.fetchDocumentConfigByTypeAndLanguage(
          accessToken: token,
          type: 'voucher',
        );
      }

      if (voucherConfig == null) {
        if (context.mounted) {
          if (Navigator.canPop(context)) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          showScaffoldError(
              context: context,
              message: 'share_helper.msg_voucher_template_not_found'.tr);
        }
        return;
      }

      // 2. Fetch currency
      final currency = Provider.of<AppSettingsProvider>(context, listen: false)
              .appSettings
              ?.currency ??
          'SAR';

      // 3. Fetch store details for billing
      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      final companyName = storeSession.activeStore?.storeName ?? 'Store';
      final companyAddress = storeSession.activeStore?.location;

      // 4. Generate A4 template PDF
      final File? pdfFile = await CustomerVoucherTemplatePdfBuilder.generate(
        details: voucher,
        config: voucherConfig,
        currency: currency,
        companyName: companyName,
        companyAddress: companyAddress,
      );

      if (context.mounted) {
        if (Navigator.canPop(context)) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }

      if (pdfFile == null) {
        if (context.mounted) {
          showScaffoldError(
              context: context, message: 'share_helper.msg_failed_pdf'.tr);
        }
        return;
      }

      // 5. Share PDF
      if (Platform.isWindows) {
        try {
          final enhancedXFile = XFile(
            pdfFile.path,
            name: 'Voucher_${voucher.voucherNumber}.pdf',
            mimeType: 'application/pdf',
            length: await pdfFile.length(),
          );
          final params = ShareParams(files: [enhancedXFile]);
          final result = await SharePlus.instance.share(params);

          if (result.status == ShareResultStatus.success) {
            debugPrint('Windows file sharing succeeded!');
          } else if (result.status == ShareResultStatus.dismissed) {
            if (context.mounted) {
              showScaffold(
                  context: context,
                  message: 'share_helper.msg_sharing_cancelled'.tr);
            }
            return;
          } else {
            _handleWindowsAlternativeSharing(
                context, pdfFile, 'Voucher #${voucher.voucherNumber}');
            return;
          }
        } catch (e) {
          debugPrint('ShareParams API failed: $e');
          _handleWindowsAlternativeSharing(
              context, pdfFile, 'Voucher #${voucher.voucherNumber}');
          return;
        }
      } else {
        final enhancedXFile = XFile(
          pdfFile.path,
          name: 'Voucher_${voucher.voucherNumber}.pdf',
          mimeType: 'application/pdf',
        );
        final params = ShareParams(
          text: 'Please find attached the voucher #${voucher.voucherNumber}',
          files: [enhancedXFile],
        );
        await SharePlus.instance.share(params);
      }

      if (context.mounted) {
        showScaffold(
            context: context, message: 'share_helper.voucher_pdf_shared'.tr);
      }
    } catch (e) {
      debugPrint('Error sharing voucher PDF: $e');
      if (context.mounted) {
        if (Navigator.canPop(context)) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        showScaffoldError(
          context: context,
          message: 'share_helper.error_generating_pdf'.tr,
        );
      }
    }
  }

  static Future<void> _sendVoucherWhatsAppMessage({
    required BuildContext context,
    required CustomerVoucher voucher,
  }) async {
    try {
      final String customerPhone = voucher.customer.user.phone.trim();
      if (customerPhone.isEmpty) {
        showScaffoldError(
            context: context, message: 'share_helper.msg_no_phone_customer'.tr);
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 1. Fetch document config for type 'Voucher'
      final docConfigProvider =
          Provider.of<DocumentConfigProvider>(context, listen: false);
      String? token = Provider.of<AuthModel>(context, listen: false).token;

      DocumentConfig? voucherConfig =
          docConfigProvider.getDocumentConfig('Voucher');
      if (voucherConfig == null && token != null) {
        voucherConfig =
            await docConfigProvider.fetchDocumentConfigByTypeAndLanguage(
          accessToken: token,
          type: 'voucher',
        );
      }

      if (voucherConfig == null) {
        if (context.mounted) {
          if (Navigator.canPop(context)) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          showScaffoldError(
              context: context,
              message: 'share_helper.msg_voucher_template_not_found'.tr);
        }
        return;
      }

      // 2. Fetch currency
      final currency = Provider.of<AppSettingsProvider>(context, listen: false)
              .appSettings
              ?.currency ??
          'SAR';

      // 3. Fetch store details for billing
      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      final companyName = storeSession.activeStore?.storeName ?? 'Store';
      final companyAddress = storeSession.activeStore?.location;

      // 4. Generate PDF
      final File? pdfFile = await CustomerVoucherTemplatePdfBuilder.generate(
        details: voucher,
        config: voucherConfig,
        currency: currency,
        companyName: companyName,
        companyAddress: companyAddress,
      );

      if (context.mounted) {
        if (Navigator.canPop(context)) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }

      if (pdfFile == null) {
        if (context.mounted) {
          showScaffoldError(
              context: context, message: 'share_helper.msg_failed_pdf'.tr);
        }
        return;
      }

      // 5. Send PDF
      final whatsappProvider =
          Provider.of<WhatsappProvider>(context, listen: false);
      final messageText = 'Dear ${voucher.customer.user.name},\n\n'
          'Please find details of your voucher #${voucher.voucherNumber} attached.\n\n'
          'Total Amount: $currency ${voucher.amount}\n'
          'Status: ${voucher.status.toUpperCase()}\n'
          'Payment Method: ${voucher.paymentMethod}\n\n'
          'Best regards,\n'
          '$companyName';

      final success = await whatsappProvider.sendPDFFile(
        phoneNumber: customerPhone,
        pdfFile: pdfFile,
        caption: messageText,
      );

      if (context.mounted) {
        if (success) {
          showScaffold(
            context: context,
            message: 'share_helper.voucher_sent_via_whatsapp'.trParams(
              {'phone': customerPhone},
            ),
          );
        } else {
          showScaffoldError(
            context: context,
            message: 'share_helper.failed_send_whatsapp'.trParams(
              {'error': whatsappProvider.lastError},
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error in WhatsApp sharing: $e');
      if (context.mounted) {
        if (Navigator.canPop(context)) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        showScaffoldError(
            context: context, message: 'share_helper.msg_wa_error'.tr);
      }
    }
  }

  // ─── Share Supplier Voucher ──────────────────────────────────────────────────

  /// Shows the share options bottom sheet for Supplier Vouchers.
  static Future<void> showShareSupplierVoucherSheet({
    required BuildContext context,
    required SupplierVoucher voucher,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Indicator
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
                  'share_helper.share_supplier_voucher'.tr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),

                // 1. Share as PDF
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0x1AE53E3E),
                    child: Icon(Icons.picture_as_pdf_outlined,
                        color: Color(0xFFE53E3E)),
                  ),
                  title: Text('share_helper.opt_share_pdf'.tr),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _generateAndShareSupplierVoucherPDF(
                      context: context,
                      voucher: voucher,
                    );
                  },
                ),

                // 2. Share to Email
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0x1A1E88E5),
                    child: Icon(Icons.email, color: Color(0xFF1E88E5)),
                  ),
                  title: Text(
                    voucher.supplier.email.isNotEmpty
                        ? 'share_helper.share_to_email_with_address'.trParams(
                            {'email': voucher.supplier.email},
                          )
                        : 'share_helper.share_to_email'.tr,
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final email = voucher.supplier.email;
                    final subject = Uri.encodeComponent(
                        'Supplier Voucher #${voucher.voucherNumber}');
                    final body = Uri.encodeComponent(
                        'Dear ${voucher.supplier.name},\n\n'
                        'Please find details of your supplier voucher #${voucher.voucherNumber}.\n'
                        'Total Amount: ${voucher.amount}\n'
                        'Status: ${voucher.status.toUpperCase()}\n\n'
                        'Best regards,');
                    final mailtoUrl =
                        'mailto:$email?subject=$subject&body=$body';
                    try {
                      await launchUrl(Uri.parse(mailtoUrl));
                    } catch (e) {
                      if (context.mounted) {
                        showScaffoldError(
                            context: context,
                            message: 'share_helper.msg_no_email_app'.tr);
                      }
                    }
                  },
                ),

                // 3. Share via WhatsApp
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0x1A25D366),
                    child: Icon(Icons.message, color: Color(0xFF25D366)),
                  ),
                  title: Text(
                    voucher.supplier.phone.isNotEmpty
                        ? 'share_helper.opt_send_whatsapp_to_number'.trParams(
                            {'phone': voucher.supplier.phone},
                          )
                        : 'share_helper.opt_send_whatsapp'.tr,
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _sendSupplierVoucherWhatsAppMessage(
                      context: context,
                      voucher: voucher,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _generateAndShareSupplierVoucherPDF({
    required BuildContext context,
    required SupplierVoucher voucher,
  }) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 1. Fetch document config for type 'Supplier Voucher'
      final docConfigProvider =
          Provider.of<DocumentConfigProvider>(context, listen: false);
      String? token = Provider.of<AuthModel>(context, listen: false).token;

      DocumentConfig? voucherConfig =
          docConfigProvider.getDocumentConfig('Supplier Voucher');
      if (voucherConfig == null && token != null) {
        debugPrint('[ShareSupplierVoucher] Fetching config from API...');
        await docConfigProvider.fetchDocumentConfigurations(accessToken: token);
        voucherConfig = docConfigProvider.getDocumentConfig('Supplier Voucher');
      }

      if (voucherConfig == null) {
        if (context.mounted) {
          if (Navigator.canPop(context)) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          showScaffoldError(
              context: context,
              message:
                  'share_helper.msg_supplier_voucher_template_not_found'.tr);
        }
        return;
      }

      // 2. Fetch currency
      final currency = Provider.of<AppSettingsProvider>(context, listen: false)
              .appSettings
              ?.currency ??
          'SAR';

      // 3. Fetch store details for billing
      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      final companyName = storeSession.activeStore?.storeName ?? 'Store';
      final companyAddress = storeSession.activeStore?.location;

      // 4. Generate A4 template PDF
      final File? pdfFile = await SupplierVoucherTemplatePdfBuilder.generate(
        details: voucher,
        config: voucherConfig,
        currency: currency,
        companyName: companyName,
        companyAddress: companyAddress,
      );

      if (context.mounted) {
        if (Navigator.canPop(context)) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }

      if (pdfFile == null) {
        if (context.mounted) {
          showScaffoldError(
              context: context, message: 'share_helper.msg_failed_pdf'.tr);
        }
        return;
      }

      // 5. Share PDF
      if (Platform.isWindows) {
        try {
          final enhancedXFile = XFile(
            pdfFile.path,
            name: 'SupplierVoucher_${voucher.voucherNumber}.pdf',
            mimeType: 'application/pdf',
            length: await pdfFile.length(),
          );
          final params = ShareParams(files: [enhancedXFile]);
          final result = await SharePlus.instance.share(params);

          if (result.status == ShareResultStatus.success) {
            debugPrint('Windows file sharing succeeded!');
          } else if (result.status == ShareResultStatus.dismissed) {
            if (context.mounted) {
              showScaffold(
                  context: context,
                  message: 'share_helper.msg_sharing_cancelled'.tr);
            }
            return;
          } else {
            _handleWindowsAlternativeSharing(
                context, pdfFile, 'Supplier Voucher #${voucher.voucherNumber}');
            return;
          }
        } catch (e) {
          debugPrint('ShareParams API failed: $e');
          _handleWindowsAlternativeSharing(
              context, pdfFile, 'Supplier Voucher #${voucher.voucherNumber}');
          return;
        }
      } else {
        final enhancedXFile = XFile(
          pdfFile.path,
          name: 'SupplierVoucher_${voucher.voucherNumber}.pdf',
          mimeType: 'application/pdf',
        );
        final params = ShareParams(
          text:
              'Please find attached the supplier voucher #${voucher.voucherNumber}',
          files: [enhancedXFile],
        );
        await SharePlus.instance.share(params);
      }

      if (context.mounted) {
        showScaffold(
            context: context,
            message: 'share_helper.supplier_voucher_pdf_shared'.tr);
      }
    } catch (e) {
      debugPrint('Error sharing supplier voucher PDF: $e');
      if (context.mounted) {
        if (Navigator.canPop(context)) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        showScaffoldError(
          context: context,
          message: 'share_helper.error_generating_pdf'.tr,
        );
      }
    }
  }

  static Future<void> _sendSupplierVoucherWhatsAppMessage({
    required BuildContext context,
    required SupplierVoucher voucher,
  }) async {
    try {
      final String customerPhone = voucher.supplier.phone.trim();
      if (customerPhone.isEmpty) {
        showScaffoldError(
          context: context,
          message: 'share_helper.supplier_phone_empty'.tr,
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 1. Fetch document config for type 'Supplier Voucher'
      final docConfigProvider =
          Provider.of<DocumentConfigProvider>(context, listen: false);
      String? token = Provider.of<AuthModel>(context, listen: false).token;

      DocumentConfig? voucherConfig =
          docConfigProvider.getDocumentConfig('Supplier Voucher');
      if (voucherConfig == null && token != null) {
        await docConfigProvider.fetchDocumentConfigurations(accessToken: token);
        voucherConfig = docConfigProvider.getDocumentConfig('Supplier Voucher');
      }

      if (voucherConfig == null) {
        if (context.mounted) {
          if (Navigator.canPop(context)) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          showScaffoldError(
              context: context,
              message:
                  'share_helper.msg_supplier_voucher_template_not_found'.tr);
        }
        return;
      }

      // 2. Fetch currency
      final currency = Provider.of<AppSettingsProvider>(context, listen: false)
              .appSettings
              ?.currency ??
          'SAR';

      // 3. Fetch store details for billing
      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      final companyName = storeSession.activeStore?.storeName ?? 'Store';
      final companyAddress = storeSession.activeStore?.location;

      // 4. Generate PDF
      final File? pdfFile = await SupplierVoucherTemplatePdfBuilder.generate(
        details: voucher,
        config: voucherConfig,
        currency: currency,
        companyName: companyName,
        companyAddress: companyAddress,
      );

      if (context.mounted) {
        if (Navigator.canPop(context)) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }

      if (pdfFile == null) {
        if (context.mounted) {
          showScaffoldError(
              context: context, message: 'share_helper.msg_failed_pdf'.tr);
        }
        return;
      }

      // 5. Send PDF
      final whatsappProvider =
          Provider.of<WhatsappProvider>(context, listen: false);
      final messageText = 'Dear ${voucher.supplier.name},\n\n'
          'Please find details of your supplier voucher #${voucher.voucherNumber} attached.\n\n'
          'Total Amount: $currency ${voucher.amount}\n'
          'Status: ${voucher.status.toUpperCase()}\n'
          'Payment Method: ${voucher.paymentMethod}\n\n'
          'Best regards,\n'
          '$companyName';

      final success = await whatsappProvider.sendPDFFile(
        phoneNumber: customerPhone,
        pdfFile: pdfFile,
        caption: messageText,
      );

      if (context.mounted) {
        if (success) {
          showScaffold(
            context: context,
            message: 'share_helper.supplier_voucher_sent_via_whatsapp'
                .trParams({'phone': customerPhone}),
          );
        } else {
          showScaffoldError(
            context: context,
            message: 'share_helper.failed_send_whatsapp'.trParams(
              {'error': whatsappProvider.lastError},
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error in WhatsApp sharing: $e');
      if (context.mounted) {
        if (Navigator.canPop(context)) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        showScaffoldError(
            context: context, message: 'share_helper.msg_wa_error'.tr);
      }
    }
  }
}
