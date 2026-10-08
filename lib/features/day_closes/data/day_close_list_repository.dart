import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pos_machine/helpers/api_response_helper.dart';
import 'package:pos_machine/models/daily_sales_close.dart';
import 'package:pos_machine/models/day_close_pending_status.dart';
import '../domain/day_close_list.dart';

class DayCloseListRepository implements DayCloseListSource {
  DayCloseListRepository(this.scope, {http.Client? client}) : _client = client;
  @override
  final DayCloseListScope scope;
  final http.Client? _client;

  Future<String> _get(String endpoint, Map<String, String> params) async {
    if (scope.token.isEmpty ||
        scope.tenant.isEmpty ||
        scope.storeId <= 0 ||
        scope.userId <= 0) {
      throw StateError('Day close request scope is unavailable');
    }
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(Uri.parse(endpoint).replace(queryParameters: params), headers: {
        'Authorization': 'Bearer ${scope.token}',
        'X-Tenant': scope.tenant,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));
      ApiResponseHelper.ensureSuccess(response.statusCode, response.body,
          fallback: 'Failed to load day closes');
      return response.body;
    } finally {
      if (_client == null) client.close();
    }
  }

  @override
  Future<DayCloseListData> fetch(int page, {String? date}) async {
    if (page < 1 || (date != null && !validDayCloseDate(date))) {
      throw const FormatException('Invalid day close query');
    }
    final body = await _get(scope.endpoint, {
      'store_id[]': '${scope.storeId}',
      'user_id[]': '${scope.userId}',
      'page': '$page',
      if (date != null) 'start_date': date,
      if (date != null) 'end_date': date,
    });
    final result = parse(body, requestedPage: page);
    if (result.rows.any((row) =>
        (row.id ?? 0) <= 0 ||
        row.store?.id != scope.storeId ||
        row.salesExecutive?.id != scope.userId)) {
      throw const FormatException('Day close response scope mismatch');
    }
    return result;
  }

  static DayCloseListData parse(String body, {required int requestedPage}) {
    final json = jsonDecode(body);
    if (json is! Map ||
        json['success'] != true ||
        json['data'] is! List ||
        json['pagination'] is! Map) {
      throw const FormatException('Invalid day close response');
    }
    final pagination = json['pagination'] as Map;
    int integer(String key, {bool zero = false}) {
      final value = int.tryParse(pagination[key]?.toString() ?? '');
      if (value == null || value < (zero ? 0 : 1)) {
        throw FormatException('Invalid pagination: $key');
      }
      return value;
    }

    final page = integer('current_page'), pages = integer('last_page');
    final perPage = integer('per_page'), total = integer('total', zero: true);
    final rawRows = json['data'] as List;
    final remaining = total - (page - 1) * perPage;
    final expected = remaining < perPage ? remaining : perPage;
    if (page != requestedPage ||
        pages != (total == 0 ? 1 : (total / perPage).ceil()) ||
        rawRows.length > perPage ||
        (page > pages && rawRows.isNotEmpty) ||
        (page <= pages && rawRows.length != expected)) {
      throw const FormatException('Inconsistent day close pagination');
    }
    final rows = rawRows.map((raw) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid day close row');
      }
      final row = Map<String, dynamic>.from(raw);
      // Normalize wire types locally; the shared detail model stays unchanged.
      for (final key in [
        'id',
        'opening_transaction_id',
        'closing_transaction_id',
        'total_orders'
      ]) {
        if (row[key] != null) row[key] = int.tryParse(row[key].toString());
      }
      for (final key in [
        'total_sales',
        'total_online',
        'total_cash',
        'total_credit',
        'total_payment_received',
        'total_amount_collected_on_sale',
        'total_credit_collected',
        'total_returns',
        'total_refunds'
      ]) {
        if (row[key] != null) row[key] = row[key].toString();
      }
      for (final key in ['store', 'sales_executive']) {
        if (row[key] is Map) {
          final nested = Map<String, dynamic>.from(row[key]);
          if (nested['id'] != null) {
            nested['id'] = int.tryParse(nested['id'].toString());
          }
          if (nested['phone'] != null) {
            nested['phone'] = nested['phone'].toString();
          }
          row[key] = nested;
        }
      }
      return DailySalesCloseData.fromJson(row);
    }).toList(growable: false);
    return DayCloseListData(
        rows: List.unmodifiable(rows),
        page: page,
        pages: pages,
        perPage: perPage,
        total: total);
  }

  @override
  Future<DayClosePendingStatus> fetchPending() async {
    final body = await _get(scope.pendingEndpoint,
        {'store_id': '${scope.storeId}', 'user_id': '${scope.userId}'});
    final json = jsonDecode(body);
    if (json is! Map || json['success'] != true || json['data'] is! Map) {
      throw const FormatException('Invalid shift status response');
    }
    final data = Map<String, dynamic>.from(json['data']);
    if (data['can_open_shift'] is! bool || data['pending_day_close'] is! bool) {
      throw const FormatException('Missing shift status');
    }
    for (final key in ['opening_transaction_id', 'closing_transaction_id']) {
      if (data[key] != null) data[key] = int.parse(data[key].toString());
    }
    if (data['open_draft'] is Map) {
      final draft = Map<String, dynamic>.from(data['open_draft']);
      if (draft['id'] != null) draft['id'] = int.parse(draft['id'].toString());
      data['open_draft'] = draft;
    }
    return DayClosePendingStatus.fromJson(data);
  }
}

Future<List<DailySalesCloseData>> dayCloseListSnapshot(
    DayCloseListSource source,
    {String? date,
    Future<bool> Function()? isCurrent,
    void Function(int, int)? onPage}) async {
  final rows = <DailySalesCloseData>[], ids = <int>{};
  DayCloseListData? first;
  for (var page = 1;; page++) {
    if (isCurrent != null && !await isCurrent()) {
      throw StateError('Day close export scope changed');
    }
    final result = await source.fetch(page, date: date);
    first ??= result;
    if (result.pages > 1000 ||
        result.page != page ||
        result.pages != first.pages ||
        result.total != first.total ||
        result.perPage != first.perPage) {
      throw StateError('Day close export pagination changed');
    }
    final remaining = first.total - (page - 1) * first.perPage;
    if (result.rows.length !=
        (remaining < first.perPage ? remaining : first.perPage)) {
      throw StateError('Day close export is incomplete');
    }
    for (final row in result.rows) {
      if (!completeDayCloseRow(row, source.scope) || !ids.add(row.id!)) {
        throw StateError('Day close export contains invalid or duplicate rows');
      }
      rows.add(row);
    }
    onPage?.call(page, first.pages);
    if (page == first.pages) break;
  }
  if (isCurrent != null && !await isCurrent()) {
    throw StateError('Day close export scope changed');
  }
  return List.unmodifiable(rows);
}
