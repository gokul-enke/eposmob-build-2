import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'day_close_form_inputs.dart';

class DayCloseConfirmSummaryRow extends StatelessWidget {
  const DayCloseConfirmSummaryRow(this.label, this.value,
      {super.key, required this.inputs});
  final DayCloseFormInputs inputs;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s11,
            0.18,
            Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s13,
            0.18,
            ColorManager.kTitleTextColor,
          ),
        ),
      ],
    );
  }
}
