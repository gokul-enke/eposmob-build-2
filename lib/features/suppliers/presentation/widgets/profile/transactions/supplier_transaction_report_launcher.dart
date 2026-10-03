import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/screens/reports/supplier_transaction_report/supplier_transaction_report_print.dart';

import '../../../../domain/models/supplier.dart';

/// The print page's input: every transaction, their summed amount and the
/// span of their dates.
@immutable
class SupplierTransactionReportData {
  const SupplierTransactionReportData({
    required this.transactions,
    required this.formattedTotal,
    this.fromDate,
    this.toDate,
  });

  factory SupplierTransactionReportData.build(
    List<SupplierTransaction> transactions,
  ) {
    final format = DateFormat('yyyy-MM-dd');
    var total = 0.0;
    final dates = <DateTime>[];
    for (final transaction in transactions) {
      total += double.tryParse(transaction.amount) ?? 0.0;
      if (transaction.date.isEmpty) continue;
      try {
        dates.add(format.parse(transaction.date));
      } on FormatException {
        debugPrint('Error parsing date: ${transaction.date}');
      }
    }
    dates.sort();
    return SupplierTransactionReportData(
      transactions: transactions,
      formattedTotal: total.toStringAsFixed(2),
      fromDate: dates.isEmpty ? null : format.format(dates.first),
      toDate: dates.isEmpty ? null : format.format(dates.last),
    );
  }

  final List<SupplierTransaction> transactions;
  final String formattedTotal;
  final String? fromDate;
  final String? toDate;
}

/// Opens the supplier transaction report print page for [transactions].
/// Shows an error instead when there is nothing to print.
void openSupplierTransactionReport(
  BuildContext context, {
  required Supplier supplier,
  required List<SupplierTransaction> transactions,
}) {
  if (transactions.isEmpty) {
    AppToast.error(context, 'supplier_profile.trans_msg_no_transactions'.tr);
    return;
  }
  AppToast.info(context, 'supplier_profile.trans_msg_preparing_print'.tr);

  try {
    final data = SupplierTransactionReportData.build(transactions);
    final now = DateTime.now();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierTransactionReportPrint(
          cartItems: data.transactions,
          formattedTotal: data.formattedTotal,
          savedTotal: data.formattedTotal,
          orderDate: now.toIso8601String(),
          orderNumber: 'SUPP-${now.millisecondsSinceEpoch}',
          isFromLocalStorage: false,
          supplierName: supplier.name,
          supplierPhone: supplier.phone,
          supplierEmail: supplier.email,
          supplierAddress: supplier.address,
          fromDate: data.fromDate,
          toDate: data.toDate,
        ),
      ),
    );
  } catch (error) {
    debugPrint('Error preparing print: $error');
    AppToast.error(
      context,
      '${'supplier_profile.trans_msg_print_error'.tr} $error',
    );
  }
}
