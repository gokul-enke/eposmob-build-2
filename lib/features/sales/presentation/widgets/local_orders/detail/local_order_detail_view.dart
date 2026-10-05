import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

import 'local_order_detail_info_row.dart';
import 'local_order_detail_inputs.dart';
import 'local_order_items_table.dart';
import 'local_order_payment_info.dart';
import 'local_order_sync_notice.dart';

class LocalOrderDetailView extends StatelessWidget {
  const LocalOrderDetailView({super.key, required this.inputs});
  final LocalOrderDetailInputs inputs;
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final currency = inputs.currency;
        final syncRecord = inputs.record;
        final canDelete =
            syncRecord == null || syncRecord.state == LocalSaleSyncState.synced;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 8,
          backgroundColor: Colors.white,
          child: Container(
            constraints: BoxConstraints(
                maxWidth: 700,
                maxHeight: MediaQuery.of(context).size.height * 0.8),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with close button (Fixed at top)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "kitchen.order_details".tr,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () => inputs.onClose(),
                    ),
                  ],
                ),
                if (syncRecord != null &&
                    syncRecord.state != LocalSaleSyncState.synced) ...[
                  const SizedBox(height: 12),
                  LocalOrderSyncNotice(syncRecord, inputs: inputs),
                ],
                const SizedBox(height: 18),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Order Information Card
                        Card(
                          elevation: 2,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "confirmed_orders.order_info".tr,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                LocalOrderDetailInfoRow(
                                    "sales.order_number_hint".tr,
                                    "#${order.orderNumber}",
                                    inputs: inputs),
                                const SizedBox(height: 8),
                                LocalOrderDetailInfoRow(
                                    "confirmed_orders.customer_phone".tr,
                                    order.customerPhone ??
                                        "confirmed_orders.na".tr,
                                    inputs: inputs),
                                const SizedBox(height: 8),
                                if (order.customerName != null &&
                                    order.customerName!.isNotEmpty) ...[
                                  LocalOrderDetailInfoRow(
                                      "sales.customer_name_hint".tr,
                                      order.customerName!,
                                      inputs: inputs),
                                  const SizedBox(height: 8),
                                ],
                                LocalOrderDetailInfoRow("sales.date_col".tr,
                                    _formatDateTime(order.createdAt),
                                    inputs: inputs),
                                const SizedBox(height: 8),
                                LocalOrderDetailInfoRow(
                                    "confirmed_orders.time".tr,
                                    _formatTime(order.createdAt),
                                    inputs: inputs),
                                const SizedBox(height: 8),
                                LocalOrderDetailInfoRow(
                                    "confirmed_orders.total_amount".tr,
                                    "$currency${order.total.toStringAsFixed(2)}",
                                    inputs: inputs),
                                const SizedBox(height: 8),
                                LocalOrderDetailInfoRow(
                                    "confirmed_orders.total_mrp".tr,
                                    "$currency${_calculateTotalMRP().toStringAsFixed(2)}",
                                    inputs: inputs),
                                const SizedBox(height: 8),
                                LocalOrderDetailInfoRow(
                                    "confirmed_orders.you_saved".tr,
                                    "$currency${_calculateYouSaved().toStringAsFixed(2)}",
                                    valueStyle: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    inputs: inputs),
                                // Display additional order details
                                if (order.deliveryMethod != null &&
                                    order.deliveryMethod!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  LocalOrderDetailInfoRow(
                                      "confirmed_orders.delivery_method".tr,
                                      order.deliveryMethod!,
                                      inputs: inputs),
                                ],
                                if (order.transactionId != null &&
                                    order.transactionId!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  LocalOrderDetailInfoRow(
                                      "confirmed_orders.transaction_id".tr,
                                      order.transactionId!,
                                      inputs: inputs),
                                ],
                                if (order.balanceAmount != null &&
                                    order.balanceAmount != "0.0" &&
                                    order.balanceAmount!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  LocalOrderDetailInfoRow(
                                      "confirmed_orders.balance_amount".tr,
                                      "$currency${order.balanceAmount}",
                                      valueStyle: const TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      inputs: inputs),
                                ],
                                if (order.carNumber != null &&
                                    order.carNumber!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  LocalOrderDetailInfoRow(
                                      "confirmed_orders.car_number".tr,
                                      order.carNumber!,
                                      valueStyle: const TextStyle(
                                        color: Colors.purple,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      inputs: inputs),
                                ],
                                if (order.status != null &&
                                    order.status!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  LocalOrderDetailInfoRow(
                                      "confirmed_orders.order_status".tr,
                                      UiCodeLabels.status(order.status),
                                      valueStyle: TextStyle(
                                        color: order.status!.toLowerCase() ==
                                                'confirmed'
                                            ? Colors.green
                                            : order.status!.toLowerCase() ==
                                                    'saved'
                                                ? Colors.orange
                                                : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      inputs: inputs),
                                ],
                                // Display Discount Information
                                if ((order.flatDiscount != null &&
                                        order.flatDiscount! > 0) ||
                                    (order.percentageDiscount != null &&
                                        order.percentageDiscount! > 0)) ...[
                                  const SizedBox(height: 8),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Text(
                                    "confirmed_orders.applied_discounts".tr,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (order.flatDiscount != null &&
                                      order.flatDiscount! > 0)
                                    LocalOrderDetailInfoRow(
                                        "confirmed_orders.flat_discount".tr,
                                        "$currency${order.flatDiscount!.toStringAsFixed(2)}",
                                        valueStyle: const TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        inputs: inputs),
                                  if (order.percentageDiscount != null &&
                                      order.percentageDiscount! > 0) ...[
                                    const SizedBox(height: 4),
                                    LocalOrderDetailInfoRow(
                                        "confirmed_orders.percentage_discount"
                                            .tr,
                                        "${order.percentageDiscount!.toStringAsFixed(1)}%",
                                        valueStyle: const TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        inputs: inputs),
                                  ],
                                  if (order.couponId != null &&
                                      order.couponId!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    LocalOrderDetailInfoRow(
                                        "confirmed_orders.coupon_code".tr,
                                        order.couponId!,
                                        valueStyle: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        inputs: inputs),
                                  ],
                                ],
                                // Display Payment Method(s)
                                if (order.paymentMethod != null) ...[
                                  const SizedBox(height: 8),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  LocalOrderPaymentInfo(
                                      order.paymentMethod!, currency,
                                      inputs: inputs),
                                ],
                                if (order.deliveryDate != null &&
                                    order.deliveryDate!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  LocalOrderDetailInfoRow(
                                      "confirmed_orders.delivery_date".tr,
                                      DateHelper.formatToISODateOnlyFromISO(
                                          order.deliveryDate!),
                                      inputs: inputs),
                                ],
                                if (order.deliveryTime != null &&
                                    order.deliveryTime!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  LocalOrderDetailInfoRow(
                                      "confirmed_orders.delivery_time".tr,
                                      order.deliveryTime!,
                                      inputs: inputs),
                                ],
                                if (order.comment != null &&
                                    order.comment!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  LocalOrderDetailInfoRow(
                                      "confirmed_orders.comment".tr,
                                      order.comment!,
                                      inputs: inputs),
                                ],
                                if (order.toCustomerCredit == true) ...[
                                  const SizedBox(height: 8),
                                  LocalOrderDetailInfoRow(
                                      "confirmed_orders.credit_applied".tr,
                                      "confirmed_orders.yes".tr,
                                      valueStyle: const TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      inputs: inputs),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Order Items Section
                        Text(
                          "confirmed_orders.order_items".tr,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Table with order items (now scrolls with everything else)
                        LocalOrderItemsTable(inputs: inputs),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Action Buttons (Fixed at bottom)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CustomRoundButton(
                      fct: () => inputs.onPrint(),
                      title: "confirmed_orders.print_order".tr,
                      fontSize: FontSize.s12,
                      height: MediaQuery.of(context).size.height * .05,
                      width: 120,
                      boxColor: ColorManager.kPrimaryColor,
                      textColor: Colors.white,
                    ),
                    Row(
                      children: [
                        if (canDelete)
                          CustomRoundButton(
                            fct: () => inputs.onDelete(),
                            title: "confirmed_orders.delete".tr,
                            fontSize: FontSize.s12,
                            height: MediaQuery.of(context).size.height * .05,
                            width: 80,
                            boxColor: ColorManager.kButtonRed,
                            borderColor: ColorManager.kButtonRed,
                            textColor: Colors.white,
                          ),
                        const SizedBox(width: 12),
                        CustomRoundButton(
                          fct: () => inputs.onClose(),
                          title: "confirmed_orders.close".tr,
                          fontSize: FontSize.s12,
                          height: MediaQuery.of(context).size.height * .05,
                          width: 80,
                          boxColor: Colors.grey[300],
                          textColor: Colors.black,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  SavedOrder get order => inputs.order;
  double _calculateTotalMRP() {
    double totalMRP = 0.0;
    for (var item in order.items) {
      final mrp = item.mrp ?? item.product.mrp ?? 0.0;
      totalMRP += mrp * item.quantity;
    }
    return totalMRP;
  }

  double _calculateYouSaved() {
    double totalMRP = _calculateTotalMRP();
    double netTotal = 0.0;
    for (var item in order.items) {
      final price = item.price ?? item.product.price?.price ?? 0.0;
      netTotal += price * item.quantity;
    }
    double youSaved = totalMRP - netTotal;
    return youSaved > 0 ? youSaved : 0.0;
  }

  static String _formatDateTime(String isoDateString) {
    return DateHelper.formatToISODateOnlyFromISO(isoDateString);
  }

  static String _formatTime(String isoDateString) {
    return DateHelper.formatToISODateFromIST(isoDateString);
  }
}
