import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';

class SalesStatusChip extends StatelessWidget {
  const SalesStatusChip({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'confirmed':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green.shade700;
        break;
      case 'pending':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange.shade800;
        break;
      case 'cancelled':
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red.shade700;
        break;
      case 'new':
        backgroundColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue.shade700;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.12);
        textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsetsDirectional.only(
          start: 10, end: 12, top: 5, bottom: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return 'sales.status_new'.tr;
      case 'pending':
        return 'sales.status_pending'.tr;
      case 'confirmed':
        return 'sales.status_confirmed'.tr;
      case 'cancelled':
        return 'sales.status_cancelled'.tr;
      default:
        return UiCodeLabels.status(status);
    }
  }
}
