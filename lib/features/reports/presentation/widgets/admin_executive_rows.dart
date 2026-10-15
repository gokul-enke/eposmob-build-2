import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/sales_executive_report.dart';

String adminExecutiveMoney(String currency, String? value) =>
    value == null ? '—' : '$currency ${double.parse(value).toStringAsFixed(2)}';

Widget _view(SalesExecutiveReportData row,
        ValueChanged<SalesExecutiveReportData> onView) =>
    AppSquareIconButton(
        icon: Icons.visibility_outlined,
        tooltip: 'list.view'.tr,
        size: 36,
        foreground: AppColors.primary,
        onPressed: () => onView(row));

List<TableColumnDef<SalesExecutiveReportData>> adminExecutiveColumns({
  required String currency,
  required ValueChanged<SalesExecutiveReportData> onView,
}) =>
    [
      TableColumnDef(
          label: 'exec_report.header_exec_name'.tr,
          flex: 2,
          cellBuilder: (r, _) =>
              TableCells.text(r.name ?? 'exec_report.na'.tr)),
      TableColumnDef(
          label: 'exec_report.header_phone'.tr,
          flex: 1.4,
          cellBuilder: (r, _) =>
              TableCells.text(r.phone ?? 'exec_report.na'.tr)),
      TableColumnDef(
          label: 'exec_report.header_total_orders'.tr,
          cellBuilder: (r, _) =>
              TableCells.text(r.orderCount?.toString() ?? '—')),
      for (final metric
          in <(String, String? Function(SalesExecutiveReportData))>[
        ('card_total_sales', (r) => r.totalSales),
        ('card_online_sales', (r) => r.onlineSales),
        ('card_cash_sales', (r) => r.cashSales),
        ('card_credit_sales', (r) => r.creditSales),
        ('card_collected_sales', (r) => r.collectedSales),
      ])
        TableColumnDef(
            label: 'exec_report.${metric.$1}'.tr,
            flex: 1.3,
            cellBuilder: (r, _) =>
                TableCells.text(adminExecutiveMoney(currency, metric.$2(r)))),
      TableColumnDef(
          label: 'exec_report.header_actions'.tr,
          flex: .6,
          cellBuilder: (r, _) => TableCells.widget(_view(r, onView))),
    ];

Widget adminExecutiveCard(
  SalesExecutiveReportData row, {
  required String currency,
  required ValueChanged<SalesExecutiveReportData> onView,
}) =>
    AppListCard(
        title: row.name ?? 'exec_report.na'.tr,
        subtitle: row.phone,
        trailing: _view(row, onView),
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppMetric(
              icon: Icons.receipt_long_outlined,
              label: 'exec_report.header_total_orders'.tr,
              value: row.orderCount?.toString() ?? '—'),
          for (final metric in [
            ('card_total_sales', row.totalSales),
            ('card_online_sales', row.onlineSales),
            ('card_cash_sales', row.cashSales),
            ('card_credit_sales', row.creditSales),
            ('card_collected_sales', row.collectedSales),
          ]) ...[
            const SizedBox(height: AppSpacing.sm),
            AppMetric(
                icon: Icons.payments_outlined,
                label: 'exec_report.${metric.$1}'.tr,
                value: adminExecutiveMoney(currency, metric.$2)),
          ]
        ]));
