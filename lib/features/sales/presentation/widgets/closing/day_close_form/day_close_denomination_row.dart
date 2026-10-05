import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'day_close_compact_field.dart';
import 'day_close_denomination_dropdown.dart';
import 'day_close_form_inputs.dart';

class DayCloseDenominationRow extends StatelessWidget {
  const DayCloseDenominationRow(
      {super.key,
      required this.inputs,
      required this.denominationController,
      required this.countController,
      required this.isNarrow,
      required this.allDenominationControllers,
      required this.index,
      this.isReadOnly = false,
      this.onDenominationChanged,
      this.onCountChanged});
  final DayCloseFormInputs inputs;
  final TextEditingController denominationController;
  final TextEditingController countController;
  final bool isNarrow;
  final List<TextEditingController> allDenominationControllers;
  final int index;
  final bool isReadOnly;
  final ValueChanged<String?>? onDenominationChanged;
  final ValueChanged<String>? onCountChanged;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isNarrow
            ? Column(
                children: [
                  DayCloseDenominationDropdown(
                      controller: denominationController,
                      allDenominationControllers: allDenominationControllers,
                      index: index,
                      isReadOnly: isReadOnly,
                      onChanged: onDenominationChanged,
                      inputs: inputs),
                  const SizedBox(height: 6),
                  DayCloseCompactField(
                      label: 'daily_sales_close.count'.tr,
                      controller: countController,
                      keyboardType: TextInputType.number,
                      enabled: !isReadOnly,
                      onChanged: onCountChanged,
                      inputs: inputs),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: DayCloseDenominationDropdown(
                        controller: denominationController,
                        allDenominationControllers: allDenominationControllers,
                        index: index,
                        isReadOnly: isReadOnly,
                        onChanged: onDenominationChanged,
                        inputs: inputs),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: DayCloseCompactField(
                        label: 'daily_sales_close.count'.tr,
                        controller: countController,
                        keyboardType: TextInputType.number,
                        enabled: !isReadOnly,
                        onChanged: onCountChanged,
                        inputs: inputs),
                  ),
                ],
              ),
      ],
    );
  }
}
