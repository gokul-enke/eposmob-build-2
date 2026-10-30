import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../../domain/general_payment_totals.dart';
import '../../domain/general_payment_type.dart';
import 'general_payment_results.dart';

/// The web's four cards (Total Expense, Asset, Income and Loan) over the
/// filtered entries: one strip on wide screens, two rows of two on narrow
/// ones.
class GeneralPaymentTotalsStrip extends StatelessWidget {
  const GeneralPaymentTotalsStrip(
      {super.key, required this.totals, required this.currency});
  final GeneralPaymentTotals totals;
  final String currency;

  static const _icons = {
    GeneralPaymentType.expense: Icons.receipt_long_outlined,
    GeneralPaymentType.asset: Icons.business_outlined,
    GeneralPaymentType.income: Icons.trending_up_rounded,
    GeneralPaymentType.loan: Icons.account_balance_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final metrics = [
      for (final type in GeneralPaymentType.values)
        AppMetric(
            key: ValueKey('general-payments-total-${type.name}'),
            icon: _icons[type]!,
            label: 'general_payments.total_${type.name}'.tr,
            value: generalPaymentMoney(currency, totals[type])),
    ];
    return LayoutBuilder(
        builder: (_, constraints) =>
            constraints.maxWidth < ListLayoutBreakpoints.cardsBelow
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    AppMetricStrip(metrics: metrics.sublist(0, 2)),
                    const SizedBox(height: AppSpacing.xs),
                    AppMetricStrip(metrics: metrics.sublist(2)),
                  ])
                : AppMetricStrip(metrics: metrics));
  }
}
