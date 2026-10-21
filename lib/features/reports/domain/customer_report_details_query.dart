import 'package:intl/intl.dart';
import 'package:pos_machine/models/list_transaction.dart';

/// Frozen selection and local filters for one details export.
class CustomerReportDetailsQuery {
  const CustomerReportDetailsQuery({
    required this.customerId,
    required this.customerName,
    this.transactionType = '',
    this.status = '',
    this.type = '',
    this.from = '',
    this.to = '',
  });

  final String customerId,
      customerName,
      transactionType,
      status,
      type,
      from,
      to;

  bool get hasCustomer => customerId.isNotEmpty || customerName.isNotEmpty;

  bool selects(Object? id, Object? name) => customerId.isNotEmpty
      ? id?.toString() == customerId
      : customerName.isNotEmpty &&
          name?.toString().toLowerCase() == customerName.toLowerCase();

  /// Matches the screen's contains filters and inclusive date boundaries.
  List<ListTransaction> filter(List<ListTransaction> rows) {
    bool contains(String? value, String filter) =>
        filter.isEmpty ||
        filter == 'All' ||
        (value ?? '').toLowerCase().contains(filter.toLowerCase());
    final formatter = DateFormat('yyyy-MM-dd');
    final start = from.isEmpty ? null : formatter.parse(from);
    final end =
        to.isEmpty ? null : formatter.parse(to).add(const Duration(days: 1));
    return List.unmodifiable(rows.where((row) {
      if (!contains(row.transactionType, transactionType) ||
          !contains(row.status, status) ||
          !contains(row.type, type)) {
        return false;
      }
      if (start == null && end == null) return true;
      if (row.date == null) return false;
      try {
        final date = formatter.parse(row.date!);
        return (start == null || !date.isBefore(start)) &&
            (end == null || date.isBefore(end));
      } on FormatException {
        return false;
      }
    }));
  }

  @override
  bool operator ==(Object other) =>
      other is CustomerReportDetailsQuery &&
      customerId == other.customerId &&
      customerName == other.customerName &&
      transactionType == other.transactionType &&
      status == other.status &&
      type == other.type &&
      from == other.from &&
      to == other.to;

  @override
  int get hashCode => Object.hash(
      customerId, customerName, transactionType, status, type, from, to);
}
