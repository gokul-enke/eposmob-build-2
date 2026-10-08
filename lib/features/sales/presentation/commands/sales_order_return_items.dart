import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/features/sales_returns/presentation/navigation/sales_return_navigation.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';

import '../sharing/sales_page_services.dart';

Future<void> returnItemsSalesOrder(
    BuildContext context,
    BuildContext ctx,
    SalesPageServices services,
    ListOrderModelData order,
    bool isOnlineSales) async {
  Navigator.pop(ctx);

  try {
    // Store order details in providers
    services.sales.setOrderNumber(order.orderNumber.toString());
    services.sales.setOrderId(order.id.toString());

    if (order.cartId != null) {
      services.cart.setCartIDForOrder(int.parse(order.cartId.toString()));
    }

    // Navigate to sales return page
    SalesReturnNavigation.openCreate();

    // Show success message
    if (context.mounted) {
      showScaffold(
        context: context,
        message: 'sales.preparing_return'
            .tr
            .replaceAll('@number', order.orderNumber.toString()),
      );
    }
  } catch (error) {
    if (context.mounted) {
      showScaffoldError(
        context: context,
        message: 'sales.err_preparing_return'.tr,
      );
    }
  }
}
