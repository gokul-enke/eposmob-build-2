import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'daily_close_list_inputs.dart';

class DailyCloseTableCell extends StatelessWidget {
  const DailyCloseTableCell(this.text, {super.key, required this.inputs});
  final DailyCloseListInputs inputs;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s9,
          0.18,
          Colors.black,
        ),
      ),
    );
  }
}
