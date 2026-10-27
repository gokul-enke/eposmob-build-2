import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/resources/app_url.dart';
import '../domain/discount_sale_report_query.dart';
import '../domain/models/discount_sale_report.dart';
import '../domain/report_values.dart';

typedef DiscountSaleReportHttpGet = Future<http.Response> Function(Uri uri,
    {Map<String, String>? headers});

/// GET transport of the Discount Sale Report. Endpoint, HTTP and the tenant
/// session are injectable for tests.
class DiscountSaleReportApi {
  DiscountSaleReportApi(
      {String Function()? endpoint,
      DiscountSaleReportHttpGet? get,
      this.session = const TenantSession()})
      : endpoint = endpoint ?? (() => APPUrl.discountSaleReport),
        _get = get ?? http.get;

  /// Read on every call, since the base URL follows the login.
  final String Function() endpoint;
  final DiscountSaleReportHttpGet _get;
  final TenantSession session;

  Future<DiscountSaleReportScope> scope(String token) async => (
        token: token,
        tenant: await session.apiKey(),
        activeStoreId: await session.activeStoreId(),
        endpoint: endpoint()
      );

  /// The report's filters plus paging. The active store is deliberately not
  /// sent: the report covers every store unless the Store filter is set
  /// (`store_id` *is* that filter).
  static Uri uri(String endpoint, Map<String, String> parameters,
          {required int page, required int perPage}) =>
      Uri.parse(endpoint).replace(queryParameters: {
        ...parameters,
        DiscountSaleReportParams.page: '$page',
        DiscountSaleReportParams.perPage: '$perPage',
      });

  Future<DiscountSaleReportResponse> fetch(
      {required String accessToken,
      required Map<String, String> parameters,
      required int page,
      required int perPage}) async {
    final scope = await this.scope(accessToken);
    final body = await _read(
        scope, uri(scope.endpoint, parameters, page: page, perPage: perPage));
    return DiscountSaleReportResponse.parse(jsonDecode(body));
  }

  /// Sales executives of the company, for the Executive filter.
  Future<List<DiscountSaleReportOption>> salesExecutives(
      String accessToken) async {
    final scope = await this.scope(accessToken);
    final body = await _read(scope, Uri.parse(APPUrl.listSalesExecutives));
    final json = jsonDecode(body);
    if (json is! Map || json['data'] is! List) {
      throw const FormatException('Invalid sales executive response');
    }
    return [
      for (final item in json['data'] as List)
        if (item is Map &&
            reportInt(item['id']) != null &&
            reportText(item['name']) != null)
          DiscountSaleReportOption(
              '${reportInt(item['id'])}', reportText(item['name'])!)
    ];
  }

  Future<String> _read(DiscountSaleReportScope scope, Uri uri) async {
    final tenant = scope.tenant;
    if (tenant == null || tenant.isEmpty) {
      throw const HttpException('API key not found. Please restart the app.');
    }
    final response = await _get(uri,
            headers:
                TenantSession.headers(accessToken: scope.token, apiKey: tenant))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw HttpException('Report request failed (${response.statusCode})');
    }
    if (response.body.isEmpty) {
      throw const FormatException('Received empty response');
    }
    return response.body;
  }
}
