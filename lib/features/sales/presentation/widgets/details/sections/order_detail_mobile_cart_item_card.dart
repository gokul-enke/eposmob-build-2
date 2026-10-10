import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/screens/print/receipt_line_discount.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'order_detail_inputs.dart';
import 'order_detail_mobile_detail_chip.dart';

class OrderDetailMobileCartItemCard extends StatelessWidget {
  const OrderDetailMobileCartItemCard(this.index, this.item, this.currency,
      {super.key, required this.inputs});
  final OrderDetailInputs inputs;
  final int index;
  final OrderDetailsModelDataCartItem item;
  final String currency;
  @override
  Widget build(BuildContext context) {
    final amounts = ReceiptLineDiscount.fromItem(item);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ColorManager.kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s11,
                    0.16,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName ?? 'sales_order_details.value_na'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s12,
                        0.18,
                        ColorManager.textColor,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.formattedVariantAttributes.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.formattedVariantAttributes,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s10,
                          0.16,
                          Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$currency ${inputs.data.fmt(amounts.discountedTotal)}',
                style: buildCustomStyle(
                  FontWeightManager.bold,
                  FontSize.s12,
                  0.18,
                  ColorManager.kPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OrderDetailMobileDetailChip('sales_order_details.th_qty'.tr,
              inputs.data.fmtQty(item.quantity),
              inputs: inputs),
          const SizedBox(height: 6),
          OrderDetailMobileDetailChip(
              'sales_order_details.th_unit'.tr, inputs.data.unitText(item),
              inputs: inputs),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OrderDetailMobileDetailChip(
                    'sales_order_details.th_mrp'.tr,
                    '$currency ${inputs.data.fmt(item.mrp)}',
                    inputs: inputs),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OrderDetailMobileDetailChip(
                    'sales_order_details.th_rate'.tr,
                    '$currency ${inputs.data.fmt(amounts.originalRate)}',
                    inputs: inputs),
              ),
            ],
          ),
          const SizedBox(height: 6),
          OrderDetailMobileDetailChip('sales_order_details.th_tax'.tr,
              '$currency ${inputs.data.fmt(item.discountedTaxAmount ?? item.taxAmount)}',
              inputs: inputs),
          if (amounts.totalDiscount > 0) ...[
            const SizedBox(height: 6),
            OrderDetailMobileDetailChip('billing.discount_label'.tr,
                '$currency ${inputs.data.fmt(amounts.totalDiscount)}',
                inputs: inputs),
          ],
        ],
      ),
    );
  }
}
