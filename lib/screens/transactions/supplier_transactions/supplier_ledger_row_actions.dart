import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/models/transaction_model.dart';
import '../widgets/common_details_dialog.dart';

mixin SupplierLedgerRowActions<T extends StatefulWidget> on State<T> {
  void showTransactionDetails(TransactionModel transaction) {
    showDialog(
      context: context,
      builder: (context) => CommonDetailsDialog(
        title: 'supplier_transactions.dialog_title'.tr,
        gridColumns: [
          [
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_transactions.supplier_name'.tr,
                transaction.supplier.user.name),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_transactions.date'.tr,
                DateHelper.formatISODate(transaction.date)),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_transactions.type'.tr,
                UiCodeLabels.documentKind(transaction.type)),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_transactions.transaction_type'.tr,
                UiCodeLabels.documentKind(transaction.transactionType)),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_transactions.payment_mode'.tr,
                UiCodeLabels.payment(transaction.paymentMode)),
          ],
          [
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_transactions.amount'.tr,
                '${transaction.currency} ${transaction.amount}'),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_transactions.tax_amount'.tr,
                transaction.taxAmount ?? 'supplier_transactions.na'.tr),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_transactions.reference'.tr, transaction.reference,
                copyable: true),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_transactions.status'.tr, transaction.status),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_transactions.comment'.tr,
                transaction.transactionComment ??
                    'supplier_transactions.na'.tr),
          ],
        ],
      ),
    );
  }
}
