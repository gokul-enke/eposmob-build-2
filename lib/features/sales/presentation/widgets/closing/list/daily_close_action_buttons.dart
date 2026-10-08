import 'package:flutter/material.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';
import 'package:pos_machine/resources/color_manager.dart';

import 'daily_close_list_inputs.dart';

class DailyCloseActionButtons extends StatelessWidget {
  const DailyCloseActionButtons(this.data, {super.key, required this.inputs});
  final DailyCloseListInputs inputs;
  final DailySalesCloseData data;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(
            Icons.visibility,
            size: 18,
            color: ColorManager.kPrimaryColor,
          ),
          onPressed: () {
            inputs.onView(data);
          },
        ),
      ],
    );
  }
}
