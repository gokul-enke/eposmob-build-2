import 'package:pos_machine/services/customer_ledger_snapshot.dart';

import '../domain/customer_report.dart';

/// Loads one page of the Customer Transactions Report API.
typedef CustomerReportPageFetch = Future<dynamic> Function(int page);

/// Reads every page of the report for an export. Independent of the page on
/// screen; fails rather than saving partial or overlapping data.
Future<List<CustomerReportRow>> fetchCustomerReportSnapshot(
    CustomerReportPageFetch fetch,
    {void Function(int page, int total)? progress}) async {
  final first = CustomerReportPage.parse(await fetch(1), 1);
  final pages = [first];
  final ids = <String>{};
  void check(CustomerReportPage page) {
    if (page.last != first.last ||
        page.total != first.total ||
        page.grouped != first.grouped ||
        page.perPage != first.perPage) {
      throw const FormatException('Customer report changed during export.');
    }
    for (final value in page.raw) {
      final rawId = (value as Map)[first.grouped ? 'customer_id' : 'id'];
      // Anonymous groups have no stable identity to check across pages.
      if (rawId == null && first.grouped) {
        if (first.last > 1) {
          throw const FormatException('Missing customer identifier.');
        }
        continue;
      }
      final id = CustomerLedgerPage.integer(rawId);
      if (id == null || id <= 0 || !ids.add('$id')) {
        throw const FormatException('Duplicate customer report row.');
      }
    }
  }

  check(first);
  progress?.call(1, first.last);
  for (var page = 2; page <= first.last; page++) {
    final next = CustomerReportPage.parse(await fetch(page), page);
    check(next);
    pages.add(next);
    progress?.call(page, first.last);
  }
  final raw = pages.expand((p) => p.raw).toList();
  if (first.total != null && raw.length != first.total) {
    throw const FormatException('Incomplete customer report.');
  }
  if (first.grouped) return List.unmodifiable(pages.expand((p) => p.rows));
  return List.unmodifiable(CustomerReportPage.fromLedger({
    'status': 'success',
    'data': {
      'data': raw,
      'current_page': 1,
      'last_page': 1,
      'total': raw.length
    }
  }, 1));
}
