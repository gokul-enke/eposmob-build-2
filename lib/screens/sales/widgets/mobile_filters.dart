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
import 'package:pos_machine/helpers/ui_code_labels.dart';

class MobileFilters extends StatelessWidget {
  final TextEditingController orderNumberController;
  final TextEditingController customerNameController;
  final TextEditingController phoneController;
  final TextEditingController amountController;
  final TextEditingController storeController;
  final TextEditingController storeSearchController;
  final TextEditingController statusController;
  final String? selectedStatus;
  final GetStoreModelData? storeSelected;
  final DateTime? selectedDate;
  final Key calendarPickerKey;
  final List<GetStoreModelData> storeList;
  final List<String> statusOptions;
  final Function(String?) onSearch;
  final Function(GetStoreModelData?) onStoreChanged;
  final Function(String?) onStatusChanged;
  final Function(DateTime) onDateSelected;
  final VoidCallback onReset;
  final DateTime? selectedBusinessDate;
  final Key? businessCalendarPickerKey;
  final Function(DateTime)? onBusinessDateSelected;

  const MobileFilters({
    super.key,
    required this.orderNumberController,
    required this.customerNameController,
    required this.phoneController,
    required this.amountController,
    required this.storeController,
    required this.storeSearchController,
    required this.statusController,
    required this.selectedStatus,
    required this.storeSelected,
    required this.selectedDate,
    required this.calendarPickerKey,
    required this.storeList,
    required this.statusOptions,
    required this.onSearch,
    required this.onStoreChanged,
    required this.onStatusChanged,
    required this.onDateSelected,
    required this.onReset,
    this.selectedBusinessDate,
    this.businessCalendarPickerKey,
    this.onBusinessDateSelected,
  });

  Widget _buildFilterField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
          child: Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              Colors.black.withOpacity(0.7),
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildTextFilter({
    required String label,
    required String hint,
    required TextEditingController controller,
    required Size size,
  }) {
    return _buildFilterField(
      label: label,
      child: buildColumnWidgetForTextFields(
        height: 45,
        onchanged: onSearch,
        controller: controller,
        size: size,
        hintText: hint,
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return _buildFilterField(
      label: 'mobile_filters.field_status'.tr,
      child: SizedBox(
        height: 45,
        child: BuildBoxShadowContainer(
          circleRadius: 10,
          alignment: Alignment.centerLeft,
          margin: EdgeInsets.zero,
          padding: const EdgeInsetsDirectional.only(start: 15),
          color: Colors.white,
          border: Border.all(color: Colors.grey.withOpacity(0.12)),
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              border: InputBorder.none,
              filled: true,
              fillColor: Colors.white,
            ),
            value: selectedStatus,
            isExpanded: true,
            dropdownColor: Colors.white,
            hint: Text(
              'mobile_filters.hint_select_status'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                  'mobile_filters.option_all'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s10,
                    0.27,
                    ColorManager.textColor.withOpacity(.5),
                  ),
                ),
              ),
              ...statusOptions.map((String status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Text(
                    UiCodeLabels.status(status),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s10,
                      0.27,
                      ColorManager.textColor.withOpacity(.5),
                    ),
                  ),
                );
              }),
            ],
            onChanged: onStatusChanged,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool narrow = constraints.maxWidth < 400;

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextFilter(
                label: 'mobile_filters.field_order_num'.tr,
                hint: 'mobile_filters.hint_order_number'.tr,
                controller: orderNumberController,
                size: size,
              ),
              const SizedBox(height: 12),
              _buildTextFilter(
                label: 'mobile_filters.field_customer'.tr,
                hint: 'mobile_filters.hint_customer_name'.tr,
                controller: customerNameController,
                size: size,
              ),
              const SizedBox(height: 12),
              _buildTextFilter(
                label: 'mobile_filters.field_phone'.tr,
                hint: 'mobile_filters.hint_phone'.tr,
                controller: phoneController,
                size: size,
              ),
              const SizedBox(height: 12),
              _buildFilterField(
                label: 'mobile_filters.field_date'.tr,
                child: BuildBoxShadowContainer(
                  circleRadius: 10,
                  height: 45,
                  border: Border.all(color: Colors.grey.withOpacity(0.12)),
                  child: Center(
                    child: CalendarPickerTableCell(
                      key: calendarPickerKey,
                      onDateSelected: onDateSelected,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildFilterField(
                label: 'mobile_filters.field_business_date'.tr,
                child: BuildBoxShadowContainer(
                  circleRadius: 10,
                  height: 45,
                  border: Border.all(color: Colors.grey.withOpacity(0.12)),
                  child: Center(
                    child: CalendarPickerTableCell(
                      key: businessCalendarPickerKey ?? UniqueKey(),
                      onDateSelected: onBusinessDateSelected ?? (date) {},
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildTextFilter(
                label: 'mobile_filters.field_price'.tr,
                hint: 'mobile_filters.hint_price'.tr,
                controller: amountController,
                size: size,
              ),
              const SizedBox(height: 12),
              _buildStatusDropdown(),
              const SizedBox(height: 16),
              CustomRoundButton(
                title: 'mobile_filters.btn_reset_filters'.tr,
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
                  child: _buildTextFilter(
                    label: 'mobile_filters.field_order_num'.tr,
                    hint: 'mobile_filters.hint_order_number'.tr,
                    controller: orderNumberController,
                    size: size,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextFilter(
                    label: 'mobile_filters.field_customer'.tr,
                    hint: 'mobile_filters.hint_customer_name'.tr,
                    controller: customerNameController,
                    size: size,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextFilter(
                    label: 'mobile_filters.field_phone'.tr,
                    hint: 'mobile_filters.hint_phone'.tr,
                    controller: phoneController,
                    size: size,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildFilterField(
                    label: 'mobile_filters.field_date'.tr,
                    child: BuildBoxShadowContainer(
                      circleRadius: 10,
                      height: 45,
                      border: Border.all(color: Colors.grey.withOpacity(0.12)),
                      child: Center(
                        child: CalendarPickerTableCell(
                          key: calendarPickerKey,
                          onDateSelected: onDateSelected,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildFilterField(
                    label: 'mobile_filters.field_business_date'.tr,
                    child: BuildBoxShadowContainer(
                      circleRadius: 10,
                      height: 45,
                      border: Border.all(color: Colors.grey.withOpacity(0.12)),
                      child: Center(
                        child: CalendarPickerTableCell(
                          key: businessCalendarPickerKey ?? UniqueKey(),
                          onDateSelected: onBusinessDateSelected ?? (date) {},
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
            _buildTextFilter(
              label: 'mobile_filters.field_price'.tr,
              hint: 'mobile_filters.hint_price'.tr,
              controller: amountController,
              size: size,
            ),
            const SizedBox(height: 12),
            _buildStatusDropdown(),
            const SizedBox(height: 16),
            CustomRoundButton(
              title: 'mobile_filters.btn_reset_filters'.tr,
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
