import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/features/purchase_returns/data/purchase_return_api.dart';
import 'package:pos_machine/resources/app_url.dart';
import '../../../test_support/network_fakes.dart';

void main() {
  test('return list preserves query, headers, pagination and no store filter',
      () async {
    final api = PurchaseReturnApi(
        session: const FakeTenantSession(storeId: 42),
        httpGet: (url, {headers}) async {
          expect(url.path, Uri.parse(APPUrl.listPurchaseReturns).path);
          expect(url.queryParameters, {
            'page': '3',
            'supplier_id': '7',
            'date_from': '2026-09-01',
            'date_to': '2026-09-30'
          });
          expect(headers, {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer token',
            'X-Tenant': 'tenant'
          });
          return jsonResponse({
            'status': 'success',
            'data': {
              'current_page': 3,
              'last_page': 5,
              'data': [
                {'id': 12, 'total_amount': '4.19'}
              ]
            }
          });
        });
    final result = await api.listPurchaseReturns(
        accessToken: 'token',
        page: 3,
        supplierId: '7',
        dateFrom: '2026-09-01',
        dateTo: '2026-09-30');
    expect(result.currentPage, 3);
    expect(result.lastPage, 5);
    expect(result.data!.single.totalAmount, 4.19);
  });
  test('empty filters omitted; page defaults to one', () async {
    final api = PurchaseReturnApi(
        session: const FakeTenantSession(),
        httpGet: (url, {headers}) async {
          expect(url.queryParameters, {'page': '1'});
          return jsonResponse({'status': 'success'});
        });
    expect(
        (await api.listPurchaseReturns(
                accessToken: 't', supplierId: '', dateFrom: '', dateTo: ''))
            .data,
        isEmpty);
  });
  test('missing tenant sends no request', () async {
    var calls = 0;
    final api = PurchaseReturnApi(
        session: const FakeTenantSession(key: null),
        httpGet: (url, {headers}) async {
          calls++;
          return http.Response('', 500);
        });
    await expectLater(api.listPurchaseReturns(accessToken: 't'),
        throwsA(isA<HttpException>()));
    await expectLater(
        api.fetchReturnableItems(accessToken: 't', purchaseVoucherId: 9),
        throwsA(isA<HttpException>()));
    expect(await api.fetchPurchaseReturnDetails(accessToken: 't', returnId: 9),
        isNull);
    expect(
        (await api.createPurchaseReturn(
            accessToken: 't',
            purchaseVoucherId: 9,
            returnDate: '2026-09-30',
            items: []))['status'],
        'failed');
    expect(calls, 0);
  });
  for (final response in [
    http.Response('', 500),
    jsonResponse({'status': 'failed', 'message': 'Denied'}),
    http.Response('invalid', 200)
  ]) {
    test('list rejects failed response ${response.body}', () async {
      final api = PurchaseReturnApi(
          session: const FakeTenantSession(),
          httpGet: (url, {headers}) async => response);
      await expectLater(api.listPurchaseReturns(accessToken: 't'),
          throwsA(isA<HttpException>()));
    });
  }
  test('returnable items and details preserve endpoint and parsed IDs',
      () async {
    var details = false;
    final api = PurchaseReturnApi(
        session: const FakeTenantSession(),
        httpGet: (url, {headers}) async {
          expect(headers!['X-Tenant'], 'tenant');
          expect(
              url.toString(),
              details
                  ? APPUrl.purchaseReturnDetails(9)
                  : APPUrl.returnableItems(8));
          return details
              ? jsonResponse({
                  'status': 'success',
                  'data': {
                    'id': 9,
                    'items': [
                      {'quantity': '0.5', 'amount': '3.25'}
                    ]
                  }
                })
              : jsonResponse({
                  'status': 'success',
                  'data': {
                    'items': [
                      {'purchase_item_id': 10, 'returnable_quantity': '0.5'}
                    ]
                  }
                });
        });
    expect(
        (await api.fetchReturnableItems(
                accessToken: 't', purchaseVoucherId: 8))!
            .items!
            .single
            .purchaseItemId,
        10);
    details = true;
    expect(
        (await api.fetchPurchaseReturnDetails(accessToken: 't', returnId: 9))!
            .items!
            .single
            .quantity,
        0.5);
  });
  test('failed details retain nullable fallback', () async {
    final api = PurchaseReturnApi(
        session: const FakeTenantSession(),
        httpGet: (url, {headers}) async => http.Response('invalid', 200));
    expect(await api.fetchPurchaseReturnDetails(accessToken: 't', returnId: 1),
        isNull);
    await expectLater(
        api.fetchReturnableItems(accessToken: 't', purchaseVoucherId: 1),
        throwsA(isA<HttpException>()));
  });
  for (final paid in [false, true]) {
    test('create preserves boolean and optional payment payload ($paid)',
        () async {
      final api = PurchaseReturnApi(
          session: const FakeTenantSession(),
          httpPost: (url, {headers, body, encoding}) async {
            expect(url.toString(), APPUrl.createPurchaseReturn);
            expect(headers!['Accept'], 'application/json');
            final payload = jsonDecode(body as String);
            expect(payload, {
              'purchase_voucher_id': 8,
              'return_date': '2026-09-30',
              'items': [
                {'purchase_item_id': 10, 'quantity': 0.5, 'reason': 'Damaged'}
              ],
              'has_payment': paid,
              if (paid) 'paid_amount': 3.25,
              if (paid) 'payment_method': '2'
            });
            return jsonResponse(
                {'status': 'success', 'message': 'Created'}, 201);
          });
      expect(
          await api.createPurchaseReturn(
              accessToken: 't',
              purchaseVoucherId: 8,
              returnDate: '2026-09-30',
              items: [
                {'purchase_item_id': 10, 'quantity': 0.5, 'reason': 'Damaged'}
              ],
              hasPayment: paid,
              paidAmount: 3.25,
              paymentMethod: '2'),
          {'status': 'success', 'message': 'Created'});
    });
  }
  test('create retains validation, non-JSON and timeout errors', () async {
    var response = jsonResponse({
      'status': 'failed',
      'message': 'Invalid',
      'errors': {
        'quantity': ['Too much']
      }
    }, 422);
    var timeout = false;
    final api = PurchaseReturnApi(
        session: const FakeTenantSession(),
        httpPost: (url, {headers, body, encoding}) async {
          if (timeout) throw TimeoutException('timeout');
          return response;
        });
    Future<Map<String, dynamic>> submit() => api.createPurchaseReturn(
        accessToken: 't',
        purchaseVoucherId: 1,
        returnDate: '2026-09-30',
        items: []);
    expect(await submit(),
        {'status': 'failed', 'http_status_code': 422, 'message': 'Too much'});
    response = http.Response('html', 502);
    expect(
        (await submit())['message'], 'Server error (502). Please try again.');
    timeout = true;
    expect((await submit())['message'], 'Request timed out. Please try again.');
  });
  test(
      'voucher lookup defaults to active store but does not change provider state',
      () async {
    final api = PurchaseReturnApi(
        session: const FakeTenantSession(storeId: 42),
        httpGet: (url, {headers}) async {
          expect(url.path, Uri.parse(APPUrl.listPurchaseOrder).path);
          expect(url.queryParameters, {'page': '4', 'store_id': '42'});
          return jsonResponse({
            'status': 'success',
            'data': {
              'current_page': 4,
              'last_page': 8,
              'data': [
                {'id': 12}
              ]
            }
          });
        });
    expect((await api.fetchVouchers(accessToken: 't', page: 4)).data!.single.id,
        12);
  });
  test('voucher lookup preserves empty response fallback on failure', () async {
    final api = PurchaseReturnApi(
        session: const FakeTenantSession(),
        httpGet: (url, {headers}) async => http.Response('bad', 500));
    final result = await api.fetchVouchers(accessToken: 't');
    expect(result.data, isEmpty);
    expect(result.currentPage, isNull);
  });
}
