import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pos_machine/helpers/api_response_helper.dart';
import 'package:pos_machine/features/sales_returns/domain/models/list_sales_return.dart';
import '../domain/sales_return_list.dart';

class SalesReturnListRepository implements SalesReturnListSource {
  SalesReturnListRepository(this.scope, {http.Client? client})
      : _client = client;
  @override
  final SalesReturnListScope scope;
  final http.Client? _client;

  @override
  Future<SalesReturnListData> fetch(int page) async {
    if (scope.token.isEmpty || scope.tenant.isEmpty || page < 1) {
      throw StateError('Sales return request scope is unavailable');
    }
    final uri = Uri.parse(scope.endpoint).replace(queryParameters: {
      'page': '$page',
      if (scope.storeId != null) 'store_id': '${scope.storeId}',
    });
    final client = _client ?? http.Client();
    try {
      final response = await client.get(uri, headers: {
        'Authorization': 'Bearer ${scope.token}',
        'X-Tenant': scope.tenant,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));
      ApiResponseHelper.ensureSuccess(response.statusCode, response.body,
          fallback: 'Failed to load sales returns');
      return parse(response.body, requestedPage: page);
    } finally {
      if (_client == null) client.close();
    }
  }

  static SalesReturnListData parse(String body, {required int requestedPage}) {
    final json = jsonDecode(body);
    if (json is! Map || json['status'] != 'success' || json['data'] is! Map) {
      throw const FormatException('Invalid sales return response');
    }
    final data = json['data'] as Map;
    int integer(String key, {bool zero = false}) {
      final raw = data[key];
      final number = int.tryParse(raw?.toString() ?? '');
      if (number == null || number < (zero ? 0 : 1)) {
        throw FormatException('Invalid sales return pagination: $key');
      }
      return number;
    }

    final page = integer('current_page'), pages = integer('last_page');
    final perPage = integer('per_page'), total = integer('total', zero: true);
    final expectedPages = total == 0 ? 1 : (total / perPage).ceil();
    final rawRows = data['data'];
    if (page != requestedPage ||
        pages != expectedPages ||
        rawRows is! List ||
        rawRows.length > perPage ||
        (page > pages && rawRows.isNotEmpty)) {
      throw const FormatException('Inconsistent sales return pagination');
    }
    var completeForExport = true;
    final rows = rawRows.map((row) {
      if (row is! Map<String, dynamic>) {
        throw const FormatException('Invalid sales return row');
      }
      final items = row['items'] ?? row['return_items'];
      final status = int.tryParse(row['status']?.toString() ?? '');
      if (status == null ||
          items is! List ||
          items.isEmpty ||
          items.any((item) {
            if (item is! Map) return true;
            final quantity = num.tryParse(item['quantity']?.toString() ?? '');
            return quantity == null || !quantity.isFinite || quantity < 0;
          })) {
        completeForExport = false;
      }
      return SalesReturnOrder.fromJson(row);
    }).toList(growable: false);
    return SalesReturnListData(
        rows: List.unmodifiable(rows),
        page: page,
        pages: pages,
        perPage: perPage,
        total: total,
        completeForExport: completeForExport);
  }
}

/// Fetches every page without mutating the visible list or shared providers.
Future<List<SalesReturnOrder>> salesReturnListSnapshot(
    SalesReturnListSource source,
    {void Function(int, int)? onPage,
    Future<bool> Function()? isCurrent}) async {
  final rows = <SalesReturnOrder>[];
  final ids = <int>{};
  SalesReturnListData? first;
  for (var page = 1;; page++) {
    if (isCurrent != null && !await isCurrent()) {
      throw StateError('Sales return export scope changed');
    }
    final result = await source.fetch(page);
    first ??= result;
    if (!result.completeForExport ||
        result.pages > 1000 ||
        result.page != page ||
        result.pages != first.pages ||
        result.perPage != first.perPage ||
        result.total != first.total) {
      throw StateError('Sales return export pagination changed');
    }
    final remaining = first.total - (page - 1) * first.perPage;
    final expected = remaining < first.perPage ? remaining : first.perPage;
    if (result.rows.length != expected) {
      throw StateError('Sales return export is incomplete');
    }
    for (final row in result.rows) {
      final amount = double.tryParse(row.totalAmount);
      if (row.id <= 0 ||
          row.orderId <= 0 ||
          !ids.add(row.id) ||
          amount == null ||
          !amount.isFinite ||
          !row.hasCreatedAt ||
          row.items.isEmpty ||
          !salesReturnQuantity(row).isFinite ||
          row.items
              .any((item) => !item.quantity.isFinite || item.quantity < 0)) {
        throw StateError(
            'Sales return export contains invalid or duplicate rows');
      }
      rows.add(row);
    }
    onPage?.call(page, first.pages);
    if (page == first.pages) break;
  }
  if (isCurrent != null && !await isCurrent()) {
    throw StateError('Sales return export scope changed');
  }
  return List.unmodifiable(rows);
}
