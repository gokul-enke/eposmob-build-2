import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';

import 'daily_close_detail_inputs.dart';

class DayCloseActionButtons extends StatelessWidget {
  const DayCloseActionButtons(this.size, this.data,
      {super.key, required this.inputs});
  final DailyCloseDetailInputs inputs;
  final Size size;
  final DailySalesCloseData data;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          CustomRoundButton(
            title: "general.print".tr,
            boxColor: Colors.white,
            textColor: ColorManager.kPrimaryColor,
            fct: () {
              inputs.onPrint(data);
            },
            height: 50,
            width: size.width * 0.19,
            fontSize: FontSize.s12,
          ),
          CustomRoundButton(
            title: "daily_sales_close.export".tr,
            boxColor: ColorManager.kPrimaryColor,
            textColor: Colors.white,
            fct: () {
              inputs.onExport(data);
            },
            height: 50,
            width: size.width * 0.19,
            fontSize: FontSize.s12,
          ),
        ],
      ),
    );
  }
}
