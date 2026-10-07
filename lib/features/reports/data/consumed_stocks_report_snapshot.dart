import '../domain/models/consumed_stocks_report.dart';

/// Withdrawals are identified by record ID, not product: repeated withdrawals
/// of the same product are distinct rows. Never save a partial workbook.
Future<List<ConsumedStockData>> consumedStocksReportSnapshot(
    Future<GetConsumedStocksReportResponse> Function(int page) fetch,
    {void Function(int page, int total)? progress}) async {
  final rows = <ConsumedStockData>[], seen = <int>{};
  Pagination? first;
  var page = 1;
  do {
    final response = await fetch(page);
    final data = response.data?.data, meta = response.data?.pagination;
    if (response.status != 'success' || data == null) {
      throw StateError('Consumed stock report failed');
    }
    for (final row in data) {
      final withdrawn = num.tryParse(row.quantityWithdrawn ?? ''),
          remaining = num.tryParse(row.newQuantity?.toString() ?? '');
      if (row.id == null ||
          row.id! <= 0 ||
          !seen.add(row.id!) ||
          withdrawn == null ||
          !withdrawn.isFinite ||
          remaining == null ||
          !remaining.isFinite) {
        throw StateError(
            'Missing, invalid or overlapping consumed stock record');
      }
    }
    if (meta == null) {
      if (page != 1 || first != null) {
        throw StateError('Consumed stock pagination disappeared');
      }
      progress?.call(1, 1);
      return List.unmodifiable(data);
    }
    first ??= meta;
    if (meta.currentPage != page ||
        (meta.lastPage ?? 0) < page ||
        (meta.perPage ?? 0) < 1 ||
        (meta.total != null && meta.total! < 0) ||
        meta.lastPage != first.lastPage ||
        meta.perPage != first.perPage ||
        meta.total != first.total ||
        data.length > meta.perPage! ||
        (data.isEmpty && (page > 1 || meta.lastPage! > 1)) ||
        (page < meta.lastPage! && data.length != meta.perPage)) {
      throw StateError('Incomplete or changing consumed stock pagination');
    }
    rows.addAll(data);
    progress?.call(page, meta.lastPage!);
    page++;
  } while (page <= first.lastPage!);
  if (first.total != null && rows.length != first.total) {
    throw StateError('Incomplete consumed stock export');
  }
  return List.unmodifiable(rows);
}
