import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/core/ui/ui.dart';

String _tr(String key) => 'customer_transaction_report.$key'.tr;

/// Controlled presentation fields; the page keeps the existing local filters.
FilterPanel customerReportDetailsFilters({
  required Key key,
  required String transactionType,
  required String status,
  required String type,
  required List<String> transactionTypes,
  required List<String> statuses,
  required List<String> types,
  required String Function(String) optionLabel,
  required DateTime? from,
  required DateTime? to,
  required Key fromKey,
  required Key toKey,
  required ValueChanged<String?> onTransactionType,
  required ValueChanged<String?> onStatus,
  required ValueChanged<String?> onType,
  required ValueChanged<DateTime> onFrom,
  required ValueChanged<DateTime> onTo,
  required VoidCallback onReset,
}) {
  List<FilterOption<String>> options(List<String> values) => [
        FilterOption('', _tr('all')),
        for (final value in values) FilterOption(value, optionLabel(value)),
      ];

  return FilterPanel(
    key: key,
    title: _tr('find'),
    hint: _tr('try_adjusting_filters'),
    resetLabel: _tr('reset'),
    onSearch: () {},
    onReset: onReset,
    fields: [
      DropdownFilterField<String>(
        label: _tr('transaction_type_label'),
        icon: Icons.receipt_long_outlined,
        value: transactionType,
        options: options(transactionTypes),
        onChanged: onTransactionType,
      ),
      DropdownFilterField<String>(
        label: _tr('status_label'),
        icon: Icons.check_circle_outline,
        value: status,
        options: options(statuses),
        onChanged: onStatus,
      ),
      DropdownFilterField<String>(
        label: _tr('type_label'),
        icon: Icons.swap_vert,
        value: type,
        options: options(types),
        onChanged: onType,
      ),
      CustomFilterField(
        child: CustomerReportDetailsDateField(
          key: fromKey,
          label: _tr('from_date'),
          value: from,
          onChanged: onFrom,
        ),
      ),
      CustomFilterField(
        child: CustomerReportDetailsDateField(
          key: toKey,
          label: _tr('to_date'),
          value: to,
          onChanged: onTo,
        ),
      ),
    ],
  );
}

/// Keeps the date-only auto-dismiss calendar and bounds of the original field.
/// Its value comes from the page, so Reset also clears the visible date.
class CustomerReportDetailsDateField extends StatelessWidget {
  const CustomerReportDetailsDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: () async {
          final picked = await showAutoDismissDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2101),
          );
          if (picked != null && context.mounted) onChanged(picked);
        },
        child: InputDecorator(
          decoration: AppInputDecoration.filter(
              label: label, icon: Icons.calendar_today_outlined),
          child: Text(
            value == null
                ? _tr('select_date_hint')
                : DateFormat('yyyy-MM-dd').format(value!),
            style: value == null
                ? AppTextStyles.input.copyWith(color: AppColors.muted)
                : AppTextStyles.input,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
}
