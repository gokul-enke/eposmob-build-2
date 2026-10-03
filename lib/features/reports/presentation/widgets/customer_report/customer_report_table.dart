import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../domain/customer_report.dart';
import '../../export/customer_transactions_report_export.dart';

String _tr(String key) => 'customer_transaction_report.$key'.tr;

String _money(double value) => value.toStringAsFixed(2);

/// Table columns of the Customer Transactions Report.
List<TableColumnDef<CustomerReportRow>> customerReportColumns(
        {required ValueChanged<CustomerReportRow> onView}) =>
    [
      TableColumnDef(
          label: _tr('customer_name_col'),
          flex: 2,
          cellBuilder: (r, _) {
            final name = CustomerTransactionsReportExport.customerName(r);
            return TableCells.avatarName(
                name: name,
                avatar: AppAvatar(name: name, semanticLabel: name, size: 36));
          }),
      TableColumnDef(
          label: _tr('total_debit_col'),
          cellBuilder: (r, _) => TableCells.text(_money(r.debit))),
      TableColumnDef(
          label: _tr('total_credit_col'),
          cellBuilder: (r, _) => TableCells.text(_money(r.credit))),
      TableColumnDef(
          label: _tr('balance'),
          cellBuilder: (r, _) => TableCells.amount(r.balance)),
      TableColumnDef(
          label: _tr('transactions'),
          cellBuilder: (r, _) => TableCells.text('${r.count}')),
      TableColumnDef(
          label: _tr('action_col'),
          cellBuilder: (r, _) => TableCells.action(
              label: 'list.view'.tr,
              icon: Icons.visibility_outlined,
              onPressed: () => onView(r))),
    ];

/// Phone card of one customer's totals.
class CustomerReportCard extends StatelessWidget {
  const CustomerReportCard(
      {super.key, required this.row, required this.onView});

  final CustomerReportRow row;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final name = CustomerTransactionsReportExport.customerName(row);
    return AppListCard(
      leading: AppAvatar(name: name, semanticLabel: name, size: 42),
      title: name,
      subtitle: '${_tr('transactions')}: ${row.count}',
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppMetricStrip(metrics: [
          AppMetric(
              icon: Icons.north_east_rounded,
              label: _tr('total_debit_col'),
              value: _money(row.debit)),
          AppMetric(
              icon: Icons.south_west_rounded,
              label: _tr('total_credit_col'),
              value: _money(row.credit)),
        ]),
        const SizedBox(height: AppSpacing.sm),
        InfoRow(
            icon: Icons.account_balance_wallet_outlined,
            label: _tr('balance'),
            value: _money(row.balance),
            valueColor: AppColors.amount(row.balance)),
      ]),
      actionLabel: 'list.view'.tr,
      actionIcon: Icons.visibility_outlined,
      onAction: onView,
    );
  }
}
