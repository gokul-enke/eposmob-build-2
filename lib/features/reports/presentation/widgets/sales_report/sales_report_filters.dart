import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../../../domain/report_period.dart';
import '../../../domain/sales_report_query.dart';
import '../../state/sales_report_controller.dart';
import '../non_stock_report/non_stock_report_picker.dart';
import '../report_date_field.dart';

String _tr(String key) => 'order_sales_report.$key'.tr;

IconData _icon(SalesReportFilter filter) => switch (filter) {
      SalesReportFilter.store => Icons.store_outlined,
      SalesReportFilter.salesExecutive => Icons.badge_outlined,
      SalesReportFilter.paymentMethod => Icons.payments_outlined,
      SalesReportFilter.deliveryMethod => Icons.local_shipping_outlined,
      SalesReportFilter.category => Icons.category_outlined,
      SalesReportFilter.product => Icons.inventory_2_outlined,
      SalesReportFilter.customer => Icons.person_outline,
    };

/// The web's filters: Stores, Sales Executives, Payment Methods, Delivery
/// Modes, Categories, Products and Customers (one choice each, with the same
/// searchable picker as the Discount Sale and Non-Stock reports), the Date
/// Range (From/To when Custom) and the order-date sort. Reads the
/// controller's values and calls its methods; no provider access.
FilterPanel salesReportFilters(SalesReportController report) => FilterPanel(
        key: const ValueKey('sales-report-filters'),
        title: _tr('find'),
        hint: _tr('filter_hint'),
        onSearch: () {}, // No text fields: every filter applies at once.
        onSubmit: report.submit,
        onReset: report.reset,
        resetLabel: 'list.reset'.tr,
        fields: [
          // The bounded searchable picker stays fast with thousands of
          // products and customers.
          for (final filter in SalesReportFilter.values)
            CustomFilterField(
                child: NonStockReportPicker(
                    key: ValueKey(
                        'sales-report-${filter.name}-${report.resetRevision}'),
                    label: filter.labelKey.tr,
                    allLabel: _tr('all'),
                    icon: _icon(filter),
                    options: report.optionMap(filter),
                    value: report.ids(filter).firstOrNull,
                    loading: report.optionsLoading(filter),
                    enabled: !report.isLocked(filter),
                    onChanged: (id) =>
                        report.select(filter, {if (id != null) id}))),
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
                    key: const ValueKey('sales-report-from'),
                    label: _tr('from_date'),
                    value: report.customFrom,
                    onChanged: (v) => report.setCustomDate(v, from: true))),
            CustomFilterField(
                child: ReportDateField(
                    key: const ValueKey('sales-report-to'),
                    label: _tr('to_date'),
                    value: report.customTo,
                    onChanged: (v) => report.setCustomDate(v, from: false))),
          ],
          DropdownFilterField<bool>(
              label: _tr('sort'),
              icon: Icons.sort_rounded,
              value: report.oldestFirst,
              options: [
                FilterOption(false, _tr('sort_newest')),
                FilterOption(true, _tr('sort_oldest')),
              ],
              onChanged: report.setOldestFirst),
        ]);
