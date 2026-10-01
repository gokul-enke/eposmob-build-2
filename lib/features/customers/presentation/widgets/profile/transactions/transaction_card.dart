import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../../domain/models/customer_list.dart';
import 'transaction_labels.dart';

/// Card for one transaction on narrow layouts.
class TransactionCard extends StatelessWidget {
  const TransactionCard({
    super.key,
    required this.transaction,
    required this.rowNumber,
    required this.onView,
  });

  final CustomerTransaction transaction;
  final int rowNumber;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return AppListCard(
      leading: TransactionTypeIcon(type: transaction.type),
      title: TransactionLabels.reference(transaction),
      subtitle: '#$rowNumber · ${TransactionLabels.date(transaction)}',
      trailing: TransactionStatusBadge(status: transaction.status),
      body: AppMetricStrip(
        metrics: [
          AppMetric(
            icon: Icons.payments_outlined,
            label: 'customer_profile.label_amount'.tr,
            value: TransactionLabels.amount(transaction),
            valueColor: TransactionLabels.amountColor(transaction),
          ),
          AppMetric(
            icon: Icons.credit_card_outlined,
            label: 'customer_transactions.label_payment_method'.tr,
            value: TransactionLabels.orNa(transaction.paymentMethod),
          ),
        ],
      ),
      actionLabel: 'general.view_details'.tr,
      actionIcon: Icons.visibility_outlined,
      onAction: onView,
      onTap: onView,
    );
  }
}
