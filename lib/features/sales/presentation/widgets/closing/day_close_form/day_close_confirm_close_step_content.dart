import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/payment_method_display.dart';
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
    final online = inputs.controller.onlineSales;
    final onlineMethods = inputs.controller.onlineBreakdown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('daily_sales_close.cash_summary'.tr),
        const SizedBox(height: 12),
        _card([
          DayCloseConfirmSummaryRow(
              'daily_sales_close.expected_closing_cash'.tr,
              '$currency ${AmountHelper.formatAmount(expected)}',
              inputs: inputs),
          const SizedBox(height: 10),
          DayCloseConfirmSummaryRow(
              'daily_sales_close.today_cash_collection'.tr,
              '$currency ${AmountHelper.formatAmount(todayCollection)}',
              inputs: inputs),
        ]),
        // Non-cash payments (card, UPI, online), as in the Day Close step.
        const SizedBox(height: 20),
        _title('daily_sales_close.online_summary'.tr),
        const SizedBox(height: 12),
        _card([
          DayCloseConfirmSummaryRow('daily_sales_close.online_sales'.tr,
              '$currency ${AmountHelper.formatAmount(online)}',
              inputs: inputs),
          // Each method behind the total, indented under it.
          for (final method in onlineMethods.entries) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 16),
              child: DayCloseConfirmSummaryRow(_methodLabel(method.key),
                  '$currency ${AmountHelper.formatAmount(method.value)}',
                  inputs: inputs),
            ),
          ],
        ]),
      ],
    );
  }

  /// The method's name. Codes the shared helper leaves as the raw code
  /// (ONLINE, BANK) fall back to the billing names the Day Close details use.
  String _methodLabel(String code) {
    final label = PaymentMethodDisplay.labelFor(code);
    if (label.trim().toLowerCase() != code.trim().toLowerCase()) return label;
    final key = 'billing.payment_method_labels.${code.trim().toLowerCase()}';
    final bundled = key.tr;
    return bundled == key ? label : bundled;
  }

  Widget _title(String text) => Text(
        text,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s12,
          0.21,
          Colors.grey.shade800,
        ),
      );

  Widget _card(List<Widget> rows) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(children: rows),
      );
}
