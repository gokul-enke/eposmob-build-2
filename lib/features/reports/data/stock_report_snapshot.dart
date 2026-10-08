import '../domain/models/stock_report.dart';
import '../domain/models/stock_report_pagination.dart';

/// Every filtered page; rejects changing metadata or an incomplete export.
Future<List<StockReportData>> stockReportSnapshot(
    Future<GetStockReportResponse> Function(int page) fetch,
    {void Function(int page, int total)? progress}) async {
  final rows = <StockReportData>[];
  final seenIds = <int>{};
  StockReportPagination? first;
  var page = 1;
  do {
    final response = await fetch(page);
    final pagination = response.pagination;
    if (response.status.toLowerCase() != 'success') {
      throw StateError('Stock report failed');
    }
    // Overlapping pages can keep the declared count while omitting a product.
    // Reject the snapshot rather than deduplicating an incomplete workbook.
    for (final row in response.data) {
      if (!seenIds.add(row.id)) {
        throw StateError('Duplicate product in stock export');
      }
    }
    if (pagination == null) {
      // A flat legacy response represents a single unpaginated result.
      if (page != 1 || first != null) {
        throw StateError('Stock pagination disappeared');
      }
      return response.data;
    }
    first ??= pagination;
    if (pagination.currentPage != page ||
        (pagination.lastPage ?? 0) < 1 ||
        (pagination.perPage ?? 0) < 1 ||
        (pagination.total != null && pagination.total! < 0) ||
        pagination.lastPage != first.lastPage ||
        pagination.perPage != first.perPage ||
        pagination.total != first.total ||
        (page < pagination.lastPage! && response.data.isEmpty) ||
        response.data.length > pagination.perPage!) {
      throw StateError('Stock export pagination changed or is incomplete');
    }
    rows.addAll(response.data);
    progress?.call(page, pagination.lastPage!);
    page++;
  } while (page <= first.lastPage!);
  if (first.total != null && rows.length != first.total) {
    throw StateError('Incomplete stock export');
  }
  return rows;
}
