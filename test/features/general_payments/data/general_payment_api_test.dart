import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/features/general_payments/data/general_payment_api.dart';
import '../../../test_support/network_fakes.dart';
import '../support/general_payment_fixtures.dart';

const _endpoint = 'https://x.test/api/v1/general-payment/list-general-payments';

void main() {
  /// An API serving [pages] in order and recording every request.
  (GeneralPaymentApi, List<Uri>) apiOf(List<Object> pages,
      {FakeTenantSession session = const FakeTenantSession(storeId: 2)}) {
    final requests = <Uri>[];
    return (
      GeneralPaymentApi(
          endpoint: () => _endpoint,
          session: session,
          get: (url, {headers}) async {
            requests.add(url);
            expect(headers?['Authorization'], 'Bearer token');
            expect(headers?['X-Tenant'], 'tenant');
            final page = pages[requests.length - 1];
            return page is http.Response ? page : jsonResponse(page);
          }),
      requests
    );
  }

  test('asks for every entry type of the store, 100 per page', () async {
    final (api, requests) = apiOf([
      apiPage([paymentJson(1)])
    ]);
    final rows = await api.fetchAll(accessToken: 'token');
    expect(rows!.single.referenceNumber, 'EXP00001');
    expect(requests.single.path, Uri.parse(_endpoint).path);
    expect(
        requests.single.queryParameters, {'store_id': '2', 'per_page': '100'});
  });

  test('reads every page of the separate pagination object', () async {
    final (api, requests) = apiOf([
      apiPage([paymentJson(3), paymentJson(2, type: 'INCOME')],
          last: 2, total: 3),
      apiPage([paymentJson(1, type: 'LOAN')], current: 2, last: 2, total: 3),
    ]);
    final rows = await api.fetchAll(accessToken: 'token');
    expect(rows!.map((r) => r.referenceNumber),
        ['EXP00003', 'INC00002', 'LON00001']);
    expect([for (final r in requests) r.queryParameters['page']], [null, '2']);
    expect([for (final r in requests) r.queryParameters['per_page']],
        ['100', '100']);
  });

  test('a list without paging is the whole list', () async {
    final (api, requests) = apiOf([
      {
        'success': true,
        'data': [paymentJson(1), paymentJson(2)]
      }
    ]);
    expect(await api.fetchAll(accessToken: 'token'), hasLength(2));
    expect(requests, hasLength(1));
  });

  test('an empty store loads as an empty list', () async {
    final (api, _) = apiOf([apiPage(const [])]);
    expect(await api.fetchAll(accessToken: 'token'), isEmpty);
  });

  for (final (name, pages) in [
    (
      'a page that is not the one asked for',
      [
        apiPage([paymentJson(2)], last: 2, total: 2),
        apiPage([paymentJson(1)], current: 1, last: 2, total: 2),
      ]
    ),
    (
      'a total that changes between pages',
      [
        apiPage([paymentJson(2)], last: 2, total: 2),
        apiPage([paymentJson(1)], current: 2, last: 2, total: 3),
      ]
    ),
    (
      'a last page that changes between pages',
      [
        apiPage([paymentJson(3)], last: 2, total: 3),
        apiPage([paymentJson(2)], current: 2, last: 3, total: 3),
      ]
    ),
    (
      'an empty later page',
      [
        apiPage([paymentJson(2)], last: 2, total: 2),
        apiPage(const [], current: 2, last: 2, total: 2),
      ]
    ),
    (
      'fewer entries than the total',
      [
        apiPage([paymentJson(1)], total: 2),
      ]
    ),
    (
      'an entry on two pages',
      [
        apiPage([paymentJson(1)], last: 2, total: 2),
        apiPage([paymentJson(1)], current: 2, last: 2, total: 2),
      ]
    ),
    (
      'a failed answer',
      [
        {'success': false, 'message': 'no'}
      ]
    ),
    (
      'rows that are not a list',
      [
        {'success': true, 'data': 'none'}
      ]
    ),
    (
      'a row without an amount',
      [
        apiPage([
          {...paymentJson(1), 'amount': null}
        ])
      ]
    ),
  ]) {
    test('rejects $name', () async {
      final (api, _) = apiOf(pages);
      await expectLater(
          api.fetchAll(accessToken: 'token'), throwsFormatException);
    });
  }

  test('a server error fails the load', () async {
    final (api, _) = apiOf([http.Response('down', 500)]);
    await expectLater(api.fetchAll(accessToken: 'token'), throwsStateError);
  });

  test('stops without a result once the load is no longer current', () async {
    final (api, requests) = apiOf([
      apiPage([paymentJson(2)], last: 2, total: 2),
      apiPage([paymentJson(1)], current: 2, last: 2, total: 2),
    ]);
    expect(await api.fetchAll(accessToken: 'token', isCurrent: () => false),
        isNull);
    expect(requests, hasLength(1));
  });

  test('a missing tenant sends no request', () async {
    final (api, requests) =
        apiOf(const [], session: const FakeTenantSession(key: null));
    await expectLater(api.fetchAll(accessToken: 'token'), throwsStateError);
    expect(requests, isEmpty);
  });
}
