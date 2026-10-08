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

  /// The provider matches text case-insensitively and treats empty filters as
  /// absent. Preserve paging when transient edits leave these filters unchanged.
  bool sameFiltersAs(StockListQuery other) {
    String normalized(String? value) => value?.toLowerCase() ?? '';
    return normalized(name) == normalized(other.name) &&
        normalized(category) == normalized(other.category) &&
        normalized(barcode) == normalized(other.barcode) &&
        normalized(rack) == normalized(other.rack) &&
        normalized(store) == normalized(other.store) &&
        normalized(status) == normalized(other.status) &&
        includeVariants == other.includeVariants;
  }
}
