import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../../domain/sales_list_query.dart';
import '../state/sales_list_controller.dart';

FilterPanel salesListFilters(SalesListController controller) => FilterPanel(
      title: 'sales.list_filter_title'.tr,
      hint: 'sales.list_filter_hint'.tr,
      resetLabel: 'general.reset'.tr,
      onSearch: controller.scheduleSearch,
      onSubmit: controller.search,
      onReset: controller.reset,
      fields: [
        TextFilterField(
            controller: controller.number,
            label: 'sales.order_number_short'.tr,
            hint: 'sales.order_number_hint'.tr,
            icon: Icons.search_rounded),
        TextFilterField(
            controller: controller.customer,
            label: 'billing.customer'.tr,
            hint: 'sales.customer_name_hint'.tr,
            icon: Icons.person_outline),
        TextFilterField(
            controller: controller.phone,
            label: 'sales.phone'.tr,
            hint: 'sales.phone'.tr,
            keyboardType: TextInputType.phone,
            icon: Icons.phone_outlined),
        TextFilterField(
            controller: controller.email,
            label: 'sales.email'.tr,
            hint: 'sales.email'.tr,
            keyboardType: TextInputType.emailAddress,
            icon: Icons.email_outlined),
        TextFilterField(
            controller: controller.price,
            label: 'sales.price'.tr,
            hint: 'sales.price'.tr,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            icon: Icons.payments_outlined),
        CustomFilterField(
            child: SalesDateFilter(
                label: 'sales.from_date'.tr,
                value: controller.from,
                includeTime: true,
                onChanged: (date) {
                  controller.from = date;
                  controller.search();
                })),
        CustomFilterField(
            child: SalesDateFilter(
                label: 'sales.to_date'.tr,
                value: controller.until,
                includeTime: true,
                until: true,
                onChanged: (date) {
                  controller.until = date;
                  controller.search();
                })),
        DropdownFilterField<String>(
            label: 'sales.status'.tr,
            value: controller.status,
            icon: Icons.flag_outlined,
            options: [
              for (final code in [
                'all',
                'new',
                'pending',
                'confirmed',
                'delivered',
                'cancelled'
              ])
                FilterOption(code,
                    code == 'all' ? 'common.all'.tr : 'sales.status_$code'.tr)
            ],
            onChanged: (value) {
              controller.status = value ?? 'all';
              controller.search();
            }),
        CustomFilterField(
            child: SalesDateFilter(
                label: 'sales.business_date'.tr,
                value: controller.businessDate,
                onChanged: (date) {
                  controller.businessDate = date;
                  controller.search();
                })),
      ],
    );

/// Uses the shared input decoration with Sales' existing date/time semantics.
/// Abandoning the time dialog keeps the selected day at 00:00 (From) or 23:59 (To).
class SalesDateFilter extends StatelessWidget {
  const SalesDateFilter(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged,
      this.includeTime = false,
      this.until = false});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool includeTime, until;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          final current = value ?? DateTime.now();
          final date = await showAutoDismissDatePicker(
              context: context,
              initialDate: current,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100));
          if (date == null || !context.mounted) return;
          if (!includeTime) {
            onChanged(date);
            return;
          }
          final time = await showTimePicker(
              context: context, initialTime: TimeOfDay.fromDateTime(current));
          if (!context.mounted) return;
          onChanged(DateTime(
              date.year,
              date.month,
              date.day,
              time?.hour ?? (until ? 23 : 0),
              time?.minute ?? (until ? 59 : 0),
              // The picker has no seconds; an upper bound covers its minute.
              until ? 59 : 0));
        },
        child: InputDecorator(
          decoration: AppInputDecoration.filter(
              label: label,
              icon: Icons.calendar_today_outlined,
              suffix: value == null
                  ? null
                  : IconButton(
                      tooltip: 'general.clear'.tr,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => onChanged(null))),
          child: Text(
              value == null
                  ? 'common.select_date'.tr
                  : includeTime
                      ? SalesListQuery.dateTime(value!)
                      : SalesListQuery.date(value!),
              style: value == null
                  ? AppTextStyles.sectionHint
                  : AppTextStyles.input),
        ),
      );
}
