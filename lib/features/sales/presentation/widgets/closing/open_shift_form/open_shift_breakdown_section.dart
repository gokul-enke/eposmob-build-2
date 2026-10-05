import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'open_shift_denomination_row.dart';
import 'open_shift_form_inputs.dart';

class OpenShiftBreakdownSection extends StatelessWidget {
  const OpenShiftBreakdownSection(
      {super.key,
      required this.inputs,
      required this.title,
      required this.denominationControllers,
      required this.countControllers,
      required this.isNarrow,
      required this.onAddRow});
  final OpenShiftFormInputs inputs;
  final String title;
  final List<TextEditingController> denominationControllers;
  final List<TextEditingController> countControllers;
  final bool isNarrow;
  final VoidCallback onAddRow;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s12,
                0.21,
                Colors.grey.shade800,
              ),
            ),
            TextButton(
              onPressed: onAddRow,
              child: Text('daily_sales_close.add_row'.tr),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(denominationControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OpenShiftDenominationRow(
                          denominationController:
                              denominationControllers[index],
                          countController: countControllers[index],
                          isNarrow: true,
                          allDenominationControllers: denominationControllers,
                          index: index,
                          inputs: inputs),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'daily_sales_close.remove_row'.tr,
                            onPressed: denominationControllers.length == 1
                                ? null
                                : () {
                                    inputs.controller.update(() {
                                      denominationControllers[index].dispose();
                                      countControllers[index].dispose();
                                      denominationControllers.removeAt(index);
                                      countControllers.removeAt(index);
                                      inputs.controller
                                          .recalculateOpeningCash();
                                    });
                                  },
                            icon: const Icon(Icons.remove_circle_outline,
                                size: 18, color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: OpenShiftDenominationRow(
                            denominationController:
                                denominationControllers[index],
                            countController: countControllers[index],
                            isNarrow: false,
                            allDenominationControllers: denominationControllers,
                            index: index,
                            inputs: inputs),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'daily_sales_close.remove_row'.tr,
                          onPressed: denominationControllers.length == 1
                              ? null
                              : () {
                                  inputs.controller.update(() {
                                    denominationControllers[index].dispose();
                                    countControllers[index].dispose();
                                    denominationControllers.removeAt(index);
                                    countControllers.removeAt(index);
                                    inputs.controller.recalculateOpeningCash();
                                  });
                                },
                          icon: const Icon(Icons.remove_circle_outline,
                              size: 18, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
          );
        }),
      ],
    );
  }
}
