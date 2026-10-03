import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/sales_executive_report.dart';

String _tr(String key) => 'sales_executive_report.$key'.tr;

/// `SAR 12.50`; an empty amount shows as zero.
String mySalesMoney(String currency, String? raw) =>
    '$currency ${(double.tryParse(raw ?? '') ?? 0).toStringAsFixed(2)}';

/// Table columns of My Sales Report.
List<TableColumnDef<SalesExecutiveReportData>> mySalesColumns({
  required String currency,
  required ValueChanged<SalesExecutiveReportData> onView,
}) {
  TableColumnDef<SalesExecutiveReportData> money(
          String key, String? Function(SalesExecutiveReportData) value) =>
      TableColumnDef(
          label: _tr(key),
          flex: 1.3,
          cellBuilder: (r, _) =>
              TableCells.text(mySalesMoney(currency, value(r))));
  return [
    TableColumnDef(
        label: _tr('executive_name'),
        flex: 2,
        cellBuilder: (r, _) {
          final name = r.name ?? _tr('na');
          return TableCells.avatarName(
              name: name,
              avatar: AppAvatar(name: name, semanticLabel: name, size: 36));
        }),
    TableColumnDef(
        label: _tr('phone'),
        flex: 1.3,
        cellBuilder: (r, _) => TableCells.text(r.phone ?? '—')),
    TableColumnDef(
        label: _tr('total_orders'),
        cellBuilder: (r, _) => TableCells.text('${r.orderCount ?? 0}')),
    money('total_sales', (r) => r.totalSales),
    money('online_sales', (r) => r.onlineSales),
    money('cash_sales', (r) => r.cashSales),
    money('credit_sales', (r) => r.creditSales),
    money('collected_sales', (r) => r.collectedSales),
    TableColumnDef(
        label: _tr('actions'),
        cellBuilder: (r, _) => TableCells.action(
            label: 'list.view'.tr,
            icon: Icons.visibility_outlined,
            onPressed: () => onView(r))),
  ];
}

/// Phone card of one sales executive's totals.
class MySalesCard extends StatelessWidget {
  const MySalesCard({
    super.key,
    required this.row,
    required this.currency,
    required this.onView,
  });

  final SalesExecutiveReportData row;
  final String currency;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final name = row.name ?? _tr('na');
    return AppListCard(
      leading: AppAvatar(name: name, semanticLabel: name, size: 42),
      title: name,
      subtitle: row.phone,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppMetricStrip(metrics: [
          AppMetric(
              icon: Icons.receipt_long_outlined,
              label: _tr('total_orders'),
              value: '${row.orderCount ?? 0}'),
          AppMetric(
              icon: Icons.payments_outlined,
              label: _tr('total_sales'),
              value: mySalesMoney(currency, row.totalSales)),
        ]),
        const SizedBox(height: AppSpacing.sm),
        for (final entry in <String, String?>{
          'online_sales': row.onlineSales,
          'cash_sales': row.cashSales,
          'credit_sales': row.creditSales,
          'collected_sales': row.collectedSales,
        }.entries)
          InfoRow(
              label: _tr(entry.key),
              value: mySalesMoney(currency, entry.value)),
      ]),
      actionLabel: 'list.view'.tr,
      actionIcon: Icons.visibility_outlined,
      onAction: onView,
    );
  }
}
