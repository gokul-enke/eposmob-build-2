import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/features/sales_returns/presentation/navigation/sales_return_navigation.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';

import '../../sharing/sales_page_services.dart';

Future<void> returnMobileOrder(
    BuildContext context,
    ListOrderModelData order,
    SalesPageServices services,
    Function(ListOrderModelData) onSharePDF,
    Function(ListOrderModelData) onShareWhatsApp) async {
  try {
    services.sales.setOrderNumber(order.orderNumber.toString());
    services.sales.setOrderId(order.id.toString());

    if (order.cartId != null) {
      services.cart.setCartIDForOrder(int.parse(order.cartId.toString()));
    }

    SalesReturnNavigation.openCreate();

    if (context.mounted) {
      showScaffold(
        context: context,
        message: 'sales.preparing_return'.trParams({
          'number': '${order.orderNumber}',
        }),
      );
    }
  } catch (error) {
    debugPrint('Error preparing order return: $error');
    if (context.mounted) {
      showScaffoldError(
        context: context,
        message: 'sales.error_preparing_return'.tr,
      );
    }
  }
}
