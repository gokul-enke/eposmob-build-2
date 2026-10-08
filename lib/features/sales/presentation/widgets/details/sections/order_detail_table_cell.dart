import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'order_detail_inputs.dart';

class OrderDetailTableCell extends StatelessWidget {
  const OrderDetailTableCell(this.text,
      {super.key,
      required this.inputs,
      this.isHeader = false,
      this.align = TextAlign.left});
  final OrderDetailInputs inputs;
  final String text;
  final bool isHeader;
  final TextAlign align;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: isHeader ? 12.0 : 10.0,
      ),
      child: Text(
        text,
        textAlign: align,
        style: buildCustomStyle(
          isHeader ? FontWeightManager.semiBold : FontWeightManager.regular,
          isHeader ? FontSize.s12 : FontSize.s11,
          0.18,
          isHeader ? ColorManager.textColor : Colors.black87,
        ),
      ),
    );
  }
}
