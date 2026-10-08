import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'order_detail_inputs.dart';

class OrderDetailMobileDetailChip extends StatelessWidget {
  const OrderDetailMobileDetailChip(this.label, this.value,
      {super.key, required this.inputs});
  final OrderDetailInputs inputs;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s11,
            0.16,
            ColorManager.blackWithOpacity50,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s11,
              0.16,
              Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
