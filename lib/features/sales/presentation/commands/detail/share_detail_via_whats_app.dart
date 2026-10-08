import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/features/sales/presentation/sharing/sales_page_services.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_order_detail_controller.dart';
import 'package:pos_machine/resources/app_url.dart';

Future<void> shareDetailViaWhatsApp(BuildContext context,
    SalesOrderDetailController controller, SalesPageServices services) async {
  final orderDetailsModelData = controller.data;
  final customerDetails = controller.customer;

  final orderNumber = controller.orderNumber;

  try {
    final whatsappProvider = services.whatsapp;

    if (!whatsappProvider.isWhatsAppAvailable()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              Text('sales_order_details.title_wa_not_connected'.tr),
            ],
          ),
          content: Text(
            '${'sales_order_details.msg_wa_not_connected'.tr}\n\n'
            '${'sales_order_details.label_wa_status'.tr} ${whatsappProvider.connectionStatus}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('general.cancel'.tr),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                Get.find<SideBarController>().index.value = 63;
              },
              child: Text('sales_order_details.btn_connect_whatsapp'.tr),
            ),
          ],
        ),
      );
      return;
    }

    if (customerDetails?.phone == null || customerDetails!.phone!.isEmpty) {
      showScaffoldError(
        context: context,
        message: 'sales_order_details.msg_no_phone'.tr,
      );
      return;
    }

    final customerPhone = customerDetails.phone!;
    final customerName =
        customerDetails.name ?? 'sales_order_details.label_default_customer'.tr;
    final totalAmount =
        orderDetailsModelData?.priceSummary?.netPayable?.toString() ??
            orderDetailsModelData?.priceSummary?.netTotal?.toString() ??
            '0.00';
    final currency = services.settings.appSettings?.currency ?? 'INR';

    final success = await whatsappProvider.sendInvoiceMessage(
      phoneNumber: customerPhone,
      orderNumber: orderNumber,
      customerName: customerName,
      totalAmount: '$currency $totalAmount',
      invoiceUrl: '${APPUrl.baseURL}/invoice/$orderNumber',
    );

    if (context.mounted) {
      if (success) {
        showScaffold(
          context: context,
          message:
              '${'sales_order_details.msg_invoice_sent_wa'.tr} $customerPhone',
        );
      } else {
        showScaffoldError(
          context: context,
          message:
              '${'sales_order_details.msg_wa_send_failed'.tr} ${whatsappProvider.lastError}',
        );
      }
    }
  } catch (e) {
    debugPrint('Error in WhatsApp sharing: $e');
    if (context.mounted) {
      showScaffoldError(
        context: context,
        message: 'sales_order_details.msg_wa_error'.tr,
      );
    }
  }
}
