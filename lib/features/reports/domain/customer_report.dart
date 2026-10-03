import 'package:pos_machine/services/customer_ledger_snapshot.dart';

/// One customer's totals in the Customer Transactions Report.
class CustomerReportRow {
  const CustomerReportRow(
      {required this.id,
      required this.name,
      required this.debit,
      required this.credit,
      required this.balance,
      required this.count});
  final String? id;
  final String name;
  final double debit, credit, balance;
  final int count;
}

/// One validated page of the report API. The API returns either customer
/// groups (`total_debit`, `transactions`…) or, on older servers, the flat
/// ledger, which is grouped here by customer.
class CustomerReportPage {
  CustomerReportPage(this.rows, this.current, this.last, this.total,
      this.perPage, this.grouped, this.raw);
  final List<CustomerReportRow> rows;
  final int current, last, perPage;
  final int? total;
  final bool grouped;
  final List<dynamic> raw;

  factory CustomerReportPage.parse(dynamic response, int requested) {
    if (response is! Map ||
        response['status'] != 'success' ||
        response['data'] is! Map) {
      throw const FormatException('Customer report request failed.');
    }
    final data = response['data'] as Map;
    final current = CustomerLedgerPage.integer(data['current_page']);
    final last = CustomerLedgerPage.integer(data['last_page']);
    final total = CustomerLedgerPage.integer(data['total']);
    final perPage = CustomerLedgerPage.integer(data['per_page'] ?? 20);
    final raw = data['data'];
    if (current != requested ||
        last == null ||
        last < requested ||
        perPage == null ||
        perPage < 1 ||
        raw is! List ||
        (data['total'] != null && (total == null || total < 0)) ||
        (raw.isEmpty && (requested > 1 || last > 1 || (total ?? 0) > 0)) ||
        (total != null && raw.length > total)) {
      throw const FormatException('Invalid customer report pagination.');
    }
    final grouped = raw.isEmpty ||
        (raw.first is Map &&
            ((raw.first as Map).containsKey('total_debit') ||
                (raw.first as Map).containsKey('transactions')));
    final rows = grouped ? _groups(raw) : fromLedger(response, requested);
    return CustomerReportPage(List.unmodifiable(rows), current!, last, total,
        perPage, grouped, List.unmodifiable(raw));
  }

  static double _money(Object? value) {
    final amount = double.tryParse(value?.toString() ?? '');
    if (amount == null || !amount.isFinite) {
      throw const FormatException('Invalid customer report amount.');
    }
    return amount;
  }

  static List<CustomerReportRow> _groups(List raw) {
    final ids = <String>{};
    return raw.map((value) {
      if (value is! Map) throw const FormatException('Invalid customer group.');
      String? id;
      if (value['customer_id'] != null) {
        final parsed = CustomerLedgerPage.integer(value['customer_id']);
        if (parsed == null || parsed <= 0 || !ids.add('$parsed')) {
          throw const FormatException(
              'Invalid or duplicate customer identifier.');
        }
        id = '$parsed';
      }
      final countValue = value['transaction_count'] ??
          value['transactions_count'] ??
          (value['transactions'] is List
              ? (value['transactions'] as List).length
              : null);
      final count = CustomerLedgerPage.integer(countValue);
      if (count == null || count < 0) {
        throw const FormatException('Invalid customer transaction count.');
      }
      return CustomerReportRow(
          id: id,
          name: value['customer_name']?.toString().trim() ?? '',
          debit: _money(value['total_debit']),
          credit: _money(value['total_credit']),
          balance: _money(value['balance']),
          count: count);
    }).toList();
  }

  /// Groups a flat ledger response (one row per transaction) by customer.
  static List<CustomerReportRow> fromLedger(dynamic response, int page) {
    final ledger = CustomerLedgerPage.parse(response, page);
    final groups = <String, CustomerReportRow>{};
    for (final row in ledger.rows) {
      final id = row.customerId?.toString();
      final name = row.customerName?.trim() ?? '';
      final key = id ?? 'name:$name';
      final previous = groups[key];
      final type = row.type?.toLowerCase();
      if (!['credit', 'cr', 'debit', 'dr'].contains(type)) {
        throw const FormatException('Invalid customer transaction type.');
      }
      final amount = _money(row.amount);
      groups[key] = CustomerReportRow(
          id: id,
          name: name,
          debit: (previous?.debit ?? 0) +
              (type == 'debit' || type == 'dr' ? amount : 0),
          credit: (previous?.credit ?? 0) +
              (type == 'credit' || type == 'cr' ? amount : 0),
          balance: previous?.balance ?? _money(row.balance),
          count: (previous?.count ?? 0) + 1);
    }
    return groups.values.toList();
  }
}
