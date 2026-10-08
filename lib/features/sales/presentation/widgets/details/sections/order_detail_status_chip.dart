import 'package:flutter/material.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';

import 'order_detail_inputs.dart';

class OrderDetailStatusChip extends StatelessWidget {
  const OrderDetailStatusChip(this.label, this.status,
      {super.key, required this.inputs});
  final OrderDetailInputs inputs;
  final String label;
  final String status;
  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'confirmed':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        break;
      case 'pending':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        break;
      case 'cancelled':
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        break;
      case 'paid':
        backgroundColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Text(
        '$label: ${UiCodeLabels.status(status)}',
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
