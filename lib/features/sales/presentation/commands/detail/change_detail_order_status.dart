import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/sales/presentation/sharing/sales_page_services.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_order_detail_controller.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/features/sales/presentation/widgets/actions/change_order_status_modal.dart';

Future<void> changeDetailOrderStatus(BuildContext context,
    SalesOrderDetailController controller, SalesPageServices services) async {
  final orderDetailsModelData = controller.data;

  final priceSummary = controller.priceSummary;

  showDialog(
    context: context,
    builder: (dialogCtx) => ChangeOrderStatusModal(
      currentStatus: orderDetailsModelData?.orderStatus ?? 'pending',
      orderTotal: priceSummary?.netPayable?.toString() ?? '0',
      onConfirm: ({
        required newStatus,
        refundAmount,
        paymentMethod,
        deliveryChargeRefundable,
        deliveryLogistics,
      }) async {
        try {
          final authModel = services.auth;
          final salesProvider = services.sales;
          await salesProvider.changeOrderStatus(
            accessToken: authModel.token ?? '',
            orderId: orderDetailsModelData?.ordersId?.toString() ?? '',
            status: newStatus,
            refundAmount: refundAmount,
            paymentMethod: paymentMethod,
            deliveryChargeRefundable: deliveryChargeRefundable,
            deliveryLogistics: deliveryLogistics,
          );
          if (context.mounted) {
            showScaffold(
              context: context,
              message:
                  '${'sales_order_details.msg_status_updated'.tr} $newStatus',
            );
            controller.load();
          }
        } catch (e) {
          if (context.mounted) {
            showScaffoldError(
              context: context,
              message: SalesProvider.apiErrorMessage(
                e,
                fallback: 'sales_order_details.msg_failed_status'.tr,
              ),
            );
          }
        }
      },
    ),
  );
}
