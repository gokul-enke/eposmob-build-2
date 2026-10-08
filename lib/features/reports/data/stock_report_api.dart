import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/resources/app_url.dart';
import '../domain/models/stock_report.dart';
import '../domain/stock_report_query.dart';

typedef StockReportHttpGet = Future<http.Response> Function(Uri uri,
    {Map<String, String>? headers});

/// The existing stock endpoint, with injectable transport and tenant lookup.
class StockReportApi {
  StockReportApi(
      {StockReportHttpGet? get, this.session = const TenantSession()})
      : _get = get ?? http.get;
  final StockReportHttpGet _get;
  final TenantSession session;
  Future<StockReportScope> scope(String token) async => (
        token: token,
        tenant: await session.apiKey(),
        activeStoreId: await session.activeStoreId(),
        endpoint: APPUrl.stockReportUrl
      );

  static Uri uri(
      {required String endpoint,
      String? product,
      String? sortBy,
      String? sortDirection,
      int? storeId,
      int? activeStoreId,
      int? categoryId,
      String? stockLevel,
      String? expiringWithin,
      String? snapshotDate,
      String? from,
      String? until,
      int? page,
      int? perPage}) {
    final query = <String, String>{};
    void add(String key, String? value) {
      if (value != null && value.isNotEmpty) query[key] = value;
    }

    add('product', product);
    add('sort_by', sortBy);
    add('sort_direction', sortDirection);
    add('store_id', (storeId ?? activeStoreId)?.toString());
    add('category_id', categoryId?.toString());
    if (stockLevel != 'All') add('stock_level', stockLevel);
    if (expiringWithin != 'All') add('expiring_within', expiringWithin);
    add('snapshot_date', snapshotDate);
    add('from', from);
    add('until', until);
    add('page', page?.toString());
    add('per_page', perPage?.toString());
    return Uri.parse(endpoint).replace(queryParameters: query);
  }

  Future<GetStockReportResponse> fetch(
      {required String accessToken,
      String? product,
      String? sortBy,
      String? sortDirection,
      int? storeId,
      int? categoryId,
      String? stockLevel,
      String? expiringWithin,
      String? snapshotDate,
      String? from,
      String? until,
      int? page,
      int? perPage}) async {
    final tenant = await session.apiKey(),
        activeStore = await session.activeStoreId();
    if (tenant == null || tenant.isEmpty) {
      throw const HttpException('API key not found. Please restart the app.');
    }
    final response = await _get(
            uri(
                endpoint: APPUrl.stockReportUrl,
                product: product,
                sortBy: sortBy,
                sortDirection: sortDirection,
                storeId: storeId,
                activeStoreId: activeStore,
                categoryId: categoryId,
                stockLevel: stockLevel,
                expiringWithin: expiringWithin,
                snapshotDate: snapshotDate,
                from: from,
                until: until,
                page: page,
                perPage: perPage),
            headers:
                TenantSession.headers(accessToken: accessToken, apiKey: tenant))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Failed to load stock report');
    }
    if (response.body.isEmpty) throw Exception('Received empty response');
    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic> ||
        !(json['data'] is List ||
            (json['data'] is Map && json['data']['data'] is List))) {
      throw const FormatException('Invalid stock report envelope');
    }
    return GetStockReportResponse.fromJson(json);
  }
}
