import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/features/purchases/data/purchase_api.dart';
import 'package:pos_machine/features/purchases/data/purchase_repository.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_provider.dart';

import '../support/fixed_session.dart';

void main() {
  test('order query preserves all-store override, dates, supplier, and page',
      () async {
    Uri? captured;
    Map<String, String>? sentHeaders;
    var calls = 0;
    final api = PurchaseApi(
        session: const FixedSession(),
        httpGet: (url, {headers}) async {
          captured = url;
          sentHeaders = headers;
          calls++;
          return http.Response(
              '{"status":"success","data":{"current_page":3,"last_page":5,"data":[]}}',
              200);
        });
    final request = await api.prepareListPurchaseOrders(
        accessToken: 'token',
        storeId: 'ALL',
        supplierId: '9',
        dateFrom: '2026-10-01',
        dateTo: '2026-10-03',
        page: 3);
    expect(calls, 0);
    await request.send();
    expect(captured!.queryParameters, {
      'page': '3',
      'supplier_id': '9',
      'date_from': '2026-10-01',
      'filter_date': '2026-10-01',
      'date_to': '2026-10-03'
    });
    expect(sentHeaders, {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer token',
      'X-Tenant': 'tenant-test'
    });
    final active = await api.prepareListPurchaseOrders(accessToken: 'token');
    expect(active.url.queryParameters, {'page': '1', 'store_id': '42'});
    final explicit =
        await api.prepareListPurchaseOrders(accessToken: 'token', storeId: '7');
    expect(explicit.url.queryParameters['store_id'], '7');
  });
  test('lookup and legacy query conventions stay unchanged', () async {
    final api = PurchaseApi(session: const FixedSession());
    final stores = await api.prepareListAllStores('token', 'Shop');
    expect(stores.url.queryParameters['store_name'], 'Shop');
    expect(stores.url.queryParameters['store_id'], '42');
    final suppliers = await api.prepareListAllSuppliers('token', 'Supplier');
    expect(suppliers.url.queryParameters['supplier_name'], 'Supplier');
    final units = await api.prepareListAllUnits('token');
    expect(units.url.queryParameters['store_id'], '42');
    expect(units.url.queryParameters.containsKey('locale'), isFalse);
    final legacy = await api.prepareListPurchase(
        accessToken: 'token',
        storeId: 'all',
        supplierId: '2',
        filterName: 'name',
        filterProduct: 'product',
        filterStore: 'store',
        filterSupplier: 'supplier',
        filterDate: 'date',
        createdBy: '5');
    expect(legacy.url.queryParameters, {
      'page': 'null',
      'store_id': 'all',
      'supplier_id': '2',
      'filter_name': 'name',
      'filter_product': 'product',
      'filter_store': 'store',
      'filter_supplier': 'supplier',
      'filter_date': 'date',
      'created_by': '5'
    });
    final vouchers = await api.prepareListPurchaseVoucher(
        accessToken: 'token',
        filterAmount: '12.00',
        filterDate: 'date',
        filterStore: 'store',
        page: 2);
    expect(vouchers.url.queryParameters, {
      'page': '2',
      'filter_amount_total': '12.00',
      'filter_date': 'date',
      'filter_store': 'store',
      'store_id': '42'
    });
    final items = await api.prepareListAllPurchaseItems('token');
    expect(items.url.queryParameters, {'store_id': '42'});
  });
  test('missing tenant fails during preparation, before any HTTP', () async {
    var calls = 0;
    final api = PurchaseApi(
        session: const FixedSession(key: null),
        httpGet: (url, {headers}) async {
          calls++;
          return http.Response('{}', 200);
        });
    await expectLater(api.prepareListPurchaseOrders(accessToken: 'token'),
        throwsA(isA<HttpException>()));
    await expectLater(
        api.createPurchaseOrder(
            accessToken: 'token',
            purchaseDate: 'date',
            supplierId: '1',
            storeId: '2',
            discount: 0,
            items: []),
        throwsA(isA<HttpException>()));
    expect(calls, 0);
  });
  test('create/receive preserve JSON field types and optional payment omission',
      () async {
    final bodies = <Map<String, dynamic>>[];
    final paths = <String>[];
    final api = PurchaseApi(
        session: const FixedSession(),
        httpPost: (url, {headers, body, encoding}) async {
          bodies.add(jsonDecode(body as String) as Map<String, dynamic>);
          paths.add(url.path);
          expect(headers!['Content-Type'], 'application/json');
          return http.Response('{"status":"success"}', 201);
        });
    final items = [
      {
        'product_id': 7,
        'quantity': '1.250',
        'receive': true,
        'tax_include_purchase': false
      }
    ];
    await api.createPurchaseOrder(
        accessToken: 'token',
        purchaseDate: '2026-10-03',
        supplierId: '9',
        storeId: '2',
        discount: 1.5,
        items: items,
        voucherNumber: 'V1',
        invoiceRef: 'INV1',
        paymentMethods: ['3'],
        paidAmounts: {'3': 12.5});
    expect(bodies[0], {
      'purchase_date': '2026-10-03',
      'supplier_id': '9',
      'store_id': '2',
      'discount': 1.5,
      'items': items,
      'voucher_number': 'V1',
      'invoice_ref': 'INV1',
      'payment_methods': ['3'],
      'paid_amounts': {'3': 12.5}
    });
    await api.receivePurchaseOrder(
        accessToken: 'token',
        purchaseId: '100',
        discount: 0,
        items: items,
        timeoutMessage: 'Timed out',
        invoiceRef: '');
    expect(bodies[1], {'discount': 0, 'items': items});
    expect(paths[1], contains('100'));
  });
  test(
      'legacy item endpoints retain form encoding and finish normalizes payment ids',
      () async {
    final requests = <Object?>[];
    final api = PurchaseApi(
        session: const FixedSession(),
        httpPost: (url, {headers, body, encoding}) async {
          requests.add(body);
          return http.Response('{"status":"success"}', 200);
        });
    await api.addPurchaseItem(
        accessToken: 'token',
        categoryId: '1',
        productId: '2',
        quantity: '3',
        unit: 'PCS',
        supplierId: '4',
        storeId: '5',
        batchNumber: 'B');
    expect(requests[0], {
      'category_id': '1',
      'product_id': '2',
      'quantity': '3',
      'unit': 'PCS',
      'supplier_id': '4',
      'store_id': '5',
      'batch_number': 'B'
    });
    await api.addPurchase(accessToken: 'token', purchaseId: '10');
    expect(requests[1], {'purchase_id': '10'});
    await api.removePurchaseItem(accessToken: 'token', itemId: '11');
    expect(requests[2], {'item_id': '11'});
    await api.finishPurchaseOrder(
        accessToken: 'token',
        purchaseId: '10',
        purchaseVoucherId: '12',
        paymentMethods: [
          '3',
          'cash'
        ],
        paidMethods: [
          {'method': '3', 'amount': '2.500'}
        ]);
    expect(jsonDecode(requests[3] as String), {
      'purchase_id': 10,
      'purchase_voucher_id': 12,
      'payment_methods': [3, 'cash'],
      'paid_methods': [
        {'method': 3, 'amount': 2.5}
      ]
    });
  });
  test('structured 422 body and status survive both order mutations', () async {
    final api = PurchaseApi(
        session: const FixedSession(),
        httpPost: (url, {headers, body, encoding}) async => http.Response(
            '{"status":"failed","message":"Invalid payment","errors":{"amount":["Too much"]}}',
            422));
    final created = await api.createPurchaseOrder(
        accessToken: 'token',
        purchaseDate: 'date',
        supplierId: '1',
        storeId: '2',
        discount: 0,
        items: []);
    final received = await api.receivePurchaseOrder(
        accessToken: 'token',
        purchaseId: '1',
        discount: 0,
        items: [],
        timeoutMessage: 'Timeout');
    for (final result in [created, received]) {
      expect(result['http_status_code'], 422);
      expect(result['message'], 'Invalid payment');
      expect(result['errors'], {
        'amount': ['Too much']
      });
    }
  });
  test('snapshot reads leave shared list and listeners unchanged', () async {
    final repository = PurchaseRepository(
        api: PurchaseApi(
            session: const FixedSession(),
            httpGet: (url, {headers}) async => http.Response(
                '{"status":"success","data":{"current_page":2,"last_page":4,"data":[]}}',
                200)));
    final provider = PurchaseProvider(repository: repository);
    var notifications = 0;
    provider.addListener(() => notifications++);
    final original = provider.purchaseOrdersList;
    final snapshot = await repository.fetchOrdersPage(
        accessToken: 'token', storeId: 'all', page: 2);
    expect(snapshot.data!.currentPage, 2);
    expect(identical(provider.purchaseOrdersList, original), isTrue);
    expect(provider.listPurchaseOrderCurrentPage, 1);
    expect(notifications, 0);
    await provider.listPurchaseOrders(
        accessToken: 'token', storeId: 'all', page: 2);
    expect(provider.listPurchaseOrderCurrentPage, 2);
    expect(provider.listPurchaseOrderTotalPages, 4);
    expect(notifications, 1);
    provider.dispose();
  });
}
