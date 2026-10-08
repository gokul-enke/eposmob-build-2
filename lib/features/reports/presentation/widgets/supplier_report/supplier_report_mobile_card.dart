import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../domain/supplier_report.dart';
import '../../export/supplier_transactions_report_export.dart';

class SupplierReportMobileCard extends StatelessWidget {
  const SupplierReportMobileCard(
      {super.key, required this.summary, required this.onView});
  final SupplierTransactionSummary summary;
  final ValueChanged<SupplierTransactionSummary> onView;

  @override
  Widget build(BuildContext context) {
    final name = SupplierTransactionsReportExport.name(summary);
    return AppListCard(
      leading: AppAvatar(name: name, semanticLabel: name),
      title: name,
      subtitle:
          '${'supplier_transaction_report.transactions'.tr}: ${summary.transactionCount}',
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppMetricStrip(metrics: [
          AppMetric(
              icon: Icons.north_east_rounded,
              label: 'supplier_transaction_report.debit_stat'.tr,
              value: summary.totalDebit.toStringAsFixed(2)),
          AppMetric(
              icon: Icons.south_west_rounded,
              label: 'supplier_transaction_report.credit_stat'.tr,
              value: summary.totalCredit.toStringAsFixed(2)),
        ]),
        const SizedBox(height: AppSpacing.sm),
        InfoRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'supplier_transaction_report.balance'.tr,
            value: summary.balance.toStringAsFixed(2),
            valueColor: AppColors.amount(summary.balance)),
      ]),
      actionLabel: 'list.view'.tr,
      actionIcon: Icons.visibility_outlined,
      onAction: () => onView(summary),
      onTap: () => onView(summary),
    );
  }
}
