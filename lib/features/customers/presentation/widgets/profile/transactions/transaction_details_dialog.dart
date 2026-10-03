import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../../domain/models/customer_list.dart';
import 'transaction_labels.dart';

/// Shows every field of [transaction] (the old expandable card's body).
Future<void> showTransactionDetailsDialog(
  BuildContext context,
  CustomerTransaction transaction,
) {
  return AppDialog.show<void>(
    context,
    title: TransactionLabels.reference(transaction),
    subtitle: TransactionLabels.date(transaction),
    maxWidth: 520,
    child: TransactionDetails(transaction: transaction),
  );
}

/// Label/value list for one transaction.
class TransactionDetails extends StatelessWidget {
  const TransactionDetails({super.key, required this.transaction});

  final CustomerTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final comment = transaction.transactionComment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                TransactionLabels.amount(transaction),
                style: AppTextStyles.sectionTitle.copyWith(
                  fontSize: 18,
                  color: TransactionLabels.amountColor(transaction),
                ),
              ),
            ),
            TransactionStatusBadge(status: transaction.status),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        InfoGrid(
          minColumnWidth: 200,
          maxColumns: 2,
          children: [
            InfoRow(
              label: 'customer_transactions.label_transaction_id'.tr,
              value: TransactionLabels.orNa(transaction.id?.toString()),
            ),
            InfoRow(
              label: 'customer_transactions.label_reference'.tr,
              value: TransactionLabels.orNa(transaction.reference),
            ),
            InfoRow(
              label: 'customer_transactions.label_type'.tr,
              value: TransactionLabels.orNa(transaction.type),
            ),
            InfoRow(
              label: 'customer_transactions.label_payment_method'.tr,
              value: TransactionLabels.orNa(transaction.paymentMethod),
            ),
            if (comment != null)
              InfoRow(
                label: 'customer_transactions.label_comment'.tr,
                value: comment,
              ),
          ],
        ),
      ],
    );
  }
}
