import 'package:pos_machine/models/list_transaction.dart';

/// Strict page parsing prevents partial or overlapping ledger exports.
class CustomerLedgerPage {
  CustomerLedgerPage(this.rows, this.current, this.last, this.total);
  final List<ListTransaction> rows;
  final int current, last;
  final int? total;

  static int? integer(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');

  static bool validDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null || value.length < 10) return false;
    final canonical =
        '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    return value.substring(0, 10) == canonical;
  }

  factory CustomerLedgerPage.parse(dynamic response, int requested) {
    if (response is! Map ||
        response['status'] != 'success' ||
        response['data'] is! Map) {
      throw const FormatException('Customer transactions request failed.');
    }
    final data = response['data'] as Map;
    final current = integer(data['current_page']);
    final last = integer(data['last_page']);
    final total = integer(data['total']);
    final raw = data['data'];
    if (current != requested ||
        last == null ||
        last < requested ||
        raw is! List ||
        (data['total'] != null && (total == null || total < 0)) ||
        (raw.isEmpty && (requested > 1 || last > 1 || (total ?? 0) > 0))) {
      throw const FormatException('Invalid customer transaction pagination.');
    }
    final ids = <int>{};
    final rows = <ListTransaction>[];
    for (final value in raw) {
      if (value is! Map) throw const FormatException('Invalid ledger row.');
      final row = Map<String, dynamic>.from(value);
      final id = integer(row['id']);
      final amount = double.tryParse(row['amount']?.toString() ?? '');
      final date = row['date'];
      if (id == null ||
          id <= 0 ||
          !ids.add(id) ||
          amount == null ||
          !amount.isFinite ||
          date is! String ||
          !validDate(date)) {
        throw const FormatException('Invalid or duplicate ledger row.');
      }
      for (final key in ['id', 'order_id', 'customer_id']) {
        if (row[key] != null) {
          final parsed = integer(row[key]);
          if (parsed == null) {
            throw const FormatException('Invalid ledger identifier.');
          }
          row[key] = parsed;
        }
      }
      for (final key in [
        'amount',
        'balance',
        'reference_id',
        'reference',
        'order_number'
      ]) {
        if (row[key] != null) row[key] = row[key].toString();
      }
      if (row['payment_method'] is num) {
        row['payment_method'] = row['payment_method'].toString();
      }
      rows.add(ListTransaction.fromJson(row));
    }
    if (total != null && rows.length > total) {
      throw const FormatException('Invalid ledger total.');
    }
    return CustomerLedgerPage(rows, current!, last, total);
  }
}

Future<List<ListTransaction>> fetchCustomerLedgerSnapshot(
    Future<dynamic> Function(int page) fetch,
    {void Function(int, int)? onProgress}) async {
  final rows = <ListTransaction>[];
  final ids = <int>{};
  int? last, total;
  for (var page = 1;; page++) {
    final result = CustomerLedgerPage.parse(await fetch(page), page);
    if (last != null && (last != result.last || total != result.total)) {
      throw const FormatException('Customer ledger changed during export.');
    }
    last = result.last;
    total = result.total;
    for (final row in result.rows) {
      if (!ids.add(row.id!)) {
        throw const FormatException('Overlapping ledger pages.');
      }
      rows.add(row);
    }
    onProgress?.call(page, last);
    if (page == last) break;
  }
  if (total != null && rows.length != total) {
    throw const FormatException('Incomplete customer ledger.');
  }
  return List.unmodifiable(rows);
}
