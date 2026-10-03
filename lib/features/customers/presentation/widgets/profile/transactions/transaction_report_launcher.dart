import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/screens/reports/customer_transactions_reports/transaction_report_print.dart';

import '../../../../domain/models/customer_list.dart';
import '../../../state/customer_transactions_controller.dart';

/// The print page's input, built from the visible transactions.
@immutable
class TransactionReportData {
  const TransactionReportData({
    required this.rows,
    required this.formattedTotal,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.customerAddress,
    this.fromDate,
    this.toDate,
  });

  factory TransactionReportData.build({
    required CustomerListModelData customer,
    required List<CustomerTransaction> transactions,
    required TransactionTotals totals,
    DateTimeRange? range,
  }) {
    final address = [
      customer.address,
      customer.city,
      customer.state,
      customer.pincode,
      customer.country,
    ].whereType<String>().where((part) => part.isNotEmpty).join(', ');

    return TransactionReportData(
      rows: [
        for (final transaction in transactions)
          {
            'id': transaction.id,
            'order_id': transaction.orderId,
            'order_number': transaction.orderNumber,
            'payment_method': transaction.paymentMethod,
            'date': transaction.date,
            'type': transaction.type,
            'reference_id': transaction.referenceId,
            'transaction_type': transaction.transactionType,
            'amount': transaction.amount,
            'currency': transaction.currency,
            'reference': transaction.reference,
            'transaction_comment': transaction.transactionComment,
            'status': transaction.status,
          },
      ],
      formattedTotal: totals.net.toStringAsFixed(2),
      customerName: customer.name ?? '',
      customerPhone: customer.phone ?? '',
      customerEmail: customer.email ?? '',
      customerAddress: address,
      fromDate: range == null
          ? null
          : CustomerTransactionsController.formatApiDate(range.start),
      toDate: range == null
          ? null
          : CustomerTransactionsController.formatApiDate(range.end),
    );
  }

  final List<Map<String, dynamic>> rows;
  final String formattedTotal;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String customerAddress;
  final String? fromDate;
  final String? toDate;
}

/// Opens the transaction report print page for [data], showing
/// "preparing" messages.
void openTransactionReport(BuildContext context, TransactionReportData data) {
  void notify(String key) => AppToast.info(context, key.tr);

  notify('customer_transactions.msg_preparing_report');
  final now = DateHelper.now();
  Get.to(() => TransactionReportPrintPage(
        cartItems: data.rows,
        formattedTotal: data.formattedTotal,
        savedTotal: 0.0.toStringAsFixed(2),
        orderDate: DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
        orderNumber: 'TXN-REPORT-${now.millisecondsSinceEpoch}',
        customerName: data.customerName,
        customerPhone: data.customerPhone,
        customerEmail: data.customerEmail,
        customerAddress: data.customerAddress,
        fromDate: data.fromDate,
        toDate: data.toDate,
        isFromLocalStorage: false,
        returnToPreviousRoute: true,
      ));
  notify('customer_transactions.msg_preparing_print');
}
