/// List-only inputs. Property selects products with an assigned property code,
/// either on the product itself or in its variant attributes.
class ProductListQuery {
  const ProductListQuery(
      {this.name = '',
      this.price = '',
      this.barcode = '',
      this.hsn = '',
      this.itemCode = '',
      this.categoryId,
      this.property});
  final String name, price, barcode, hsn, itemCode;
  final int? categoryId;
  final String? property;
  bool get isEmpty =>
      name.isEmpty &&
      price.isEmpty &&
      barcode.isEmpty &&
      hsn.isEmpty &&
      itemCode.isEmpty &&
      categoryId == null &&
      property == null;
}
