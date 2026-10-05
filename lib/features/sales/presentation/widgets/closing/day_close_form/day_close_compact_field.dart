import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'day_close_form_inputs.dart';

class DayCloseCompactField extends StatelessWidget {
  const DayCloseCompactField(
      {super.key,
      required this.inputs,
      required this.label,
      required this.controller,
      required this.keyboardType,
      this.enabled = true,
      this.onChanged});
  final DayCloseFormInputs inputs;
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
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
        const SizedBox(height: 4),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 36,
          width: double.infinity,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            enabled: enabled,
            onChanged: onChanged,
            cursorColor: ColorManager.kPrimaryColor,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(
                  color: ColorManager.kPrimaryColor,
                  width: 2,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 8,
              ),
              hintText: '',
              hintStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s11,
                0.20,
                ColorManager.textColor.withOpacity(.5),
              ),
            ),
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s10,
              0.20,
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
