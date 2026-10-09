import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';

class InvoiceListFilters extends StatelessWidget {
  const InvoiceListFilters(
      {super.key,
      required this.panelKey,
      required this.invoiceNumberController,
      required this.searchTextController,
      required this.phoneController,
      required this.showZatca,
      required this.selectedStatus,
      required this.selectedZatcaStatus,
      required this.statusOptions,
      required this.zatcaOptions,
      required this.fromField,
      required this.toField,
      required this.onSearch,
      required this.onSubmit,
      required this.onReset,
      required this.onStatusChanged,
      required this.onZatcaChanged});
  final Key panelKey;
  final TextEditingController invoiceNumberController,
      searchTextController,
      phoneController;
  final bool showZatca;
  final String? selectedStatus, selectedZatcaStatus;
  final List<String> statusOptions, zatcaOptions;
  final FilterFieldDef fromField, toField;
  final VoidCallback onSearch, onSubmit, onReset;
  final ValueChanged<String?> onStatusChanged, onZatcaChanged;
  FilterFieldDef _textFilter(
          TextEditingController controller, String label, IconData icon,
          {TextInputType keyboardType = TextInputType.text}) =>
      TextFilterField(
          controller: controller,
          label: label,
          hint: label,
          icon: icon,
          keyboardType: keyboardType);

  /// The provider's options plus the current value, without the "All"
  /// placeholder (shown as the `null` option instead).
  List<FilterOption<String?>> _options(String allLabel, List<String> values,
          String placeholder, String? current, String Function(String) label) =>
      [
        FilterOption<String?>(null, allLabel),
        for (final value in {
          ...values.where((v) => v != placeholder),
          if (current != null) current,
        })
          FilterOption<String?>(value, label(value)),
      ];

  @override
  Widget build(BuildContext context) => FilterPanel(
          key: panelKey,
          title: 'invoice.find'.tr,
          hint: 'invoice.filter_hint'.tr,
          resetLabel: 'list.reset'.tr,
          onSearch: onSearch,
          onSubmit: onSubmit,
          onReset: onReset,
          fields: [
            _textFilter(invoiceNumberController, 'invoice.invoice_no'.tr,
                Icons.receipt_long_outlined),
            _textFilter(
                searchTextController, 'invoice.name'.tr, Icons.person_outline),
            _textFilter(
                phoneController, 'invoice.phone'.tr, Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            if (showZatca)
              DropdownFilterField<String?>(
                  label: 'invoice.col_zatca_status'.tr,
                  icon: Icons.cloud_sync_outlined,
                  value: selectedZatcaStatus,
                  options: _options(
                      'invoice.all_zatca_status'.tr,
                      zatcaOptions,
                      'All ZATCA Status',
                      selectedZatcaStatus,
                      UiCodeLabels.zatca),
                  onChanged: onZatcaChanged),
            DropdownFilterField<String?>(
                label: 'invoice.field_status'.tr,
                icon: Icons.check_circle_outline,
                value: selectedStatus,
                options: _options('invoice.all_status'.tr, statusOptions,
                    'All Status', selectedStatus, UiCodeLabels.status),
                onChanged: onStatusChanged),
            fromField,
            toField,
          ]);
}
