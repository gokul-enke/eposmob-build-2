import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';

import '../../sharing/sales_page_services.dart';

Future<void> showMobileOrderShareOptions(
    BuildContext context,
    ListOrderModelData order,
    SalesPageServices services,
    Function(ListOrderModelData) onSharePDF,
    Function(ListOrderModelData) onShareWhatsApp) async {
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

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text('mobile_order_card.opt_share_invoice'.tr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: Text('mobile_order_card.opt_share_pdf'.tr),
            onTap: () {
              Navigator.pop(context);
              onSharePDF(order);
            },
          ),
          ListTile(
            leading: Icon(Icons.message, color: Color(0xFF25D366)),
            title: Text('mobile_order_card.opt_whatsapp_bot'.tr),
            onTap: () {
              Navigator.pop(context);
              onShareWhatsApp(order);
            },
          ),
        ],
      ),
    ),
  );
}
