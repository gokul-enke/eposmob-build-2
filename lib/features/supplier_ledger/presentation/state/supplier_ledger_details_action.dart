import 'package:flutter/material.dart';
import 'package:pos_machine/models/transaction_model.dart';
import '../widgets/supplier_ledger_details_dialog.dart';

/// Opens details for a record supplied by the desktop or mobile list.
mixin SupplierLedgerRowActions<T extends StatefulWidget> on State<T> {
  void showTransactionDetails(TransactionModel transaction) {
    showDialog(
      context: context,
      builder: (context) =>
          SupplierLedgerDetailsDialog(transaction: transaction),
    );
  }
}
