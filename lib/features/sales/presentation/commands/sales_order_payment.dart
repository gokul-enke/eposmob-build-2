import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/features/sales/presentation/widgets/actions/change_payment_status_modal.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';

import '../sharing/sales_page_services.dart';

Future<void> paymentSalesOrder(
    BuildContext context,
    BuildContext ctx,
    SalesPageServices services,
    ListOrderModelData order,
    Future<void> Function() refresh) async {
  Navigator.pop(ctx);
  if (!context.mounted) return;
  if (ChangePaymentStatusModal.blockIfPaid(context, order.paymentStatus)) {
    return;
  }
  showDialog(
    context: context,
    builder: (dialogCtx) => ChangePaymentStatusModal(
      currentPaymentStatus: order.paymentStatus ?? 'unpaid',
      grandTotal: order.grantTotal?.toString() ?? '0',
      paymentMethodCode: order.paymentMethods.firstOrNull,
      onConfirm: (newStatus, amount, paymentMethod) async {
        try {
          final authModel = services.auth;
          final salesProvider = services.sales;

          await salesProvider.changePaymentStatus(
            accessToken: authModel.token ?? "",
            orderId: order.id.toString(),
            status: newStatus,
            amount: amount,
            paymentMethod: paymentMethod,
          );

          if (context.mounted) {
            showScaffold(
              context: context,
              message: 'sales.payment_status_updated'
                  .tr
                  .replaceAll('@status', newStatus.toString()),
            );
            try {
              await refresh();
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
                fallback: 'sales.failed_update_payment_status'.tr,
              ),
            );
          }
        }
      },
    ),
  );
}
