import 'package:intl/intl.dart';

/// Raw controls captured together. API normalization remains compatible with
/// InvoiceProvider so existing consumers and backend parameters do not change.
class InvoiceListQuery {
  const InvoiceListQuery(
      {this.name = '',
      this.invoiceNumber = '',
      this.orderNumber = '',
      this.phone = '',
      this.fromDate = '',
      this.toDate = '',
      this.status,
      this.zatcaStatus});
  final String name, invoiceNumber, orderNumber, phone, fromDate, toDate;
  final String? status, zatcaStatus;
  bool get isActive =>
      [name, invoiceNumber, orderNumber, phone, fromDate, toDate]
          .any((s) => s.isNotEmpty) ||
      status != null ||
      zatcaStatus != null;
}

String? normalizeInvoiceFilter(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

/// Text format the From/To date fields hold; the picker and Today share it.
final invoiceFilterDateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

/// The Today toggle's range, in the same text format the date pickers write.
/// The toggle reads as on only while both fields hold exactly this range.
({String from, String to}) invoiceTodayRange(DateTime now) {
  final start = DateTime(now.year, now.month, now.day);
  final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
  return (
    from: invoiceFilterDateTimeFormat.format(start),
    to: invoiceFilterDateTimeFormat.format(end),
  );
}

String? formatInvoiceApiDate(String? value) {
  final normalized = normalizeInvoiceFilter(value);
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

String? mapInvoiceZatcaStatusToApi(String? value) {
  final normalized = normalizeInvoiceFilter(value)?.toLowerCase();
  switch (normalized) {
    case 'sent':
    case 'success':
      return 'sent';
    case 'not sent':
    case 'not_sent':
      return 'not_sent';
    case 'failed':
    case 'fail':
      return 'failed';
    default:
      return null;
  }
}
