import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/responsive.dart';

import 'order_detail_cart_items_table.dart';
import 'order_detail_customer_header.dart';
import 'order_detail_inputs.dart';

class OrderDetailOverview extends StatelessWidget {
  const OrderDetailOverview({super.key, required this.inputs});
  final OrderDetailInputs inputs;
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveWidget.isMobile(context);
    final currency = inputs.currency ?? "";
    final effectivePriceSummary = inputs.data.effectivePriceSummary()!;
    return BuildBoxShadowContainer(
      circleRadius: 7,
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      margin: EdgeInsets.only(
        top: isMobile ? 8.0 : 13.0,
        left: isMobile ? 0 : 8,
        right: isMobile ? 0 : 8,
      ),
      offsetValue: const Offset(1, 1),
      child: Column(
        children: [
          // Customer Details and Order Date
          OrderDetailCustomerHeader(inputs: inputs),
          // Cart Items - cards on mobile, table on desktop
          OrderDetailCartItemsTable(currency, inputs: inputs),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 14.0),
              child: Column(
                children: [
                  // Displaying Price Summary
                  BuildPaymentRow(
                    amount:
                        "$currency ${inputs.data.formatAmount(effectivePriceSummary.netTotal)}",
                    title: 'sales_order_details.label_net_total_inc_tax'.tr,
                    color: ColorManager.textColor,
                    firstRowTextStyle: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s14,
                      0.21,
                      ColorManager.textColor,
                    ),
                    secondRowTextStyle: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s14,
                      0.21,
                      ColorManager.textColor,
                    ),
                  ),
                  BuildPaymentRow(
                    amount:
                        "$currency ${inputs.data.formatAmount(effectivePriceSummary.netExcTax ?? inputs.data.orderDetailsModelData?.cart?.priceSummary?.netExcTax)}",
                    title: 'sales_order_details.label_net_total_exc_tax'.tr,
                    color: ColorManager.textColor,
                  ),
                  BuildPaymentRow(
                    amount:
                        "$currency ${inputs.data.formatAmount(effectivePriceSummary.discount)}",
                    title: 'sales_order_details.label_discount'.tr,
                    color: ColorManager.textColor,
                  ),
                  BuildPaymentRow(
                    amount:
                        "$currency ${inputs.data.formatAmount(effectivePriceSummary.totalTax)}",
                    title: (effectivePriceSummary.discount ?? 0) > 0
                        ? 'sales_order_details.label_tax_after_discount'.tr
                        : 'sales_order_details.label_tax_amount'.tr,
                    color: ColorManager.textColor,
                  ),
                  const Divider(thickness: 2),
                  BuildPaymentRow(
                    amount:
                        "$currency ${inputs.data.formatAmount(effectivePriceSummary.netPayable)}",
                    title: 'sales_order_details.label_payable'.tr,
                    secondRowTextStyle: buildCustomStyle(
                      FontWeightManager.bold,
                      FontSize.s15,
                      0.23,
                      ColorManager.kButtonGreen,
                    ),
                    firstRowTextStyle: buildCustomStyle(
                      FontWeightManager.bold,
                      FontSize.s15,
                      0.23,
                      ColorManager.kButtonGreen,
                    ),
                    color: ColorManager.kButtonGreen,
                  ),
                  BuildPaymentRow(
                    amount:
                        "$currency ${inputs.data.balanceAmount(effectivePriceSummary).toStringAsFixed(2)}",
                    title: 'sales_order_details.label_balance_amount'.tr,
                    secondRowTextStyle: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s12,
                      0.18,
                      ColorManager.textColorRed,
                    ),
                    firstRowTextStyle: buildCustomStyle(
                      FontWeightManager.bold,
                      FontSize.s15,
                      0.23,
                      ColorManager.textColorRed,
                    ),
                    color: ColorManager.textColorRed,
                  ),
                  const SizedBox(height: 5),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }
}
