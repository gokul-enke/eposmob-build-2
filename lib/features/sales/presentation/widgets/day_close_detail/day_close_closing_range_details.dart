import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';

import 'daily_close_detail_inputs.dart';
import 'day_close_card.dart';
import 'day_close_detail_item.dart';

class DayCloseClosingRangeDetails extends StatelessWidget {
  const DayCloseClosingRangeDetails(this.data,
      {super.key, required this.inputs});
  final DailyCloseDetailInputs inputs;
  final DailySalesCloseData data;
  @override
  Widget build(BuildContext context) {
    return DayCloseCard(
        child: Row(
          children: [
            Expanded(
              child: DayCloseDetailItem(
                  'daily_sales_close.opening_date'.tr, data.openingDate ?? '-',
                  inputs: inputs),
            ),
            Expanded(
              child: DayCloseDetailItem(
                  'daily_sales_close.opening_time'.tr, data.openingTime ?? '-',
                  inputs: inputs),
            ),
            Expanded(
              child: DayCloseDetailItem(
                  'daily_sales_close.closing_date'.tr, data.closingDate ?? '-',
                  inputs: inputs),
            ),
            Expanded(
              child: DayCloseDetailItem(
                  'daily_sales_close.closing_time'.tr, data.closingTime ?? '-',
                  inputs: inputs),
            ),
          ],
        ),
        inputs: inputs);
  }
}
