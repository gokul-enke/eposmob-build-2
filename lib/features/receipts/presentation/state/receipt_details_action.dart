import 'package:flutter/material.dart';
import 'package:pos_machine/models/list_receipt.dart';
import '../widgets/receipt_details_dialog.dart';

mixin ReceiptRowActions<T extends StatefulWidget> on State<T> {
  void showReceiptDetails(Receipt receipt) {
    showDialog(
      context: context,
      builder: (context) => ReceiptDetailsDialog(receipt: receipt),
    );
  }
}
