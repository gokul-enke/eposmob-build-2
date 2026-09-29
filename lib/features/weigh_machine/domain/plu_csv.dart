import 'package:pos_machine/models/get_product.dart';

/// The columns the weigh machine's import expects; PLU is the product's SKU.
/// Barcode and PLU stay strings so leading zeroes survive the CSV round trip.
class PluCsv {
  static const fileName = 'PLU.csv';
  static const headers = <String>['NAME', 'BARCODE', 'PRICE', 'UNIT', 'PLU'];

  /// The product's SKU for the weigh machine, or null when it has none.
  ///
  /// The catalog API usually leaves the product-level `sku` empty and sets
  /// the SKU on each store's stock rows (`stock[].sku`). So the product's own
  /// SKU wins, then the latest stock row of [storeId] that has one. With no
  /// [storeId] (no active store known), any stock row counts.
  static String? skuOf(GetProduct product, {int? storeId}) {
    final own = product.sku?.trim();
    if (own != null && own.isNotEmpty) return own;
    String? found;
    for (final row in product.stock ?? const <Stock>[]) {
      if (storeId != null && row.storeId != storeId) continue;
      final sku = row.sku?.trim();
      if (sku != null && sku.isNotEmpty) found = sku; // later rows win
    }
    return found;
  }

  /// A product belongs on the weigh machine when it has an SKU in this
  /// store. The back office sets an SKU only on products sold through the
  /// scale; the `weight_info.is_weighted` flag is not sent with the catalog.
  static bool isWeighted(GetProduct product, {int? storeId}) =>
      skuOf(product, storeId: storeId) != null;

  static List<GetProduct> weighted(
    Iterable<GetProduct> products, {
    int? storeId,
  }) =>
      products
          .where((product) => isWeighted(product, storeId: storeId))
          .toList(growable: false);

  /// [storeId] picks the stock row whose SKU fills the PLU column, as in
  /// [skuOf].
  static String build(Iterable<GetProduct> products, {int? storeId}) {
    final rows = <List<String>>[
      headers,
      for (final product in products)
        [
          product.productName?.trim() ?? '',
          product.barcode ?? '',
          _money(product.price?.price),
          product.unit ?? '',
          skuOf(product, storeId: storeId) ?? '',
        ],
    ];
    return '${rows.map((row) => row.map(_escape).join(',')).join('\r\n')}\r\n';
  }

  static String _money(Object? value) {
    final number = num.tryParse(value?.toString() ?? '');
    return number == null ? '' : number.toStringAsFixed(2);
  }

  static String _escape(String value) {
    if (!value.contains(RegExp('[",\r\n]'))) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}
