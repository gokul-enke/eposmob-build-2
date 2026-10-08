import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/resources/app_url.dart';
import '../domain/models/non_stock_report.dart';
import '../domain/non_stock_report_query.dart';

typedef NonStockReportHttpGet = Future<http.Response> Function(Uri uri,
    {Map<String, String>? headers});

/// Existing non-stock request with injectable HTTP and tenant lookup.
class NonStockReportApi {
  NonStockReportApi(
      {NonStockReportHttpGet? get, this.session = const TenantSession()})
      : _get = get ?? http.get;
  final NonStockReportHttpGet _get;
  final TenantSession session;
  Future<NonStockReportScope> scope(String token) async => (
        token: token,
        tenant: await session.apiKey(),
        activeStoreId: await session.activeStoreId(),
        endpoint: APPUrl.nonStockReportUrl
      );
  static Uri uri(
          {required String endpoint,
          String? store,
          String? category,
          String? product,
          String? barcode,
          int? page,
          int? activeStoreId}) =>
      Uri.parse(endpoint).replace(queryParameters: {
        if (store != null && store.isNotEmpty) 'store': store,
        if (category != null && category.isNotEmpty) 'category': category,
        if (product != null && product.isNotEmpty) 'product': product,
        if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
        if (page != null) 'page': '$page',
        if (activeStoreId != null) 'store_id': '$activeStoreId',
      });
  Future<GetNonStockReportResponse> fetch(
      {required String accessToken,
      String? store,
      String? category,
      String? product,
      String? barcode,
      int? page}) async {
    final scope = await this.scope(accessToken);
    if (scope.tenant == null || scope.tenant!.isEmpty) {
      throw const HttpException('API key not found. Please restart the app.');
    }
    final response = await _get(
            uri(
                endpoint: scope.endpoint,
                store: store,
                category: category,
                product: product,
                barcode: barcode,
                page: page,
                activeStoreId: scope.activeStoreId),
            headers: TenantSession.headers(
                accessToken: accessToken, apiKey: scope.tenant!))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw HttpException(
          'Failed to load non-stock report (${response.statusCode})');
    }
    if (response.body.isEmpty) {
      throw const FormatException('Received empty response');
    }
    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic> ||
        json['status'] != 'success' ||
        !(json['data'] is List ||
            (json['data'] is Map && json['data']['data'] is List))) {
      throw const FormatException('Invalid non-stock report envelope');
    }
    return GetNonStockReportResponse.fromJson(json);
  }
}
