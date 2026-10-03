import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/features/expenses/data/expense_api.dart';
import '../../../test_support/network_fakes.dart';
import '../support/expense_fixtures.dart';

void main() {
  test('injected GET preserves tenant/store/type and first-page query',
      () async {
    final requests = <Uri>[];
    final api = ExpenseApi(
        session: const FakeTenantSession(storeId: 7),
        httpGet: (url, {headers}) async {
          requests.add(url);
          expect(
              headers, {'Authorization': 'Bearer token', 'X-Tenant': 'tenant'});
          return jsonResponse(page(requests.length));
        });
    final result = await api.fetchGeneralPayments(accessToken: 'token');
    expect(result!.length, 2);
    expect(
        requests.first.queryParameters, {'type': 'EXPENSE', 'store_id': '7'});
    expect(requests.last.queryParameters['page'], '2');
  });
  test('stale request stops before fetching another page', () async {
    var current = true;
    var requests = 0;
    final api = ExpenseApi(
        session: const FakeTenantSession(),
        httpGet: (url, {headers}) async {
          requests++;
          current = false;
          return jsonResponse(page(1));
        });
    expect(
        await api.fetchGeneralPayments(
            accessToken: 't', isCurrent: () => current),
        isNull);
    expect(requests, 1);
  });
  test('missing tenant does not issue HTTP', () async {
    final api = ExpenseApi(
        session: const FakeTenantSession(key: null),
        httpGet: (_, {headers}) async => throw StateError('unexpected HTTP'));
    await expectLater(
        api.fetchGeneralPayments(accessToken: 't'), throwsStateError);
    expect(await api.fetchAccountOptions(accessToken: 't'), isNull);
    expect(
        (await api
            .createGeneralPayment(accessToken: 't', payload: {}))['message'],
        'API key not found');
  });
  test(
      'create preserves body types, uses active store and does not mutate input',
      () async {
    final input = {
      'entry_type': 'EXPENSE',
      'amount': 1.25,
      'category': '12',
      'expense_account_id': 4,
      'store_id': 99
    };
    final api = ExpenseApi(
        session: const FakeTenantSession(storeId: 7),
        httpPost: (url, {headers, body}) async {
          expect(url.path, endsWith('/create-general-payment'));
          expect(headers, {
            'Authorization': 'Bearer token',
            'Content-Type': 'application/json',
            'X-Tenant': 'tenant'
          });
          expect(jsonDecode(body as String), {...input, 'store_id': 7});
          return jsonResponse({
            'message': 'created',
            'data': {'id': 1}
          }, 201);
        });
    final result =
        await api.createGeneralPayment(accessToken: 'token', payload: input);
    expect(result['status'], 'success');
    expect(input['store_id'], 99);
  });
  test('create retains field errors and malformed-response error handling',
      () async {
    var malformed = false;
    final api = ExpenseApi(
        session: const FakeTenantSession(),
        httpPost: (_, {headers, body}) async => malformed
            ? http.Response('bad', 500)
            : jsonResponse({
                'message': 'Validation',
                'errors': {
                  'amount': ['Invalid amount']
                }
              }, 422));
    expect(
        (await api
            .createGeneralPayment(accessToken: 't', payload: {}))['message'],
        'Invalid amount');
    malformed = true;
    expect(
        (await api
            .createGeneralPayment(accessToken: 't', payload: {}))['status'],
        'error');
  });
  test(
      'closing breakdown uses explicit store and date without active-store override',
      () async {
    final api = ExpenseApi(
        session: const FakeTenantSession(storeId: 7),
        httpGet: (url, {headers}) async {
          expect(url.queryParameters['store_id'], '19');
          return jsonResponse({
            'data': [
              {...row(1), 'payment_account_name': 'Cash', 'amount': 2},
              {...row(2), 'payment_account_name': 'Bank', 'amount': 3},
              {...row(3), 'payment_date': '2026-09-30', 'amount': 100},
            ]
          });
        });
    expect(
        await api.getExpenseBreakdownForDate(
            accessToken: 't', storeId: 19, businessDate: '2026-10-01'),
        {'cash': 2.0, 'bank': 3.0, 'total': 5.0});
  });
  test('account options returns data without changing or fetching master data',
      () async {
    final api = ExpenseApi(
        session: const FakeTenantSession(),
        httpGet: (url, {headers}) async {
          expect(url.queryParameters, isEmpty);
          return jsonResponse({
            'data': {
              'expense_accounts': [
                {'id': 1, 'name': 'Office'}
              ]
            }
          });
        });
    expect(
        (await api.fetchAccountOptions(accessToken: 't'))['expense_accounts'], [
      {'id': 1, 'name': 'Office'}
    ]);
  });
}
