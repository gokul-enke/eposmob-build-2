import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/sales/presentation/sharing/sales_page_services.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_order_detail_controller.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> shareDetailViaEmail(BuildContext context,
    SalesOrderDetailController controller, SalesPageServices services) async {
  final orderDetailsModelData = controller.data;
  final customerDetails = controller.customer;

  final orderNumber = controller.orderNumber;

  final invoiceUrl = orderDetailsModelData?.orderNumber != null
      ? '${APPUrl.baseURL}/invoice/${orderDetailsModelData!.orderNumber}'
      : null;

  if (invoiceUrl == null) {
    showScaffoldError(
      context: context,
      message: 'sales_order_details.msg_no_invoice_url'.tr,
    );
    return;
  }

  final message =
      'sales_order_details.msg_email_body'.trParams({'invoiceUrl': invoiceUrl});
  final uri = Uri(
    scheme: 'mailto',
    path: customerDetails?.email ?? '',
    queryParameters: <String, String>{
      'subject': 'sales_order_details.msg_email_subject'
          .trParams({'orderNumber': orderNumber}),
      'body': message,
    },
  );

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    if (context.mounted) {
      showScaffoldError(
        context: context,
        message: 'sales_order_details.msg_no_email_app'.tr,
      );
    }
  }
}
