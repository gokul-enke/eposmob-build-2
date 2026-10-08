import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';

import 'daily_close_detail_inputs.dart';
import 'day_close_card.dart';
import 'day_close_detail_item.dart';

class DayCloseExpensesBreakdown extends StatelessWidget {
  const DayCloseExpensesBreakdown(this.data, {super.key, required this.inputs});
  final DailyCloseDetailInputs inputs;
  final DailySalesCloseData data;
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final currency = inputs.currency;
        return DayCloseCard(
            child: Row(
              children: [
                Expanded(
                  child: DayCloseDetailItem(
                      'daily_sales_close.cash_expenses'.tr,
                      '$currency ${data.cashExpenses ?? '0.00'}',
                      valueColor: Colors.red,
                      inputs: inputs),
                ),
                Expanded(
                  child: DayCloseDetailItem(
                      'daily_sales_close.bank_expenses'.tr,
                      '$currency ${data.bankExpenses ?? '0.00'}',
                      valueColor: Colors.red,
                      inputs: inputs),
                ),
                Expanded(
                  child: DayCloseDetailItem(
                      'daily_sales_close.total_expense'.tr,
                      '$currency ${data.totalExpenses ?? '0.00'}',
                      valueColor: Colors.red,
                      isValueBold: true,
                      inputs: inputs),
                ),
              ],
            ),
            inputs: inputs);
      },
    );
  }
}
