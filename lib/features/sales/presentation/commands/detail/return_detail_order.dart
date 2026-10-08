import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/sales/presentation/sharing/sales_page_services.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_order_detail_controller.dart';
import 'package:pos_machine/features/sales_returns/presentation/navigation/sales_return_navigation.dart';

Future<void> returnDetailOrder(BuildContext context,
    SalesOrderDetailController controller, SalesPageServices services) async {
  final orderDetailsModelData = controller.data;

  final cart = controller.cart;

  final orderNo = orderDetailsModelData?.orderNumber;
  if (orderNo == null || orderNo.isEmpty) {
    showScaffoldError(
      context: context,
      message: 'sales_order_details.msg_no_order_number'.tr,
    );
    return;
  }

  try {
    services.sales.setOrderNumber(orderNo);

    final ordersId = orderDetailsModelData?.ordersId;
    if (ordersId != null) {
      services.sales.setOrderId(ordersId.toString());
    }

    final cartId = cart?.id;
    if (cartId != null) {
      services.cart.setCartIDForOrder(cartId);
    }

    SalesReturnNavigation.openCreate();

    if (context.mounted) {
      showScaffold(
        context: context,
        message: '${'sales_order_details.msg_preparing_return'.tr} #$orderNo',
      );
    }
  } catch (e) {
    debugPrint('Error preparing order return: $e');
    if (context.mounted) {
      showScaffoldError(
        context: context,
        message: 'sales_order_details.msg_error_return'.tr,
      );
    }
  }
}
