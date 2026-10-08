import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/responsive.dart';

import 'order_detail_inputs.dart';
import 'order_detail_status_chip.dart';

class OrderDetailStatusChips extends StatelessWidget {
  const OrderDetailStatusChips({super.key, required this.inputs});
  final OrderDetailInputs inputs;
  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      OrderDetailStatusChip('sales_order_details.title_order_status'.tr,
          inputs.data.orderDetailsModelData?.orderStatus ?? '',
          inputs: inputs),
      if (inputs.data.orderDetailsModelData?.paymentStatus != null)
        OrderDetailStatusChip('sales_order_details.btn_payment_status'.tr,
            inputs.data.orderDetailsModelData?.paymentStatus ?? '',
            inputs: inputs),
      if (inputs.data.orderDetailsModelData?.deliveryStatus != null)
        OrderDetailStatusChip(
            'sales_order_details.label_delivery_job_status'.tr,
            inputs.data.orderDetailsModelData?.deliveryStatus ?? '',
            inputs: inputs),
    ];

    if (ResponsiveWidget.isMobile(context)) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips,
      );
    }

    return Row(
      children: [
        for (int i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          chips[i],
        ],
      ],
    );
  }
}
