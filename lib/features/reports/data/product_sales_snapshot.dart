import '../domain/models/product_sales_report.dart';

/// Fetches the same filtered all-pages dataset without changing visible state.
Future<List<ProductSalesReportEntry>> productSalesSnapshot(
    Future<GetProductSalesReportResponse> Function(int page) fetch,
    {void Function(int page, int total)? progress}) async {
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
        data.entries.length > pagination.perPage) {
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
  if (entries.length != first.total) {
    throw StateError('Incomplete product sales export.');
  }
  return entries;
}
