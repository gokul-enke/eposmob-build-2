import 'package:flutter/material.dart';
import 'package:pos_machine/newcomponents/custom_container_box.dart';

import 'daily_close_detail_inputs.dart';

class DayCloseCard extends StatelessWidget {
  const DayCloseCard({super.key, required this.inputs, required this.child});
  final DailyCloseDetailInputs inputs;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return CustomBoxShadowContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      circleRadius: 12,
      border: Border.all(color: Colors.grey.shade200),
      child: child,
    );
  }
}
