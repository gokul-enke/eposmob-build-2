import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory hiveDirectory;
  var nextStoreId = 100;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'customer-provider-pagination-test-',
    );
    Hive.init(hiveDirectory.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'api_key': 'test-tenant',
      'active_store_id': nextStoreId++,
    });
  });

  test('snapshot loads every declared page without mutating provider state',
      () async {
    final requestedPages = <int>[];
    final provider = CustomerProvider(httpGet: (uri, {headers}) async {
      final page = int.parse(uri.queryParameters['page']!);
      requestedPages.add(page);
      return http.Response(
        jsonEncode({
          'status': 'success',
          'data': {
            'current_page': page,
            'last_page': 2,
            'per_page': 2,
            'total': 3,
            'data': page == 1
                ? [
                    {'id': 1, 'name': 'Zulu'},
                    {'id': 2, 'name': 'Bravo'},
                  ]
                : [
                    {'id': 2, 'name': 'Duplicate'},
                    {'id': 3, 'name': 'Alpha'},
                  ],
          },
        }),
        200,
      );
    });
    var notifications = 0;
    provider.addListener(() => notifications++);

    final customers = await provider.fetchAllCustomersSnapshot(
      accessToken: 'token',
    );

    expect(requestedPages, [1, 2]);
    expect(customers.map((customer) => customer.id), [3, 2, 1]);
    expect(provider.allCustomers, isEmpty);
    expect(provider.currentPage, 1);
    expect(notifications, 0);
  });

  test('flat capped responses continue until a short page', () async {
    final requestedPages = <int>[];
    final provider = CustomerProvider(httpGet: (uri, {headers}) async {
      final page = int.parse(uri.queryParameters['page']!);
      requestedPages.add(page);
      final start = page == 1 ? 1 : 101;
      final count = page == 1 ? 100 : 5;
      return http.Response(
        jsonEncode({
          'status': 'success',
          'data': List.generate(
            count,
            (index) => {
              'id': start + index,
              'name': 'Customer ${start + index}',
            },
          ),
        }),
        200,
      );
    });

    final customers = await provider.fetchAllCustomersSnapshot(
      accessToken: 'token',
    );

    expect(requestedPages, [1, 2]);
    expect(customers, hasLength(105));
    expect(customers.map((customer) => customer.id), containsAll([1, 105]));
  });

  test('an unpaginated flat response larger than the requested limit is used',
      () async {
    var requests = 0;
    final provider = CustomerProvider(httpGet: (uri, {headers}) async {
      requests++;
      return http.Response(
        jsonEncode({
          'status': 'success',
          'data': List.generate(
            220,
            (index) => {'id': index + 1, 'name': 'Customer ${index + 1}'},
          ),
        }),
        200,
      );
    });

    final customers = await provider.fetchAllCustomersSnapshot(
      accessToken: 'token',
    );

    expect(requests, 1);
    expect(customers, hasLength(220));
  });

  test('flat endpoints that ignore page stop after the duplicate probe',
      () async {
    final requestedPages = <int>[];
    final pageData = List.generate(
      100,
      (index) => {'id': index + 1, 'name': 'Customer ${index + 1}'},
    );
    final provider = CustomerProvider(httpGet: (uri, {headers}) async {
      requestedPages.add(int.parse(uri.queryParameters['page']!));
      return http.Response(
        jsonEncode({'status': 'success', 'data': pageData}),
        200,
      );
    });

    final customers = await provider.fetchAllCustomersSnapshot(
      accessToken: 'token',
    );

    expect(requestedPages, [1, 2]);
    expect(customers, hasLength(100));
  });

  test('loadAll returns the same complete dataset stored by the provider',
      () async {
    final provider = CustomerProvider(httpGet: (uri, {headers}) async {
      final page = int.parse(uri.queryParameters['page']!);
      return http.Response(
        jsonEncode({
          'status': 'success',
          'data': {
            'current_page': page,
            'last_page': 2,
            'per_page': 2,
            'total': 3,
            'data': page == 1
                ? [
                    {'id': 1, 'name': 'One'},
                    {'id': 2, 'name': 'Two'},
                  ]
                : [
                    {'id': 3, 'name': 'Three'},
                  ],
          },
        }),
        200,
      );
    });

    final response = await provider.listCustomer(
      accessToken: 'token',
      loadAll: true,
    ) as Map<String, dynamic>;
    final returnedCustomers = CustomerListModel.fromJson(response).data!;

    expect(returnedCustomers.map((customer) => customer.id), [1, 2, 3]);
    expect(provider.allCustomers!.map((customer) => customer.id), [1, 2, 3]);
  });

  test('a later page failure does not expose a partial snapshot', () async {
    final provider = CustomerProvider(httpGet: (uri, {headers}) async {
      final page = int.parse(uri.queryParameters['page']!);
      if (page == 2) return http.Response('server error', 500);
      return http.Response(
        jsonEncode({
          'status': 'success',
          'data': {
            'current_page': 1,
            'last_page': 2,
            'per_page': 1,
            'total': 2,
            'data': [
              {'id': 1, 'name': 'One'},
            ],
          },
        }),
        200,
      );
    });

    await expectLater(
      provider.fetchAllCustomersSnapshot(accessToken: 'token'),
      throwsA(isA<HttpException>()),
    );
    expect(provider.allCustomers, isEmpty);
  });
}
