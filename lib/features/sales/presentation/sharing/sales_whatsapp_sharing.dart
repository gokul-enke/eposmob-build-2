import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/resources/app_url.dart';

import 'sales_page_services.dart';
import 'sales_whatsapp_pdf.dart';

Future<void> shareSalesWhatsapp(BuildContext context,
    SalesPageServices services, ListOrderModelData order) async {
  try {
    final whatsappProvider = services.whatsapp;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    // Check WhatsApp connection
    if (!whatsappProvider.isWhatsAppAvailable()) {
      Navigator.of(context, rootNavigator: true).pop();

      // Show connection dialog
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              Text('sales.wa_not_connected_title'.tr),
            ],
          ),
          content: Text(
            '${'sales.wa_not_connected_body'.tr}\n\n'
            '${'sales.wa_status_label'.tr} ${whatsappProvider.connectionStatus}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('general.cancel'.tr),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Navigate to WhatsApp settings
                Get.find<SideBarController>().index.value =
                    63; // Adjust this index to your WhatsApp settings page
              },
              child: Text('sales.btn_connect_wa'.tr),
            ),
          ],
        ),
      );
      return;
    }

    // Fetch order details
    final String ordersId = order.orderNumber.toString();
    final String? accessToken = services.auth.token;
    final OrderDetailsresponse = await services.sales
        .listOrderDetails(context, ordersId, accessToken ?? "");
    if (!context.mounted) return;

    if (OrderDetailsresponse["status"] != "success") {
      Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'sales.unable_fetch_order_details'.tr,
        );
      }
      return;
    }

    final OrderDetailsModel details =
        OrderDetailsModel.fromJson(OrderDetailsresponse);
    final orderData = details.data;

    if (orderData?.customerDetails?.phone == null ||
        orderData!.customerDetails!.phone!.isEmpty) {
      Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'sales.customer_phone_not_available'.tr,
        );
      }
      return;
    }

    // Prepare customer info
    final customerPhone = orderData.customerDetails!.phone!;
    final customerName = orderData.customerDetails?.name ?? 'Valued Customer';
    final totalAmount = orderData.priceSummary?.netPayable?.toString() ??
        orderData.priceSummary?.netTotal?.toString() ??
        order.grantTotal ??
        '0.00';
    final currency = services.settings.appSettings?.currency ?? 'INR';

    // Create invoice URL if available
    String? invoiceUrl;
    if (order.invoiceHash != null) {
      invoiceUrl = '${APPUrl.baseURL}/invoice-download/${order.invoiceHash}';
    }

    // Close loading dialog
    Navigator.of(context, rootNavigator: true).pop();

    // Show options dialog
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.message, color: Color(0xFF25D366)),
            const SizedBox(width: 8),
            Text('sales.title_send_wa_bot'.tr),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${'sales.label_customer'.tr} $customerName'),
            Text('${'sales.label_phone_wa'.tr} $customerPhone'),
            Text('${'sales.label_order'.tr} #${order.orderNumber}'),
            Text('${'sales.label_amount'.tr} $currency $totalAmount'),
            const SizedBox(height: 16),
            Text(
              'sales.label_choose_what'.tr,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('general.cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              if (!context.mounted) return;

              // Send invoice message with URL
              final success = await whatsappProvider.sendInvoiceMessage(
                phoneNumber: customerPhone,
                orderNumber: order.orderNumber.toString(),
                customerName: customerName,
                totalAmount: '$currency $totalAmount',
                invoiceUrl: invoiceUrl,
              );
              if (!context.mounted) return;

              if (context.mounted) {
                if (success) {
                  showScaffold(
                    context: context,
                    message: 'sales.invoice_sent_whatsapp'
                        .tr
                        .replaceAll('@phone', customerPhone),
                  );
                } else {
                  showScaffoldError(
                    context: context,
                    message: 'sales.failed_send_whatsapp'
                        .tr
                        .replaceAll('@error', whatsappProvider.lastError),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
            child: Text('sales.btn_send_invoice_link'.tr),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await sendSalesWhatsappPdf(
                  context, services, order, whatsappProvider);
              if (!context.mounted) return;
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text('sales.btn_send_with_pdf'.tr),
          ),
        ],
      ),
    );
  } catch (e) {
    // Close loading dialog if still showing
    if (!context.mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (context.mounted) {
      showScaffoldError(
        context: context,
        message: 'sales.err_sending_whatsapp'.tr,
      );
    }
  }
}
