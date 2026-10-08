import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'open_shift_form_inputs.dart';

class OpenShiftDateField extends StatelessWidget {
  const OpenShiftDateField(
      {super.key,
      required this.inputs,
      required this.label,
      required this.controller});
  final OpenShiftFormInputs inputs;
  final String label;
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 6),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 12),
          height: 42,
          width: double.infinity,
          child: CalendarPickerTableCell(
            initialDate:
                inputs.controller.parseDate(controller.text) ?? DateTime.now(),
            onDateSelected: (picked) {
              inputs.controller.update(() {
                controller.text = DateFormat('yyyy-MM-dd').format(picked);
              });
            },
          ),
        ),
      ],
    );
  }
}
