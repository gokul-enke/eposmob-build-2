import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/data/supplier_report_snapshot.dart';

Map<String, dynamic> snapshotPage(
  int page, {
  Object id = 7,
  int pages = 2,
  int total = 2,
}) =>
    {
      'status': 'success',
      'data': {
        'current_page': page,
        'last_page': pages,
        'per_page': 1,
        'total': total,
        'data': [
          <String, dynamic>{
            'supplier_id': id,
            'supplier_name': 'Supplier $id',
            'total_debit': '12.25',
            'total_credit': 2,
            'balance': -10.25,
            'transactions': [{}, {}]
          },
        ]
      },
    };

void main() {
  test(
      'accepts the exact pagination safety boundary and rejects larger declarations',
      () async {
    final result = await fetchSupplierReportSnapshot(
        (page) async => snapshotPage(page, id: page, pages: 1000, total: 1000));
    expect(result.length, 1000);
    await expectLater(
        fetchSupplierReportSnapshot(
            (page) async => snapshotPage(page, pages: 1001, total: 1001)),
        throwsFormatException);
  });
  test('reads every page and keeps numeric values and progress', () async {
    final progress = <(int, int)>[];
    final result = await fetchSupplierReportSnapshot(
        (page) async => snapshotPage(page, id: page == 1 ? 7 : '8'),
        progress: (page, total) => progress.add((page, total)));
    expect(result.map((row) => row.supplierId), ['7', '8']);
    expect(result.first.totalDebit, 12.25);
    expect(result.first.transactionCount, 2);
    expect(progress, [(1, 2), (2, 2)]);
  });
  test('rejects IDs repeated in another page, including numeric strings',
      () async {
    await expectLater(
        fetchSupplierReportSnapshot(
            (page) async => snapshotPage(page, id: page == 1 ? 7 : '007')),
        throwsFormatException);
  });
  test('rejects changing totals, page counts and repeated pages', () async {
    for (final change in ['total', 'last_page', 'current_page', 'per_page']) {
      await expectLater(fetchSupplierReportSnapshot((page) async {
        final response = snapshotPage(page, id: page + 6);
        if (page == 2) {
          (response['data'] as Map)[change] = change == 'current_page' ? 1 : 3;
        }
        return response;
      }), throwsFormatException);
    }
  });
  test('rejects malformed, missing or non-finite financial rows', () async {
    for (final value in [null, 'bad', 'NaN', 'Infinity']) {
      final response = snapshotPage(1, pages: 1, total: 1);
      ((response['data'] as Map)['data'] as List).first['balance'] = value;
      await expectLater(fetchSupplierReportSnapshot((_) async => response),
          throwsFormatException);
    }
  });
  test(
      'rejects incomplete totals, empty later pages and failed HTTP-200 envelopes',
      () async {
    await expectLater(
        fetchSupplierReportSnapshot(
            (page) async => snapshotPage(page, id: page + 6, total: 3)),
        throwsFormatException);
    await expectLater(fetchSupplierReportSnapshot((page) async {
      final response = snapshotPage(page, id: page + 6);
      if (page == 2) (response['data'] as Map)['data'] = [];
      return response;
    }), throwsFormatException);
    await expectLater(
        fetchSupplierReportSnapshot(
            (_) async => snapshotPage(1)..['status'] = 'failed'),
        throwsFormatException);
  });
  test('supports unpaginated legacy groups and propagates later-page failures',
      () async {
    final response = snapshotPage(1, pages: 1, total: 1);
    final result = await fetchSupplierReportSnapshot(
        (_) async => {'data': (response['data'] as Map)['data']});
    expect(result.single.supplierId, '7');
    await expectLater(fetchSupplierReportSnapshot((page) async {
      if (page == 2) throw StateError('network');
      return snapshotPage(page);
    }), throwsStateError);
  });
}
