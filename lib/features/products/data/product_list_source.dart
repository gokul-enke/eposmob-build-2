import 'package:pos_machine/helpers/product_search_helper.dart';
import 'package:pos_machine/models/get_product.dart';
import '../domain/product_list_query.dart';

/// List-only access to the existing offline catalog. No provider/UI dependency.
/// Does not replace the catalog, its billing filters, or its selected page.
class ProductListSource {
  ProductListSource({required this.readCatalog, required this.deleteProduct});
  final List<GetProduct> Function() readCatalog;
  final Future<bool> Function(int id) deleteProduct;

  List<GetProduct> select(ProductListQuery query) {
    var rows = List<GetProduct>.of(readCatalog());
    if (query.categoryId != null && query.categoryId != 0) {
      rows = rows.where((p) => p.categoryId == query.categoryId).toList();
    }
    if (query.name.isNotEmpty) {
      rows = ProductSearchHelper.search(rows, query.name);
    }
    if (query.barcode.isNotEmpty) {
      rows = ProductSearchHelper.searchBarcodes(rows, query.barcode);
    }
    if (query.hsn.isNotEmpty) {
      final term = query.hsn.toLowerCase();
      rows = rows
          .where((p) =>
              (p.hsnCode?.toLowerCase().contains(term) ?? false) ||
              (p.stock?.any((s) =>
                      s.hsnCode?.toLowerCase().contains(term) ?? false) ??
                  false))
          .toList();
    }
    if (query.price.isNotEmpty) {
      rows = rows
          .where(
              (p) => (p.price?.price?.toString() ?? '').contains(query.price))
          .toList();
    }
    if (query.itemCode.isNotEmpty) {
      rows = rows
          .where((p) =>
              p.itemCode
                  ?.toLowerCase()
                  .contains(query.itemCode.toLowerCase()) ??
              false)
          .toList();
    }
    final property = query.property?.trim();
    if (property != null && property.isNotEmpty) {
      final code = _propertyCode(property);
      rows = rows.where((p) => _hasProperty(p, code)).toList();
    }
    return List.unmodifiable(rows);
  }

  // Older picker values used COLOR; the synced catalog uses PRODUCT_COLOR.
  static String _propertyCode(String code) {
    final normalized = code.trim().toUpperCase();
    return normalized == 'COLOR' ? 'PRODUCT_COLOR' : normalized;
  }

  static bool _hasProperty(GetProduct product, String code) =>
      (product.productProps?.any((property) =>
              _propertyCode(property.propsCode ?? '') == code &&
              _hasAssignedValue(property.masterValue)) ??
          false) ||
      (product.variants?.any((variant) => variant.attributes.entries.any(
              (attribute) =>
                  _propertyCode(attribute.key) == code &&
                  _hasAssignedValue(attribute.value))) ??
          false);

  // Catalog property definitions often have no value. A definition alone does
  // not mean the product has this property assigned. Variant values can also
  // be multi-select lists, so empty collections must not count as assignments.
  static bool _hasAssignedValue(Object? value) {
    if (value is String) return value.trim().isNotEmpty;
    if (value is Iterable) return value.any(_hasAssignedValue);
    if (value is Map) return value.values.any(_hasAssignedValue);
    return value is num || value is bool;
  }
}
