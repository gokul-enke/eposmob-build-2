import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';

import 'daily_close_detail_inputs.dart';
import 'day_close_card.dart';
import 'day_close_detail_item.dart';
import 'day_close_detail_row.dart';

class DayCloseClosingPeriodDetails extends StatelessWidget {
  const DayCloseClosingPeriodDetails(this.data,
      {super.key, required this.inputs});
  final DailyCloseDetailInputs inputs;
  final DailySalesCloseData data;
  @override
  Widget build(BuildContext context) {
    return DayCloseCard(
        child: Column(
          children: [
            DayCloseDetailRow(
                'daily_sales_close.closing'.tr, data.closingPeriod ?? '-',
                isHighlight: true, inputs: inputs),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DayCloseDetailItem(
                      'daily_sales_close.sales_executive'.tr,
                      data.salesExecutive?.name ?? '-',
                      inputs: inputs),
                ),
                Expanded(
                  child: DayCloseDetailItem(
                      'daily_sales_close.store'.tr, data.store?.name ?? '-',
                      inputs: inputs),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DayCloseDetailItem('daily_sales_close.phone'.tr,
                      data.salesExecutive?.phone ?? '-',
                      inputs: inputs),
                ),
                const Expanded(child: SizedBox()), // Spacer
              ],
            ),
          ],
        ),
        inputs: inputs);
  }
}
