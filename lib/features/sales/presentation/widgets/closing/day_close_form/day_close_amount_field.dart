import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'day_close_form_inputs.dart';

class DayCloseAmountField extends StatelessWidget {
  const DayCloseAmountField(
      {super.key,
      required this.inputs,
      required this.label,
      required this.controller,
      this.enabled = true,
      this.onChanged});
  final DayCloseFormInputs inputs;
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onChanged;
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
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            onChanged: onChanged,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            cursorColor: ColorManager.kPrimaryColor,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '',
              hintStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.27,
                ColorManager.textColor.withOpacity(.5),
              ),
            ),
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              enabled
                  ? ColorManager.textColor
                  : ColorManager.textColor.withOpacity(.5),
            ),
          ),
        ),
      ],
    );
  }
}
