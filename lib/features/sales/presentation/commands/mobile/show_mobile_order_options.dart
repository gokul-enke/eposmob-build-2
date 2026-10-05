import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/features/sales/presentation/widgets/actions/cancel_order_modal.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/resources/color_manager.dart';

import '../../sharing/sales_page_services.dart';
import 'return_mobile_order.dart';
import 'show_mobile_order_share_options.dart';

Future<void> showMobileOrderOptions(
    BuildContext context,
    ListOrderModelData order,
    SalesPageServices services,
    Function(ListOrderModelData) onSharePDF,
    Function(ListOrderModelData) onShareWhatsApp) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Order #${order.orderNumber}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: ColorManager.kPrimaryColor.withOpacity(0.12),
                  child: const Icon(Icons.share,
                      color: ColorManager.kPrimaryColor),
                ),
                title: Text('mobile_order_card.opt_share'.tr),
                onTap: () async {
                  Navigator.pop(ctx);
                  showMobileOrderShareOptions(
                      context, order, services, onSharePDF, onShareWhatsApp);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.red.withOpacity(0.12),
                  child: const Icon(Icons.assignment_return, color: Colors.red),
                ),
                title: Text('mobile_order_card.opt_return'.tr),
                onTap: () async {
                  Navigator.pop(ctx);
                  returnMobileOrder(
                      context, order, services, onSharePDF, onShareWhatsApp);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.red.withOpacity(0.12),
                  child: const Icon(Icons.cancel_outlined, color: Colors.red),
                ),
                title: Text('mobile_order_card.opt_cancel'.tr),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (!context.mounted) return;
                  showDialog(
                    context: context,
                    builder: (dialogCtx) => CancelOrderModal(
                      isUnpaidCod: order.isUnpaidCod,
                      initialRefundAmount: order.priceSummary?.grandTotal ??
                          order.grantTotal ??
                          '',
                      onConfirm: (paymentMethodId, refundAmount,
                          deliveryChargeRefundable) async {
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
                                fallback: 'sales.failed_cancel_order'.tr,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
