import 'package:pos_machine/models/list_stock.dart';
import '../domain/stock_list_query.dart';

/// Frozen export of the loaded catalogue using the provider's local filter
/// rules. Never fetches data or moves the visible page.
List<ListStockModelData> stockListSnapshot(
    Iterable<ListStockModelData> stocks, StockListQuery query,
    {String? secondaryName}) {
  bool contains(String? value, String? filter) =>
      filter == null ||
      filter.isEmpty ||
      (value?.toLowerCase().contains(filter.toLowerCase()) ?? false);
  bool equals(String? value, String? filter, String all) =>
      filter == null ||
      filter.isEmpty ||
      filter == all ||
      value?.toLowerCase() == filter.toLowerCase();
  bool nameMatches(ListStockModelData stock, String? filter) =>
      contains(stock.productName, filter) ||
      (query.includeVariants && contains(stock.variantName, filter));
  return List.unmodifiable(stocks.where((stock) =>
      nameMatches(stock, query.name) &&
      nameMatches(stock, secondaryName) &&
      equals(stock.categoryName, query.category, 'All Categories') &&
      contains(stock.barCode, query.barcode) &&
      contains(stock.rack, query.rack) &&
      equals(stock.storeName, query.store, 'All Stores') &&
      equals(stock.stockStatus, query.status, 'All Statuses')));
}
