import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/models/list_receipt.dart';
import 'package:pos_machine/resources/app_url.dart';
import '../domain/receipt_list_query.dart';

Future<({List<Receipt> items, Map<String, dynamic> data})>
    fetchReceiptListPages({
  required String accessToken,
  String? fromDate,
  String? toDate,
  void Function(int page, int totalPages)? onProgress,
  http.Client? client,
  int pageSize = 100,
  Duration requestTimeout = const Duration(seconds: 30),
}) async {
  final prefs = await SharedPreferences.getInstance();
  final tenant = prefs.getString('api_key');
  final store = prefs.getInt('active_store_id');
  if (tenant == null || tenant.isEmpty) {
    throw const HttpException('API key not found. Please restart the app.');
  }
  final filters = <String, String>{
    'per_page': '$pageSize',
    if (store != null) 'store_id': '$store',
  };
  void add(String key, String? value) {
    final normalized = normalizeReceiptFilter(value);
    if (normalized != null) filters[key] = normalized;
  }

  add('date_from', formatReceiptApiDate(fromDate));
  add('date_to', formatReceiptApiDate(toDate));
  final headers = {'Authorization': 'Bearer $accessToken', 'X-Tenant': tenant};
  final items = <Receipt>[];
  final ids = <int>{};
  int? lastPage, expectedTotal;
  Map<String, dynamic>? firstData;
  for (int page = 1; page <= (lastPage ?? 1); page++) {
    final uri = Uri.parse(APPUrl.listAllReceipts)
        .replace(queryParameters: {...filters, 'page': '$page'});
    final response = await (client == null
            ? http.get(uri, headers: headers)
            : client.get(uri, headers: headers))
        .timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw HttpException(
          'Failed to fetch receipt page $page (${response.statusCode})',
          uri: uri);
    }
    final payload = json.decode(response.body);
    if (payload is! Map<String, dynamic> ||
        payload['status'] != 'success' ||
        payload['data'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid receipt response.');
    }
    final data = payload['data'] as Map<String, dynamic>;
    firstData ??= data;
    final current = int.tryParse('${data['current_page']}');
    final last = int.tryParse('${data['last_page']}');
    final total = int.tryParse('${data['total']}');
    final rows = data['data'];
    if (current != page ||
        last == null ||
        last < page ||
        total == null ||
        total < 0 ||
        (lastPage != null && last != lastPage) ||
        (expectedTotal != null && total != expectedTotal) ||
        rows is! List ||
        rows.any((row) => row is! Map<String, dynamic>) ||
        (rows.isEmpty && (page > 1 || total > 0))) {
      throw const FormatException('Incomplete receipt page.');
    }
    lastPage = last;
    expectedTotal = total;
    for (final row in rows) {
      final invoice = Receipt.fromJson(row as Map<String, dynamic>);
      if (!ids.add(invoice.id)) {
        throw const FormatException('Duplicate receipt rows.');
      }
      items.add(invoice);
    }
    onProgress?.call(page, last);
  }
  if (items.length != expectedTotal) {
    throw const FormatException('Receipt count does not match the API total.');
  }
  return (items: items, data: firstData!);
}
