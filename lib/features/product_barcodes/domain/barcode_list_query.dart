/// Filters applied to the existing local catalogue. Print selection is separate.
class BarcodeListQuery {
  const BarcodeListQuery({this.name = '', this.barcode = '', this.categoryId});
  final String name;
  final String barcode;
  final int? categoryId;

  bool sameFiltersAs(BarcodeListQuery other) =>
      name.trim().toLowerCase() == other.name.trim().toLowerCase() &&
      barcode.trim().toLowerCase() == other.barcode.trim().toLowerCase() &&
      categoryId == other.categoryId;
  bool get isFiltered =>
      name.trim().isNotEmpty || barcode.trim().isNotEmpty || categoryId != null;
}

class BarcodeCategory {
  const BarcodeCategory(this.id, this.name);
  final int? id;
  final String name;
}
