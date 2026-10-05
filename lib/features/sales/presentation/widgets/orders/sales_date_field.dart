import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import '../../state/sales_list_controller.dart';

class SalesDateField extends StatelessWidget {
  const SalesDateField(
      {super.key,
      required this.controller,
      required this.label,
      required this.controllerField,
      required this.isFromDate,
      required this.onPickDate});
  final SalesListController controller;
  final String label;
  final TextEditingController controllerField;
  final bool isFromDate;
  final ValueChanged<bool> onPickDate;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.27,
              Colors.black.withOpacity(0.6),
            ),
          ),
        ),
        BuildBoxShadowContainer(
          height: 45,
          width: double.infinity,
          circleRadius: 7,
          child: TextFormField(
            controller: controllerField,
            onTap: () => onPickDate(isFromDate),
            readOnly: true,
            cursorColor: ColorManager.kPrimaryColor,
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                0.18, ColorManager.textColor),
            decoration: InputDecoration(
              hintText: 'general.datetime_format_hint'.tr,
              hintStyle: buildCustomStyle(FontWeightManager.medium,
                  FontSize.s10, 0.18, ColorManager.textColor.withOpacity(.5)),
              prefixIcon: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: ColorManager.kPrimaryColor,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
      ],
    );
  }
}
