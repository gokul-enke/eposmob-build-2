import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/resources/app_url.dart';
import '../domain/models/general_payment.dart';

typedef GeneralPaymentHttpGet = Future<http.Response> Function(Uri url,
    {Map<String, String>? headers});

/// Reads the active store's general payments of every entry type. The list
/// is small (about 130 entries), so it loads whole and is filtered in memory.
class GeneralPaymentApi {
  GeneralPaymentApi(
      {String Function()? endpoint,
      GeneralPaymentHttpGet? get,
      this.session = const TenantSession()})
      : _endpoint = endpoint ?? (() => APPUrl.listGeneralPayments),
        _get = get ?? http.get;

  /// The API's largest page.
  static const pageSize = 100;

  /// Stops a server that never reaches its last page.
  static const maxPages = 1000;
  static const timeout = Duration(seconds: 30);

  final String Function() _endpoint;
  final GeneralPaymentHttpGet _get;
  final TenantSession session;

  /// Every page of the list, checked to add up: each page is the one asked
  /// for, the last page and total never change, no entry repeats and the
  /// count matches the total. Returns null once [isCurrent] turns false.
  Future<List<GeneralPayment>?> fetchAll(
      {required String accessToken, bool Function()? isCurrent}) async {
    final apiKey = await session.apiKey();
    if (apiKey == null) throw StateError('Tenant is unavailable.');
    final storeId = await session.activeStoreId();
    final rows = <GeneralPayment>[];
    final seen = <Object>{};
    int? lastPage, total;
    for (var page = 1; page <= (lastPage ?? 1); page++) {
      if (page > maxPages) {
        throw const FormatException('Too many general payment pages.');
      }
      final uri = Uri.parse(_endpoint()).replace(queryParameters: {
        if (storeId != null) 'store_id': '$storeId',
        'per_page': '$pageSize',
        if (page > 1) 'page': '$page',
      });
      final response = await _get(uri,
              headers: TenantSession.headers(
                  accessToken: accessToken, apiKey: apiKey))
          .timeout(timeout);
      if (isCurrent != null && !isCurrent()) return null;
      if (response.statusCode != 200) {
        throw StateError(
            'General payments request failed (${response.statusCode}).');
      }
      final body = json.decode(response.body);
      if (body is! Map ||
          body['success'] == false ||
          body['status'] == 'failed') {
        throw const FormatException('Invalid general payments response.');
      }
      final data = body['data'];
      if (data is! List) {
        throw const FormatException('General payment rows are missing.');
      }
      final paging = body['pagination'];
      if (paging is Map) {
        final current = paging['current_page'];
        final last = paging['last_page'];
        final count = paging['total'];
        if (current != page ||
            last is! int ||
            last < page ||
            (lastPage != null && last != lastPage) ||
            count is! int ||
            count < 0 ||
            (total != null && count != total) ||
            (data.isEmpty && (page > 1 || last > 1))) {
          throw const FormatException('Incomplete general payment pages.');
        }
        lastPage = last;
        total = count;
      } else {
        // Without paging the first answer is the whole list.
        lastPage = 1;
      }
      for (final raw in data) {
        if (raw is! Map) {
          throw const FormatException('Invalid general payment row.');
        }
        final row = GeneralPayment.fromJson(Map<String, dynamic>.from(raw));
        if (!seen.add(row.id ?? row.referenceNumber)) {
          throw const FormatException('Duplicate general payment.');
        }
        rows.add(row);
      }
    }
    if (total != null && rows.length != total) {
      throw const FormatException('Incomplete general payment total.');
    }
    if (isCurrent != null && !isCurrent()) return null;
    return rows;
  }
}
