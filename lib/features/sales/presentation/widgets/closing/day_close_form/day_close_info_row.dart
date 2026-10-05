import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'day_close_form_inputs.dart';

class DayCloseInfoRow extends StatelessWidget {
  const DayCloseInfoRow(this.icon, this.label, this.value,
      {super.key, required this.inputs});
  final DayCloseFormInputs inputs;
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        Text(
          '$label:',
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s11,
            0.18,
            Colors.grey.shade700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s11,
              0.18,
              ColorManager.kTitleTextColor,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
