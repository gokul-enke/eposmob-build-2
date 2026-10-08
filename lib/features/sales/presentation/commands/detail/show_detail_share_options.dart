import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/sales/presentation/sharing/sales_page_services.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_order_detail_controller.dart';

import 'share_detail_pdf.dart';
import 'share_detail_via_email.dart';
import 'share_detail_via_whats_app.dart';

Future<void> showDetailShareOptions(BuildContext context,
    SalesOrderDetailController controller, SalesPageServices services) async {
  final orderDetailsModelData = controller.data;
  final customerDetails = controller.customer;

  if (orderDetailsModelData == null) {
    showScaffoldError(
      context: context,
      message: 'sales_order_details.msg_not_available'.tr,
    );
    return;
  }

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
                'sales_order_details.title_share_invoice'.tr,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              ListTile(
                leading: const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0x1AE53E3E),
                  child: Icon(Icons.picture_as_pdf_outlined,
                      color: Color(0xFFE53E3E)),
                ),
                title: Text('sales_order_details.opt_share_pdf'.tr),
                onTap: () async {
                  Navigator.pop(ctx);
                  await shareDetailPdf(context, controller, services);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0x1A1E88E5),
                  child: Icon(Icons.email, color: Color(0xFF1E88E5)),
                ),
                title: Text(
                  customerDetails?.email != null &&
                          customerDetails!.email!.isNotEmpty
                      ? '${'sales_order_details.opt_share_email'.tr} (${customerDetails.email})'
                      : 'sales_order_details.opt_share_email'.tr,
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await shareDetailViaEmail(context, controller, services);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0x1A25D366),
                  child: Icon(Icons.message, color: Color(0xFF25D366)),
                ),
                title: Text(
                  customerDetails?.phone != null &&
                          customerDetails!.phone!.isNotEmpty
                      ? '${'sales_order_details.opt_share_whatsapp'.tr} (${customerDetails.phone})'
                      : 'sales_order_details.opt_share_whatsapp'.tr,
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await shareDetailViaWhatsApp(context, controller, services);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
