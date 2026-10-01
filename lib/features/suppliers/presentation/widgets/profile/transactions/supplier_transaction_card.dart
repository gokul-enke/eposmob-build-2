import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../../domain/models/supplier.dart';
import 'supplier_transaction_labels.dart';

/// Card for one supplier transaction on narrow layouts.
class SupplierTransactionCard extends StatelessWidget {
  const SupplierTransactionCard({
    super.key,
    required this.transaction,
    required this.rowNumber,
    required this.onView,
  });

  final SupplierTransaction transaction;
  final int rowNumber;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return AppListCard(
      leading: SupplierTransactionTypeIcon(type: transaction.type),
      title: SupplierTransactionLabels.reference(transaction),
      subtitle:
          '#$rowNumber · ${SupplierTransactionLabels.orNa(transaction.date)}',
      trailing: SupplierTransactionStatusBadge(status: transaction.status),
      body: AppMetricStrip(
        metrics: [
          AppMetric(
            icon: Icons.payments_outlined,
            label: 'supplier_profile.col_amount'.tr,
            value: SupplierTransactionLabels.amount(transaction),
            valueColor: SupplierTransactionLabels.amountColor(transaction),
          ),
          AppMetric(
            icon: Icons.credit_card_outlined,
            label: 'supplier_profile.trans_detail_payment_method'.tr,
            value: SupplierTransactionLabels.orNa(transaction.paymentMethod),
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
