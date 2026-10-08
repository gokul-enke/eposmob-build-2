import 'package:flutter/material.dart';

import 'order_detail_actions.dart';
import 'order_detail_inputs.dart';

class OrderDetailFulfillmentSectionHeader extends StatelessWidget {
  const OrderDetailFulfillmentSectionHeader(
      {super.key, required this.inputs, required this.title, this.action});
  final OrderDetailInputs inputs;
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: orderDetailSectionTitleStyle(context)),
        ),
        if (action != null) action!,
      ],
    );
  }
}
