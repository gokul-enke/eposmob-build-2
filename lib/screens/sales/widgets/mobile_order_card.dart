import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart'
    hide
        showScaffold,
        showScaffoldError,
        showLoadingOverlay,
        hideLoadingOverlay;
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/list_sales_order.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:pos_machine/screens/sales/widgets/cancel_order_modal.dart';
import 'package:provider/provider.dart';

class MobileOrderCard extends StatelessWidget {
  final ListOrderModelData order;
  final int index;
  final Function(ListOrderModelData) onSharePDF;
  final Function(ListOrderModelData) onShareWhatsApp;

  const MobileOrderCard({
    super.key,
    required this.order,
    required this.index,
    required this.onSharePDF,
    required this.onShareWhatsApp,
  });

  bool _isDefaultCustomerPhone(BuildContext context, String? phone) {
    if (phone == null || phone.isEmpty) return false;
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final defaultPhone =
        appSettingsProvider.appSettings?.autoAssignDefaultCustomerPhone ?? "";
    return defaultPhone.isNotEmpty && phone == defaultPhone;
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return 'sales.status_new'.tr;
      case 'pending':
        return 'sales.status_pending'.tr;
      case 'confirmed':
        return 'sales.status_confirmed'.tr;
      case 'cancelled':
        return 'sales.status_cancelled'.tr;
      default:
        return status.toUpperCase();
    }
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'confirmed':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green.shade700;
        break;
      case 'pending':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange.shade800;
        break;
      case 'cancelled':
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red.shade700;
        break;
      case 'new':
        backgroundColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue.shade700;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.12);
        textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsetsDirectional.only(
          start: 10, end: 12, top: 5, bottom: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        icon: Icon(icon, size: 20, color: color),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed: onPressed,
      ),
    );
  }

  void _showOptionsSheet(BuildContext context) async {
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
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        ColorManager.kPrimaryColor.withOpacity(0.12),
                    child: const Icon(Icons.share,
                        color: ColorManager.kPrimaryColor),
                  ),
                  title: const Text('Share'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    _showShareOptions(context);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.red.withOpacity(0.12),
                    child:
                        const Icon(Icons.assignment_return, color: Colors.red),
                  ),
                  title: const Text('Return Order'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    _handleReturnOrder(context);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.red.withOpacity(0.12),
                    child: const Icon(Icons.cancel_outlined, color: Colors.red),
                  ),
                  title: const Text('Cancel Order'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      builder: (dialogCtx) => CancelOrderModal(
                        initialRefundAmount: order.priceSummary?.grandTotal ??
                            order.grantTotal ??
                            '',
                        onConfirm: (paymentMethodId, refundAmount,
                            deliveryChargeRefundable) async {
                          try {
                            final authModel =
                                Provider.of<AuthModel>(context, listen: false);
                            final salesProvider = Provider.of<SalesProvider>(
                                context,
                                listen: false);

                            await salesProvider.cancelOrder(
                              accessToken: authModel.token ?? "",
                              orderId: order.id.toString(),
                              paymentMethod: paymentMethodId,
                              refundAmount: refundAmount,
                              deliveryChargeRefundable:
                                  deliveryChargeRefundable,
                            );

                            if (context.mounted) {
                              showScaffold(
                                context: context,
                                message: "Order cancelled successfully",
                              );
                              salesProvider.fetchOrders(
                                accessToken: authModel.token ?? "",
                                page: salesProvider.currentPage,
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              showScaffoldError(
                                context: context,
                                message: "Failed to cancel order: $e",
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

  void _showShareOptions(BuildContext context) async {
    String? invoiceHash = order.invoiceHash;
    if (invoiceHash == null) {
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'Invoice not available for sharing.',
        );
      }
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Share Invoice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Share PDF'),
              onTap: () {
                Navigator.pop(context);
                onSharePDF(order);
              },
            ),
            ListTile(
              leading: Icon(Icons.message, color: Color(0xFF25D366)),
              title: const Text('WhatsApp Bot'),
              onTap: () {
                Navigator.pop(context);
                onShareWhatsApp(order);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleReturnOrder(BuildContext context) async {
    try {
      Provider.of<SalesProvider>(context, listen: false)
          .setOrderNumber(order.orderNumber.toString());
      Provider.of<SalesProvider>(context, listen: false)
          .setOrderId(order.id.toString());

      if (order.cartId != null) {
        Provider.of<CartProvider>(context, listen: false)
            .setCartIDForOrder(int.parse(order.cartId.toString()));
      }

      Get.find<SideBarController>().index.value = 49;

      if (context.mounted) {
        showScaffold(
          context: context,
          message: 'Preparing return for order #${order.orderNumber}',
        );
      }
    } catch (error) {
      debugPrint('Error preparing order return: $error');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'Error preparing order return. Please try again.',
        );
      }
    }
  }

  void _handlePrint(BuildContext context) async {
    try {
      String ordersId = order.orderNumber.toString();
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      final OrderDetailsresponse = await SalesProvider()
          .listOrderDetails(context, ordersId, accessToken ?? "");

      if (OrderDetailsresponse["status"] == "success") {
        OrderDetailsModel orderDetails =
            OrderDetailsModel.fromJson(OrderDetailsresponse);

        String? formattedTotal =
            orderDetails.data?.cart?.priceSummary?.netPayable?.toString() ??
                orderDetails.data?.cart?.priceSummary?.netTotal.toString();
        String? savedTotal =
            orderDetails.data?.cart?.priceSummary?.savedTotal.toString();

        String storeName = orderDetails.data!.cart!.storeName ?? "";
        String orderDate = orderDetails.data!.orderDate ?? "";

        String? customerName = orderDetails.data?.customerDetails?.name;
        String? customerPhone = orderDetails.data?.customerDetails?.phone;
        String? customerEmail = orderDetails.data?.customerDetails?.email;
        String? customerAddress =
            orderDetails.data?.getCustomerAddressForDisplay();
        String? customerAlternatePhone =
            orderDetails.data?.customerDetails?.alternatePhone;
        String? customerType = orderDetails.data?.customerDetails?.customerType;
        String? paymentMethod =
            orderDetails.data?.paymentDetails?.paymentMethod;

        String? orderComment;
        if (orderDetails.data?.orderProps != null) {
          try {
            final commentProp = orderDetails.data!.orderProps!.firstWhere(
              (prop) => prop.propsCode == "COMMENT",
              orElse: () => OrderDetailsModelDataOrderProp(),
            );
            orderComment = commentProp.propsValue;
          } catch (e) {
            debugPrint("Error extracting order comment: $e");
          }
        }

        double paidAmount = 0.0;
        if (orderDetails.data?.payments != null) {
          orderDetails.data!.payments!.forEach((key, value) {
            paidAmount += double.tryParse(value.toString()) ?? 0.0;
          });
        }

        double? customerCurrentBalance;
        if (orderDetails.data?.orderProps != null) {
          try {
            final balanceProp = orderDetails.data!.orderProps!.firstWhere(
              (prop) => prop.propsCode == "BALANCE",
              orElse: () => OrderDetailsModelDataOrderProp(),
            );
            if (balanceProp.propsValue != null) {
              customerCurrentBalance =
                  double.tryParse(balanceProp.propsValue.toString());
            }
          } catch (e) {
            debugPrint("Error extracting balance: $e");
          }
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PrintPage(
              storeName: storeName,
              cartItems: orderDetails.data?.cart?.cartItems ?? [],
              formattedTotal: formattedTotal!,
              savedTotal: savedTotal!,
              discountAmount:
                  orderDetails.data?.priceSummary?.discount?.toString() ??
                      "0.00",
              orderDate: DateHelper.formatInputToDisplay(orderDate),
              orderNumber: orderDetails.data!.orderNumber.toString(),
              customerName: customerName,
              customerPhone: customerPhone,
              customerEmail: customerEmail,
              customerAddress: customerAddress,
              customerAlternatePhone: customerAlternatePhone,
              customerType: customerType,
              customerVatNumber: orderDetails.data?.kycInfo?.vatNumber,
              customerCrNumber: orderDetails.data?.kycInfo?.crNumber,
              paymentMethod: paymentMethod,
              paymentBreakdown: orderDetails.data?.payments,
              orderComment: orderComment,
              orderReturns: orderDetails.data?.orderReturns,
              paidAmount: paidAmount > 0 ? paidAmount : null,
              customerCurrentBalance: customerCurrentBalance,
              netExcTax:
                  orderDetails.data?.cart?.priceSummary?.netExcTax?.toString(),
              isDefaultCustomer:
                  _isDefaultCustomerPhone(context, customerPhone),
              documentConfigType: orderDetails.data?.orderReturns != null &&
                      (orderDetails
                              .data?.orderReturns?.returnItems?.isNotEmpty ??
                          false)
                  ? 'Sales and Return Bill'
                  : 'Bill',
              apiTotalTax:
                  orderDetails.data?.priceSummary?.totalTax?.toDouble(),
            ),
          ),
        );
      }
    } catch (error) {
      debugPrint(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    PriceSummary priceSummary = order.priceSummary ?? PriceSummary();
    final customerLabel = (order.customerName?.isNotEmpty == true)
        ? order.customerName!
        : (order.customerDetails?.phone?.isNotEmpty == true
            ? order.customerDetails!.phone!
            : "NA");

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BuildBoxShadowContainer(
        circleRadius: 14,
        padding: const EdgeInsets.all(16),
        showShadow: true,
        blurRadius: 10,
        offsetValue: const Offset(0, 3),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
        color: Colors.white,
        child: InkWell(
          onTap: () {
            Provider.of<SalesProvider>(context, listen: false)
                .setOrderNumber(order.orderNumber ?? "0");
            Get.find<SideBarController>().index.value = 11;
          },
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            "#${order.orderNumber}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s16,
                              0.18,
                              ColorManager.kPrimaryColor,
                            ),
                          ),
                        ),
                        if (order.orderNumber != null &&
                            order.orderNumber!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: order.orderNumber!));
                              showScaffold(
                                context: context,
                                message: 'Order number copied to clipboard',
                              );
                            },
                            child: const Icon(
                              Icons.copy,
                              size: 14,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildStatusChip(order.status ?? "pending"),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      customerLabel,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.18,
                        Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            DateHelper.formatYearMonthDay(order.orderDate!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s11,
                              0.18,
                              Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_bag_outlined,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        "${order.cartItems?.length ?? 0} items",
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s11,
                          0.18,
                          Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Consumer<AppSettingsProvider>(
                      builder: (context, appSettingsProvider, child) {
                        final currency =
                            appSettingsProvider.appSettings?.currency ?? 'INR';
                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            // Keep the mobile amount consistent with the desktop
                            // table, which displays the order-level grand_total.
                            "$currency ${AmountHelper.formatAmount(order.grantTotal ?? priceSummary.grandTotal ?? 0.0)}",
                            maxLines: 1,
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s16,
                              0.18,
                              ColorManager.kPrimaryColor,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildActionButton(
                        icon: Icons.visibility,
                        color: ColorManager.kPrimaryColor,
                        onPressed: () {
                          Provider.of<SalesProvider>(context, listen: false)
                              .setOrderNumber(order.orderNumber ?? "0");
                          Get.find<SideBarController>().index.value = 11;
                        },
                      ),
                      _buildActionButton(
                        icon: Icons.print,
                        color: Colors.blue,
                        onPressed: () => _handlePrint(context),
                      ),
                      _buildActionButton(
                        icon: Icons.more_vert,
                        color: Colors.blue,
                        onPressed: () => _showOptionsSheet(context),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
