import 'package:flutter/material.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'daily_close_detail_inputs.dart';

class DayCloseSectionHeader extends StatelessWidget {
  const DayCloseSectionHeader(this.title, this.icon,
      {super.key, required this.inputs});
  final DailyCloseDetailInputs inputs;
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          title,
          style: buildCustomStyle(
            FontWeightManager.bold,
            FontSize.s16,
            0.18,
            Colors.black87,
          ),
        ),
      ],
    );
  }
}
