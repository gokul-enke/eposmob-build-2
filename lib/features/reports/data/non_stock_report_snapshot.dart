import '../domain/models/non_stock_report.dart';
import '../domain/models/non_stock_report_pagination.dart';

/// Loads every matching row without changing the visible report. A product
/// can occur in different stores: its row identity includes the store.
Future<List<NonStockReportData>> nonStockReportSnapshot(
    Future<GetNonStockReportResponse> Function(int page) fetch,
    {void Function(int page, int total)? progress}) async {
  final rows = <NonStockReportData>[];
  final seen = <(int, String?)>{};
  NonStockReportPagination? first;
  var page = 1;
  do {
    final response = await fetch(page);
    if (response.status.toLowerCase() != 'success') {
      throw StateError('Non-stock report failed');
    }
    for (final row in response.data) {
      if (row.id <= 0 || !seen.add((row.id, row.store))) {
        throw StateError('Missing or overlapping non-stock row');
      }
    }
    final meta = response.pagination;
    if (meta == null) {
      if (page != 1 || first != null) {
        throw StateError('Non-stock pagination disappeared');
      }
      progress?.call(1, 1);
      return List.unmodifiable(response.data);
    }
    first ??= meta;
    if (meta.currentPage != page ||
        (meta.lastPage ?? 0) < page ||
        (meta.perPage ?? 0) < 1 ||
        (meta.total != null && meta.total! < 0) ||
        meta.lastPage != first.lastPage ||
        meta.perPage != first.perPage ||
        meta.total != first.total ||
        response.data.length > meta.perPage! ||
        (response.data.isEmpty && (page > 1 || meta.lastPage! > 1)) ||
        (page < meta.lastPage! && response.data.length != meta.perPage)) {
      throw StateError('Incomplete or changing non-stock pagination');
    }
    rows.addAll(response.data);
    progress?.call(page, meta.lastPage!);
    page++;
  } while (page <= first.lastPage!);
  if (first.total != null && rows.length != first.total) {
    throw StateError('Incomplete non-stock export');
  }
  return List.unmodifiable(rows);
}
