import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/data/customer_report_snapshot.dart';

import '../support/report_fixtures.dart';

void main() {
  test('a complete export visits every page', () async {
    final calls = <int>[];
    final progress = <int>[];
    final result = await fetchCustomerReportSnapshot((p) async {
      calls.add(p);
      return customerReportResponse(p, [customerGroup(p)], last: 3, total: 3);
    }, progress: (page, _) => progress.add(page));
    expect(calls, [1, 2, 3]);
    expect(progress, [1, 2, 3]);
    expect(result.length, 3);
  });

  test('rejects overlapping pages with matching totals', () async {
    await expectLater(
        fetchCustomerReportSnapshot((p) async => customerReportResponse(
            p, [customerGroup(p == 1 ? 1 : '1')],
            last: 2, total: 2)),
        throwsFormatException);
  });

  test('a failed later page does not return a partial export', () async {
    await expectLater(fetchCustomerReportSnapshot((p) async {
      if (p == 2) throw StateError('network');
      return customerReportResponse(p, [customerGroup(p)], last: 2, total: 2);
    }), throwsStateError);
  });

  test('rejects changed totals and missing final records', () async {
    await expectLater(
        fetchCustomerReportSnapshot((p) async => customerReportResponse(
            p, [customerGroup(p)],
            last: 2, total: p == 1 ? 2 : 3)),
        throwsFormatException);
    await expectLater(
        fetchCustomerReportSnapshot((p) async =>
            customerReportResponse(p, [customerGroup(p)], last: 2, total: 3)),
        throwsFormatException);
  });

  test('a legacy flat ledger export aggregates across pages', () async {
    final rows =
        await fetchCustomerReportSnapshot((p) async => customerReportResponse(
            p,
            [
              {
                'id': p,
                'customer_id': 1,
                'customer_name': 'Same',
                'date': '2026-10-01',
                'amount': '5',
                'balance': '12',
                'type': p == 1 ? 'debit' : 'credit'
              }
            ],
            last: 2,
            total: 2));
    expect(rows.single.debit, 5);
    expect(rows.single.credit, 5);
    expect(rows.single.count, 2);
  });
}
