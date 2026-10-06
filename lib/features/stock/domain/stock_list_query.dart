/// Listing query passed to the existing shared StockProvider boundary.
class StockListQuery {
  const StockListQuery(
      {required this.name,
      this.category,
      this.barcode,
      this.rack,
      this.store,
      this.status,
      required this.includeVariants});
  final String name;
  final String? category, barcode, rack, store, status;
  final bool includeVariants;
}
