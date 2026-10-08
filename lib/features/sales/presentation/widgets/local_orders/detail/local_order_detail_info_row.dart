import 'package:flutter/material.dart';

import 'local_order_detail_inputs.dart';

class LocalOrderDetailInfoRow extends StatelessWidget {
  const LocalOrderDetailInfoRow(this.label, this.value,
      {super.key, required this.inputs, this.valueStyle});
  final LocalOrderDetailInputs inputs;
  final String label;
  final String value;
  final TextStyle? valueStyle;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            "$label:",
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: valueStyle ??
                const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}
