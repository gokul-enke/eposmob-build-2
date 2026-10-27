import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/date_helper.dart';

/// Date-only report filter with a clear button, using the app's auto-dismiss
/// calendar (the Custom From/To dates of the reports).
class ReportDateField extends StatelessWidget {
  const ReportDateField(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: () async {
          final picked = await showAutoDismissDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100));
          if (picked != null && context.mounted) onChanged(picked);
        },
        child: InputDecorator(
            isEmpty: value == null,
            textAlignVertical: TextAlignVertical.center,
            decoration: AppInputDecoration.filter(
                label: label,
                hint: 'report_filters.select_date'.tr,
                icon: Icons.calendar_today_outlined,
                suffix: value == null
                    ? null
                    : IconButton(
                        tooltip: 'report_filters.clear_date'.tr,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => onChanged(null))),
            child: Text(
                value == null ? '' : DateHelper.formatYearMonthDay(value!),
                style: AppTextStyles.input,
                maxLines: 1,
                overflow: TextOverflow.ellipsis)),
      );
}
