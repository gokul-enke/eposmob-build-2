import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'open_shift_form_inputs.dart';

class OpenShiftDisabledStoreField extends StatelessWidget {
  const OpenShiftDisabledStoreField({super.key, required this.inputs});
  final OpenShiftFormInputs inputs;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'daily_sales_close.store'.tr,
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
            initialValue: inputs.controller.selectedStoreName ?? '-',
            enabled: false,
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              ColorManager.textColor.withOpacity(.5),
            ),
          ),
        ),
      ],
    );
  }
}
