import 'package:pos_machine/models/sales_executive_report.dart';

const _amountKeys = [
  'total_sales',
  'totalSales',
  'online_sales',
  'onlineSales',
  'upi_sales',
  'upiSales',
  'card_sales',
  'cardSales',
  'cash_sales',
  'cashSales',
  'credit_sales',
  'creditSales',
  'collected_sales',
  'collectedSales',
  'total_payment_received',
  'payment_received',
  'totalPaymentReceived',
  'credit_collected_prev',
  'prev_balance_collected',
  'creditCollectedPrev',
  'total_collected_on_sale',
  'totalCollectedOnSale',
];

/// Validates a My Sales Report response and returns its rows. Throws
/// [FormatException] for a failed request or any non-numeric amount, so a
/// bad response never shows as a report of zeros.
List<SalesExecutiveReportData> parseMySalesReport(dynamic response) {
  if (response is! Map<String, dynamic> ||
      response['status'] != 'success' ||
      response['data'] is! List) {
    throw const FormatException('Invalid My Sales Report response.');
  }
  for (final row in response['data'] as List) {
    if (row is! Map<String, dynamic>) {
      throw const FormatException('Invalid sales report row.');
    }
    for (final key in _amountKeys) {
      final value = row[key];
      if (value == null) continue;
      final amount = double.tryParse(value.toString());
      if (amount == null || !amount.isFinite) {
        throw const FormatException('Invalid sales report amount.');
      }
    }
    final count = row['order_count'] ?? row['orderCount'];
    if (count != null &&
        (int.tryParse(count.toString()) == null ||
            int.parse(count.toString()) < 0)) {
      throw const FormatException('Invalid sales report order count.');
    }
    final breakdown = row['payment_breakdown'];
    if (breakdown != null &&
        breakdown is! Map &&
        !(breakdown is List && breakdown.isEmpty)) {
      throw const FormatException('Invalid payment breakdown.');
    }
    if (breakdown is Map) {
      for (final key in ['UPI', 'CARD']) {
        final value = breakdown[key];
        if (value != null) {
          final amount = double.tryParse(value.toString());
          if (amount == null || !amount.isFinite) {
            throw const FormatException('Invalid payment breakdown amount.');
          }
        }
      }
    }
  }
  return List.unmodifiable(
      SalesExecutiveReportModel.fromJson(response).data ?? []);
}
