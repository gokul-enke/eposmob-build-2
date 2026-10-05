import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'day_close_confirm_summary_row.dart';
import 'day_close_form_inputs.dart';

class DayCloseConfirmCloseStepContent extends StatelessWidget {
  const DayCloseConfirmCloseStepContent(this.currency,
      {super.key, required this.inputs});
  final DayCloseFormInputs inputs;
  final String currency;
  @override
  Widget build(BuildContext context) {
    final expected = inputs.controller.expectedClosingCash;
    final todayCollection = inputs.controller.todayCashCollection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'daily_sales_close.cash_summary'.tr,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.21,
            Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              DayCloseConfirmSummaryRow(
                  'daily_sales_close.expected_closing_cash'.tr,
                  '$currency ${expected.toStringAsFixed(2)}',
                  inputs: inputs),
              const SizedBox(height: 10),
              DayCloseConfirmSummaryRow(
                  'daily_sales_close.today_cash_collection'.tr,
                  '$currency ${todayCollection.toStringAsFixed(2)}',
                  inputs: inputs),
            ],
          ),
        ),
      ],
    );
  }
}
