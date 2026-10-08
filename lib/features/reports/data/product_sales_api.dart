import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/resources/app_url.dart';
import '../domain/models/product_sales_report.dart';
import '../domain/product_sales_query.dart';

typedef ProductSalesHttpGet = Future<http.Response> Function(Uri uri,
    {Map<String, String>? headers});

/// Product Sales HTTP only. Other ReportsProvider endpoints are unchanged.
class ProductSalesApi {
  ProductSalesApi(
      {ProductSalesHttpGet? get, this.session = const TenantSession()})
      : _get = get ?? http.get;
  final ProductSalesHttpGet _get;
  final TenantSession session;

  static Uri uri(
      {required String endpoint,
      String? categoryId,
      String? productId,
      String? customerId,
      String? startDate,
      String? endDate,
      int page = 1,
      int perPage = 25}) {
    final query = <String, String>{'page': '$page', 'per_page': '$perPage'};
    void add(String key, String? value) {
      if (value != null && value.isNotEmpty) query[key] = value;
    }

    add('category_id', categoryId);
    add('product_id', productId);
    add('customer_id', customerId);
    add('from', startDate);
    add('to', endDate);
    return Uri.parse(endpoint).replace(queryParameters: query);
  }

  Future<ProductSalesScope> scope(String token) async => (
        token: token,
        tenant: await session.apiKey(),
        storeId: await session.activeStoreId(),
        endpoint: APPUrl.productSalesReport
      );

  Future<GetProductSalesReportResponse> fetch(
      {required String accessToken,
      String? categoryId,
      String? productId,
      String? customerId,
      String? startDate,
      String? endDate,
      int page = 1,
      int perPage = 25}) async {
    final tenant = await session.apiKey();
    if (tenant == null || tenant.isEmpty) {
      throw const HttpException('API key not found. Please restart the app.');
    }
    final response = await _get(
            uri(
                endpoint: APPUrl.productSalesReport,
                categoryId: categoryId,
                productId: productId,
                customerId: customerId,
                startDate: startDate,
                endDate: endDate,
                page: page,
                perPage: perPage),
            headers:
                TenantSession.headers(accessToken: accessToken, apiKey: tenant))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Failed to load product sales report');
    }
    if (response.body.isEmpty) throw Exception('Received empty response');
    return GetProductSalesReportResponse.fromJson(json.decode(response.body));
  }
}
