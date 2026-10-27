import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../../../domain/discount_sale_report_query.dart';
import '../../../domain/report_period.dart';
import '../../state/discount_sale_report_controller.dart';
import '../non_stock_report/non_stock_report_picker.dart';
import '../report_date_field.dart';

String _tr(String key) => 'discount_sale_report.$key'.tr;

/// The web's filters: Discount Type, Order / Offline Receipt Number,
/// Executive, Customer, Store (single choice each) and the Date Range, with
/// From/To when Custom is chosen. Reads the controller's values and calls its
/// methods; no provider access.
FilterPanel discountSaleReportFilters(DiscountSaleReportController report) {
  // The bounded searchable picker stays fast with thousands of customers.
  FilterFieldDef picker(DiscountSaleReportFilter filter, IconData icon) =>
      CustomFilterField(
          child: NonStockReportPicker(
              key: ValueKey(
                  'discount-sale-report-${filter.name}-${report.resetRevision}'),
              label: filter.labelKey.tr,
              allLabel: _tr('all'),
              icon: icon,
              options: report.optionMap(filter),
              value: report.selected[filter],
              loading: report.optionsLoading(filter),
              enabled: !report.isLocked(filter),
              onChanged: (id) => report.select(filter, id)));
  return FilterPanel(
      key: const ValueKey('discount-sale-report-filters'),
      title: _tr('find'),
      hint: _tr('filter_hint'),
      onSearch: () {}, // The controller debounces order number edits itself.
      onSubmit: report.submit,
      onReset: report.reset,
      resetLabel: 'list.reset'.tr,
      fields: [
        DropdownFilterField<DiscountType>(
            label: _tr('filter_discount_type'),
            icon: Icons.discount_outlined,
            value: report.discountType,
            options: [
              for (final type in DiscountType.values)
                FilterOption(type, type.labelKey.tr)
            ],
            onChanged: report.setDiscountType),
        TextFilterField(
            controller: report.orderNumber,
            label: _tr('filter_order_number'),
            hint: _tr('order_number_hint'),
            icon: Icons.receipt_long_outlined),
        picker(DiscountSaleReportFilter.salesExecutive, Icons.badge_outlined),
        picker(DiscountSaleReportFilter.customer, Icons.person_outline),
        picker(DiscountSaleReportFilter.store, Icons.store_outlined),
        DropdownFilterField<ReportPeriod>(
            label: _tr('date_range'),
            icon: Icons.date_range_outlined,
            value: report.period,
            options: [
              for (final p in report.periods) FilterOption(p, p.labelKey.tr)
            ],
            onChanged: report.setPeriod),
        if (report.period == ReportPeriod.custom) ...[
          CustomFilterField(
              child: ReportDateField(
                  key: const ValueKey('discount-sale-report-from'),
                  label: _tr('from_date'),
                  value: report.customFrom,
                  onChanged: (v) => report.setCustomDate(v, from: true))),
          CustomFilterField(
              child: ReportDateField(
                  key: const ValueKey('discount-sale-report-to'),
                  label: _tr('to_date'),
                  value: report.customTo,
                  onChanged: (v) => report.setCustomDate(v, from: false))),
        ],
      ]);
}
