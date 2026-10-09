import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pos_machine/helpers/api_response_helper.dart';
import 'package:pos_machine/models/sales_executive_report.dart';
import '../domain/admin_executive_report.dart';
import '../domain/report_date_range.dart';

class AdminExecutiveRepository implements AdminExecutiveSource {
  AdminExecutiveRepository(this.scope, {http.Client? client})
      : _client = client;
  @override
  final AdminExecutiveScope scope;
  final http.Client? _client;
  @override
  Future<List<SalesExecutiveReportData>> fetch(ReportDateRange range) async {
    if (!scope.allowed) throw StateError('Admin report scope unavailable');
    if (range.isInverted) throw const FormatException('Inverted report dates');
    final client = _client ?? http.Client();
    try {
      final response = await client.get(
          Uri.parse(scope.endpoint).replace(queryParameters: {
            'store_id': '${scope.storeId}',
            'dateFilter': range.isEmpty ? 'today' : 'custom',
            if (range.apiFrom != null) 'dateFrom': range.apiFrom!,
            if (range.apiTo != null) 'dateTo': range.apiTo!,
          }),
          headers: {
            'Authorization': 'Bearer ${scope.token}',
            'X-Tenant': scope.tenant,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          }).timeout(const Duration(seconds: 15));
      ApiResponseHelper.ensureSuccess(response.statusCode, response.body,
          fallback: 'Unable to load admin executive report');
      return parseAdminExecutiveReport(jsonDecode(response.body));
    } finally {
      if (_client == null) client.close();
    }
  }
}
