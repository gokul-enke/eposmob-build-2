import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/features/sales_returns/data/sales_return_list_repository.dart';
import '../sales_returns/support.dart';

void main() {
  test('sends the existing store, page and auth contract', () async {
    final repo =
        SalesReturnListRepository(returnScope, client: MockClient((r) async {
      expect(r.url.queryParameters, {'page': '2', 'store_id': '2'});
      expect(r.headers['Authorization'], 'Bearer test-token');
      expect(r.headers['X-Tenant'], 'test-tenant');
      return http.Response(
          jsonEncode(returnEnvelope([returnRow(3)], page: 2, total: 3)), 200);
    }));
    expect((await repo.fetch(2)).page, 2);
  });
  for (final response in [
    http.Response('{"message":"Server failed"}', 500),
    http.Response('{"status":"error","message":"Denied"}', 200)
  ]) {
    test('does not turn failure ${response.statusCode} into an empty success',
        () async {
      final repo = SalesReturnListRepository(returnScope,
          client: MockClient((_) async => response));
      await expectLater(repo.fetch(1), throwsA(anything));
    });
  }
  test('accepts a genuine empty list and numeric string pagination', () {
    final body = returnEnvelope([]);
    final data = body['data'] as Map;
    for (final key in ['current_page', 'last_page', 'per_page', 'total']) {
      data[key] = '${data[key]}';
    }
    expect(
        SalesReturnListRepository.parse(jsonEncode(body), requestedPage: 1)
            .rows,
        isEmpty);
  });
  for (final key in [
    'current_page',
    'last_page',
    'per_page',
    'total',
    'data'
  ]) {
    test('rejects missing pagination or rows: $key', () {
      final body = returnEnvelope([returnRow(1)]);
      (body['data'] as Map).remove(key);
      expect(
          () => SalesReturnListRepository.parse(jsonEncode(body),
              requestedPage: 1),
          throwsFormatException);
    });
  }
  test('rejects contradictory metadata', () {
    final body = returnEnvelope([returnRow(1)]);
    (body['data'] as Map)['last_page'] = 2;
    expect(
        () =>
            SalesReturnListRepository.parse(jsonEncode(body), requestedPage: 1),
        throwsFormatException);
  });
  test('fetches every page and accepts separate returns for one original order',
      () async {
    final source = ReturnSource((page) async => returnData(
        page == 1 ? [returnRow(1), returnRow(2)] : [returnRow(3)],
        page: page,
        total: 3));
    final progress = <String>[];
    final rows = await salesReturnListSnapshot(source,
        onPage: (p, t) => progress.add('$p/$t'));
    expect(rows.map((r) => r.id), [1, 2, 3]);
    expect(rows.map((r) => r.orderId).toSet(), {10});
    expect(source.calls, [1, 2]);
    expect(progress, ['1/2', '2/2']);
  });
  test('rejects overlapping pages even when the count matches', () async {
    final source = ReturnSource((p) async => returnData(
        p == 1 ? [returnRow(1), returnRow(2)] : [returnRow(2)],
        page: p,
        total: 3));
    await expectLater(salesReturnListSnapshot(source), throwsStateError);
  });
  test('rejects a short page', () async {
    final source = ReturnSource(
        (p) async => returnData([returnRow(p)], page: p, total: 3));
    await expectLater(salesReturnListSnapshot(source), throwsStateError);
  });
  test('rejects changed totals across pages', () async {
    final source = ReturnSource((p) async => returnData(
        [returnRow(1), returnRow(2)],
        page: p, total: p == 1 ? 3 : 4));
    await expectLater(salesReturnListSnapshot(source), throwsStateError);
  });
  test('propagates a later-page API failure', () async {
    final source = ReturnSource((p) async {
      if (p == 2) throw StateError('HTTP 500');
      return returnData([returnRow(1), returnRow(2)], total: 3);
    });
    await expectLater(salesReturnListSnapshot(source), throwsStateError);
    expect(source.calls, [1, 2]);
  });
  final invalidRows = <String, Map<String, dynamic>>{
    'zero ID': returnRow(0),
    'zero order ID': returnRow(1, orderId: 0),
    'missing amount': returnRow(1)..remove('total_amount'),
    'invalid amount': returnRow(1)..['total_amount'] = 'NaN',
    'missing date': returnRow(1)..remove('created_at'),
    'missing items': returnRow(1)..remove('items'),
    'missing status': returnRow(1)..remove('status'),
    'missing quantity': returnRow(1)
      ..['items'] = [
        {'price': '10'}
      ],
    'negative quantity': returnRow(1)
      ..['items'] = [
        {'quantity': -1}
      ],
    'invalid quantity': returnRow(1)
      ..['items'] = [
        {'quantity': 'wrong'}
      ],
    'infinite quantity': returnRow(1)
      ..['items'] = [
        {'quantity': 'Infinity'}
      ],
    'sum overflow': returnRow(1)
      ..['items'] = [
        {'quantity': 1e308},
        {'quantity': 1e308}
      ],
  };
  for (final entry in invalidRows.entries) {
    test('blocks incomplete export: ${entry.key}', () async {
      final source = ReturnSource((_) async => returnData([entry.value]));
      await expectLater(salesReturnListSnapshot(source), throwsStateError);
    });
  }
  test('bounds unusually large exports', () async {
    final source = ReturnSource(
        (_) async => returnData([returnRow(1), returnRow(2)], total: 2001));
    await expectLater(salesReturnListSnapshot(source), throwsStateError);
    expect(source.calls, [1]);
  });
  test('aborts after scope changes during the last page', () async {
    var current = true;
    final source = ReturnSource((_) async {
      current = false;
      return returnData([returnRow(1)]);
    });
    await expectLater(
        salesReturnListSnapshot(source, isCurrent: () async => current),
        throwsStateError);
  });
}
