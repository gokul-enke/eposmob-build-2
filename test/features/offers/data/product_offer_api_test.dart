import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/features/offers/data/product_offer_api.dart';
import 'package:pos_machine/resources/app_url.dart';

Map<String, dynamic> _page({
  required List<int> offerIds,
  Object? nextPage,
  List<int> removed = const [],
  String serverTime = '2026-10-06T11:00:00Z',
}) =>
    {
      'success': true,
      'server_time': serverTime,
      'offers': [
        for (final id in offerIds)
          {
            'id': id,
            'version': 1,
            'valid_from': '2026-10-01T00:00:00+05:30',
            'valid_until': '2026-11-01T00:00:00+05:30',
            'lines': [
              {'product_id': 123, 'type': 'percentage', 'value': 10},
            ],
          },
      ],
      'removed_offer_ids': removed,
      'next_page': nextPage,
    };

/// Records every request and answers with [responses] in order.
class _FakeGet {
  _FakeGet(this.responses);

  final List<http.Response> responses;
  final urls = <Uri>[];
  final headers = <Map<String, String>>[];

  Future<http.Response> call(Uri url, {Map<String, String>? headers}) async {
    urls.add(url);
    this.headers.add(headers ?? const {});
    return responses[urls.length - 1];
  }
}

void main() {
  test('sends store, since, tenant and bearer headers', () async {
    final fake = _FakeGet([
      http.Response(jsonEncode(_page(offerIds: [9])), 200),
    ]);
    final response = await ProductOfferApi(httpGet: fake.call).fetch(
      accessToken: 'token',
      apiKey: 'tenant',
      storeId: 1,
      since: DateTime.utc(2026, 10, 5, 10),
    );

    final url = fake.urls.single;
    expect(url.toString(), startsWith(APPUrl.posOfferSync));
    expect(url.queryParameters['store_id'], '1');
    expect(url.queryParameters['since'], '2026-10-05T10:00:00.000Z');
    expect(url.queryParameters.containsKey('page'), isFalse);
    expect(fake.headers.single['Authorization'], 'Bearer token');
    expect(fake.headers.single['X-Tenant'], 'tenant');
    expect(response.offers.single.id, 9);
    expect(response.serverTime, DateTime.utc(2026, 10, 6, 11));
  });

  test('a full download sends no since', () async {
    final fake = _FakeGet([
      http.Response(jsonEncode(_page(offerIds: [])), 200),
    ]);
    await ProductOfferApi(httpGet: fake.call).fetch(
      accessToken: 'token',
      apiKey: 'tenant',
      storeId: 1,
    );
    expect(fake.urls.single.queryParameters.containsKey('since'), isFalse);
  });

  test('follows next_page and keeps the first server_time', () async {
    final fake = _FakeGet([
      http.Response(jsonEncode(_page(offerIds: [9], nextPage: 2)), 200),
      http.Response(
        jsonEncode(_page(
          offerIds: [10],
          removed: [7],
          serverTime: '2026-10-06T11:00:05Z',
        )),
        200,
      ),
    ]);
    final response = await ProductOfferApi(httpGet: fake.call).fetch(
      accessToken: 'token',
      apiKey: 'tenant',
      storeId: 1,
    );
    expect(fake.urls[1].queryParameters['page'], '2');
    expect(response.offers.map((o) => o.id), [9, 10]);
    expect(response.removedOfferIds, {7});
    expect(response.serverTime, DateTime.utc(2026, 10, 6, 11));
  });

  test('404 means the backend has no offer endpoint yet', () async {
    final fake = _FakeGet([http.Response('Not found', 404)]);
    expect(
      ProductOfferApi(httpGet: fake.call).fetch(
        accessToken: 'token',
        apiKey: 'tenant',
        storeId: 1,
      ),
      throwsA(isA<ProductOfferEndpointMissing>()),
    );
  });

  test('rejects an incomplete download when the page limit is reached', () {
    var requests = 0;
    final api = ProductOfferApi(httpGet: (url, {headers}) async {
      requests++;
      return http.Response(
        jsonEncode(_page(offerIds: [requests], nextPage: requests + 1)),
        200,
      );
    });
    expect(
      api.fetch(accessToken: 'token', apiKey: 'tenant', storeId: 1),
      throwsFormatException,
    );
  });

  test('rejects repeated pages instead of accepting a partial snapshot', () {
    final api = ProductOfferApi(httpGet: (url, {headers}) async {
      return http.Response(jsonEncode(_page(offerIds: [9], nextPage: 2)), 200);
    });
    expect(
      api.fetch(accessToken: 'token', apiKey: 'tenant', storeId: 1),
      throwsFormatException,
    );
  });
}
