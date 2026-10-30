import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../../../reports/domain/report_period.dart';
import '../../../reports/presentation/widgets/report_date_field.dart';
import '../../domain/general_payment_type.dart';
import '../state/general_payment_list_controller.dart';

String _tr(String key) => 'general_payments.$key'.tr;

/// The web's filters: Reference Number, Entry type, Category, Debit A/c,
/// Credit A/c and the Date Range, with From/To when Custom is chosen. The
/// category and account lists follow the chosen entry type. Reads the
/// controller's values and calls its methods; no provider access.
FilterPanel generalPaymentFilters(GeneralPaymentListController list) {
  final filter = list.filter;
  FilterFieldDef choice(String name, IconData icon, String? value,
          Map<String, String> options, ValueChanged<String?> onChanged) =>
      DropdownFilterField<String?>(
          label: _tr('filter_$name'),
          icon: icon,
          value: options.containsKey(value) ? value : null,
          options: [
            FilterOption(null, _tr('all')),
            for (final MapEntry(:key, :value) in options.entries)
              FilterOption(key, value),
          ],
          onChanged: onChanged);
  return FilterPanel(
      key: const ValueKey('general-payments-filters'),
      title: _tr('find'),
      hint: _tr('filter_hint'),
      onSearch: () {}, // The controller follows the reference field itself.
      onReset: list.reset,
      resetLabel: 'list.reset'.tr,
      fields: [
        TextFilterField(
            controller: list.reference,
            label: _tr('filter_reference'),
            hint: _tr('reference_hint'),
            icon: Icons.tag_rounded),
        DropdownFilterField<GeneralPaymentType?>(
            label: _tr('filter_entry_type'),
            icon: Icons.swap_horiz_rounded,
            value: filter.type,
            options: [
              FilterOption(null, _tr('all')),
              for (final type in GeneralPaymentType.values)
                FilterOption(type, type.labelKey.tr),
            ],
            onChanged: list.setType),
        choice('category', Icons.category_outlined, filter.categoryId,
            list.categoryOptions, list.setCategory),
        choice(
            'debit_account',
            Icons.account_balance_outlined,
            filter.debitAccountId,
            list.debitAccountOptions,
            list.setDebitAccount),
        choice(
            'credit_account',
            Icons.account_balance_wallet_outlined,
            filter.creditAccountId,
            list.creditAccountOptions,
            list.setCreditAccount),
        DropdownFilterField<ReportPeriod?>(
            label: _tr('filter_date_range'),
            icon: Icons.date_range_outlined,
            value: filter.period,
            options: [
              FilterOption(null, _tr('all_dates')),
              for (final period in GeneralPaymentListController.periods)
                FilterOption(period, period.labelKey.tr),
            ],
            onChanged: list.setPeriod),
        if (filter.period == ReportPeriod.custom) ...[
          CustomFilterField(
              child: ReportDateField(
                  key: const ValueKey('general-payments-from'),
                  label: _tr('from_date'),
                  value: filter.customFrom,
                  onChanged: (v) => list.setCustomDate(v, from: true))),
          CustomFilterField(
              child: ReportDateField(
                  key: const ValueKey('general-payments-to'),
                  label: _tr('to_date'),
                  value: filter.customTo,
                  onChanged: (v) => list.setCustomDate(v, from: false))),
        ],
      ]);
}
