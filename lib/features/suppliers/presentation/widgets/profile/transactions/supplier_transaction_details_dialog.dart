import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../../domain/models/supplier.dart';
import 'supplier_transaction_labels.dart';

/// Shows the fields of [transaction] (the old expandable card's body).
Future<void> showSupplierTransactionDetailsDialog(
  BuildContext context,
  SupplierTransaction transaction,
) {
  return AppDialog.show<void>(
    context,
    title: SupplierTransactionLabels.reference(transaction),
    subtitle: SupplierTransactionLabels.orNa(transaction.date),
    maxWidth: 520,
    child: SupplierTransactionDetails(transaction: transaction),
  );
}

/// Amount, status and label/value list for one supplier transaction.
class SupplierTransactionDetails extends StatelessWidget {
  const SupplierTransactionDetails({super.key, required this.transaction});

  final SupplierTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                SupplierTransactionLabels.amount(transaction),
                style: AppTextStyles.sectionTitle.copyWith(
                  fontSize: 18,
                  color: SupplierTransactionLabels.amountColor(transaction),
                ),
              ),
            ),
            SupplierTransactionStatusBadge(status: transaction.status),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        InfoGrid(
          minColumnWidth: 200,
          maxColumns: 2,
          children: [
            InfoRow(
              label: 'supplier_profile.trans_detail_type'.tr,
              value: SupplierTransactionLabels.orNa(
                transaction.transactionType,
              ),
            ),
            InfoRow(
              label: 'supplier_profile.trans_detail_payment_method'.tr,
              value: SupplierTransactionLabels.orNa(transaction.paymentMethod),
            ),
            InfoRow(
              label: 'supplier_profile.trans_detail_date'.tr,
              value: SupplierTransactionLabels.orNa(transaction.date),
            ),
          ],
        ),
      ],
    );
  }
}
