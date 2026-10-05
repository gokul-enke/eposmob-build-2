import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'daily_close_list_inputs.dart';

class DailyCloseStatusChip extends StatelessWidget {
  const DailyCloseStatusChip(this.status, {super.key, required this.inputs});
  final DailyCloseListInputs inputs;
  final String status;
  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    String statusText;

    switch (status.toLowerCase()) {
      case 'closed':
      case 'completed':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green.shade700;
        break;
      case 'draft':
      case 'open':
      case 'pending':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange.shade800;
        break;
      default:
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green.shade700;
    }

    switch (status.toLowerCase()) {
      case 'draft':
        statusText = 'daily_sales_close.status_draft'.tr;
        break;
      case 'closed':
        statusText = 'daily_sales_close.status_closed'.tr;
        break;
      case 'open':
        statusText = 'daily_sales_close.status_open'.tr;
        break;
      case 'pending':
        statusText = 'daily_sales_close.status_pending'.tr;
        break;
      case 'completed':
        statusText = 'daily_sales_close.status_completed'.tr;
        break;
      default:
        statusText = UiCodeLabels.status(status);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
            decoration: BoxDecoration(color: textColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s9,
              0.18,
              textColor,
            ),
          ),
        ],
      ),
    );
  }
}
