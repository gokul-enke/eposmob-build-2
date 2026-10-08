import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'day_close_form_inputs.dart';

class DayCloseSummaryCard extends StatelessWidget {
  const DayCloseSummaryCard(this.label, this.value,
      {super.key, required this.inputs, this.color, this.icon});
  final DayCloseFormInputs inputs;
  final String label;
  final String value;
  final Color? color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s10,
                  0.18,
                  Colors.grey.shade500,
                ),
              ),
              if (icon != null)
                Icon(icon, size: 16, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: buildCustomStyle(
              FontWeightManager.bold,
              FontSize.s16,
              0.18,
              color ?? ColorManager.kTitleTextColor,
            ),
          ),
        ],
      ),
    );
  }
}
