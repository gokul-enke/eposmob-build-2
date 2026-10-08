import '../domain/models/product_sales_report.dart';

/// Fetches the same filtered all-pages dataset without changing visible state.
///
/// [pageSize] is the per_page the caller requested. Rows per page are checked
/// against it rather than the parsed `per_page`, which falls back to 25 when
/// the API omits it. The row count is checked against `total` only when the
/// API reports one: the model parses a missing `total` as 0, and a real 0 can't
/// reach export because Export needs visible rows.
Future<List<ProductSalesReportEntry>> productSalesSnapshot(
    Future<GetProductSalesReportResponse> Function(int page) fetch,
    {required int pageSize,
    void Function(int page, int total)? progress}) async {
  final entries = <ProductSalesReportEntry>[];
  ProductSalesReportPagination? first;
  String? currency;
  var page = 1;
  do {
    final response = await fetch(page);
    final data = response.data, pagination = data.pagination;
    first ??= pagination;
    currency ??= data.currency;
    if (pagination.currentPage != page ||
        pagination.lastPage < 1 ||
        pagination.perPage < 1 ||
        pagination.total < 0 ||
        pagination.lastPage != first.lastPage ||
        pagination.total != first.total ||
        pagination.perPage != first.perPage ||
        data.currency != currency ||
        (page < pagination.lastPage && data.entries.isEmpty) ||
        data.entries.length > pageSize) {
      throw StateError(
          'Product sales export pagination changed or is incomplete.');
    }
    for (final item in data.entries) {
      if (!item.price.isFinite ||
          !item.totalPrice.isFinite ||
          !item.salesCount.isFinite) {
        throw StateError('Invalid product sales export amount.');
      }
    }
    entries.addAll(data.entries);
    progress?.call(page, pagination.lastPage);
    page++;
  } while (page <= first.lastPage);
  if (first.total > 0 && entries.length != first.total) {
    throw StateError('Incomplete product sales export.');
  }
  return entries;
}
