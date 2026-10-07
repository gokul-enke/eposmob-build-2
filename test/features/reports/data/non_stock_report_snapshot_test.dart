import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/data/non_stock_report_snapshot.dart';
import 'package:pos_machine/features/reports/domain/models/non_stock_report.dart';
import '../support/non_stock_fixtures.dart';

void main() {
  test(
      'all pages, progress and separate rows for the same product in two stores',
      () async {
    final visited = <int>[], progress = <int>[];
    final rows = await nonStockReportSnapshot((p) async {
      visited.add(p);
      return nonStockPage(p,
          last: 2, total: 2, rows: [nonStockRow(1, store: 'Store $p')]);
    }, progress: (p, _) => progress.add(p));
    expect(visited, [1, 2]);
    expect(progress, [1, 2]);
    expect(rows.length, 2);
  });
  test('overlapping product/store rows fail even when count is correct',
      () async {
    await expectLater(
        nonStockReportSnapshot((p) async =>
            nonStockPage(p, last: 2, total: 2, rows: [nonStockRow(1)])),
        throwsStateError);
  });
  test('missing stable identifier stops export', () async {
    await expectLater(
        nonStockReportSnapshot(
            (p) async => nonStockPage(p, rows: [nonStockRow(0)])),
        throwsStateError);
  });
  test('flat responses export without a pagination assumption', () async {
    final rows = await nonStockReportSnapshot((_) async =>
        GetNonStockReportResponse(
            status: 'success', message: '', data: [nonStockRow(1)]));
    expect(rows.single.id, 1);
  });
  for (final change in [
    'total',
    'last',
    'perPage',
    'current',
    'empty',
    'flat',
    'failed'
  ]) {
    test('stops partial export on $change response', () async {
      await expectLater(nonStockReportSnapshot((p) async {
        if (p == 1) {
          return nonStockPage(1, last: 2, total: 2);
        }
        if (change == 'flat' || change == 'failed') {
          return GetNonStockReportResponse(
              status: change == 'failed' ? 'failed' : 'success',
              message: '',
              data: [nonStockRow(2)]);
        }
        return nonStockPage(change == 'current' ? 1 : p,
            last: change == 'last' ? 3 : 2,
            perPage: change == 'perPage' ? 2 : 1,
            total: change == 'total' ? 3 : 2,
            rows: change == 'empty' ? [] : null);
      }), throwsStateError);
    });
  }
  test('count mismatch and short intermediate pages stop export', () async {
    await expectLater(
        nonStockReportSnapshot((p) async => nonStockPage(p, total: 2)),
        throwsStateError);
    await expectLater(
        nonStockReportSnapshot(
            (p) async => nonStockPage(p, last: 2, perPage: 2)),
        throwsStateError);
  });
  test('no arbitrary data/page limit: 1001 pages succeed', () async {
    final rows = await nonStockReportSnapshot(
        (p) async => nonStockPage(p, last: 1001, total: 1001));
    expect(rows.length, 1001);
  });
}
