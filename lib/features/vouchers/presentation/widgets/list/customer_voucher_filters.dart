import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';

class CustomerVoucherFilters {
  CustomerVoucherFilters(
      {required this.voucherNumberController,
      required this.selectedType,
      required this.selectedStatus,
      required this.typeOptions,
      required this.statusOptions,
      required this.onSearch,
      required this.onSubmit,
      required this.onReset,
      required this.onType,
      required this.onStatus,
      required this.searchTextController,
      required this.dateFromController,
      required this.dateToController,
      required this.onDate});
  final TextEditingController voucherNumberController;
  final String? selectedType, selectedStatus;
  final List<String> typeOptions, statusOptions;
  final VoidCallback onSearch, onSubmit, onReset;
  final ValueChanged<String?> onType, onStatus;
  final TextEditingController searchTextController,
      dateFromController,
      dateToController;
  final ValueChanged<bool> onDate;
  FilterPanel build() => FilterPanel(
        key: const ValueKey('customer-voucher-desktop-filters'),
        title: 'customer_voucher.find'.tr,
        hint: 'customer_voucher.filter_hint'.tr,
        resetLabel: 'list.reset'.tr,
        onSearch: onSearch,
        onSubmit: onSubmit,
        onReset: onReset,
        fields: [
          TextFilterField(
              controller: searchTextController,
              label: 'customer_voucher.customer_name_hint'.tr,
              hint: 'customer_voucher.customer_name_hint'.tr,
              icon: Icons.person_outline),
          TextFilterField(
              controller: voucherNumberController,
              label: 'customer_voucher.voucher_no_hint'.tr,
              hint: 'customer_voucher.voucher_no_hint'.tr,
              icon: Icons.receipt_long_outlined),
          _dropdown(
              label: 'customer_voucher.col_type'.tr,
              allLabel: 'customer_voucher.hint_all_types'.tr,
              icon: Icons.swap_vert,
              value: selectedType,
              options: {
                ...typeOptions.where((v) => v != 'All Types'),
                if (selectedType != null) selectedType!
              },
              display: UiCodeLabels.voucherType,
              onChanged: onType),
          _dropdown(
              label: 'customer_voucher.col_status'.tr,
              allLabel: 'customer_voucher.hint_all_status'.tr,
              icon: Icons.check_circle_outline,
              value: selectedStatus,
              options: statusOptions.where((v) => v != 'All Status'),
              display: UiCodeLabels.status,
              onChanged: onStatus),
          for (final from in [true, false])
            CustomFilterField(
                child: TextField(
                    controller: from ? dateFromController : dateToController,
                    readOnly: true,
                    textAlignVertical: TextAlignVertical.center,
                    style: AppTextStyles.input,
                    decoration: AppInputDecoration.filter(
                        label: from
                            ? 'customer_voucher.from_date'.tr
                            : 'customer_voucher.to_date'.tr,
                        icon: Icons.calendar_today_outlined),
                    onTap: () => onDate(from))),
        ],
      );

  /// Type/status dropdown whose empty choice (`null`) means "all".
  DropdownFilterField<String?> _dropdown({
    required String label,
    required String allLabel,
    required IconData icon,
    required String? value,
    required Iterable<String> options,
    required String Function(String) display,
    required ValueChanged<String?> onChanged,
  }) =>
      DropdownFilterField<String?>(
        label: label,
        icon: icon,
        value: value,
        options: [
          FilterOption<String?>(null, allLabel),
          for (final option in options)
            FilterOption<String?>(option, display(option)),
        ],
        onChanged: onChanged,
      );
}
