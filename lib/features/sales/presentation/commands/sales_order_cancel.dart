import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/features/sales/presentation/widgets/actions/cancel_order_modal.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';

import '../sharing/sales_page_services.dart';

Future<void> cancelSalesOrder(
    BuildContext context,
    BuildContext ctx,
    SalesPageServices services,
    ListOrderModelData order,
    bool isOnlineSales) async {
  Navigator.pop(ctx);
  if (!context.mounted) return;
  showDialog(
    context: context,
    builder: (dialogCtx) => CancelOrderModal(
      isUnpaidCod: order.isUnpaidCod,
      initialRefundAmount:
          order.priceSummary?.grandTotal ?? order.grantTotal ?? '',
      onConfirm:
          (paymentMethodId, refundAmount, deliveryChargeRefundable) async {
        try {
          final authModel = services.auth;
          final salesProvider = services.sales;

          await salesProvider.cancelOrder(
            accessToken: authModel.token ?? "",
            orderId: order.id.toString(),
            paymentMethod: paymentMethodId,
            refundAmount: refundAmount,
            deliveryChargeRefundable: deliveryChargeRefundable,
          );

          if (context.mounted) {
            showScaffold(
              context: context,
              message: 'sales.order_cancelled_success'.tr,
            );
            // Refresh orders
            try {
              await salesProvider.fetchOrders(
                accessToken: authModel.token ?? "",
                page: salesProvider.currentPage,
                filterOnlineSales: isOnlineSales ? true : null,
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
                fallback: 'sales.failed_cancel_order'.tr,
              ),
            );
          }
        }
      },
    ),
  );
}
