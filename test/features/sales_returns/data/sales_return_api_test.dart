import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/features/sales_returns/data/sales_return_api.dart';
import 'package:pos_machine/features/sales_returns/data/sales_return_repository.dart';
import '../../../test_support/network_fakes.dart';
import '../support/return_fixtures.dart';

void main() {
  test('list preserves tenant bearer store and pagination query', () async {
    final api = SalesReturnApi(
        session: const FakeTenantSession(storeId: 9),
        get: (uri, {headers}) async {
          expect(uri.queryParameters, {'page': '2', 'store_id': '9'});
          expect(headers?['Authorization'], 'Bearer token');
          expect(headers?['X-Tenant'], 'tenant');
          return jsonResponse(returnListBody(page: 2));
        });
    final result =
        await SalesReturnRepository(api: api).fetchPage('token', page: 2);
    expect(result.data.currentPage, 2);
  });
  test('items passes order number and omits absent store/page', () async {
    final api = SalesReturnApi(
        session: const FakeTenantSession(storeId: null),
        get: (uri, {headers}) async {
          expect(uri.queryParameters, {'order_number': 'INV-7'});
          return jsonResponse(
              {'status': 'success', 'message': 'ok', 'data': []});
        });
    expect(
        (await SalesReturnRepository(api: api)
                .fetchItems('token', orderId: 'INV-7'))
            .data,
        isEmpty);
  });
  test('missing tenant stops before HTTP', () async {
    var calls = 0;
    final api = SalesReturnApi(
        session: const FakeTenantSession(key: null),
        get: (uri, {headers}) async {
          calls++;
          return http.Response('{}', 200);
        });
    await expectLater(
        SalesReturnRepository(api: api).fetchPage('token'), throwsException);
    expect(calls, 0);
  });
  test('submit preserves JSON types and returns server draft ID', () async {
    final api = SalesReturnApi(
        session: const FakeTenantSession(),
        post: (uri, {headers, body, encoding}) async {
          expect(jsonDecode(body as String), {
            'order_id': 100,
            'price': 10.0,
            'quantity': 0.5,
            'cart_item_id': 40,
            'reason': 'Damaged',
            'is_delivery_refundable': true
          });
          expect(headers?['Content-Type'], 'application/json');
          return jsonResponse({
            'status': 'success',
            'data': {'id': '75'}
          });
        });
    final result = await api.submit(
        accessToken: 'token',
        orderId: 100,
        price: 10,
        quantity: 0.5,
        cartItemId: 40,
        reason: 'Damaged',
        isDeliveryRefundable: true);
    expect(result.id, 75);
  });
  test('complete excludes payment fields unless explicitly enabled', () async {
    final bodies = <Map<String, dynamic>>[];
    final api = SalesReturnApi(
        session: const FakeTenantSession(),
        post: (uri, {headers, body, encoding}) async {
          bodies.add(jsonDecode(body as String));
          return jsonResponse({'status': 'success'});
        });
    await api.complete(
        accessToken: 'token',
        returnOrderId: 75,
        paymentMethod: 'CARD',
        paidAmount: 2);
    await api.complete(
        accessToken: 'token',
        returnOrderId: 75,
        hasPayment: true,
        paymentMethod: 'CASH',
        paidAmount: 2,
        isDeliveryRefundable: true);
    expect(bodies[0], {
      'return_order_id': 75,
      'is_delivery_refundable': false,
      'has_payment': false
    });
    expect(bodies[1], {
      'return_order_id': 75,
      'is_delivery_refundable': true,
      'has_payment': true,
      'payment_method': 'CASH',
      'paid_amount': 2.0
    });
  });
  test('server rejection and missing successful draft ID stay errors',
      () async {
    final api = SalesReturnApi(
        session: const FakeTenantSession(),
        post: (uri, {headers, body, encoding}) async =>
            jsonResponse({'status': 'success', 'data': {}}));
    await expectLater(
        api.submit(
            accessToken: 'token',
            orderId: 1,
            price: 1,
            quantity: 1,
            cartItemId: 1,
            reason: 'Bad'),
        throwsException);
    final failed = SalesReturnApi(
        session: const FakeTenantSession(),
        get: (uri, {headers}) async =>
            jsonResponse({'status': 'failed', 'message': 'Not allowed'}, 422));
    await expectLater(SalesReturnRepository(api: failed).fetchPage('token'),
        throwsA(predicate((e) => e.toString().contains('Not allowed'))));
  });
}
