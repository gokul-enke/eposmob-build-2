import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/core/ui/ui.dart';

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
    SupplierReportOption? selected;
    for (final supplier in suppliers) {
      if (supplier.id == selectedSupplierId) selected = supplier;
    }
    return FilterPanel(
      key: const ValueKey('supplier-transactions-report-filters'),
      title: 'supplier_transaction_report.find'.tr,
      hint: 'supplier_transaction_report.filter_hint'.tr,
      resetLabel: 'list.reset'.tr,
      onSearch: () {},
      onReset: onReset,
      fields: [
        CustomFilterField(
            child: DropdownSearch<SupplierReportOption>(
          // Keep the picker alive while its popup closes. Re-keying on selection
          // makes dropdown_search.dispose pop the report route a second time.
          key: const ValueKey('supplier-report-supplier-picker'),
          items: (_, __) => suppliers,
          selectedItem: selected,
          compareFn: (a, b) => a.id == b.id,
          itemAsString: (supplier) => supplier.name,
          decoratorProps: DropDownDecoratorProps(
            decoration: AppInputDecoration.filter(
                label: 'supplier_transaction_report.supplier'.tr,
                icon: Icons.local_shipping_outlined),
          ),
          dropdownBuilder: (_, supplier) => Text(
            supplier?.name ?? 'supplier_transaction_report.all_suppliers'.tr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.input,
          ),
          suffixProps: const DropdownSuffixProps(
              clearButtonProps: ClearButtonProps(isVisible: true)),
          popupProps: AppSearchDropdownPopup.menu<SupplierReportOption>(
            searchHint:
                'supplier_transaction_report.search_supplier_hint_typing'.tr,
            itemLabel: (supplier) => supplier.name,
          ),
          onChanged: onSupplier,
        )),
        CustomFilterField(
            child: SupplierReportDateField(
                key: const ValueKey('supplier-report-from'),
                label: 'supplier_transaction_report.from_date'.tr,
                value: DateTime.tryParse(fromInput.text),
                onChanged: (value) => onDate(value, true))),
        CustomFilterField(
            child: SupplierReportDateField(
                key: const ValueKey('supplier-report-to'),
                label: 'supplier_transaction_report.to_date'.tr,
                value: DateTime.tryParse(toInput.text),
                onChanged: (value) => onDate(value, false))),
      ],
    );
  }
}

/// Keeps date-only filtering and the app's auto-dismiss calendar, styled by
/// the shared input decoration. No time picker or changed API date bounds.
class SupplierReportDateField extends StatelessWidget {
  const SupplierReportDateField(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          final picked = await showAutoDismissDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2101));
          if (picked != null && context.mounted) onChanged(picked);
        },
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: InputDecorator(
          isEmpty: value == null,
          decoration: AppInputDecoration.filter(
              label: label,
              hint: 'supplier_transaction_report.select_date_hint'.tr,
              icon: Icons.calendar_today_outlined),
          child: Text(
              value == null ? '' : DateFormat('MMM dd, yyyy').format(value!),
              style: AppTextStyles.input,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      );
}
