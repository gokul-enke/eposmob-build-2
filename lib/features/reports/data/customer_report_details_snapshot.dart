import 'package:pos_machine/models/list_transaction.dart';
import 'package:pos_machine/services/customer_ledger_snapshot.dart';

import '../domain/customer_report_details_query.dart';

/// Isolated all-page read: outer pagination counts customer groups in the new
/// response, and transactions in the legacy flat response.
/// Rejects declarations above 1,000 pages instead of truncating the export.
Future<List<ListTransaction>> fetchCustomerReportDetailsSnapshot(
  Future<dynamic> Function(int page) fetch,
  CustomerReportDetailsQuery query, {
  void Function(int page, int last)? onProgress,
}) async {
  if (!query.hasCustomer) throw StateError('No customer selected.');
  final rows = <ListTransaction>[];
  final groupIds = <int>{}, transactionIds = <int>{}, selectedIds = <int>{};
  int? last, total, perPage;
  bool? grouped;
  var rawCount = 0;
  for (var page = 1;; page++) {
    final response = await fetch(page);
    if (response is! Map ||
        response['status'] != 'success' ||
        response['data'] is! Map) {
      throw const FormatException('Customer details request failed.');
    }
    final data = response['data'] as Map;
    final current = CustomerLedgerPage.integer(data['current_page']);
    final nextLast = CustomerLedgerPage.integer(data['last_page']);
    final nextTotal = CustomerLedgerPage.integer(data['total']);
    final nextPerPage = CustomerLedgerPage.integer(data['per_page']);
    final raw = data['data'];
    if (current != page ||
        nextLast == null ||
        nextLast < page ||
        nextLast > 1000 ||
        raw is! List ||
        (data['total'] != null && (nextTotal == null || nextTotal < 0)) ||
        (data['per_page'] != null &&
            (nextPerPage == null ||
                nextPerPage < 1 ||
                raw.length > nextPerPage)) ||
        (raw.isEmpty && (page > 1 || nextLast > 1 || (nextTotal ?? 0) > 0))) {
      throw const FormatException('Invalid customer details pagination.');
    }
    final nextGrouped = raw.isEmpty
        ? (grouped ?? true)
        : raw.first is Map && (raw.first as Map).containsKey('transactions');
    if (last != null &&
        (last != nextLast ||
            total != nextTotal ||
            perPage != nextPerPage ||
            grouped != nextGrouped)) {
      throw const FormatException('Customer details changed during export.');
    }
    last = nextLast;
    total = nextTotal;
    perPage = nextPerPage;
    grouped = nextGrouped;
    rawCount += raw.length;
    if (grouped) {
      for (final value in raw) {
        if (value is! Map) {
          throw const FormatException('Invalid customer group.');
        }
        final id = CustomerLedgerPage.integer(value['customer_id']);
        if (id == null || id <= 0 || !groupIds.add(id)) {
          throw const FormatException(
              'Invalid or overlapping customer groups.');
        }
        if (!query.selects(id, value['customer_name'])) continue;
        selectedIds.add(id);
        if (selectedIds.length > 1) {
          throw const FormatException(
              'Customer name identifies multiple customers.');
        }
        final transactions = value['transactions'];
        final declaredCount =
            value['transaction_count'] ?? value['transactions_count'];
        if (transactions is! List ||
            (declaredCount != null &&
                CustomerLedgerPage.integer(declaredCount) !=
                    transactions.length)) {
          throw const FormatException('Incomplete customer transactions.');
        }
        final nested = <Map<String, dynamic>>[];
        for (final transaction in transactions) {
          if (transaction is! Map ||
              (transaction['customer_id'] != null &&
                  CustomerLedgerPage.integer(transaction['customer_id']) !=
                      id)) {
            throw const FormatException('Invalid transaction customer.');
          }
          nested.add({
            ...Map<String, dynamic>.from(transaction),
            'customer_id': id,
            'customer_name': value['customer_name'],
            'reference_id':
                transaction['reference_id'] ?? transaction['reference'],
          });
        }
        // Reuse the existing financial/date/identifier validation on nested rows.
        final parsed = CustomerLedgerPage.parse({
          'status': 'success',
          'data': {
            'data': nested,
            'current_page': 1,
            'last_page': 1,
            'total': nested.length
          }
        }, 1);
        for (final row in parsed.rows) {
          if (!transactionIds.add(row.id!)) {
            throw const FormatException('Overlapping customer transactions.');
          }
          rows.add(row);
        }
      }
    } else {
      final parsed = CustomerLedgerPage.parse(response, page);
      for (final row in parsed.rows) {
        if (!transactionIds.add(row.id!)) {
          throw const FormatException('Overlapping customer transactions.');
        }
        if (query.selects(row.customerId, row.customerName)) {
          if (row.customerId != null) selectedIds.add(row.customerId!);
          if (selectedIds.length > 1) {
            throw const FormatException(
                'Customer name identifies multiple customers.');
          }
          rows.add(row);
        }
      }
    }
    onProgress?.call(page, last);
    if (page == last) break;
  }
  if (total != null && rawCount != total) {
    throw const FormatException('Incomplete customer details pages.');
  }
  return query.filter(rows);
}
