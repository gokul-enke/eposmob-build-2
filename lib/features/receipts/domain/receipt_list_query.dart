import 'package:pos_machine/models/list_receipt.dart';

/// Raw page inputs; matching and date transport retain the existing rules.
class ReceiptListQuery {
  const ReceiptListQuery(
      {this.name = '',
      this.receiptNumber = '',
      this.paymentReference = '',
      this.phone = '',
      this.email = '',
      this.fromDate = '',
      this.toDate = '',
      this.status,
      this.paymentMethod});
  final String name,
      receiptNumber,
      paymentReference,
      phone,
      email,
      fromDate,
      toDate;
  final String? status, paymentMethod;
  bool get isActive =>
      [name, receiptNumber, paymentReference, phone, email, fromDate, toDate]
          .any((value) => value.isNotEmpty) ||
      status != null ||
      paymentMethod != null;
}

String receiptTypeKey(Receipt r) {
  final invoice = r.receiptPayments.any((p) => p.invoiceId != null);
  final general = r.receiptPayments.any((p) => p.invoiceId == null);
  return invoice && general
      ? 'receipt.type_mixed'
      : invoice
          ? 'receipt.type_invoice_payment'
          : 'receipt.type_general_payment';
}

String? normalizeReceiptFilter(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String? formatReceiptApiDate(String? value) {
  final normalized = normalizeReceiptFilter(value);
  if (normalized == null) {
    return null;
  }

  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    return normalized;
  }

  final parts = normalized.split('/');
  if (parts.length == 3) {
    final day = parts[0].padLeft(2, '0');
    final month = parts[1].padLeft(2, '0');
    final year = parts[2];
    return '$year-$month-$day';
  }

  return normalized;
}

List<Receipt> matchReceiptList(
  List<Receipt> rows, {
  String? filterName,
  String? filterReceiptNumber,
  String? filterPaymentReference,
  String? filterStatus,
  String? filterPaymentMethod,
  String? filterPhone,
  String? filterEmail,
}) {
  bool contains(String value, String? filter) {
    final normalized = normalizeReceiptFilter(filter);
    return normalized == null ||
        value.toLowerCase().contains(normalized.toLowerCase());
  }

  bool equal(String value, String? filter) {
    final normalized = normalizeReceiptFilter(filter);
    return normalized == null ||
        value.toLowerCase() == normalized.toLowerCase();
  }

  return rows
      .where((r) =>
          contains(r.customer.user.name, filterName) &&
          contains(r.receiptNumber, filterReceiptNumber) &&
          contains(r.paymentReference, filterPaymentReference) &&
          contains(r.customer.user.phone, filterPhone) &&
          contains(r.customer.user.email, filterEmail) &&
          equal(r.receiptStatus, filterStatus) &&
          (normalizeReceiptFilter(filterPaymentMethod) == null ||
              r.paymentMethods
                  .any((method) => equal(method, filterPaymentMethod))))
      .toList();
}
