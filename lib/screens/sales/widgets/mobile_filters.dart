import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

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
  });

  Widget _buildFilterField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Order # and Customer
        Row(
          children: [
            Expanded(
              child: _buildFilterField(
                label: "Order #",
                child: buildColumnWidgetForTextFields(
                  height: 45,
                  onchanged: onSearch,
                  controller: orderNumberController,
                  size: size,
                  hintText: 'Order Number',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildFilterField(
                label: "Customer",
                child: buildColumnWidgetForTextFields(
                  height: 45,
                  onchanged: onSearch,
                  controller: customerNameController,
                  size: size,
                  hintText: 'Customer Name',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 2: Phone and Date
        Row(
          children: [
            Expanded(
              child: _buildFilterField(
                label: "Phone",
                child: buildColumnWidgetForTextFields(
                  height: 45,
                  onchanged: onSearch,
                  controller: phoneController,
                  size: size,
                  hintText: 'Phone',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildFilterField(
                label: "Date",
                child: BuildBoxShadowContainer(
                  circleRadius: 7,
                  height: 45,
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

        // Row 3: Price and Store
        Row(
          children: [
            Expanded(
              child: _buildFilterField(
                label: "Price",
                child: buildColumnWidgetForTextFields(
                  height: 45,
                  onchanged: onSearch,
                  controller: amountController,
                  size: size,
                  hintText: 'Price',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildFilterField(
                label: "Store",
                child: BuildDropDownWithSearch<GetStoreModelData>(
                  title: null,
                  showName: false,
                  hintText: 'Select Store',
                  value: storeSelected,
                  items: [
                    GetStoreModelData(id: 0, name: 'All Stores'),
                    ...storeList
                  ],
                  onChanged: onStoreChanged,
                  displayText: (store) => store.name ?? 'Unknown Store',
                  searchController: storeSearchController,
                  height: 45,
                  margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 4: Status (full width)
        _buildFilterField(
          label: "Status",
          child: SizedBox(
            height: 45,
            child: BuildBoxShadowContainer(
              circleRadius: 7,
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              padding: const EdgeInsets.only(left: 15),
              color: Colors.white,
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  filled: true,
                  fillColor: Colors.white,
                ),
                value: selectedStatus,
                dropdownColor: Colors.white,
                hint: Text(
                  'Select Status',
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
                      'All',
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
                        status.toUpperCase(),
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
                onChanged: onStatusChanged,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Reset button
        CustomRoundButton(
          title: "Reset Filters",
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
}
