import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../../../domain/consumed_stocks_report_query.dart';
import 'consumed_stocks_report_picker.dart';

FilterPanel consumedStocksReportFilters(
        {required String? productId,
        required String? storeId,
        required DateTime? from,
        required DateTime? until,
        required Map<String, String> products,
        required Map<String, String> stores,
        required int resetRevision,
        required ValueChanged<String?> onProduct,
        required ValueChanged<String?> onStore,
        required ValueChanged<DateTime?> onFrom,
        required ValueChanged<DateTime?> onUntil,
        required VoidCallback onReset}) =>
    FilterPanel(
        key: const ValueKey('consumed-stocks-report-filters'),
        title: 'consumed_stocks_report.find'.tr,
        hint: 'consumed_stocks_report.filter_hint'.tr,
        onSearch: () {},
        onSubmit: () {},
        onReset: onReset,
        resetLabel: 'list.reset'.tr,
        fields: [
          CustomFilterField(
              child: ConsumedStocksReportPicker(
                  key: ValueKey('consumed-product-$resetRevision'),
                  options: products,
                  value: productId,
                  onChanged: onProduct,
                  label: 'consumed_stocks_report.product'.tr,
                  allLabel: 'consumed_stocks_report.all_products'.tr,
                  icon: Icons.inventory_2_outlined)),
          CustomFilterField(
              child: ConsumedStocksReportPicker(
                  key: ValueKey('consumed-store-$resetRevision'),
                  options: stores,
                  value: storeId,
                  onChanged: onStore,
                  label: 'consumed_stocks_report.store'.tr,
                  allLabel: 'consumed_stocks_report.all_stores'.tr,
                  icon: Icons.store_outlined)),
          CustomFilterField(
              child: ConsumedStocksDateField(
                  key: const ValueKey('consumed-from'),
                  label: 'consumed_stocks_report.from_date'.tr,
                  hint: 'consumed_stocks_report.select_from_date'.tr,
                  value: from,
                  onChanged: onFrom)),
          CustomFilterField(
              child: ConsumedStocksDateField(
                  key: const ValueKey('consumed-until'),
                  label: 'consumed_stocks_report.until_date'.tr,
                  hint: 'consumed_stocks_report.select_until_date'.tr,
                  value: until,
                  onChanged: onUntil)),
        ]);

/// Date-only adapter using the existing auto-dismiss calendar and shared input
/// decoration. Controlled values make Reset/clear update the visible dates.
class ConsumedStocksDateField extends StatelessWidget {
  const ConsumedStocksDateField(
      {super.key,
      required this.label,
      required this.hint,
      required this.value,
      required this.onChanged});
  final String label, hint;
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
            lastDate: DateTime(2101));
        if (picked != null && context.mounted) onChanged(picked);
      },
      child: InputDecorator(
          decoration: AppInputDecoration.filter(
              label: label,
              icon: Icons.calendar_today_outlined,
              suffix: value == null
                  ? null
                  : IconButton(
                      tooltip: 'consumed_stocks_report.clear_date'.tr,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => onChanged(null))),
          child: Text(
              value == null
                  ? hint
                  : ConsumedStocksReportQuery.formatDate(value!),
              style: value == null
                  ? AppTextStyles.input.copyWith(color: AppColors.muted)
                  : AppTextStyles.input,
              maxLines: 1,
              overflow: TextOverflow.ellipsis)));
}
