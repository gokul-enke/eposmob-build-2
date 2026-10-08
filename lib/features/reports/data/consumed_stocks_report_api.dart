import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/resources/app_url.dart';
import '../domain/models/consumed_stocks_report.dart';
import '../domain/consumed_stocks_report_query.dart';

typedef ConsumedStocksHttpGet = Future<http.Response> Function(Uri uri,
    {Map<String, String>? headers});

class ConsumedStocksReportApi {
  ConsumedStocksReportApi(
      {ConsumedStocksHttpGet? get, this.session = const TenantSession()})
      : _get = get ?? http.get;
  final ConsumedStocksHttpGet _get;
  final TenantSession session;
  Future<ConsumedStocksReportScope> scope(String token) async => (
        token: token,
        tenant: await session.apiKey(),
        activeStoreId: await session.activeStoreId(),
        endpoint: APPUrl.consumedStocksReport
      );
  static Uri uri(
          {required String endpoint,
          String? productId,
          String? storeId,
          String? from,
          String? until,
          int? page,
          int? activeStoreId}) =>
      Uri.parse(endpoint).replace(queryParameters: {
        if (productId != null && productId.isNotEmpty) 'product_id': productId,
        if (storeId != null && storeId.isNotEmpty)
          'store_id': storeId
        else if (activeStoreId != null)
          'store_id': '$activeStoreId',
        if (from != null && from.isNotEmpty) 'from': from,
        if (until != null && until.isNotEmpty) 'until': until,
        if (page != null) 'page': '$page',
      });
  Future<GetConsumedStocksReportResponse> fetch(
      {required String accessToken,
      String? productId,
      String? storeId,
      String? from,
      String? until,
      int? page}) async {
    final current = await scope(accessToken);
    if (current.tenant == null || current.tenant!.isEmpty) {
      throw const HttpException('API key not found. Please restart the app.');
    }
    final response = await _get(
            uri(
                endpoint: current.endpoint,
                productId: productId,
                storeId: storeId,
                from: from,
                until: until,
                page: page,
                activeStoreId: current.activeStoreId),
            headers: TenantSession.headers(
                accessToken: accessToken, apiKey: current.tenant!))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw HttpException(
          'Consumed stocks report failed (${response.statusCode})');
    }
    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic> ||
        json['status'] != 'success' ||
        json['data'] is! Map ||
        json['data']['data'] is! List) {
      throw const FormatException('Invalid consumed stocks report envelope');
    }
    return GetConsumedStocksReportResponse.fromJson(json);
  }
}
