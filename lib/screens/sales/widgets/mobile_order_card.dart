import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
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

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'confirmed':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        break;
      case 'pending':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        break;
      case 'cancelled':
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        break;
      case 'new':
        backgroundColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: ColorManager.kPrimaryColor.withOpacity(0.12),
                    child: const Icon(Icons.share, color: ColorManager.kPrimaryColor),
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
                    child: const Icon(Icons.assignment_return, color: Colors.red),
                  ),
                  title: const Text('Return Order'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    _handleReturnOrder(context);
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
      String? accessToken = Provider.of<AuthModel>(context, listen: false).token;

      final OrderDetailsresponse = await SalesProvider()
          .listOrderDetails(context, ordersId, accessToken ?? "");

      if (OrderDetailsresponse["status"] == "success") {
        OrderDetailsModel orderDetails =
            OrderDetailsModel.fromJson(OrderDetailsresponse);

        String? formattedTotal = orderDetails.data?.cart?.priceSummary?.netPayable
                ?.toString() ??
            orderDetails.data?.cart?.priceSummary?.netTotal.toString();
        String? savedTotal =
            orderDetails.data?.cart?.priceSummary?.savedTotal.toString();

        String storeName = orderDetails.data!.cart!.storeName ?? "";
        String orderDate = orderDetails.data!.orderDate ?? "";

        String? customerName = orderDetails.data?.customerDetails?.name;
        String? customerPhone = orderDetails.data?.customerDetails?.phone;
        String? customerEmail = orderDetails.data?.customerDetails?.email;
        String? customerAddress =
            orderDetails.data?.customerDetails?.address?.join(', ');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PrintPage(
              storeName: storeName,
              cartItems: orderDetails.data?.cart?.cartItems ?? [],
              formattedTotal: formattedTotal!,
              savedTotal: savedTotal!,
              discountAmount:
                  orderDetails.data?.priceSummary?.discount?.toString() ?? "0.00",
              orderDate: orderDate,
              orderNumber: orderDetails.data!.orderNumber.toString(),
              customerName: customerName,
              customerPhone: customerPhone,
              customerEmail: customerEmail,
              customerAddress: customerAddress,
              orderReturns: orderDetails.data?.orderReturns,
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Provider.of<SalesProvider>(context, listen: false)
              .setOrderNumber(order.orderNumber ?? "0");
          Get.find<SideBarController>().index.value = 11;
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with order number and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "#${order.orderNumber}",
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s16,
                        0.18,
                        ColorManager.kPrimaryColor,
                      ),
                    ),
                  ),
                  _buildStatusChip(order.status ?? "pending"),
                ],
              ),
              const SizedBox(height: 12),

              // Customer info
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (order.customerName?.isNotEmpty == true)
                          ? order.customerName!
                          : (order.customerDetails?.phone?.isNotEmpty == true
                              ? order.customerDetails!.phone!
                              : "NA"),
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

              // Date and items
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          DateHelper.formatYearMonthDay(order.orderDate!),
                          style: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s11,
                            0.18,
                            Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined,
                          size: 16, color: Colors.grey),
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

              // Amount and actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Consumer<AppSettingsProvider>(
                    builder: (context, appSettingsProvider, child) {
                      final currency =
                          appSettingsProvider.appSettings?.currency ?? 'INR';
                      return Text(
                        "$currency ${AmountHelper.formatAmount(priceSummary.grandTotal ?? 0.0)}",
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s16,
                          0.18,
                          ColorManager.kPrimaryColor,
                        ),
                      );
                    },
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility,
                            size: 20, color: ColorManager.kPrimaryColor),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Provider.of<SalesProvider>(context, listen: false)
                              .setOrderNumber(order.orderNumber ?? "0");
                          Get.find<SideBarController>().index.value = 11;
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.print, size: 20, color: Colors.blue),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _handlePrint(context),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.more_vert,
                            size: 20, color: Colors.blue),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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
