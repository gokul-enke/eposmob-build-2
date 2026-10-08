import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';

import 'daily_close_detail_inputs.dart';
import 'day_close_breakdown_card.dart';

class DayCloseCashBreakdownSection extends StatelessWidget {
  const DayCloseCashBreakdownSection(this.cashSummary,
      {super.key, required this.inputs});
  final DailyCloseDetailInputs inputs;
  final CashSummary cashSummary;
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final currency = inputs.currency;
        return Column(
          children: [
            DayCloseBreakdownCard(
                title: 'daily_sales_close.opening_cash_breakdown'.tr,
                subtitle: 'daily_sales_close.saved_denomination_details'.tr,
                rows: cashSummary.openingCashBreakdown,
                currency: currency,
                inputs: inputs),
            const SizedBox(height: 14),
            DayCloseBreakdownCard(
                title: 'daily_sales_close.closing_cash_breakdown'.tr,
                subtitle: 'daily_sales_close.saved_denomination_details'.tr,
                rows: cashSummary.closingCashBreakdown,
                currency: currency,
                inputs: inputs),
          ],
        );
      },
    );
  }
}
