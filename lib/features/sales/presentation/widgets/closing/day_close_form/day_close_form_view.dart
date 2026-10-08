import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'day_close_cash_closing_step_content.dart';
import 'day_close_confirm_close_step_content.dart';
import 'day_close_footer.dart';
import 'day_close_form_inputs.dart';

class DayCloseFormView extends StatelessWidget {
  const DayCloseFormView({super.key, required this.inputs});
  final DayCloseFormInputs inputs;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: BuildBoxShadowContainer(
        circleRadius: 20,
        color: Colors.white,
        width: isMobile ? size.width * 0.98 : 760,
        padding: EdgeInsets.all(isMobile ? 8 : 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 420;
            final maxHeight = size.height * 0.85;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inputs.controller.currentStep == 0
                                  ? 'daily_sales_close.btn_day_close'.tr
                                  : 'daily_sales_close.confirm_close'.tr,
                              style: buildCustomStyle(
                                FontWeightManager.bold,
                                FontSize.s18,
                                0.21,
                                ColorManager.kTitleTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              inputs.controller.currentStep == 0
                                  ? 'daily_sales_close.day_close_subtitle'.tr
                                  : 'daily_sales_close.confirm_close_subtitle'
                                      .tr,
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s11,
                                0.18,
                                Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Material(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => inputs.onClose(),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: inputs.controller.scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (inputs.controller.isLoadingSummary)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (inputs.controller.errorMessage != null)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red.shade400,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      inputs.controller.errorMessage!,
                                      style: TextStyle(
                                        color: Colors.red.shade600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: inputs.controller.fetchSummary,
                                      child: Text('restaurant.retry'.tr),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Builder(
                              builder: (context) {
                                final currency = inputs.currency;
                                return inputs.controller.currentStep == 0
                                    ? DayCloseCashClosingStepContent(
                                        currency, isNarrow, constraints,
                                        inputs: inputs)
                                    : DayCloseConfirmCloseStepContent(currency,
                                        inputs: inputs);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Footer buttons
                  DayCloseFooter(isNarrow, inputs: inputs),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
