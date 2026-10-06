import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import '../../../domain/supplier_report.dart';

class SupplierReportFilters extends StatelessWidget {
  const SupplierReportFilters(
      {super.key,
      required this.suppliers,
      required this.selectedSupplierId,
      required this.fromInput,
      required this.toInput,
      required this.onReset,
      required this.onSupplier,
      required this.onDate});
  final List<SupplierReportOption> suppliers;
  final String? selectedSupplierId;
  final TextEditingController fromInput, toInput;
  final VoidCallback onReset;
  final ValueChanged<SupplierReportOption?> onSupplier;
  final void Function(DateTime, bool) onDate;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width < 768) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSupplierAutocompleteField(context),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _buildDateField(
                      'supplier_transaction_report.from_date'.tr,
                      fromInput,
                      true)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildDateField(
                      'supplier_transaction_report.to_date'.tr,
                      toInput,
                      false)),
            ],
          ),
          const SizedBox(height: 8),
          CustomRoundButton(
            title: 'supplier_transaction_report.reset'.tr,
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
      children: [
        // First row of filters
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: _buildSupplierAutocompleteField(context),
            ),
            Expanded(
              flex: 1,
              child: _buildDateField(
                'supplier_transaction_report.from_date'.tr,
                fromInput,
                true,
              ),
            ),
            Expanded(
              flex: 1,
              child: _buildDateField(
                'supplier_transaction_report.to_date'.tr,
                toInput,
                false,
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(top: 45, left: 10),
                child: CustomRoundButton(
                  title: 'supplier_transaction_report.reset'.tr,
                  boxColor: Colors.white,
                  textColor: ColorManager.kPrimaryColor,
                  fct: onReset,
                  height: 45,
                  width: double.infinity,
                  fontSize: FontSize.s12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSupplierAutocompleteField(BuildContext context) {
    // Derive currently selected Supplier from selectedSupplierId to show in dropdown
    SupplierReportOption? currentSelected;
    if (selectedSupplierId != null && suppliers.isNotEmpty) {
      try {
        currentSelected =
            suppliers.firstWhere((s) => s.id.toString() == selectedSupplierId);
      } catch (_) {
        currentSelected = null;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'supplier_transaction_report.supplier'.tr,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.27,
                Colors.black.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(height: 8),
          BuildDropDownWithSearch<SupplierReportOption>(
            title: null,
            hintText: 'supplier_transaction_report.search_supplier_hint'.tr,
            value: currentSelected,
            items: suppliers,
            displayText: (s) => s.name,
            height: 45,
            margin: EdgeInsets.zero,
            onChanged: (SupplierReportOption? s) {
              onSupplier(s);
            },
            searchHintText:
                'supplier_transaction_report.search_supplier_hint_typing'.tr,
            // Ensure consistent padding/width like date fields
            width: double.infinity,
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(
      String label, TextEditingController controller, bool isFromDate) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              label,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.27,
                Colors.black.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(height: 8),
          BuildBoxShadowContainer(
            height: 45,
            width: double.infinity,
            circleRadius: 7,
            child: CalendarPickerTableCell(
              key: ValueKey(
                  'supplier-report-date-$isFromDate-${controller.text}'),
              onDateSelected: (DateTime selectedDate) {
                onDate(selectedDate, isFromDate);
              },
              initialDate: controller.text.isNotEmpty
                  ? DateFormat('yyyy-MM-dd').parse(controller.text)
                  : null,
              firstDate: DateTime(2000),
              lastDate: DateTime(2101),
              hintText: 'supplier_transaction_report.select_date_hint'.tr,
              isAllowEdit: true,
            ),
          ),
        ],
      ),
    );
  }
}
