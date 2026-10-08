import '../domain/supplier_report.dart';

/// Reads all filtered summary pages without changing the visible report.
/// Rejects incomplete, overlapping or changing responses before making a file.
Future<List<SupplierTransactionSummary>> fetchSupplierReportSnapshot(
  Future<Map<String, dynamic>> Function(int page) fetch, {
  void Function(int page, int total)? progress,
}) async {
  final rows = <SupplierTransactionSummary>[];
  final ids = <int>{};
  int? last, total, perPage;
  bool? grouped;
  int integer(Object? value) {
    final result = value is num && value.isFinite && value == value.toInt()
        ? value.toInt()
        : int.tryParse('$value');
    if (result == null || result < 0) {
      throw const FormatException('Invalid supplier report pagination.');
    }
    return result;
  }

  for (var requested = 1; requested <= (last ?? 1); requested++) {
    final response = await fetch(requested);
    final status = response['status'];
    if (status != null && status != 'success') {
      throw const FormatException('Supplier report request failed.');
    }
    final data = response['data'];
    final isGrouped = data is Map;
    final raw = isGrouped ? data['data'] : data;
    if (raw is! List) {
      throw const FormatException('Invalid supplier report rows.');
    }
    final current = isGrouped ? integer(data['current_page']) : 1;
    final pages = isGrouped ? integer(data['last_page']) : 1;
    final declaredTotal =
        isGrouped && data['total'] != null ? integer(data['total']) : null;
    final declaredPerPage = isGrouped && data['per_page'] != null
        ? integer(data['per_page'])
        : null;
    if (current != requested ||
        pages < 1 ||
        pages > 1000 ||
        (declaredPerPage != null && declaredPerPage < 1)) {
      throw const FormatException('Invalid supplier report pagination.');
    }
    if (requested == 1) {
      last = pages;
      total = declaredTotal;
      perPage = declaredPerPage;
      grouped = isGrouped;
    } else if (last != pages ||
        total != declaredTotal ||
        perPage != declaredPerPage ||
        grouped != isGrouped) {
      throw const FormatException('Supplier report changed during export.');
    }
    if (raw.isEmpty && pages > 1) {
      throw const FormatException('Incomplete supplier report.');
    }
    for (final group in raw) {
      if (group is! Map) {
        throw const FormatException('Invalid supplier report row.');
      }
      final id = integer(group['supplier_id']);
      if (id == 0 || !ids.add(id)) {
        throw const FormatException(
            'Missing or duplicate supplier identifier.');
      }
      for (final key in ['total_debit', 'total_credit', 'balance']) {
        final value = double.tryParse('${group[key]}');
        if (value == null || !value.isFinite) {
          throw const FormatException('Incomplete supplier report amounts.');
        }
      }
      if (group['transactions'] is! List) {
        throw const FormatException('Missing supplier transaction count.');
      }
    }
    rows.addAll(SupplierReportPage.parse(response).rows.values);
    progress?.call(requested, pages);
  }
  if (total != null && rows.length != total) {
    throw const FormatException('Incomplete supplier report.');
  }
  return List.unmodifiable(rows);
}
