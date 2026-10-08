import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/features/sales/data/daily_close_api.dart';

import 'sales_orders_api_test.dart' show Session;

void main() {
  test('closing list preserves array query keys and tenant headers', () async {
    Uri? url;
    Map<String, String>? captured;
    final api = DailyCloseApi(
        session: const Session('tenant', 7),
        get: (uri, {headers}) async {
          url = uri;
          captured = headers;
          return http.Response('{"data":[],"pagination":{}}', 200);
        });
    await api.fetchDailySalesClose(
        accessToken: 't',
        storeId: 7,
        userId: 9,
        page: 3,
        startDate: '2026-10-01',
        endDate: '2026-10-05');
    expect(url!.queryParameters, {
      'store_id[]': '7',
      'user_id[]': '9',
      'page': '3',
      'start_date': '2026-10-01',
      'end_date': '2026-10-05'
    });
    expect(captured!['X-Tenant'], 'tenant');
    expect(captured!['Authorization'], 'Bearer t');
  });
  test('closing submission keeps number types, null fields and transaction IDs',
      () async {
    dynamic capturedBody;
    Uri? url;
    final api = DailyCloseApi(
        session: const Session('tenant', 7),
        post: (uri, {headers, body, encoding}) async {
          url = uri;
          capturedBody = jsonDecode(body as String);
          return http.Response('{"success":true,"message":"saved"}', 201);
        });
    final result = await api.createDailySalesClose(
        accessToken: 't',
        storeId: 7,
        cashRefunds: 4.19,
        openingCashBreakdown: [
          {'denomination': '10', 'count': 2}
        ],
        openingTransactionId: 11,
        closingTransactionId: 12);
    expect(result['success'], true);
    expect(url!.queryParameters, {'store_id': '7'});
    expect(capturedBody['cash_refunds'], 4.19);
    expect(capturedBody['notes'], null);
    expect(capturedBody['opening_transaction_id'], 11);
    expect(capturedBody['closing_transaction_id'], 12);
    expect(capturedBody['opening_cash_breakdown'], [
      {'denomination': '10', 'count': 2}
    ]);
  });
  test('open shift retains body store ID and failure policy', () async {
    dynamic capturedBody;
    final api = DailyCloseApi(
        session: const Session('tenant', 7),
        post: (uri, {headers, body, encoding}) async {
          capturedBody = jsonDecode(body as String);
          return http.Response('{"success":false}', 422);
        });
    expect(
        await api.openShiftApi(
            accessToken: 't',
            storeId: 7,
            shiftName: 'Morning',
            businessDate: '2026-10-05',
            openingDate: '2026-10-05',
            openingTime: '08:00:00',
            openingCashInHand: 20,
            openingCashBreakdown: [
              {'denomination': '10', 'count': 2}
            ]),
        false);
    expect(capturedBody['store_id'], 7);
    expect(capturedBody['opening_cash_in_hand'], 20);
    expect(capturedBody['notes'], '');
  });
  test('closing GET failures stay null, POST validation errors retain details',
      () async {
    final api = DailyCloseApi(
        session: const Session('tenant', 7),
        get: (uri, {headers}) async => http.Response('{}', 500),
        post: (uri, {headers, body, encoding}) async => http.Response(
            '{"message":"Invalid date","errors":{"date":["required"]}}', 422));
    expect(await api.fetchDailySalesClose(accessToken: 't', storeId: 7), null);
    final result =
        await api.createDailySalesClose(accessToken: 't', storeId: 7);
    expect(result['success'], false);
    expect(result['message'], 'Invalid date');
    expect(result['errors'], {
      'date': ['required']
    });
  });
}
