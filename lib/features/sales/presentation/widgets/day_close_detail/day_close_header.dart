import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/newcomponents/custom_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';

import 'daily_close_detail_inputs.dart';

class DayCloseHeader extends StatelessWidget {
  const DayCloseHeader({super.key, required this.inputs});
  final DailyCloseDetailInputs inputs;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CustomBackButton(
          onPressed: () {
            inputs.onBack();
          },
          text: 'daily_sales_close.back_to_list'.tr,
        ),
        CustomBoxShadowContainer(
          width: 30,
          height: 30,
          circleRadius: 15,
          color: ColorManager.kPrimaryColor,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              inputs.onBack();
            },
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
