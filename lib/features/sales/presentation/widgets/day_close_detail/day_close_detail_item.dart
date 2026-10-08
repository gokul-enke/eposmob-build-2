import 'package:flutter/material.dart';

import 'daily_close_detail_inputs.dart';

class DayCloseDetailItem extends StatelessWidget {
  const DayCloseDetailItem(this.label, this.value,
      {super.key,
      required this.inputs,
      this.valueColor,
      this.isValueBold = false});
  final DailyCloseDetailInputs inputs;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isValueBold;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.black87,
            fontSize: 14,
            fontWeight: isValueBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
