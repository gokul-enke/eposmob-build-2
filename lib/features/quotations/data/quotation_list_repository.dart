import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/models/quotation_model.dart';
import 'package:pos_machine/resources/app_url.dart';
import '../domain/quotation_list_query.dart';

class QuotationListPageData {
  QuotationListPageData(
      {required List<Quotation> rows,
      required this.current,
      required this.last,
      required this.from,
      this.total,
      this.perPage,
      this.totalPagesKnown = true})
      : rows = List.unmodifiable(rows);
  final List<Quotation> rows;
  final int current, last, from;
  final int? total, perPage;
  final bool totalPagesKnown;
  bool get hasNext => current < last;
}

abstract class QuotationListSource {
  Future<QuotationListPageData> fetch(
      String token, QuotationListQuery query, int page);
  Future<List<Quotation>> snapshot(String token, QuotationListQuery query,
      {void Function(int page, int last)? progress});
}

typedef QuotationHttpGet = Future<http.Response> Function(Uri uri,
    {Map<String, String>? headers});

/// Listing-only transport. Creation, conversion, details and printing continue
/// to use their existing provider and contracts.
class QuotationListRepository implements QuotationListSource {
  QuotationListRepository(
      {QuotationHttpGet? get, this.session = const TenantSession()})
      : _get = get ?? http.get;
  final QuotationHttpGet _get;
  final TenantSession session;
  static const maximumExportPages = 1000;

  Future<({Map<String, String> headers, int? store})> _scope(
      String token) async {
    if (token.isEmpty) {
      throw const HttpException('Authentication token missing');
    }
    final key = await session.apiKey();
    if (key == null || key.isEmpty) {
      throw const HttpException('API key not found. Please restart the app.');
    }
    return (
      headers: TenantSession.headers(accessToken: token, apiKey: key),
      store: await session.activeStoreId()
    );
  }

  @override
  Future<QuotationListPageData> fetch(
      String token, QuotationListQuery query, int page) async {
    final scope = await _scope(token);
    return _page(query, page, scope);
  }

  Future<QuotationListPageData> _page(QuotationListQuery query, int page,
      ({Map<String, String> headers, int? store}) scope) async {
    final response = await _get(
            Uri.parse(APPUrl.listQuotations)
                .replace(queryParameters: query.parameters(page, scope.store)),
            headers: scope.headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      // This endpoint represents an empty filter result with this exact 500
      // envelope. Other HTTP failures must remain errors, never empty results.
      if (response.statusCode == 500) {
        Object? empty;
        try {
          empty = jsonDecode(response.body);
        } on FormatException {
          // Non-JSON failures retain their HTTP status below.
        }
        if (empty is Map<String, dynamic> &&
            empty['status'] == 'failed' &&
            empty['message'] == 'No quotations found' &&
            empty['data'] is List &&
            (empty['data'] as List).isEmpty) {
          return QuotationListPageData(
              rows: const [], current: page, last: page, from: 1, total: 0);
        }
      }
      throw HttpException(
          'Failed to load quotations: HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        !(decoded['success'] == true ||
            decoded['status']?.toString().toLowerCase() == 'success')) {
      throw const FormatException('Unsuccessful quotation response');
    }
    final wrapper = decoded['data'];
    if (wrapper is! Map<String, dynamic> || wrapper['data'] is! List) {
      throw const FormatException('Invalid quotation list');
    }
    int? integer(Object? raw) => raw is int ? raw : int.tryParse('$raw');
    final current = integer(wrapper['current_page']) ??
        (wrapper.containsKey('current_page') ? 0 : 1);
    final simple = !wrapper.containsKey('last_page') &&
        wrapper.containsKey('next_page_url');
    final next = wrapper['next_page_url'];
    if (simple && next != null) {
      final nextPage = next is String
          ? integer(Uri.tryParse(next)?.queryParameters['page'])
          : null;
      if (nextPage != current + 1) {
        throw const FormatException('Invalid next quotation page');
      }
    }
    final last = integer(wrapper['last_page']) ??
        (wrapper.containsKey('last_page')
            ? 0
            : (simple ? current + (next == null ? 0 : 1) : 1));
    final total = integer(wrapper['total']);
    final perPage = integer(wrapper['per_page']);
    if (current != page ||
        last < current ||
        (wrapper.containsKey('total') && (total == null || total < 0)) ||
        (wrapper.containsKey('per_page') && (perPage == null || perPage < 1))) {
      throw const FormatException('Invalid quotation pagination');
    }
    final rows = (wrapper['data'] as List)
        .map((item) =>
            Quotation.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    final from = integer(wrapper['from']) ??
        (rows.isEmpty
            ? 1
            : (current == 1
                ? 1
                : (perPage == null ? 0 : (current - 1) * perPage + 1)));
    if (rows.isNotEmpty && from < 1) {
      throw const FormatException('Missing quotation row offset');
    }
    return QuotationListPageData(
        rows: rows,
        current: current,
        last: last,
        from: from,
        total: total,
        perPage: perPage,
        totalPagesKnown: !simple);
  }

  @override
  Future<List<Quotation>> snapshot(String token, QuotationListQuery query,
      {void Function(int page, int last)? progress}) async {
    // Freeze tenant, token and fallback store for every page of this export.
    final scope = await _scope(token);
    final first = await _page(query, 1, scope);
    if (first.last > maximumExportPages) {
      throw StateError('Quotation export exceeds page limit');
    }
    final rows = <Quotation>[];
    final ids = <int>{};
    void append(QuotationListPageData data) {
      if (data.totalPagesKnown != first.totalPagesKnown ||
          (first.totalPagesKnown && data.last != first.last) ||
          data.total != first.total ||
          data.perPage != first.perPage ||
          (data.rows.isEmpty && (data.current > 1 || data.hasNext)) ||
          (data.rows.isNotEmpty && data.from != rows.length + 1)) {
        throw StateError('Quotation export changed');
      }
      for (final row in data.rows) {
        if (row.id == null || !ids.add(row.id!)) {
          throw StateError('Duplicate or missing quotation id');
        }
        rows.add(row);
      }
      progress?.call(data.current, data.last);
    }

    append(first);
    var latest = first;
    while (latest.hasNext) {
      if (latest.current >= maximumExportPages) {
        throw StateError('Quotation export exceeds page limit');
      }
      latest = await _page(query, latest.current + 1, scope);
      append(latest);
    }
    if (first.total != null && rows.length != first.total) {
      throw StateError('Incomplete quotation export');
    }
    return List.unmodifiable(rows);
  }
}
