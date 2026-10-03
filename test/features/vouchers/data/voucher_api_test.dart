import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/features/vouchers/data/customer_voucher_api.dart';
import 'package:pos_machine/features/vouchers/data/supplier_voucher_api.dart';
import 'package:pos_machine/features/vouchers/data/voucher_payloads.dart';

class Session extends TenantSession {
  const Session({this.key = 'tenant', this.store = 9});
  final String? key;
  final int? store;
  @override
  Future<String?> apiKey() async => key;
  @override
  Future<int?> activeStoreId() async => store;
}

void main() {
  test('customer GET retains tenant, store, dates and flat empty success',
      () async {
    final api = CustomerVoucherApi(
        session: const Session(),
        httpGet: (url, {headers}) async {
          expect(
              headers, {'Authorization': 'Bearer token', 'X-Tenant': 'tenant'});
          expect(url.queryParameters, {
            'page': '1',
            'per_page': '1000',
            'store_id': '9',
            'date_from': '2026-10-01',
            'date_to': '2026-10-03'
          });
          return http.Response(
              jsonEncode({'status': true, 'message': 'ok', 'data': []}), 200);
        });
    expect(
        await api.fetch('token', dateFrom: '2026-10-01', dateTo: '2026-10-03'),
        isEmpty);
  });
  test('missing tenant rejects a fetch before any HTTP request', () async {
    var requests = 0;
    final api = SupplierVoucherApi(
        session: const Session(key: null),
        httpGet: (url, {headers}) async {
          requests++;
          return http.Response('{}', 200);
        });
    await expectLater(api.fetch('token'), throwsA(isA<HttpException>()));
    expect(requests, 0);
  });
  test(
      'create JSON contract retains nullable payment ID and unmodified item values',
      () async {
    final items = [
      {
        'item_name': '001',
        'unit_amount': 2.5,
        'quantity': 2,
        'tax': 0,
        'total_amount': 5.0
      }
    ];
    final body = customerVoucherPayload(
        customerId: 7,
        type: 'other',
        amount: 5,
        voucherDate: '2026-10-03',
        dueDate: '2026-10-03',
        status: 'paid',
        paymentMethodId: null,
        voucherItems: items);
    final api =
        CustomerVoucherApi(httpPost: (url, {headers, body, encoding}) async {
      expect(headers, {
        'Authorization': 'Bearer token',
        'X-Tenant': 'tenant',
        'Content-Type': 'application/json'
      });
      final json = jsonDecode(body! as String);
      expect(json['payment_method'], isNull);
      expect(json['customer_id'], 7);
      expect(json['voucher_items'], items);
      return http.Response('{"message":"created","data":{"id":10}}', 201);
    });
    expect(
        (await api.create(
            'https://example.test/create', 'token', 'tenant', body))['success'],
        isTrue);
    final supplier = supplierVoucherPayload(
        supplierId: 8,
        type: 'order',
        amount: 5,
        voucherDate: '2026-10-03',
        dueDate: '2026-10-03',
        status: 'paid',
        paymentMethodId: 3,
        voucherItems: items);
    expect(supplier['supplier_id'], 8);
    expect(supplier.containsKey('customer_id'), isFalse);
    expect(supplier['payment_method'], 3);
  });
  test('ZATCA keeps form body and raw success response fallback', () async {
    final api = CustomerVoucherApi(
        session: const Session(),
        httpPost: (url, {headers, body, encoding}) async {
          expect(body, {'id': '17'});
          expect(headers!['X-Tenant'], 'tenant');
          expect(headers.containsKey('Content-Type'), isFalse);
          return http.Response('pdf-url', 200);
        });
    expect(
        await api.zatca('https://example.test/zatca', 'token', 17), 'pdf-url');
  });
  test('form choices use tenant and store and keep raw customer IDs', () async {
    final api = CustomerVoucherApi(
        session: const Session(),
        httpGet: (url, {headers}) async {
          expect(url.queryParameters, {'store_id': '9'});
          return http.Response('{"data":[{"id":7,"name":"Test"}]}', 200);
        });
    expect(
        (await api.choices('https://example.test/choices', 'token'))!
            .single['id'],
        7);
  });
}
