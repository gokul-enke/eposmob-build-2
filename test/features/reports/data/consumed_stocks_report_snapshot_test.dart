import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/data/consumed_stocks_report_snapshot.dart';
import '../support/consumed_stocks_fixtures.dart';

void main() {
  test('all pages retain separate withdrawals of the same product', () async {
    final calls = <int>[], progress = <int>[];
    final rows = await consumedStocksReportSnapshot((p) async {
      calls.add(p);
      return consumedPage(p, last: 3, total: 3);
    }, progress: (p, t) => progress.add(p));
    expect(calls, [1, 2, 3]);
    expect(progress, [1, 2, 3]);
    expect(rows.map((r) => r.product), everyElement('Banana'));
    expect(rows.map((r) => r.id), [1, 2, 3]);
  });
  test('duplicate record IDs stop an apparently complete export', () async {
    await expectLater(
        consumedStocksReportSnapshot((p) async =>
            consumedPage(p, last: 2, total: 2, rows: [consumedRow(1)])),
        throwsStateError);
  });
  for (final cause in [
    'missing id',
    'missing quantity',
    'invalid quantity',
    'nonfinite quantity',
    'missing remainder',
    'duplicate page',
    'changed total',
    'changed last',
    'changed per',
    'lost pagination',
    'empty page',
    'failed'
  ]) {
    test('rejects incomplete export: $cause', () async {
      await expectLater(consumedStocksReportSnapshot((p) async {
        final response = consumedPage(p, last: 2, total: 2);
        if (p == 2) {
          final row = response.data!.data!.single;
          switch (cause) {
            case 'missing id':
              row.id = null;
            case 'missing quantity':
              row.quantityWithdrawn = null;
            case 'invalid quantity':
              row.quantityWithdrawn = 'oops';
            case 'nonfinite quantity':
              row.quantityWithdrawn = 'NaN';
            case 'missing remainder':
              row.newQuantity = null;
            case 'duplicate page':
              response.data!.pagination!.currentPage = 1;
            case 'changed total':
              response.data!.pagination!.total = 3;
            case 'changed last':
              response.data!.pagination!.lastPage = 3;
            case 'changed per':
              response.data!.pagination!.perPage = 2;
            case 'lost pagination':
              response.data!.pagination = null;
            case 'empty page':
              response.data!.data = [];
            case 'failed':
              response.status = 'failed';
          }
        }
        return response;
      }), throwsStateError);
    });
  }
  test('short intermediate page and final count mismatch fail', () async {
    await expectLater(
        consumedStocksReportSnapshot(
            (p) async => consumedPage(p, last: 2, per: 2)),
        throwsStateError);
    await expectLater(
        consumedStocksReportSnapshot((p) async => consumedPage(p, total: 2)),
        throwsStateError);
  });
  test('unpaginated response exports all provided rows', () async {
    final response = consumedPage(1);
    response.data!.pagination = null;
    expect(
        (await consumedStocksReportSnapshot((p) async => response)).length, 1);
  });
  test('no arbitrary page/data limit', () async {
    final rows = await consumedStocksReportSnapshot(
        (p) async => consumedPage(p, last: 1001, total: 1001));
    expect(rows.length, 1001);
  });
}
