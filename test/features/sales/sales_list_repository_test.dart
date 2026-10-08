import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/features/sales/data/sales_list_repository.dart';
import 'package:pos_machine/features/sales/domain/sales_list_query.dart';

Map<String, dynamic> order(int id, {Object? amount = '100.50'}) => {
      'id': id,
      'order_number': 'ORD-$id',
      'receipt_number': '000$id',
      'grand_total': amount,
      'order_date': '2026-10-08',
      'status': 'confirmed',
    };
http.Response page(List<Map<String, dynamic>> rows,
        {int current = 1,
        int last = 1,
        int perPage = 10,
        int? total,
        Map<String, dynamic> extra = const {}}) =>
    http.Response(
        jsonEncode({
          'status': 'success',
          'data': {
            'data': rows,
            'current_page': current,
            'last_page': last,
            'per_page': perPage,
            'from': rows.isEmpty ? null : (current - 1) * perPage + 1,
            if (total != null) 'total': total,
            ...extra
          }
        }),
        200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(
      {'api_key': 'tenant', 'active_store_id': 7}));
  test('all legacy filters, tenant headers and numeric pagination stay intact',
      () async {
    final source = SalesListRepository(get: (url, {headers}) async {
      expect(headers?['X-Tenant'], 'tenant');
      expect(headers?['Authorization'], 'Bearer token');
      expect(url.queryParameters, {
        'store_id': '9',
        'filter_store': '9',
        'page': '2',
        'number': 'ORD-001',
        'filter_name': 'Ann',
        'filter_phone': '00123',
        'filter_price': '10',
        'filter_status': 'pending',
        'filter_datetime[from]': '2026-10-01 09:15:00',
        'filter_datetime[until]': '2026-10-08 23:59:00',
        'business_date': '2026-10-07',
      });
      return page([order(2, amount: 10)],
          current: 2,
          last: 2,
          extra: {'current_page': '2', 'last_page': '2', 'per_page': '10'});
    });
    final result = await source.fetch(
        'token',
        SalesListQuery(
            storeId: 9,
            number: ' ord-001 ',
            customer: ' Ann ',
            phone: '00123',
            price: '10',
            status: 'pending',
            from: DateTime(2026, 10, 1, 9, 15),
            until: DateTime(2026, 10, 8, 23, 59),
            businessDate: DateTime(2026, 10, 7)),
        2);
    expect(result.current, 2);
    expect(result.from, 11);
    expect(result.rows.single.grantTotal, '10');
  });
  test('confirmed empty endpoint response differs from network/server failures',
      () async {
    final empty = SalesListRepository(
        get: (url, {headers}) async => http.Response(
            jsonEncode({'status': 'failed', 'message': 'No Orders Found'}),
            500));
    expect(
        (await empty.fetch('token', const SalesListQuery(), 1)).rows, isEmpty);
    for (final response in [
      http.Response('bad', 502),
      http.Response(
          jsonEncode({'status': 'failed', 'message': 'Server failed'}), 500),
      http.Response(
          jsonEncode({
            'status': 'success',
            'data': {'data': null}
          }),
          200)
    ]) {
      final source =
          SalesListRepository(get: (url, {headers}) async => response);
      await expectLater(
          source.fetch('token', const SalesListQuery(), 1), throwsA(anything));
    }
  });
  test('online filter is kept on every listing and export page', () async {
    final requests = <Map<String, String>>[];
    final source = SalesListRepository(get: (url, {headers}) async {
      requests.add(url.queryParameters);
      final p = int.parse(url.queryParameters['page']!);
      return page([order(p)], current: p, last: 2, perPage: 1, total: 2);
    });
    const online = SalesListQuery(isOnlineSales: true, phone: '00123');
    await source.fetch('token', online, 2);
    final rows = await source.snapshot('token', online);
    expect(rows.map((row) => row.id), [1, 2]);
    expect(requests.map((r) => r['page']), ['2', '1', '2']);
    expect(requests.every((r) => r['filter_online_sales'] == 'true'), true);
    expect(requests.every((r) => r['filter_phone'] == '00123'), true);
    expect(online.sameAs(const SalesListQuery(phone: '00123')), false);
    expect(const SalesListQuery().parameters(1, null),
        isNot(contains('filter_online_sales')));
  });
  for (final online in [false, true]) {
    test('Delivered uses the raw API filter on every page online=$online',
        () async {
      final requests = <Map<String, String>>[];
      final source = SalesListRepository(get: (url, {headers}) async {
        requests.add(url.queryParameters);
        final p = int.parse(url.queryParameters['page']!);
        return page([
          {...order(p), 'status': 'delivered'}
        ], current: p, last: 2, perPage: 1, total: 2);
      });
      final query = SalesListQuery(status: 'delivered', isOnlineSales: online);
      final listing = await source.fetch('token', query, 2);
      final exported = await source.snapshot('token', query);
      expect(listing.rows.single.status, 'delivered');
      expect(exported.map((row) => row.status), ['delivered', 'delivered']);
      expect(requests.map((r) => r['page']), ['2', '1', '2']);
      expect(requests.every((r) => r['filter_status'] == 'delivered'), true);
      expect(
          requests.every(
              (r) => r['filter_online_sales'] == (online ? 'true' : null)),
          true);
    });
  }
  test('all pages export in order with frozen tenant/store scope', () async {
    final requested = <int>[];
    final source = SalesListRepository(get: (url, {headers}) async {
      final p = int.parse(url.queryParameters['page']!);
      requested.add(p);
      expect(url.queryParameters['store_id'], '7');
      expect(headers?['X-Tenant'], 'tenant');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_key', 'different');
      await prefs.setInt('active_store_id', 90);
      return page([order(p)], current: p, last: 3, perPage: 1, total: 3);
    });
    final rows = await source.snapshot('token', const SalesListQuery());
    expect(rows.map((row) => row.id), [1, 2, 3]);
    expect(requested, [1, 2, 3]);
  });
  test(
      'duplicate IDs cannot replace another order while preserving total count',
      () async {
    final source = SalesListRepository(get: (url, {headers}) async {
      final p = int.parse(url.queryParameters['page']!);
      return page([order(1)], current: p, last: 2, perPage: 1, total: 2);
    });
    await expectLater(
        source.snapshot('token', const SalesListQuery()), throwsStateError);
  });
  test('display recovers malformed rows but export never silently drops them',
      () async {
    final source = SalesListRepository(
        get: (url, {headers}) async => page([
              order(1),
              {
                ...order(2),
                'order_props': {'bad': 'shape'}
              }
            ], total: 2));
    final data = await source.fetch('token', const SalesListQuery(), 1);
    expect(data.rows, hasLength(1));
    expect(data.completeRows, false);
    await expectLater(
        source.snapshot('token', const SalesListQuery()), throwsStateError);
  });
  for (final invalid in [null, 'bad', 'NaN', 'Infinity']) {
    test('invalid financial amount $invalid rejects export', () async {
      final source = SalesListRepository(
          get: (url, {headers}) async => page([order(1, amount: invalid)]));
      await expectLater(
          source.snapshot('token', const SalesListQuery()), throwsStateError);
    });
  }
  test('missing order identity rejects export', () async {
    for (final extra in [
      {'id': null},
      {'id': 0},
      {'order_number': null}
    ]) {
      final source = SalesListRepository(
          get: (url, {headers}) async => page([
                {...order(1), ...extra}
              ]));
      await expectLater(
          source.snapshot('token', const SalesListQuery()), throwsStateError);
    }
  });
  test('later-page failures and incomplete/changing counts reject export',
      () async {
    for (final second in [
      page([], current: 2, last: 2, perPage: 1, total: 2),
      page([order(2)], current: 2, last: 3, perPage: 1, total: 3),
      page([order(2)],
          current: 2, last: 2, perPage: 1, total: 2, extra: {'from': 99}),
      http.Response('unavailable', 503)
    ]) {
      final source = SalesListRepository(
          get: (url, {headers}) async => url.queryParameters['page'] == '1'
              ? page([order(1)], last: 2, perPage: 1, total: 2)
              : second);
      await expectLater(
          source.snapshot('token', const SalesListQuery()), throwsA(anything));
    }
    final source = SalesListRepository(
        get: (url, {headers}) async => page([order(1)], total: 2));
    await expectLater(
        source.snapshot('token', const SalesListQuery()), throwsStateError);
  });
  test('HTML server failure identifies the page and prevents partial export',
      () async {
    final requested = <int>[];
    final source = SalesListRepository(get: (url, {headers}) async {
      final p = int.parse(url.queryParameters['page']!);
      requested.add(p);
      if (p == 2) {
        return http.Response(
            '<html><title>CLOUDPOSDEMO</title>TypeError</html>', 500,
            headers: {'content-type': 'text/html'});
      }
      return page([order(p)], current: p, last: 3, perPage: 1, total: 3);
    });
    await expectLater(
        source.snapshot('token', const SalesListQuery()),
        throwsA(isA<SalesListExportPageException>()
            .having((e) => e.page, 'failed page', 2)
            .having((e) => e.cause, 'cause', isA<HttpException>())));
    expect(requested, [1, 2]);
    final retry = await source.fetch('token', const SalesListQuery(), 1);
    expect(retry.rows.single.id, 1);
  });
  test('incorrect page and missing/malformed pagination are errors', () async {
    for (final extra in [
      {'current_page': 2},
      {'last_page': null},
      {'per_page': 'bad'},
      {'total': -1}
    ]) {
      final source = SalesListRepository(
          get: (url, {headers}) async => page([order(1)], extra: extra));
      await expectLater(source.fetch('token', const SalesListQuery(), 1),
          throwsFormatException);
    }
  });
  test('simple paginator follows locally generated requests and is bounded',
      () async {
    final source = SalesListRepository(get: (url, {headers}) async {
      final p = int.parse(url.queryParameters['page']!);
      return http.Response(
          jsonEncode({
            'status': 'success',
            'data': {
              'data': [order(p)],
              'current_page': p,
              'per_page': 1,
              'from': p,
              'next_page_url':
                  p == 2 ? null : 'https://untrusted.test/orders?page=2'
            }
          }),
          200);
    });
    expect(
        (await source.fetch('token', const SalesListQuery(), 1))
            .totalPagesKnown,
        false);
    expect(
        await source.snapshot('token', const SalesListQuery()), hasLength(2));
  });
  test('too many export pages and missing authentication are rejected',
      () async {
    final source = SalesListRepository(
        get: (url, {headers}) async => page([order(1)], last: 1001));
    await expectLater(
        source.snapshot('token', const SalesListQuery()), throwsStateError);
    await expectLater(source.fetch('', const SalesListQuery(), 1),
        throwsA(isA<HttpException>()));
    SharedPreferences.setMockInitialValues({});
    await expectLater(source.fetch('token', const SalesListQuery(), 1),
        throwsA(isA<HttpException>()));
  });
}
