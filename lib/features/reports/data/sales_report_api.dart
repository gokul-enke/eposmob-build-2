import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/resources/app_url.dart';
import '../domain/models/sales_report.dart';
import '../domain/report_values.dart';
import '../domain/sales_report_query.dart';

typedef SalesReportHttpGet = Future<http.Response> Function(Uri uri,
    {Map<String, String>? headers});

/// GET transport of the Sales Report. The endpoint, HTTP and the tenant
/// session are injectable for tests.
class SalesReportApi {
  SalesReportApi(
      {String Function()? endpoint,
      SalesReportHttpGet? get,
      this.session = const TenantSession()})
      : endpoint = endpoint ?? (() => APPUrl.orderSalesReport),
        _get = get ?? http.get;

  /// Read on every call, since the base URL follows the login.
  final String Function() endpoint;
  final SalesReportHttpGet _get;
  final TenantSession session;

  Future<SalesReportScope> scope(String token) async => (
        token: token,
        tenant: await session.apiKey(),
        activeStoreId: await session.activeStoreId(),
        endpoint: endpoint()
      );

  /// The report's filters plus paging. The active store is deliberately not
  /// sent: the report covers every store unless the Stores filter is set.
  static Uri uri(String endpoint, Map<String, String> parameters,
          {required int page, required int perPage}) =>
      Uri.parse(endpoint).replace(queryParameters: {
        ...parameters,
        SalesReportParams.page: '$page',
        SalesReportParams.perPage: '$perPage',
      });

  Future<SalesReportResponse> fetch(
      {required String accessToken,
      required Map<String, String> parameters,
      required int page,
      required int perPage}) async {
    final scope = await this.scope(accessToken);
    final body = await _read(
        scope, uri(scope.endpoint, parameters, page: page, perPage: perPage));
    return SalesReportResponse.parse(jsonDecode(body));
  }

  /// Sales executives of the company, for the Sales Executives filter.
  Future<List<SalesReportOption>> salesExecutives(String accessToken) async {
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
          SalesReportOption(
              '${reportInt(item['id'])}', reportText(item['name'])!)
    ];
  }

  Future<String> _read(SalesReportScope scope, Uri uri) async {
    final tenant = scope.tenant;
    if (tenant == null || tenant.isEmpty) {
      throw const HttpException('API key not found. Please restart the app.');
    }
    final response = await _get(uri,
            headers:
                TenantSession.headers(accessToken: scope.token, apiKey: tenant))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw HttpException(
          'Failed to load sales report (${response.statusCode})');
    }
    if (response.body.isEmpty) {
      throw const FormatException('Received empty response');
    }
    return response.body;
  }
}
