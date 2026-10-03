import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../state/customer_transactions_controller.dart';

/// Total credit, total debit and net of the visible transactions.
class TransactionSummaryStrip extends StatelessWidget {
  const TransactionSummaryStrip({super.key, required this.totals});

  final TransactionTotals totals;

  @override
  Widget build(BuildContext context) {
    return AppMetricStrip(
      metrics: [
        AppMetric(
          icon: Icons.south_west_rounded,
          label: 'customer_profile.tx_total_credit'.tr,
          value: totals.credit.toStringAsFixed(2),
          valueColor: AppColors.green,
        ),
        AppMetric(
          icon: Icons.north_east_rounded,
          label: 'customer_profile.tx_total_debit'.tr,
          value: totals.debit.toStringAsFixed(2),
          valueColor: AppColors.red,
        ),
        AppMetric(
          icon: Icons.account_balance_wallet_outlined,
          label: 'customer_profile.tx_net'.tr,
          value: totals.net.toStringAsFixed(2),
          valueColor: AppColors.amount(totals.net),
        ),
      ],
    );
  }
}
