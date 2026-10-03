import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/features/expenses/domain/models/expense.dart';
import 'package:pos_machine/features/expenses/presentation/state/expense_provider.dart';
import '../../support/expense_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(
        {'api_key': 'test', 'active_store_id': 7});
  });
  test('loads every page with tenant, store and expense type', () async {
    final p = ExpenseProvider();
    final requests = <http.Request>[];
    await load(p, (request) {
      requests.add(request);
      return response(
          page(int.parse(request.url.queryParameters['page'] ?? '1')));
    });
    expect(p.allFiltered.length, 2);
    expect(p.loadError, isNull);
    expect(requests.length, 2);
    for (final request in requests) {
      expect(request.headers['X-Tenant'], 'test');
      expect(request.url.queryParameters['store_id'], '7');
      expect(request.url.queryParameters['type'], 'EXPENSE');
    }
  });
  for (final body in [
    {'data': null},
    {'data': {}},
    {'status': 'failed', 'data': []},
    {
      'data': [row(1), 'invalid']
    },
  ]) {
    test('invalid response retains previous rows: $body', () async {
      final p = ExpenseProvider()..addExpense(Expense.fromJson(row(9)));
      await load(p, (_) => response(body));
      expect(p.allFiltered.single.referenceNumber, '0009');
      expect(p.loadError, isNotNull);
      expect(p.isLoading, isFalse);
    });
  }
  for (final mode in ['http', 'last', 'total', 'empty', 'wrong-page']) {
    test('rejects incomplete later page: $mode', () async {
      final p = ExpenseProvider()..addExpense(Expense.fromJson(row(9)));
      await load(p, (request) {
        if (!request.url.queryParameters.containsKey('page')) {
          return response(page(1));
        }
        if (mode == 'http') return http.Response('failed', 500);
        final data = page(mode == 'wrong-page' ? 1 : 2,
            last: mode == 'last' ? 3 : 2, total: mode == 'total' ? 3 : 2);
        if (mode == 'empty') (data['data'] as Map)['data'] = [];
        return response(data);
      });
      expect(p.allFiltered.single.referenceNumber, '0009');
      expect(p.loadError, isNotNull);
    });
  }
  test('valid empty and nested unpaginated responses are accepted', () async {
    final p = ExpenseProvider();
    await load(
        p,
        (_) => response({
              'data': {
                'data': [row(1)]
              }
            }));
    expect(p.allFiltered.length, 1);
    await load(p, (_) => response({'data': []}));
    expect(p.allFiltered, isEmpty);
    expect(p.loadError, isNull);
  });
  test('supports pagination metadata alongside a flat row list', () async {
    final p = ExpenseProvider();
    await load(p, (request) {
      final n = int.parse(request.url.queryParameters['page'] ?? '1');
      return response({
        'data': [row(n)],
        'current_page': n,
        'last_page': 2,
        'total': 2
      });
    });
    expect(p.allFiltered.length, 2);
    expect(p.loadError, isNull);
  });
  test('category, debit, status and reference filters combine locally', () {
    final p = ExpenseProvider();
    p.addExpense(Expense.fromJson(row(1)));
    p.addExpense(Expense.fromJson({...row(2), 'status': 'PEND'}));
    p.setCategory('Rent');
    p.setDebitAccount('Office');
    p.setStatus('SUCC');
    p.setReference('0001');
    expect(p.allFiltered.single.referenceNumber, '0001');
    p.resetFilters();
    expect(p.allFiltered.length, 2);
  });
  for (final invalidRow in <Map<String, dynamic>>[
    {},
    {...row(1), 'reference_number': null},
    {...row(1), 'reference_number': ' '},
    {...row(1), 'payment_date': null},
    {...row(1), 'payment_date': 'invalid'},
    {...row(1), 'amount': null},
    {...row(1), 'amount': 'invalid'},
    {...row(1), 'amount': 'NaN'},
  ]) {
    test('rejects incomplete financial row: $invalidRow', () async {
      final p = ExpenseProvider()..addExpense(Expense.fromJson(row(9)));
      await load(
          p,
          (_) => response({
                'data': [row(1), invalidRow]
              }));
      expect(p.loadError, isNotNull);
      expect(p.allFiltered.single.referenceNumber, '0009');
      expect(p.isLoading, isFalse);
    });
  }
  for (final paginated in [false, true]) {
    test('rejects duplicate references, paginated=$paginated', () async {
      final p = ExpenseProvider()..addExpense(Expense.fromJson(row(9)));
      await load(p, (request) {
        if (!paginated) {
          return response({
            'data': [row(1), row(1)]
          });
        }
        final current = int.parse(request.url.queryParameters['page'] ?? '1');
        final body = page(current);
        (body['data'] as Map)['data'] = [row(1)];
        return response(body);
      });
      expect(p.loadError, isNotNull);
      expect(p.allFiltered.single.referenceNumber, '0009');
    });
  }
  test('accepts reference alias, zero and valid numeric string amounts',
      () async {
    final p = ExpenseProvider();
    final alias = {...row(1), 'reference_no': '0001', 'amount': 0}
      ..remove('reference_number');
    await load(
        p,
        (_) => response({
              'data': [
                alias,
                {...row(2), 'amount': '126.125'}
              ]
            }));
    expect(p.loadError, isNull);
    expect(p.allFiltered.map((e) => e.amount), [0, 126.125]);
    expect(p.allFiltered.first.referenceNumber, '0001');
  });
  test('latest request wins', () async {
    final p = ExpenseProvider();
    final old = Completer<http.Response>();
    final started = Completer<void>();
    final first = load(p, (_) {
      started.complete();
      return old.future;
    });
    await started.future;
    await load(
        p,
        (_) => response({
              'data': [row(2)]
            }));
    old.complete(response({
      'data': [row(1)]
    }));
    await first;
    expect(p.allFiltered.single.referenceNumber, '0002');
    expect(p.loadError, isNull);
    expect(p.isLoading, isFalse);
  });
  test('missing tenant reports an error and refresh clamps pagination',
      () async {
    final p = ExpenseProvider();
    for (var i = 0; i < 25; i++) {
      p.addExpense(Expense.fromJson(row(i)));
    }
    p.setPage(3);
    await load(
        p,
        (_) => response({
              'data': [row(1)]
            }));
    expect(p.currentPage, 1);
    SharedPreferences.setMockInitialValues({});
    await load(p, (_) => throw StateError('should not request'));
    expect(p.loadError, isNotNull);
    expect(p.isLoading, isFalse);
  });
}
