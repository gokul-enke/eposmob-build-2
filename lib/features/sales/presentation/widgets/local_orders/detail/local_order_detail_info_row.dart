import 'package:flutter/material.dart';

import 'local_order_detail_inputs.dart';

/// A label on the left and its value aligned right, like a receipt line.
class LocalOrderDetailInfoRow extends StatelessWidget {
  const LocalOrderDetailInfoRow(this.label, this.value,
      {super.key, required this.inputs, this.valueStyle});
  final LocalOrderDetailInputs inputs;
  final String label;
  final String value;
  final TextStyle? valueStyle;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ).merge(valueStyle),
            ),
          ),
        ],
      ),
    );
  }
}
