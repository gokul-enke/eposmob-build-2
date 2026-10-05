import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'day_close_form_inputs.dart';

class DayCloseDenominationDropdown extends StatelessWidget {
  const DayCloseDenominationDropdown(
      {super.key,
      required this.inputs,
      required this.controller,
      required this.allDenominationControllers,
      required this.index,
      this.isReadOnly = false,
      this.onChanged});
  final DayCloseFormInputs inputs;
  final TextEditingController controller;
  final List<TextEditingController> allDenominationControllers;
  final int index;
  final bool isReadOnly;
  final ValueChanged<String?>? onChanged;
  @override
  Widget build(BuildContext context) {
    final currentValue =
        controller.text.trim().isEmpty ? null : controller.text.trim();
    final hasMatch =
        inputs.controller.cashDenominations.any((d) => d.value == currentValue);
    final selectedValue = hasMatch ? currentValue : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'daily_sales_close.denomination'.tr,
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
          child: inputs.controller.isLoadingDenominations
              ? const Center(
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    isDense: true,
                    value: selectedValue,
                    disabledHint: selectedValue != null
                        ? Text(
                            inputs.controller.cashDenominations
                                .firstWhere(
                                  (d) => d.value == selectedValue,
                                  orElse: () => MasterDataValue(
                                    id: 0,
                                    value: selectedValue,
                                    description: selectedValue,
                                  ),
                                )
                                .description,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s10,
                              0.20,
                              ColorManager.textColor.withOpacity(.5),
                            ),
                          )
                        : null,
                    hint: Text(
                      'daily_sales_close.select'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s10,
                        0.20,
                        ColorManager.textColor.withOpacity(.5),
                      ),
                    ),
                    items: inputs.controller.cashDenominations
                        .where((d) {
                          // Get all currently selected denominations
                          // except the current row's own selection
                          final selectedOthers = allDenominationControllers
                              .asMap()
                              .entries
                              .where((e) => e.key != index)
                              .map((e) => e.value.text.trim())
                              .toSet();
                          // Allow this denomination if not selected
                          // in any other row, or if it's empty
                          return !selectedOthers.contains(d.value);
                        })
                        .map(
                          (d) => DropdownMenuItem<String>(
                            value: d.value,
                            child: Text(
                              d.description.isNotEmpty
                                  ? d.description
                                  : d.value,
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s10,
                                0.20,
                                isReadOnly
                                    ? ColorManager.textColor.withOpacity(.5)
                                    : ColorManager.textColor,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: isReadOnly
                        ? null
                        : (value) {
                            inputs.controller.update(() {
                              controller.text = value ?? '';
                            });
                            if (onChanged != null) {
                              onChanged!(value);
                            }
                          },
                  ),
                ),
        ),
      ],
    );
  }
}
