import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'open_shift_form_inputs.dart';

class OpenShiftCompactField extends StatelessWidget {
  const OpenShiftCompactField(
      {super.key,
      required this.inputs,
      required this.label,
      required this.controller,
      required this.keyboardType,
      this.onChanged});
  final OpenShiftFormInputs inputs;
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
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
            onChanged: onChanged,
            cursorColor: ColorManager.kPrimaryColor,
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              ColorManager.textColor,
            ),
          ),
        ),
      ],
    );
  }
}
