import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/models/list_transaction.dart';
import 'package:pos_machine/screens/transactions/widgets/common_details_dialog.dart';

/// Renders the existing transaction row without provider or API access.
class CustomerLedgerDetailsDialog extends StatelessWidget {
  const CustomerLedgerDetailsDialog({
    super.key,
    required this.transaction,
    required this.paymentLabel,
  });

  final ListTransaction transaction;
  final String paymentLabel;

  @override
  Widget build(BuildContext context) => CommonDetailsDialog(
        title: 'party_accounts.dialog_title'.tr,
        gridColumns: [
          [
            CommonDetailsDialog.buildKeyValueRow(
                'party_accounts.customer_name'.tr,
                transaction.customerName ?? 'party_accounts.no_name'.tr),
            CommonDetailsDialog.buildKeyValueRow('party_accounts.date'.tr,
                transaction.date ?? 'party_accounts.na'.tr),
            CommonDetailsDialog.buildKeyValueRow(
                'party_accounts.type'.tr,
                UiCodeLabels.documentKind(
                    transaction.type ?? 'party_accounts.na'.tr)),
            CommonDetailsDialog.buildKeyValueRow(
                'party_accounts.transaction_type'.tr,
                UiCodeLabels.documentKind(
                    transaction.transactionType ?? 'party_accounts.na'.tr)),
            CommonDetailsDialog.buildKeyValueRow(
              'party_accounts.payment_method'.tr,
              paymentLabel,
            ),
          ],
          [
            CommonDetailsDialog.buildKeyValueRow('party_accounts.amount'.tr,
                '${transaction.currency ?? ''} ${transaction.amount ?? ''}'),
            CommonDetailsDialog.buildKeyValueRow(
                'party_accounts.reference_id'.tr,
                transaction.referenceId ?? 'party_accounts.na'.tr,
                copyable: true),
            CommonDetailsDialog.buildKeyValueRow('party_accounts.reference'.tr,
                transaction.reference ?? 'party_accounts.na'.tr,
                copyable: true),
            CommonDetailsDialog.buildKeyValueRow('party_accounts.status'.tr,
                transaction.status ?? 'party_accounts.na'.tr),
            CommonDetailsDialog.buildKeyValueRow('party_accounts.comment'.tr,
                transaction.transactionComment ?? 'party_accounts.na'.tr),
            CommonDetailsDialog.buildKeyValueRow(
              'party_accounts.created_at'.tr,
              transaction.createdAt != null
                  ? DateHelper.formatDate(transaction.createdAt!)
                  : 'party_accounts.na'.tr,
            ),
          ],
        ],
      );
}
