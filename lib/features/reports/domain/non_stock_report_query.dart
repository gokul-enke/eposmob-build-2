/// The endpoint uses names (not directory IDs) for these three filters.
class NonStockReportQuery {
  const NonStockReportQuery(
      {this.store, this.category, this.product, this.barcode = ''});
  final String? store, category, product;
  final String barcode;
  bool get isEmpty =>
      store == null && category == null && product == null && barcode.isEmpty;
  bool matches(NonStockReportQuery other) =>
      store == other.store &&
      category == other.category &&
      product == other.product &&
      barcode == other.barcode;
}

typedef NonStockReportScope = ({
  String token,
  String? tenant,
  int? activeStoreId,
  String endpoint
});
