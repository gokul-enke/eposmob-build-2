import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pos_machine/resources/app_url.dart';

import '../domain/product_offer.dart';

typedef ProductOfferHttpGet = Future<http.Response> Function(
  Uri url, {
  Map<String, String>? headers,
});

/// The backend does not have the offer endpoint yet (404/405).
class ProductOfferEndpointMissing implements Exception {
  const ProductOfferEndpointMissing(this.statusCode);
  final int statusCode;

  @override
  String toString() => 'Offer sync endpoint not available ($statusCode).';
}

/// HTTP access to `GET /api/v1/offers/pos-sync`. No state, no caching.
class ProductOfferApi {
  ProductOfferApi({ProductOfferHttpGet? httpGet}) : _get = httpGet ?? http.get;

  static const requestTimeout = Duration(seconds: 20);
  static const maximumPages = 100;

  final ProductOfferHttpGet _get;

  /// Fetches every page of offers for [storeId]. Leave [since] null for a
  /// full download.
  Future<ProductOfferSyncResponse> fetch({
    required String accessToken,
    required String apiKey,
    required int storeId,
    DateTime? since,
  }) async {
    final offers = <ProductOffer>[];
    final removed = <int>{};
    DateTime? serverTime;
    var fullSnapshot = false;
    int? page;
    final visitedPages = <int>{1};

    for (var fetched = 0; fetched < maximumPages; fetched++) {
      final url = Uri.parse(APPUrl.posOfferSync).replace(queryParameters: {
        'store_id': storeId.toString(),
        if (since != null) 'since': since.toUtc().toIso8601String(),
        if (page != null) 'page': page.toString(),
      });
      final response = await _get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
        'Accept': 'application/json',
      }).timeout(requestTimeout);

      if (response.statusCode == 404 || response.statusCode == 405) {
        throw ProductOfferEndpointMissing(response.statusCode);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Offer sync failed (${response.statusCode}).',
          uri: url,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException('Offer sync returned invalid JSON.');
      }
      final json = Map<String, dynamic>.from(decoded);
      final body = ProductOfferSyncResponse.fromJson(json);
      offers.addAll(body.offers);
      removed.addAll(body.removedOfferIds);
      // The first page's server time is the safe `since` for the next sync.
      serverTime ??= body.serverTime;
      fullSnapshot = fullSnapshot || body.fullSnapshot;

      final nextPage = json['next_page'];
      if (nextPage == null) {
        page = null;
        break;
      }
      page = nextPage is int ? nextPage : int.tryParse('${nextPage ?? ''}');
      if (page == null || page <= 0 || !visitedPages.add(page)) {
        throw const FormatException('Offer sync returned invalid pagination.');
      }
    }
    if (page != null) {
      throw const FormatException('Offer sync exceeded the page limit.');
    }

    return ProductOfferSyncResponse(
      offers: offers,
      removedOfferIds: removed,
      serverTime: serverTime,
      fullSnapshot: fullSnapshot,
    );
  }
}
