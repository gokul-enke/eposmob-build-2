import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import '../../state/sales_list_controller.dart';
import 'sales_filter_field.dart';
import 'sales_mobile_status_filter.dart';

class SalesMobileFilters extends StatelessWidget {
  const SalesMobileFilters(
      {super.key,
      required this.controller,
      required this.size,
      required this.storeList,
      required this.onReset,
      required this.onPickDate});
  final SalesListController controller;
  final Size size;
  final List<GetStoreModelData> storeList;
  final VoidCallback onReset;
  final ValueChanged<bool> onPickDate;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final onTextChanged = controller.onFilterTextChanged;
        final bool narrow = constraints.maxWidth < 400;

        Widget buildTextFilter({
          required String label,
          required String hint,
          required TextEditingController controller,
        }) {
          return SalesFilterField(
            label: label,
            child: buildColumnWidgetForTextFields(
              height: 45,
              onchanged: (value) {
                if (value == null || value.isEmpty || value.length > 2) {
                  onTextChanged();
                }
              },
              controller: controller,
              size: size,
              hintText: hint,
            ),
          );
        }

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildTextFilter(
                label: 'sales.order_number_short'.tr,
                hint: 'sales.order_number_hint'.tr,
                controller: controller.orderNumberController,
              ),
              const SizedBox(height: 12),
              buildTextFilter(
                label: 'billing.customer'.tr,
                hint: 'sales.customer_name_hint'.tr,
                controller: controller.customerNameController,
              ),
              const SizedBox(height: 12),
              buildTextFilter(
                label: 'sales.phone'.tr,
                hint: 'sales.phone'.tr,
                controller: controller.phoneController,
              ),
              const SizedBox(height: 12),
              SalesFilterField(
                label: 'sales.from_date'.tr,
                child: BuildBoxShadowContainer(
                  circleRadius: 10,
                  height: 45,
                  border: Border.all(color: Colors.grey.withOpacity(0.12)),
                  child: TextFormField(
                    controller: controller.fromDateController,
                    onTap: () => onPickDate(true),
                    readOnly: true,
                    style: buildCustomStyle(FontWeightManager.medium,
                        FontSize.s10, 0.18, ColorManager.textColor),
                    decoration: InputDecoration(
                      hintText: 'general.datetime_format_hint'.tr,
                      hintStyle: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s10,
                          0.18,
                          ColorManager.textColor.withOpacity(.5)),
                      prefixIcon: const Icon(Icons.calendar_today,
                          size: 16, color: ColorManager.kPrimaryColor),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SalesFilterField(
                label: 'sales.to_date'.tr,
                child: BuildBoxShadowContainer(
                  circleRadius: 10,
                  height: 45,
                  border: Border.all(color: Colors.grey.withOpacity(0.12)),
                  child: TextFormField(
                    controller: controller.toDateController,
                    onTap: () => onPickDate(false),
                    readOnly: true,
                    style: buildCustomStyle(FontWeightManager.medium,
                        FontSize.s10, 0.18, ColorManager.textColor),
                    decoration: InputDecoration(
                      hintText: 'general.datetime_format_hint'.tr,
                      hintStyle: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s10,
                          0.18,
                          ColorManager.textColor.withOpacity(.5)),
                      prefixIcon: const Icon(Icons.calendar_today,
                          size: 16, color: ColorManager.kPrimaryColor),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SalesFilterField(
                label: 'sales.business_date'.tr,
                child: BuildBoxShadowContainer(
                  circleRadius: 10,
                  height: 45,
                  border: Border.all(color: Colors.grey.withOpacity(0.12)),
                  child: Center(
                    child: CalendarPickerTableCell(
                      key: controller.businessCalendarPickerKey,
                      onDateSelected: (date) {
                        controller.update(() {
                          controller.selectedBusinessDate = date;
                        });
                        controller.searchOrders(1);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              buildTextFilter(
                label: 'sales.price'.tr,
                hint: 'sales.price'.tr,
                controller: controller.amountController,
              ),
              const SizedBox(height: 12),
              SalesMobileStatusFilter(controller: controller),
              const SizedBox(height: 16),
              CustomRoundButton(
                title: 'sales.reset_filters'.tr,
                boxColor: Colors.white,
                textColor: ColorManager.kPrimaryColor,
                fct: onReset,
                height: 45,
                width: double.infinity,
                fontSize: FontSize.s12,
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: buildTextFilter(
                    label: 'sales.order_number_short'.tr,
                    hint: 'sales.order_number_hint'.tr,
                    controller: controller.orderNumberController,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: buildTextFilter(
                    label: 'billing.customer'.tr,
                    hint: 'sales.customer_name_hint'.tr,
                    controller: controller.customerNameController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: buildTextFilter(
                    label: 'sales.phone'.tr,
                    hint: 'sales.phone'.tr,
                    controller: controller.phoneController,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: SalesFilterField(
                          label: 'sales.from_date'.tr,
                          child: BuildBoxShadowContainer(
                            circleRadius: 10,
                            height: 45,
                            border: Border.all(
                                color: Colors.grey.withOpacity(0.12)),
                            child: TextFormField(
                              controller: controller.fromDateController,
                              onTap: () => onPickDate(true),
                              readOnly: true,
                              style: buildCustomStyle(FontWeightManager.medium,
                                  FontSize.s10, 0.18, ColorManager.textColor),
                              decoration: InputDecoration(
                                hintText: 'general.datetime_format_hint'.tr,
                                hintStyle: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s10,
                                    0.18,
                                    ColorManager.textColor.withOpacity(.5)),
                                prefixIcon: const Icon(Icons.calendar_today,
                                    size: 16,
                                    color: ColorManager.kPrimaryColor),
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SalesFilterField(
                          label: 'sales.to_date'.tr,
                          child: BuildBoxShadowContainer(
                            circleRadius: 10,
                            height: 45,
                            border: Border.all(
                                color: Colors.grey.withOpacity(0.12)),
                            child: TextFormField(
                              controller: controller.toDateController,
                              onTap: () => onPickDate(false),
                              readOnly: true,
                              style: buildCustomStyle(FontWeightManager.medium,
                                  FontSize.s10, 0.18, ColorManager.textColor),
                              decoration: InputDecoration(
                                hintText: 'general.datetime_format_hint'.tr,
                                hintStyle: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s10,
                                    0.18,
                                    ColorManager.textColor.withOpacity(.5)),
                                prefixIcon: const Icon(Icons.calendar_today,
                                    size: 16,
                                    color: ColorManager.kPrimaryColor),
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SalesFilterField(
                    label: 'sales.business_date'.tr,
                    child: BuildBoxShadowContainer(
                      circleRadius: 10,
                      height: 45,
                      border: Border.all(color: Colors.grey.withOpacity(0.12)),
                      child: Center(
                        child: CalendarPickerTableCell(
                          key: controller.businessCalendarPickerKey,
                          onDateSelected: (date) {
                            controller.update(() {
                              controller.selectedBusinessDate = date;
                            });
                            controller.searchOrders(1);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
            const SizedBox(height: 12),
            buildTextFilter(
              label: 'sales.price'.tr,
              hint: 'sales.price'.tr,
              controller: controller.amountController,
            ),
            const SizedBox(height: 12),
            SalesMobileStatusFilter(controller: controller),
            const SizedBox(height: 16),
            CustomRoundButton(
              title: 'sales.reset_filters'.tr,
              boxColor: Colors.white,
              textColor: ColorManager.kPrimaryColor,
              fct: onReset,
              height: 45,
              width: double.infinity,
              fontSize: FontSize.s12,
            ),
          ],
        );
      },
    );
  }
}
