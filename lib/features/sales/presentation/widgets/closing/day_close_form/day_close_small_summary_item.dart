import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'day_close_form_inputs.dart';

class DayCloseSmallSummaryItem extends StatelessWidget {
  const DayCloseSmallSummaryItem(this.label, this.value,
      {super.key, required this.inputs, this.color});
  final DayCloseFormInputs inputs;
  final String label;
  final String value;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s10,
              0.18,
              Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s11,
              0.18,
              color ?? ColorManager.kPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
