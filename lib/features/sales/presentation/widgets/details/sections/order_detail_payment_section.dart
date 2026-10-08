import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/payment_method_display.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'order_detail_actions.dart';
import 'order_detail_info_row.dart';
import 'order_detail_inputs.dart';
import 'order_detail_section_card.dart';

class OrderDetailPaymentSection extends StatelessWidget {
  const OrderDetailPaymentSection({super.key, required this.inputs});
  final OrderDetailInputs inputs;
  @override
  Widget build(BuildContext context) {
    final currency = inputs.currency ?? '';
    return OrderDetailSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'sales_order_details.title_payment_details'.tr,
              style: orderDetailSectionTitleStyle(context),
            ),
            const SizedBox(height: 8),
            if (inputs.data.orderDetailsModelData?.paymentDetails
                    ?.paymentMethod !=
                null)
              OrderDetailInfoRow(
                  'sales_order_details.label_payment_method'.tr,
                  PaymentMethodDisplay.labelForCodeList(inputs.data
                      .orderDetailsModelData?.paymentDetails?.paymentMethod),
                  inputs: inputs),
            if (inputs.data.orderDetailsModelData?.paymentDetails
                    ?.transactionId !=
                null)
              OrderDetailInfoRow(
                  'sales_order_details.label_transaction_id'.tr,
                  inputs.data.orderDetailsModelData?.paymentDetails
                          ?.transactionId
                          ?.toString() ??
                      '',
                  inputs: inputs),
            if (inputs.data.orderDetailsModelData?.paymentDetails?.paymentId !=
                null)
              OrderDetailInfoRow(
                  'sales_order_details.label_payment_id'.tr,
                  inputs.data.orderDetailsModelData?.paymentDetails
                          ?.paymentId ??
                      '',
                  inputs: inputs),

            // Add payment breakdown
            if (inputs.data.orderDetailsModelData?.payments != null &&
                (inputs.data.orderDetailsModelData?.payments?.isNotEmpty ??
                    false)) ...[
              const SizedBox(height: 8),
              Text(
                "${'sales_order_details.label_payment_breakdown'.tr}:",
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.18,
                  ColorManager.textColor,
                ),
              ),
              const SizedBox(height: 4),
              ...(inputs.data.orderDetailsModelData?.payments?.entries
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  // The map key is the stable
                                  // payment code, kept as-is in
                                  // the data and localized only
                                  // for display.
                                  PaymentMethodDisplay.labelFor(entry.key),
                                  style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s11,
                                    0.16,
                                    ColorManager.textColor,
                                  ),
                                ),
                              ),
                              Text(
                                '$currency ${entry.value}',
                                style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s11,
                                  0.16,
                                  ColorManager.kPrimaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList() ??
                  []),

              // Add total payment amount
              if ((inputs.data.orderDetailsModelData?.payments?.isNotEmpty ??
                  false)) ...[
                const Divider(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${'sales_order_details.label_total_paid'.tr}:",
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s12,
                        0.18,
                        ColorManager.textColor,
                      ),
                    ),
                    Text(
                      '$currency ${inputs.data.calculateTotalPayments(inputs.data.orderDetailsModelData?.payments ?? {})}',
                      style: buildCustomStyle(
                        FontWeightManager.bold,
                        FontSize.s12,
                        0.18,
                        ColorManager.kPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
        inputs: inputs);
  }
}
