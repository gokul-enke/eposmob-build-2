import 'package:pos_machine/features/suppliers/domain/models/supplier.dart';
import '../domain/supplier_report_details_query.dart';

List<dynamic> supplierReportDetailsGroups(Map<String, dynamic> response) {
  final status = response['status'];
  if (status != null && status != 'success') {
    throw const FormatException('Supplier transaction request failed.');
  }
  final data = response['data'];
  final groups = data is Map ? data['data'] : data;
  if (groups is! List) {
    throw const FormatException('Invalid supplier transaction groups.');
  }
  return groups;
}

bool _matches(Map group, SupplierReportDetailsSelection supplier) =>
    supplier.id.isNotEmpty
        ? '${group['supplier_id'] ?? ''}' == supplier.id
        : '${group['supplier_name'] ?? ''}' == supplier.name;

String supplierReportDetailsName(
    Map<String, dynamic> response, SupplierReportDetailsSelection supplier) {
  for (final group in supplierReportDetailsGroups(response).whereType<Map>()) {
    if (_matches(group, supplier)) return '${group['supplier_name'] ?? ''}';
  }
  return supplier.name;
}

/// Display parsing keeps the existing model defaults. An ID never falls back
/// to another supplier with the same name.
List<SupplierTransaction> parseSupplierReportDetails(
    Map<String, dynamic> response, SupplierReportDetailsSelection supplier) {
  final matches = supplierReportDetailsGroups(response)
      .whereType<Map>()
      .where((group) => _matches(group, supplier))
      .toList();
  if (matches.length > 1) {
    throw const FormatException('Ambiguous supplier transaction group.');
  }
  if (matches.isEmpty) return const [];
  final rows = matches.single['transactions'];
  if (rows is! List) {
    throw const FormatException('Missing supplier transactions.');
  }
  return List.unmodifiable(rows.whereType<Map>().map((row) {
    final json = Map<String, dynamic>.from(row);
    // Accept numeric-string IDs without changing the shared public model.
    json['id'] = int.tryParse('${json['id']}') ?? 0;
    return SupplierTransaction.fromJson(json);
  }));
}

int _integer(Object? value) {
  final result = value is num && value.isFinite && value == value.toInt()
      ? value.toInt()
      : int.tryParse('$value');
  if (result == null || result < 0) {
    throw const FormatException('Invalid supplier transaction count or ID.');
  }
  return result;
}

/// Export accepts only complete financial rows. Optional payment is blank for
/// invoices; reference and status remain text, amounts remain numeric in Excel.
SupplierTransaction _exportRow(Map row, Set<int> ids, String supplierId) {
  final id = _integer(row['id']);
  if (id == 0 || !ids.add(id)) {
    throw const FormatException('Missing or overlapping transaction ID.');
  }
  if (row['supplier_id'] != null && '${row['supplier_id']}' != supplierId) {
    throw const FormatException('Transaction belongs to another supplier.');
  }
  final amount = double.tryParse('${row['amount']}');
  if (amount == null || !amount.isFinite) {
    throw const FormatException('Incomplete supplier transaction amount.');
  }
  final date = '${row['date'] ?? ''}';
  final parsed = DateTime.tryParse(date);
  if (parsed == null ||
      date.length < 10 ||
      '${parsed.year.toString().padLeft(4, '0')}-'
              '${parsed.month.toString().padLeft(2, '0')}-'
              '${parsed.day.toString().padLeft(2, '0')}' !=
          date.substring(0, 10)) {
    throw const FormatException('Invalid supplier transaction date.');
  }
  for (final key in ['currency', 'type', 'transaction_type', 'status']) {
    if (row[key] == null || '${row[key]}'.trim().isEmpty) {
      throw FormatException('Missing supplier transaction $key.');
    }
  }
  return SupplierTransaction.fromJson(
      {...Map<String, dynamic>.from(row), 'id': id});
}

Future<List<SupplierTransaction>> fetchSupplierReportDetailsSnapshot(
  Future<Map<String, dynamic>> Function(int page) fetch,
  SupplierReportDetailsQuery query, {
  void Function(int page, int total)? progress,
}) async {
  if (!query.hasSupplier) throw const FormatException('No supplier selected.');
  final rows = <SupplierTransaction>[];
  final supplierIds = <int>{}, transactionIds = <int>{};
  int? last, total, perPage;
  bool? paginated;
  var groupsSeen = 0, matchedGroups = 0;
  for (var requested = 1; requested <= (last ?? 1); requested++) {
    final response = await fetch(requested);
    final groups = supplierReportDetailsGroups(response);
    final data = response['data'];
    final hasPagination = data is Map &&
        (data.containsKey('current_page') || data.containsKey('last_page'));
    // The unpaginated list_all=true contract returns the full group array.
    final current = hasPagination ? _integer(data['current_page']) : 1;
    final pages = hasPagination ? _integer(data['last_page']) : 1;
    final count =
        data is Map && data['total'] != null ? _integer(data['total']) : null;
    final size = data is Map && data['per_page'] != null
        ? _integer(data['per_page'])
        : null;
    if (current != requested ||
        pages < requested ||
        (size != null && size < 1)) {
      throw const FormatException('Invalid supplier transaction pagination.');
    }
    if (requested == 1) {
      last = pages;
      total = count;
      perPage = size;
      paginated = hasPagination;
    } else if (last != pages ||
        total != count ||
        perPage != size ||
        paginated != hasPagination) {
      throw const FormatException(
          'Supplier transactions changed during export.');
    }
    if (groups.isEmpty && pages > 1) {
      throw const FormatException('Incomplete supplier transaction page.');
    }
    for (final group in groups) {
      if (group is! Map) throw const FormatException('Invalid supplier group.');
      final id = _integer(group['supplier_id']);
      if (id == 0 || !supplierIds.add(id)) {
        throw const FormatException('Missing or overlapping supplier group.');
      }
      groupsSeen++;
      if (!_matches(group, query.supplier)) continue;
      if (++matchedGroups > 1) {
        throw const FormatException('Ambiguous supplier name.');
      }
      final transactions = group['transactions'];
      if (transactions is! List) {
        throw const FormatException('Missing supplier transactions.');
      }
      for (final key in ['transaction_count', 'transactions_count']) {
        if (group[key] != null && _integer(group[key]) != transactions.length) {
          throw const FormatException(
              'Incomplete nested supplier transactions.');
        }
      }
      for (final row in transactions) {
        if (row is! Map) {
          throw const FormatException('Invalid supplier transaction.');
        }
        rows.add(_exportRow(row, transactionIds, '$id'));
      }
    }
    progress?.call(requested, pages);
  }
  if (total != null && total != groupsSeen) {
    throw const FormatException('Incomplete supplier transaction groups.');
  }
  return query.apply(rows);
}
