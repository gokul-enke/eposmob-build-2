import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/sales/presentation/sharing/sales_page_services.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_order_detail_controller.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/features/sales/presentation/widgets/actions/change_payment_status_modal.dart';

Future<void> changeDetailPaymentStatus(BuildContext context,
    SalesOrderDetailController controller, SalesPageServices services) async {
  final orderDetailsModelData = controller.data;

  final priceSummary = controller.priceSummary;

  showDialog(
    context: context,
    builder: (dialogCtx) => ChangePaymentStatusModal(
      currentPaymentStatus: orderDetailsModelData?.paymentStatus ?? 'unpaid',
      grandTotal: priceSummary?.netPayable?.toString() ?? '0',
      onConfirm: (newStatus, amount) async {
        try {
          final authModel = services.auth;
          final salesProvider = services.sales;
          await salesProvider.changePaymentStatus(
            accessToken: authModel.token ?? '',
            orderId: orderDetailsModelData?.ordersId?.toString() ?? '',
            status: newStatus,
            amount: amount,
          );
          if (context.mounted) {
            showScaffold(
              context: context,
              message:
                  '${'sales_order_details.msg_payment_updated'.tr} $newStatus',
            );
            controller.load();
          }
        } catch (e) {
          if (context.mounted) {
            showScaffoldError(
              context: context,
              message: SalesProvider.apiErrorMessage(
                e,
                fallback: 'sales_order_details.msg_failed_payment'.tr,
              ),
            );
          }
        }
      },
    ),
  );
}
