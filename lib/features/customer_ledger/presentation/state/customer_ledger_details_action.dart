import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/models/list_transaction.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import '../widgets/customer_ledger_details_dialog.dart';

/// Resolves the existing payment label and opens the row's details view.
mixin CustomerLedgerRowActions<T extends StatefulWidget> on State<T> {
  void showCustomerLedgerDetails(ListTransaction transaction) {
    final masterData = context.read<MasterDataProvider>();
    final paymentId = int.tryParse(transaction.paymentMethod ?? '');
    final paymentLabel = (paymentId != null
            ? masterData.getPaymentMethodValue(paymentId)
            : null) ??
        transaction.paymentMethod ??
        'party_accounts.na'.tr;

    showDialog(
      context: context,
      builder: (context) => CustomerLedgerDetailsDialog(
        transaction: transaction,
        paymentLabel: paymentLabel,
      ),
    );
  }
}
