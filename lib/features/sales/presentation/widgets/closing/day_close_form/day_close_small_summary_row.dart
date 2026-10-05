import 'dart:ui';

import 'package:flutter/material.dart';

import 'day_close_form_inputs.dart';
import 'day_close_small_summary_item.dart';

class DayCloseSmallSummaryRow extends StatelessWidget {
  const DayCloseSmallSummaryRow(
      this.label1, this.value1, this.label2, this.value2,
      {super.key, required this.inputs, this.color1, this.color2});
  final DayCloseFormInputs inputs;
  final String label1;
  final String value1;
  final String label2;
  final String value2;
  final Color? color1;
  final Color? color2;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        if (isNarrow) {
          return Column(
            children: [
              DayCloseSmallSummaryItem(label1, value1,
                  color: color1, inputs: inputs),
              const SizedBox(height: 10),
              DayCloseSmallSummaryItem(label2, value2,
                  color: color2, inputs: inputs),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: DayCloseSmallSummaryItem(label1, value1,
                  color: color1, inputs: inputs),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DayCloseSmallSummaryItem(label2, value2,
                  color: color2, inputs: inputs),
            ),
          ],
        );
      },
    );
  }
}
