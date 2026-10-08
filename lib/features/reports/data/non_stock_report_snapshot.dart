import '../domain/models/non_stock_report.dart';
import '../domain/models/non_stock_report_pagination.dart';

/// The matching rows moved while pages were read (e.g. a sale pushed a product
/// below its reorder level). Reading the snapshot again usually succeeds.
class NonStockReportSnapshotChanged extends StateError {
  NonStockReportSnapshotChanged(super.message);
}

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
      if (row.id <= 0) throw StateError('Missing non-stock row identifier');
      if (!seen.add((row.id, row.store))) {
        throw NonStockReportSnapshotChanged('Overlapping non-stock row');
      }
    }
    final meta = response.pagination;
    if (meta == null) {
      if (page != 1 || first != null) {
        throw NonStockReportSnapshotChanged('Non-stock pagination disappeared');
      }
      progress?.call(1, 1);
      return List.unmodifiable(response.data);
    }
    first ??= meta;
    if (meta.currentPage != page ||
        (meta.lastPage ?? 0) < 1 ||
        (meta.perPage ?? 0) < 1 ||
        (meta.total != null && meta.total! < 0) ||
        response.data.length > meta.perPage!) {
      throw StateError('Incomplete non-stock pagination');
    }
    if (meta.lastPage! < page ||
        meta.lastPage != first.lastPage ||
        meta.perPage != first.perPage ||
        meta.total != first.total ||
        (response.data.isEmpty && (page > 1 || meta.lastPage! > 1)) ||
        (page < meta.lastPage! && response.data.length != meta.perPage)) {
      throw NonStockReportSnapshotChanged('Changing non-stock pagination');
    }
    rows.addAll(response.data);
    progress?.call(page, meta.lastPage!);
    page++;
  } while (page <= first.lastPage!);
  if (first.total != null && rows.length != first.total) {
    throw NonStockReportSnapshotChanged('Incomplete non-stock export');
  }
  return List.unmodifiable(rows);
}
