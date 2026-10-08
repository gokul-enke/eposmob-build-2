import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'open_shift_form_inputs.dart';

class OpenShiftTextAreaField extends StatelessWidget {
  const OpenShiftTextAreaField(
      {super.key,
      required this.inputs,
      required this.label,
      required this.controller,
      this.maxLines = 3});
  final OpenShiftFormInputs inputs;
  final String label;
  final TextEditingController controller;
  final int maxLines;
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
          padding: const EdgeInsets.only(left: 12, top: 6, right: 10),
          height: maxLines > 1 ? 92 : 42,
          width: double.infinity,
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
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
