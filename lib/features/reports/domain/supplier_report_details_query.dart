import 'package:intl/intl.dart';
import 'package:pos_machine/features/suppliers/domain/models/supplier.dart';

import 'supplier_report.dart';

typedef SupplierReportDetailsSelection = ({String id, String name});

/// Captured View filters. Defaults and predicates match the legacy report.
class SupplierReportDetailsQuery {
  const SupplierReportDetailsQuery({
    required this.supplier,
    this.from = '',
    this.to = '',
    this.type = 'All',
    this.payment = 'All',
    this.search = '',
  });

  final SupplierReportDetailsSelection supplier;
  final String from, to, type, payment, search;
  bool get hasSupplier => supplier.id.isNotEmpty || supplier.name.isNotEmpty;
  bool get isDateRangeValid =>
      SupplierReportQuery(fromDate: from, toDate: to).isDateRangeValid;

  List<SupplierTransaction> apply(Iterable<SupplierTransaction> rows) =>
      List.unmodifiable(rows.where((row) {
        if (from.isNotEmpty || to.isNotEmpty) {
          if (row.date.isEmpty) return false;
          try {
            final format = DateFormat('yyyy-MM-dd');
            final date = format.parse(row.date);
            if (from.isNotEmpty && date.isBefore(format.parse(from))) {
              return false;
            }
            if (to.isNotEmpty &&
                !date.isBefore(format.parse(to).add(const Duration(days: 1)))) {
              return false;
            }
          } catch (_) {
            return false;
          }
        }
        if (type != 'All' && row.type.toLowerCase() != type.toLowerCase()) {
          return false;
        }
        if (payment != 'All' &&
            row.paymentMethod.toLowerCase() != payment.toLowerCase()) {
          return false;
        }
        final text = search.toLowerCase();
        return text.isEmpty ||
            row.reference.toLowerCase().contains(text) ||
            row.transactionType.toLowerCase().contains(text) ||
            row.amount.toLowerCase().contains(text);
      }));

  @override
  bool operator ==(Object other) =>
      other is SupplierReportDetailsQuery &&
      supplier == other.supplier &&
      from == other.from &&
      to == other.to &&
      type == other.type &&
      payment == other.payment &&
      search == other.search;
  @override
  int get hashCode => Object.hash(supplier, from, to, type, payment, search);
}
