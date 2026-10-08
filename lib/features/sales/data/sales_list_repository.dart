import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/resources/app_url.dart';
import '../domain/sales_list_query.dart';

class SalesListPageData {
  SalesListPageData(
      {required List<ListOrderModelData> rows,
      required this.current,
      required this.last,
      required this.from,
      this.perPage = 20,
      this.total,
      this.completeRows = true,
      this.totalPagesKnown = true})
      : rows = List.unmodifiable(rows);
  final List<ListOrderModelData> rows;
  final int current, last, from, perPage;
  final int? total;
  final bool completeRows, totalPagesKnown;
  bool get hasNext => current < last;
}

abstract class SalesListSource {
  Future<SalesListPageData> fetch(String token, SalesListQuery query, int page);
  Future<List<ListOrderModelData>> snapshot(String token, SalesListQuery query,
      {void Function(int page, int last)? progress});
}

/// A failed page aborts the complete export; it must never be skipped.
class SalesListExportPageException implements Exception {
  const SalesListExportPageException(this.page, this.cause);
  final int page;
  final Object cause;
  @override
  String toString() => 'Sales export failed on page $page: $cause';
}

typedef SalesListHttpGet = Future<http.Response> Function(Uri uri,
    {Map<String, String>? headers});

/// Request-local list transport. Details and mutations retain SalesProvider.
class SalesListRepository implements SalesListSource {
  SalesListRepository(
      {SalesListHttpGet? get, this.session = const TenantSession()})
      : _get = get ?? http.get;
  final SalesListHttpGet _get;
  final TenantSession session;
  static const maximumExportPages = 1000;
  Future<({Map<String, String> headers, int? store})> _scope(
      String token, SalesListQuery query) async {
    if (token.isEmpty) {
      throw const HttpException('Authentication token missing');
    }
    final tenant = await session.apiKey();
    if (tenant == null || tenant.isEmpty) {
      throw const HttpException('API key not found. Please restart the app.');
    }
    return (
      headers: TenantSession.headers(accessToken: token, apiKey: tenant),
      store: query.storeId ?? await session.activeStoreId()
    );
  }

  @override
  Future<SalesListPageData> fetch(
          String token, SalesListQuery query, int page) async =>
      _page(query, page, await _scope(token, query));
  Future<SalesListPageData> _page(SalesListQuery query, int page,
      ({Map<String, String> headers, int? store}) scope) async {
    final response = await _get(
            Uri.parse(APPUrl.getListOrder)
                .replace(queryParameters: query.parameters(page, scope.store)),
            headers: scope.headers)
        .timeout(const Duration(seconds: 15));
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw HttpException(
          'Invalid sales response on page $page: HTTP ${response.statusCode}');
    }
    if (response.statusCode == 500 &&
        decoded is Map &&
        decoded['status'] == 'failed' &&
        decoded['message'] == 'No Orders Found') {
      return SalesListPageData(
          rows: const [], current: page, last: page, from: 1, total: 0);
    }
    if (response.statusCode != 200) {
      throw HttpException(
          'Failed to load sales page $page: HTTP ${response.statusCode}');
    }
    if (decoded is! Map<String, dynamic> ||
        !(decoded['status'] == 'success' || decoded['success'] == true)) {
      throw const FormatException('Unsuccessful sales response');
    }
    final wrapper = decoded['data'];
    if (wrapper is! Map<String, dynamic> || wrapper['data'] is! List) {
      throw const FormatException('Invalid sales list');
    }
    int? integer(Object? raw) => raw is int ? raw : int.tryParse('$raw');
    final current = integer(wrapper['current_page']) ?? 0;
    final simple = !wrapper.containsKey('last_page') &&
        wrapper.containsKey('next_page_url');
    final next = wrapper['next_page_url'];
    if (simple &&
        next != null &&
        (next is! String ||
            integer(Uri.tryParse(next)?.queryParameters['page']) !=
                current + 1)) {
      throw const FormatException('Invalid next sales page');
    }
    final last = integer(wrapper['last_page']) ??
        (simple ? current + (next == null ? 0 : 1) : 0);
    final perPage = integer(wrapper['per_page']) ?? 20;
    final total = integer(wrapper['total']);
    if (current != page ||
        last < current ||
        perPage < 1 ||
        (wrapper.containsKey('per_page') &&
            integer(wrapper['per_page']) == null) ||
        (wrapper.containsKey('total') && (total == null || total < 0))) {
      throw const FormatException('Invalid sales pagination');
    }
    final rawRows = wrapper['data'] as List;
    // Preserve the existing row-by-row recovery for display. Export rejects
    // any recovered page so malformed financial rows cannot silently disappear.
    final rows = <ListOrderModelData>[];
    for (final raw in rawRows) {
      try {
        rows.add(
            ListOrderModelData.fromJson(Map<String, dynamic>.from(raw as Map)));
      } catch (_) {/* Same display recovery as ListSalesOrderModel. */}
    }
    final from = integer(wrapper['from']) ??
        (rows.isEmpty ? 1 : (current - 1) * perPage + 1);
    if (rows.isNotEmpty && from < 1) {
      throw const FormatException('Invalid sales row offset');
    }
    return SalesListPageData(
        rows: rows,
        current: current,
        last: last,
        from: from,
        perPage: perPage,
        total: total,
        completeRows: rows.length == rawRows.length,
        totalPagesKnown: !simple);
  }

  @override
  Future<List<ListOrderModelData>> snapshot(String token, SalesListQuery query,
      {void Function(int page, int last)? progress}) async {
    final scope = await _scope(token, query);
    Future<SalesListPageData> exportPage(int page) async {
      try {
        return await _page(query, page, scope);
      } catch (failure) {
        throw SalesListExportPageException(page, failure);
      }
    }

    final first = await exportPage(1);
    if (first.last > maximumExportPages) {
      throw StateError('Sales export exceeds page limit');
    }
    final rows = <ListOrderModelData>[];
    final ids = <int>{};
    void append(SalesListPageData data) {
      if (!data.completeRows ||
          data.totalPagesKnown != first.totalPagesKnown ||
          (first.totalPagesKnown && data.last != first.last) ||
          data.total != first.total ||
          data.perPage != first.perPage ||
          (data.rows.isEmpty && (data.current > 1 || data.hasNext)) ||
          (data.rows.isNotEmpty && data.from != rows.length + 1)) {
        throw StateError('Sales export changed or is incomplete');
      }
      for (final row in data.rows) {
        final amount =
            double.tryParse(row.grantTotal?.replaceAll(',', '').trim() ?? '');
        if (row.id == null ||
            row.id! <= 0 ||
            row.orderNumber?.trim().isNotEmpty != true ||
            !ids.add(row.id!) ||
            amount == null ||
            !amount.isFinite) {
          throw StateError('Duplicate, missing or invalid sales export row');
        }
        rows.add(row);
      }
      progress?.call(data.current, data.last);
    }

    append(first);
    var latest = first;
    while (latest.hasNext) {
      if (latest.current >= maximumExportPages) {
        throw StateError('Sales export exceeds page limit');
      }
      latest = await exportPage(latest.current + 1);
      append(latest);
    }
    if (first.total != null && rows.length != first.total) {
      throw StateError('Incomplete sales export');
    }
    return List.unmodifiable(rows);
  }
}
