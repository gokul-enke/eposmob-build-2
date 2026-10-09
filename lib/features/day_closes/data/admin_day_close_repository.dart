import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pos_machine/helpers/api_response_helper.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';
import '../domain/admin_day_close_list.dart';
import '../domain/day_close_list.dart';
import 'day_close_list_repository.dart';

class AdminDayCloseRepository implements AdminDayCloseSource {
  AdminDayCloseRepository(this.scope, {http.Client? client}) : _client = client;
  @override
  final AdminDayCloseScope scope;
  final http.Client? _client;

  Future<String> _get(String endpoint, Map<String, String> query) async {
    if (scope.token.isEmpty ||
        scope.tenant.isEmpty ||
        scope.storeId <= 0 ||
        scope.actorId <= 0) {
      throw StateError('Admin day close scope is unavailable');
    }
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(Uri.parse(endpoint).replace(queryParameters: query), headers: {
        'Authorization': 'Bearer ${scope.token}',
        'X-Tenant': scope.tenant,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));
      ApiResponseHelper.ensureSuccess(response.statusCode, response.body,
          fallback: 'Failed to load admin day closes');
      return response.body;
    } finally {
      if (_client == null) client.close();
    }
  }

  @override
  Future<DayCloseListData> fetch(int page, AdminDayCloseQuery query) async {
    if (page < 1 ||
        (query.date != null && !validDayCloseDate(query.date)) ||
        (query.executiveId != null && query.executiveId! <= 0)) {
      throw const FormatException('Invalid admin day close query');
    }
    final body = await _get(scope.endpoint, {
      'store_id[]': '${scope.storeId}',
      'page': '$page',
      if (query.executiveId != null) 'user_id[]': '${query.executiveId}',
      if (query.date != null) 'start_date': query.date!,
      if (query.date != null) 'end_date': query.date!,
    });
    final result = DayCloseListRepository.parse(body, requestedPage: page);
    if (result.rows.any((row) => !adminDayCloseRowInScope(row, scope, query))) {
      throw const FormatException('Admin day close response scope mismatch');
    }
    return result;
  }

  @override
  Future<List<AdminExecutiveOption>> fetchExecutives() async {
    final body =
        await _get(scope.executivesEndpoint, {'store_id': '${scope.storeId}'});
    final json = jsonDecode(body);
    if (json is! Map || json['status'] != 'success' || json['data'] is! List) {
      throw const FormatException('Invalid sales executive response');
    }
    final ids = <int>{};
    final options = <AdminExecutiveOption>[];
    for (final raw in json['data'] as List) {
      if (raw is! Map) throw const FormatException('Invalid sales executive');
      final id = int.tryParse(raw['id']?.toString() ?? '');
      final name = raw['name'];
      if (id == null ||
          id <= 0 ||
          !ids.add(id) ||
          name is! String ||
          name.trim().isEmpty) {
        throw const FormatException('Invalid sales executive identity');
      }
      options.add(AdminExecutiveOption(id, name));
    }
    return List.unmodifiable(options);
  }
}

Future<List<DailySalesCloseData>> adminDayCloseSnapshot(
    AdminDayCloseSource source, AdminDayCloseQuery query,
    {required Future<bool> Function() isCurrent,
    void Function(int, int)? onPage}) async {
  final rows = <DailySalesCloseData>[], ids = <int>{};
  DayCloseListData? first;
  for (var page = 1;; page++) {
    if (!await isCurrent()) throw StateError('Admin export changed');
    final result = await source.fetch(page, query);
    first ??= result;
    if (result.pages < 1 ||
        result.pages > 1000 ||
        result.perPage < 1 ||
        result.total < 0 ||
        result.page != page ||
        result.pages != first.pages ||
        result.total != first.total ||
        result.perPage != first.perPage ||
        result.pages !=
            (result.total == 0 ? 1 : (result.total / result.perPage).ceil())) {
      throw StateError('Admin export pagination changed');
    }
    final remaining = first.total - (page - 1) * first.perPage;
    if (result.rows.length !=
        (remaining < first.perPage ? remaining : first.perPage)) {
      throw StateError('Admin export is incomplete');
    }
    for (final row in result.rows) {
      if (!completeAdminDayCloseRow(row, source.scope, query) ||
          !ids.add(row.id!)) {
        throw StateError('Admin export contains invalid or duplicate closes');
      }
      rows.add(row);
    }
    onPage?.call(page, first.pages);
    if (page == first.pages) break;
  }
  if (!await isCurrent()) throw StateError('Admin export changed');
  return List.unmodifiable(rows);
}
