import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'day_close_form_inputs.dart';

class DayCloseTimePickerField extends StatelessWidget {
  const DayCloseTimePickerField(
      {super.key,
      required this.inputs,
      required this.label,
      required this.controller,
      this.readOnly = false});
  final DayCloseFormInputs inputs;
  final String label;
  final TextEditingController controller;
  final bool readOnly;
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
          child: readOnly
              ? TextFormField(
                  controller: controller,
                  enabled: false,
                  decoration: const InputDecoration(border: InputBorder.none),
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.27,
                    ColorManager.textColor.withOpacity(.5),
                  ),
                )
              : TimePickerTableCell(
                  initialTime:
                      inputs.controller.parseTimeOfDay(controller.text),
                  onTimeSelected: (picked) {
                    inputs.controller.update(() {
                      controller.text =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00';
                    });
                  },
                ),
        ),
      ],
    );
  }
}
