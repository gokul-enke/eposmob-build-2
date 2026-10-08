import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/responsive.dart';

import 'order_detail_inputs.dart';

class OrderDetailTappableRow extends StatelessWidget {
  const OrderDetailTappableRow(this.label, this.value, this.onTap,
      {super.key, required this.inputs});
  final OrderDetailInputs inputs;
  final String label;
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveWidget.isMobile(context);
    final labelStyle = buildCustomStyle(
      FontWeightManager.medium,
      isMobile ? FontSize.s12 : FontSize.s13,
      isMobile ? 0.18 : 0.20,
      ColorManager.blackWithOpacity50,
    );
    final linkStyle = buildCustomStyle(
      FontWeightManager.medium,
      isMobile ? FontSize.s12 : FontSize.s13,
      isMobile ? 0.18 : 0.20,
      ColorManager.kPrimaryColor,
    );

    final link = InkWell(
      onTap: onTap,
      child: Text(
        value,
        style: linkStyle.copyWith(decoration: TextDecoration.underline),
      ),
    );

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label:', style: labelStyle),
            const SizedBox(height: 2),
            link,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text('$label:', style: labelStyle),
          ),
          Expanded(child: Align(alignment: Alignment.centerLeft, child: link)),
        ],
      ),
    );
  }
}
