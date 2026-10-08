import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'day_close_form_inputs.dart';

class DayCloseFooter extends StatelessWidget {
  const DayCloseFooter(this.isNarrow, {super.key, required this.inputs});
  final DayCloseFormInputs inputs;
  final bool isNarrow;
  @override
  Widget build(BuildContext context) {
    final bool onConfirmStep = inputs.controller.currentStep == 1;
    final String leftLabel = onConfirmStep
        ? 'daily_sales_close.back'.tr
        : 'daily_sales_close.cancel'.tr;
    final VoidCallback? leftOnPressed = inputs.controller.isSubmitting
        ? null
        : onConfirmStep
            ? () => inputs.controller
                .update(() => inputs.controller.currentStep = 0)
            : () => inputs.onClose();

    final String rightLabel = onConfirmStep
        ? 'daily_sales_close.confirm_close_day'.tr
        : 'daily_sales_close.next'.tr;
    final bool rightDisabled = inputs.controller.isSubmitting ||
        inputs.controller.isLoadingSummary ||
        inputs.controller.errorMessage != null;
    final VoidCallback? rightOnPressed = rightDisabled
        ? null
        : onConfirmStep
            ? inputs.controller.submitDayClose
            : () => inputs.controller
                .update(() => inputs.controller.currentStep = 1);

    final leftButton = TextButton(
      onPressed: leftOnPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.grey.shade100,
      ),
      child: Text(
        leftLabel,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s13,
          0.18,
          Colors.grey.shade700,
        ),
      ),
    );

    final rightButton = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: ColorManager.kSuccessColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: rightOnPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorManager.kSuccessColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: inputs.controller.isSubmitting && onConfirmStep
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                rightLabel,
                style: buildCustomStyle(
                  FontWeightManager.bold,
                  FontSize.s13,
                  0.18,
                  Colors.white,
                ),
              ),
      ),
    );

    if (isNarrow) {
      return Column(
        children: [
          SizedBox(width: double.infinity, child: leftButton),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: rightButton),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: leftButton),
        const SizedBox(width: 16),
        Expanded(child: rightButton),
      ],
    );
  }
}
