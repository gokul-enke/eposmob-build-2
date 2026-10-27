import '../domain/models/sales_report.dart';

/// The matching orders moved while pages were read (e.g. a sale landed on
/// page one). Reading the snapshot again usually succeeds.
class SalesReportSnapshotChanged extends StateError {
  SalesReportSnapshotChanged(super.message);
}

/// Reads every matching page for the export without changing the visible
/// report. Fails rather than returning partial or overlapping data.
Future<List<SalesReportRow>> salesReportSnapshot(
    Future<SalesReportResponse> Function(int page) fetch,
    {void Function(int page, int total)? progress,
    int maxPages = 1000}) async {
  final rows = <SalesReportRow>[];
  final seen = <int>{};
  SalesReportResponse? first;
  var page = 1;
  do {
    final response = await fetch(page);
    first ??= response;
    if (response.currentPage != page ||
        response.lastPage != first.lastPage ||
        response.perPage != first.perPage ||
        response.total != first.total ||
        response.rows.length > response.perPage ||
        (page < response.lastPage &&
            response.rows.length != response.perPage)) {
      throw SalesReportSnapshotChanged(
          'Sales report pages changed while exporting');
    }
    if (first.lastPage > maxPages) {
      throw StateError('Sales report has too many pages to export');
    }
    for (final row in response.rows) {
      if (!seen.add(row.orderId)) {
        throw SalesReportSnapshotChanged(
            'Sales report pages overlap while exporting');
      }
    }
    rows.addAll(response.rows);
    progress?.call(page, first.lastPage);
    page++;
  } while (page <= first.lastPage);
  if (first.total != null && rows.length != first.total) {
    throw SalesReportSnapshotChanged('Incomplete sales report export');
  }
  return List.unmodifiable(rows);
}
