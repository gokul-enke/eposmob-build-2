import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import '../../state/sales_list_controller.dart';
import 'sales_date_field.dart';
import 'sales_status_labels.dart';

class SalesDesktopFilters extends StatelessWidget {
  const SalesDesktopFilters(
      {super.key,
      required this.controller,
      required this.onReset,
      required this.onPickDate});
  final SalesListController controller;
  final VoidCallback onReset;
  final ValueChanged<bool> onPickDate;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // First row of filters with equal width
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order #
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'sales.order_number_short'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s14,
                        0.27,
                        Colors.black.withOpacity(0.6),
                      ),
                    ),
                  ),
                  buildColumnWidgetForTextFields(
                    height: 45,
                    onchanged: (value) {
                      if (value!.isEmpty || value.length > 2) {
                        controller.onFilterTextChanged();
                      }
                    },
                    controller: controller.orderNumberController,
                    size: size,
                    hintText: 'sales.order_number_hint'.tr,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Customer
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'billing.customer'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s14,
                        0.27,
                        Colors.black.withOpacity(0.6),
                      ),
                    ),
                  ),
                  buildColumnWidgetForTextFields(
                    height: 45,
                    onchanged: (value) {
                      if (value!.isEmpty || value.length > 2) {
                        controller.onFilterTextChanged();
                      }
                    },
                    controller: controller.customerNameController,
                    size: size,
                    hintText: 'sales.customer_name_hint'.tr,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Phone
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'sales.phone'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s14,
                        0.27,
                        Colors.black.withOpacity(0.6),
                      ),
                    ),
                  ),
                  buildColumnWidgetForTextFields(
                    height: 45,
                    onchanged: (value) {
                      if (value!.isEmpty || value.length > 2) {
                        controller.onFilterTextChanged();
                      }
                    },
                    controller: controller.phoneController,
                    size: size,
                    hintText: 'sales.phone'.tr,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // From Date
            Expanded(
              flex: 1,
              child: SalesDateField(
                controller: controller,
                onPickDate: onPickDate,
                label: 'sales.from_date'.tr,
                controllerField: controller.fromDateController,
                isFromDate: true,
              ),
            ),
            const SizedBox(width: 10),

            // To Date
            Expanded(
              flex: 1,
              child: SalesDateField(
                controller: controller,
                onPickDate: onPickDate,
                label: 'sales.to_date'.tr,
                controllerField: controller.toDateController,
                isFromDate: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Second row of filters with equal width
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Price
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'sales.price'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s14,
                        0.27,
                        Colors.black.withOpacity(0.6),
                      ),
                    ),
                  ),
                  buildColumnWidgetForTextFields(
                    height: 45,
                    onchanged: (value) {
                      if (value!.isEmpty || value.length > 2) {
                        controller.onFilterTextChanged();
                      }
                    },
                    controller: controller.amountController,
                    size: size,
                    hintText: 'sales.price'.tr,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),

// Status Filter
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'sales.status'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s14,
                        0.27,
                        Colors.black.withOpacity(0.6),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 45,
                    child: BuildBoxShadowContainer(
                      circleRadius: 7,
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 0),
                      padding: const EdgeInsets.only(left: 15),
                      color: Colors.white,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        value: controller.selectedStatus,
                        dropdownColor: Colors.white,
                        hint: Text(
                          'sales.select_status'.tr,
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s10,
                            0.27,
                            ColorManager.textColor.withOpacity(.5),
                          ),
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              'common.all'.tr,
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s10,
                                0.27,
                                ColorManager.textColor.withOpacity(.5),
                              ),
                            ),
                          ),
                          ...salesStatusOptions.map((String status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(
                                salesStatusLabel(status),
                                style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s10,
                                  0.27,
                                  ColorManager.textColor.withOpacity(.5),
                                ),
                              ),
                            );
                          }).toList()
                        ],
                        onChanged: (String? status) {
                          controller.update(() {
                            controller.selectedStatus = status;
                            if (status != null) {
                              controller.statusController.text = status;
                            } else {
                              controller.statusController.clear();
                            }
                          });
                          controller.searchOrders(1);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),

            // Business Date
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'sales.business_date'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s14,
                        0.27,
                        Colors.black.withOpacity(0.6),
                      ),
                    ),
                  ),
                  BuildBoxShadowContainer(
                    circleRadius: 7,
                    height: 45,
                    child: Center(
                      child: CalendarPickerTableCell(
                        key: controller.businessCalendarPickerKey,
                        onDateSelected: (DateTime date) {
                          controller.update(() {
                            controller.selectedBusinessDate = date;
                          });
                          controller.searchOrders(1);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),

            // Reset button
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(top: 35.0),
                child: CustomRoundButton(
                  title: 'sales.reset_filters'.tr,
                  boxColor: Colors.white,
                  textColor: ColorManager.kPrimaryColor,
                  fct: onReset,
                  height: 45,
                  width: double.infinity, // Take full available width
                  fontSize: FontSize.s12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
