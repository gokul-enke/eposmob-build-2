import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'open_shift_amount_field.dart';
import 'open_shift_breakdown_section.dart';
import 'open_shift_date_field.dart';
import 'open_shift_disabled_store_field.dart';
import 'open_shift_form_inputs.dart';
import 'open_shift_text_area_field.dart';
import 'open_shift_time_picker_field.dart';
import 'open_shift_two_column_row.dart';

class OpenShiftFormView extends StatelessWidget {
  const OpenShiftFormView({super.key, required this.inputs});
  final OpenShiftFormInputs inputs;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;
    final currency = inputs.currency;

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
                mainAxisSize: MainAxisSize.min,
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
                              'daily_sales_close.btn_open_shift'.tr,
                              style: buildCustomStyle(
                                FontWeightManager.bold,
                                FontSize.s18,
                                0.21,
                                ColorManager.kTitleTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'daily_sales_close.open_shift_subtitle'.tr,
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
                      IconButton(
                        onPressed: inputs.controller.isLoading
                            ? null
                            : () => inputs.onClose(),
                        icon: const Icon(Icons.close),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Form Area
                  Expanded(
                    child: SingleChildScrollView(
                      controller: inputs.controller.scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Store Name (disabled)
                          OpenShiftDisabledStoreField(inputs: inputs),
                          const SizedBox(height: 12),
                          // Shift Name & Business Date
                          OpenShiftTwoColumnRow(
                              isNarrow: isNarrow,
                              left: OpenShiftAmountField(
                                  label: 'daily_sales_close.shift_name'.tr,
                                  controller:
                                      inputs.controller.shiftNameController,
                                  inputs: inputs),
                              right: OpenShiftDateField(
                                  label: 'daily_sales_close.business_date'.tr,
                                  controller:
                                      inputs.controller.businessDateController,
                                  inputs: inputs),
                              inputs: inputs),
                          const SizedBox(height: 12),
                          // Opening Time & Opening Cash
                          OpenShiftTwoColumnRow(
                              isNarrow: isNarrow,
                              left: OpenShiftTimePickerField(
                                  label:
                                      'daily_sales_close.opening_time_req'.tr,
                                  controller:
                                      inputs.controller.openingTimeController,
                                  inputs: inputs),
                              right: OpenShiftAmountField(
                                  label:
                                      'daily_sales_close.opening_cash_balance'
                                          .tr
                                          .replaceAll('@currency', currency),
                                  controller: inputs
                                      .controller.openingCashInHandController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputs: inputs),
                              inputs: inputs),
                          const SizedBox(height: 20),
                          // Breakdown Section
                          OpenShiftBreakdownSection(
                              title:
                                  'daily_sales_close.opening_cash_breakdown'.tr,
                              denominationControllers:
                                  inputs.controller.denominationControllers,
                              countControllers:
                                  inputs.controller.countControllers,
                              isNarrow: isNarrow,
                              onAddRow: () {
                                inputs.controller.update(() {
                                  inputs.controller.addBreakdownRow();
                                });
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (inputs
                                      .controller.scrollController.hasClients) {
                                    inputs.controller.scrollController
                                        .animateTo(
                                      inputs.controller.scrollController
                                          .position.maxScrollExtent,
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                });
                              },
                              inputs: inputs),
                          const SizedBox(height: 20),
                          // Notes
                          OpenShiftTextAreaField(
                              label: 'daily_sales_close.notes'.tr,
                              controller: inputs.controller.notesController,
                              maxLines: 3,
                              inputs: inputs),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  // Error message
                  if (inputs.controller.errorMessage != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        inputs.controller.errorMessage!,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s11,
                          0.18,
                          Colors.red,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Footer Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: inputs.controller.isLoading
                            ? null
                            : () => inputs.onClose(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          backgroundColor: Colors.grey.shade100,
                        ),
                        child: Text(
                          'daily_sales_close.cancel'.tr,
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s12,
                            0.18,
                            Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: inputs.controller.isLoading
                            ? null
                            : inputs.controller.saveOpeningDraft,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: inputs.controller.isLoading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'daily_sales_close.save_opening_draft'.tr,
                                style: buildCustomStyle(
                                  FontWeightManager.bold,
                                  FontSize.s12,
                                  0.18,
                                  Colors.white,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
