import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';
import 'package:pos_machine/resources/color_manager.dart';

import 'daily_close_detail_inputs.dart';
import 'day_close_card.dart';
import 'day_close_detail_item.dart';

class DayCloseKeyFields extends StatelessWidget {
  const DayCloseKeyFields(this.data, {super.key, required this.inputs});
  final DailyCloseDetailInputs inputs;
  final DailySalesCloseData data;
  @override
  Widget build(BuildContext context) {
    return DayCloseCard(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DayCloseDetailItem(
                      'daily_sales_close.shift_name'.tr, data.shiftName ?? '-',
                      inputs: inputs),
                ),
                Expanded(
                  child: DayCloseDetailItem(
                      'daily_sales_close.business_date'.tr,
                      data.businessDate ?? '-',
                      inputs: inputs),
                ),
                Expanded(
                  child: DayCloseDetailItem(
                      'daily_sales_close.credit_collected'.tr,
                      data.totalCreditCollected ?? '0.00',
                      valueColor: ColorManager.kSuccessColor,
                      isValueBold: true,
                      inputs: inputs),
                ),
              ],
            ),
          ],
        ),
        inputs: inputs);
  }
}
