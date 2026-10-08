import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';
import 'package:pos_machine/resources/color_manager.dart';

import 'daily_close_detail_inputs.dart';
import 'day_close_card.dart';
import 'day_close_detail_item.dart';

class DayCloseCashSummary extends StatelessWidget {
  const DayCloseCashSummary(this.cashSummary,
      {super.key, required this.inputs});
  final DailyCloseDetailInputs inputs;
  final CashSummary cashSummary;
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final currency = inputs.currency;
        return DayCloseCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DayCloseDetailItem(
                          'daily_sales_close.sales_count'.tr,
                          cashSummary.totalSalesCount?.toString() ?? '0',
                          isValueBold: true,
                          inputs: inputs),
                    ),
                    Expanded(
                      child: DayCloseDetailItem(
                          'daily_sales_close.sales_amount'.tr,
                          '$currency ${cashSummary.totalSalesAmount ?? '0.00'}',
                          isValueBold: true,
                          inputs: inputs),
                    ),
                    Expanded(
                      child: DayCloseDetailItem(
                          'daily_sales_close.cash_collected'.tr,
                          '$currency ${cashSummary.cashCollected ?? '0.00'}',
                          inputs: inputs),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: DayCloseDetailItem(
                          'daily_sales_close.online_collected'.tr,
                          '$currency ${cashSummary.onlineCollected ?? '0.00'}',
                          inputs: inputs),
                    ),
                    Expanded(
                      child: DayCloseDetailItem(
                          'daily_sales_close.credit_amount'.tr,
                          '$currency ${cashSummary.creditAmount ?? '0.00'}',
                          inputs: inputs),
                    ),
                    Expanded(
                      child: DayCloseDetailItem(
                          'daily_sales_close.previous_balance_collected'.tr,
                          '$currency ${cashSummary.previousBalanceCollected ?? '0.00'}',
                          inputs: inputs),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: DayCloseDetailItem(
                          'daily_sales_close.cash_refunds'.tr,
                          '$currency ${cashSummary.cashRefunds ?? '0.00'}',
                          valueColor: Colors.red,
                          inputs: inputs),
                    ),
                    Expanded(
                      child: DayCloseDetailItem(
                          'daily_sales_close.cash_expenses'.tr,
                          '$currency ${cashSummary.cashExpenses ?? '0.00'}',
                          valueColor: Colors.red,
                          inputs: inputs),
                    ),
                    Expanded(
                      child: DayCloseDetailItem(
                          'daily_sales_close.cash_drop_amount'.tr,
                          '$currency ${cashSummary.cashDropAmount ?? '0.00'}',
                          inputs: inputs),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: DayCloseDetailItem(
                          'daily_sales_close.opening_cash_in_hand'.tr,
                          '$currency ${cashSummary.openingCashInHand ?? '0.00'}',
                          inputs: inputs),
                    ),
                    Expanded(
                      child: DayCloseDetailItem(
                          'daily_sales_close.expected_closing_cash'.tr,
                          '$currency ${cashSummary.expectedClosingCash ?? '0.00'}',
                          inputs: inputs),
                    ),
                    Expanded(
                      child: DayCloseDetailItem(
                          'daily_sales_close.today_cash_collection'.tr,
                          '$currency ${cashSummary.todayCashCollection ?? '0.00'}',
                          inputs: inputs),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: DayCloseDetailItem(
                          'daily_sales_close.closing_cash_in_hand'.tr,
                          '$currency ${cashSummary.closingCashInHand ?? '0.00'}',
                          inputs: inputs),
                    ),
                    Expanded(
                      child: DayCloseDetailItem(
                          'daily_sales_close.short_cash'.tr,
                          '$currency ${cashSummary.shortCash ?? '0.00'}',
                          valueColor: Colors.red,
                          inputs: inputs),
                    ),
                    Expanded(
                      child: DayCloseDetailItem(
                          'daily_sales_close.excess_cash'.tr,
                          '$currency ${cashSummary.excessCash ?? '0.00'}',
                          valueColor: ColorManager.kSuccessColor,
                          inputs: inputs),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: DayCloseDetailItem('daily_sales_close.notes'.tr,
                          cashSummary.notes ?? '-',
                          inputs: inputs),
                    ),
                    const Expanded(child: SizedBox.shrink()),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              ],
            ),
            inputs: inputs);
      },
    );
  }
}
