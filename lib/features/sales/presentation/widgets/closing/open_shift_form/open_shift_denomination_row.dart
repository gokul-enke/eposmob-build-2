import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'open_shift_compact_field.dart';
import 'open_shift_denomination_dropdown.dart';
import 'open_shift_form_inputs.dart';

class OpenShiftDenominationRow extends StatelessWidget {
  const OpenShiftDenominationRow(
      {super.key,
      required this.inputs,
      required this.denominationController,
      required this.countController,
      required this.isNarrow,
      required this.allDenominationControllers,
      required this.index});
  final OpenShiftFormInputs inputs;
  final TextEditingController denominationController;
  final TextEditingController countController;
  final bool isNarrow;
  final List<TextEditingController> allDenominationControllers;
  final int index;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isNarrow
            ? Column(
                children: [
                  OpenShiftDenominationDropdown(
                      controller: denominationController,
                      allDenominationControllers: allDenominationControllers,
                      index: index,
                      inputs: inputs),
                  const SizedBox(height: 6),
                  OpenShiftCompactField(
                      label: 'daily_sales_close.count'.tr,
                      controller: countController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) =>
                          inputs.controller.recalculateOpeningCash(),
                      inputs: inputs),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: OpenShiftDenominationDropdown(
                        controller: denominationController,
                        allDenominationControllers: allDenominationControllers,
                        index: index,
                        inputs: inputs),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OpenShiftCompactField(
                        label: 'daily_sales_close.count'.tr,
                        controller: countController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) =>
                            inputs.controller.recalculateOpeningCash(),
                        inputs: inputs),
                  ),
                ],
              ),
      ],
    );
  }
}
