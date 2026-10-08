import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/responsive.dart';

import 'order_detail_inputs.dart';

class OrderDetailInfoRow extends StatelessWidget {
  const OrderDetailInfoRow(this.label, this.value,
      {super.key, required this.inputs});
  final OrderDetailInputs inputs;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveWidget.isMobile(context);

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label:',
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.18,
                ColorManager.blackWithOpacity50,
              ),
            ),
            const SizedBox(height: 2),
            Builder(
              builder: (context) {
                final currency = inputs.currency ?? 'INR';
                return SelectableText(
                  inputs.data.formatOrderPropertyValue(label, value, currency),
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s12,
                    0.18,
                    Colors.black,
                  ),
                );
              },
            ),
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
            width: 150, // Increased from 120 to prevent truncation
            child: Text(
              '$label:',
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s13,
                0.20,
                ColorManager.blackWithOpacity50,
              ),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                final currency = inputs.currency ?? 'INR';
                return SelectableText(
                  inputs.data.formatOrderPropertyValue(label, value, currency),
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s13,
                    0.20,
                    Colors.black,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
