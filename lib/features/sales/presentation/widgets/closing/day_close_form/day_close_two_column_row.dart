import 'package:flutter/material.dart';

import 'day_close_form_inputs.dart';

class DayCloseTwoColumnRow extends StatelessWidget {
  const DayCloseTwoColumnRow(
      {super.key,
      required this.inputs,
      required this.isNarrow,
      required this.left,
      required this.right});
  final DayCloseFormInputs inputs;
  final bool isNarrow;
  final Widget left;
  final Widget right;
  @override
  Widget build(BuildContext context) {
    if (isNarrow) {
      return Column(children: [left, const SizedBox(height: 12), right]);
    }
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}
