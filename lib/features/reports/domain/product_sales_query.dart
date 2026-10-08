class ProductSalesQuery {
  const ProductSalesQuery(
      {this.categoryId,
      this.productId,
      this.customerId,
      this.from = '',
      this.to = ''});
  final String? categoryId, productId, customerId;
  final String from, to;
  bool get active =>
      categoryId != null ||
      productId != null ||
      customerId != null ||
      from.isNotEmpty ||
      to.isNotEmpty;
  bool get valid {
    final start = DateTime.tryParse(from), end = DateTime.tryParse(to);
    return start == null || end == null || !start.isAfter(end);
  }

  bool matches(ProductSalesQuery other) =>
      categoryId == other.categoryId &&
      productId == other.productId &&
      customerId == other.customerId &&
      from == other.from &&
      to == other.to;
}

class ProductSalesOption {
  const ProductSalesOption(
      {required this.id, required this.label, this.categoryId});
  final String id, label;
  final String? categoryId;
}

typedef ProductSalesScope = ({
  String token,
  String? tenant,
  int? storeId,
  String endpoint
});
