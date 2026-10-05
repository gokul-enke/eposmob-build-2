import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/features/sales/presentation/widgets/actions/change_order_status_modal.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';

import '../sharing/sales_page_services.dart';

Future<void> statusSalesOrder(
    BuildContext context,
    BuildContext ctx,
    SalesPageServices services,
    ListOrderModelData order,
    bool isOnlineSales) async {
  Navigator.pop(ctx);
  showDialog(
    context: context,
    builder: (dialogCtx) => ChangeOrderStatusModal(
      currentStatus: order.status ?? 'pending',
      orderTotal: order.grantTotal?.toString() ?? '0',
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
            accessToken: authModel.token ?? "",
            orderId: order.id.toString(),
            status: newStatus,
            refundAmount: refundAmount,
            paymentMethod: paymentMethod,
            deliveryChargeRefundable: deliveryChargeRefundable,
            deliveryLogistics: deliveryLogistics,
          );

          if (context.mounted) {
            showScaffold(
              context: context,
              message: 'sales.order_status_updated'
                  .tr
                  .replaceAll('@status', newStatus.toString()),
            );
            try {
              await salesProvider.fetchOrders(
                accessToken: authModel.token ?? "",
                page: salesProvider.currentPage,
              );
            } catch (refreshError) {
              if (context.mounted) {
                showScaffoldError(
                  context: context,
                  message: SalesProvider.apiErrorMessage(
                    refreshError,
                    fallback: 'sales.orders_load_failed'.tr,
                  ),
                );
              }
            }
          }
        } catch (e) {
          if (context.mounted) {
            showScaffoldError(
              context: context,
              message: SalesProvider.apiErrorMessage(
                e,
                fallback: 'sales.failed_update_order_status'.tr,
              ),
            );
          }
        }
      },
    ),
  );
}
