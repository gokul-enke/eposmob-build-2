import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:websafe_svg/websafe_svg.dart';

import '../sharing/sales_page_services.dart';
import '../sharing/sales_pdf_sharing.dart';
import '../sharing/sales_whatsapp_sharing.dart';

Future<void> shareSalesOrder(
    BuildContext context,
    BuildContext ctx,
    SalesPageServices services,
    ListOrderModelData order,
    bool isOnlineSales) async {
  Navigator.pop(ctx);
  // Handle share option - show share modal
  try {
    String? invoiceHash = order.invoiceHash;
    if (invoiceHash == null) {
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'sales.invoice_not_available_sharing'.tr,
        );
      }
      return;
    }

    // Build message with invoice link
    final String invoiceUrl = "${APPUrl.baseURL}/invoice-download/$invoiceHash";
    final String message = "Here is the link for your invoice: $invoiceUrl";

    // Try to fetch customer phone/email from order details (for direct share targets)
    String? customerPhone;
    String? customerEmail;
    try {
      final String ordersId = order.orderNumber.toString();
      final String? accessToken = services.auth.token;
      final OrderDetailsresponse = await services.sales
          .listOrderDetails(context, ordersId, accessToken ?? "");
      if (OrderDetailsresponse["status"] == "success") {
        final OrderDetailsModel details =
            OrderDetailsModel.fromJson(OrderDetailsresponse);
        customerPhone = details.data?.customerDetails?.phone;
        customerEmail = details.data?.customerDetails?.email;
      }
    } catch (e) {}

    // Sanitize phone for WhatsApp wa.me format (digits only, international format preferred)
    String? intlPhone;
    if (customerPhone != null && customerPhone.trim().isNotEmpty) {
      final digits = customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) intlPhone = digits;
    }

    if (!context.mounted) return;
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
                  'sales.title_share_invoice_sheet'.tr,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        ColorManager.kPrimaryColor.withOpacity(0.12),
                    child: const Icon(Icons.share,
                        color: ColorManager.kPrimaryColor),
                  ),
                  title: Text('sales.btn_share'.tr),
                  onTap: () async {
                    Navigator.pop(ctx);
                    // On Windows, sharing a file tends to open the native Share UI more reliably
                    if (Platform.isWindows) {
                      final Uint8List data =
                          Uint8List.fromList(utf8.encode(message));
                      final XFile note = XFile.fromData(
                        data,
                        mimeType: 'text/plain',
                        name: 'Invoice_${order.orderNumber}.txt',
                      );
                      await Share.shareXFiles(
                        [note],
                        text: message,
                        subject: 'Invoice #${order.orderNumber}',
                      );
                    } else {
                      await Share.share(
                        message,
                        subject: 'Invoice #${order.orderNumber}',
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0x1A1E88E5), // ~10% opacity blue
                    child: Icon(Icons.email, color: Color(0xFF1E88E5)),
                  ),
                  title: Text(
                    (customerEmail != null && customerEmail.isNotEmpty)
                        ? '${'sales.opt_share_email'.tr} ($customerEmail)'
                        : 'sales.opt_share_email'.tr,
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final uri = Uri(
                      scheme: 'mailto',
                      path: (customerEmail != null && customerEmail.isNotEmpty)
                          ? customerEmail
                          : '',
                      queryParameters: <String, String>{
                        'subject': 'Invoice #${order.orderNumber}',
                        'body': message,
                      },
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    } else {
                      if (context.mounted) {
                        showScaffoldError(
                          context: context,
                          message: 'sales.no_email_app'.tr,
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        const Color(0x1A25D366), // ~10% opacity WhatsApp green
                    child: WebsafeSvg.asset(
                      ImageAssets.whatsappIcon,
                      colorFilter: const ColorFilter.mode(
                        Colors.green,
                        BlendMode.srcIn,
                      ),
                      fit: BoxFit.none,
                    ),
                  ),
                  title: Text(
                    intlPhone != null
                        ? '${'sales.opt_share_whatsapp'.tr} ($intlPhone)'
                        : 'sales.opt_share_whatsapp'.tr,
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await shareSalesWhatsapp(context, services, order);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0x1AE53E3E), // ~10% opacity red
                    child: Icon(Icons.picture_as_pdf_outlined,
                        color: Color(0xFFE53E3E)),
                  ),
                  title: Text('sales.opt_share_pdf'.tr),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await shareSalesPdf(context, services, order);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  } catch (error) {
    if (context.mounted) {
      showScaffoldError(
        context: context,
        message: 'sales.err_sharing_invoice'.tr,
      );
    }
  }
}
