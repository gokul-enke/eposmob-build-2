import 'package:pos_machine/providers/quotations_provider.dart';
import '../domain/proforma_list_query.dart';

class ProformaListRepository {
  ProformaListRepository(this.provider);
  final QuotationsProvider provider;
  ({List<Map<String, dynamic>> rows, int current, int last, int? total})
      parsePage(Map<String, dynamic> response, int requestedPage) {
    final data = response['data'];
    if (data is! Map || data['data'] is! List) {
      throw const FormatException('Invalid proforma invoice response');
    }
    final current = proformaInt(data['current_page']);
    final last = proformaInt(data['last_page']);
    final total = data.containsKey('total') ? proformaInt(data['total']) : null;
    if (data.containsKey('total') && (total == null || total < 0)) {
      throw const FormatException('Invalid proforma total');
    }
    if (current != requestedPage ||
        last == null ||
        last < current! ||
        last < 1) {
      throw const FormatException('Invalid proforma pagination');
    }
    final rows = <Map<String, dynamic>>[];
    for (final item in data['data'] as List) {
      if (item is! Map) {
        throw const FormatException('Invalid proforma invoice row');
      }
      rows.add(Map<String, dynamic>.from(item));
    }
    if (rows.isEmpty && (current > 1 || current < last || (total ?? 0) > 0)) {
      throw const FormatException('Missing proforma invoice page');
    }
    return (rows: rows, current: current, last: last, total: total);
  }

  Future<({List<Map<String, dynamic>> rows, int current, int last, int? total})>
      fetchPage(String token, Map<String, String> snapshot, int page) async {
    final response = await provider.fetchProformaInvoices(
        accessToken: token,
        filters: {
          ...snapshot,
          'page': '$page',
          'per_page': '20'
        }).timeout(const Duration(seconds: 30));
    return parsePage(response, page);
  }

  Future<List<Map<String, dynamic>>> fetchExport(
      String token, Map<String, String> snapshot,
      {void Function(int, int)? onProgress}) async {
    final items = <Map<String, dynamic>>[];
    final ids = <int>{};
    int last = 1;
    int? expectedTotal;
    for (int page = 1; page <= last; page++) {
      onProgress?.call(page, last);
      final response = await provider.fetchProformaInvoices(
          accessToken: token,
          filters: {
            ...snapshot,
            'page': '$page',
            'per_page': '1000'
          }).timeout(const Duration(seconds: 30));
      final result = parsePage(response, page);
      if (page > 1 && (result.last != last || result.total != expectedTotal)) {
        throw const FormatException(
            'Proforma pagination changed during export');
      }
      last = result.last;
      expectedTotal = result.total;
      for (final row in result.rows) {
        final id = proformaInt(row['id']);
        if (id == null || id <= 0) {
          throw const FormatException('Invalid proforma invoice ID');
        }
        if (!ids.add(id)) {
          throw const FormatException('Duplicate proforma invoice rows');
        }
        items.add(row);
      }
    }
    if (expectedTotal != null && items.length != expectedTotal) {
      throw const FormatException(
          'Proforma export count does not match API total');
    }
    return items;
  }
}
