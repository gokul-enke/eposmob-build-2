import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';

import 'daily_close_detail_inputs.dart';

class DayCloseDetailRow extends StatelessWidget {
  const DayCloseDetailRow(this.label, this.value,
      {super.key, required this.inputs, this.isHighlight = false});
  final DailyCloseDetailInputs inputs;
  final String label;
  final String value;
  final bool isHighlight;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 10),
        if (isHighlight)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ColorManager.kSuccessColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: const TextStyle(
                color: ColorManager.kSuccessColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          )
        else
          Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
      ],
    );
  }
}
