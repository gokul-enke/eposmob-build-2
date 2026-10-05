import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:pos_machine/features/vouchers/domain/models/customer_voucher.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/resources/color_manager.dart';

import 'package:pos_machine/screens/transactions/widgets/share_helper.dart';
import '../../data/voucher_pdf_service.dart';

class CustomerVoucherActions {
  CustomerVoucherActions(
      {required this.context,
      required this.token,
      required this.phase2Enabled,
      required this.printVoucher});
  final BuildContext context;
  final String? Function() token;
  final bool Function() phase2Enabled;
  final Future<dynamic> Function(int, String) printVoucher;
  Future<void> show(CustomerVoucher voucher) async {
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bool phase2 = phase2Enabled();

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
      final String? token = this.token();
      if (token == null || token.isEmpty) {
        showScaffoldError(
            context: context, message: 'customer_voucher.missing_token'.tr);
        return;
      }

      showScaffold(
          context: context,
          message: 'customer_voucher.processing_zatca_phase2'.tr);
      showLoadingOverlay(context, message: 'customer_voucher.processing'.tr);

      final result = await printVoucher(voucher.id, token);
      if (!context.mounted) return;
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
        if (!context.mounted) return;
        showScaffold(
          context: context,
          message: 'customer_voucher.processed_phase2'
              .tr
              .replaceAll('@number', voucherNumber),
        );
      } else {
        final msg = (result is Map ? result['message'] : null) ??
            'customer_voucher.process_phase2_failed'.tr;
        showScaffoldError(context: context, message: msg.toString());
      }
    } catch (e) {
      if (!context.mounted) return;
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
      final String? token = this.token();
      if (token == null || token.isEmpty) {
        showScaffoldError(
            context: context, message: 'customer_voucher.missing_token'.tr);
        return;
      }

      showScaffold(
          context: context, message: 'customer_voucher.sending_to_zatca'.tr);
      showLoadingOverlay(context, message: 'customer_voucher.sending'.tr);

      final result = await printVoucher(voucher.id, token);
      if (!context.mounted) return;
      if (result is Map &&
          ((result['status'] == 'success') ||
              (result['success'] == true) ||
              (result['status'] == true))) {
        final data = result['data'] ?? {};
        final String voucherNumber =
            (data['voucher_number']?.toString() ?? voucher.voucherNumber);
        // Do NOT open PDF here per requirement. Just inform the user.
        if (!context.mounted) return;
        showScaffold(
          context: context,
          message: 'customer_voucher.submitted_to_zatca'
              .tr
              .replaceAll('@number', voucherNumber),
        );
      } else {
        final msg = (result is Map ? result['message'] : null) ??
            'customer_voucher.send_to_zatca_failed'.tr;
        showScaffoldError(context: context, message: msg.toString());
      }
    } catch (e) {
      if (!context.mounted) return;
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
      final browser = await VoucherPdfService()
          .open(url, suggestedFileName: suggestedFileName);
      if (!context.mounted) return;
      showScaffold(
          context: context,
          message: (browser
                  ? 'customer_voucher.opened_pdf_browser'
                  : 'customer_voucher.pdf_downloaded')
              .tr);
    } catch (_) {
      if (!context.mounted) return;
      showScaffoldError(
          context: context, message: 'customer_voucher.failed_open_pdf'.tr);
    }
  }
}
