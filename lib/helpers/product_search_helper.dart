import 'package:pos_machine/models/get_product.dart';

/// Shared catalog search used by billing, product lists, and menu grids.
///
/// A single query can match a translated product name, item code, SKU, HSN
/// code, or any sellable barcode (product, active variant, or sale unit).
class ProductSearchHelper {
  const ProductSearchHelper._();

  static List<GetProduct> search(
    Iterable<GetProduct> products,
    String query,
  ) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return products.toList();

    final matches = <({GetProduct product, int index, int rank})>[];
    for (final entry in products.toList().indexed) {
      final rank = _bestRank(entry.$2, normalized);
      if (rank != null) {
        matches.add((product: entry.$2, index: entry.$1, rank: rank));
      }
    }

    matches.sort((first, second) {
      final comparison = first.rank.compareTo(second.rank);
      return comparison != 0 ? comparison : first.index.compareTo(second.index);
    });
    return matches.map((entry) => entry.product).toList();
  }

  static bool matches(GetProduct product, String query) {
    final normalized = _normalize(query);
    return normalized.isEmpty || _bestRank(product, normalized) != null;
  }

  /// Matches every barcode representation and ranks exact/prefix/substring
  /// results. This keeps a five-digit partial scan useful without sacrificing
  /// the fast exact-barcode index used by checkout scanners.
  static List<GetProduct> searchBarcodes(
    Iterable<GetProduct> products,
    String query,
  ) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return products.toList();

    final matches = <({GetProduct product, int index, int rank})>[];
    for (final entry in products.toList().indexed) {
      final rank = _bestValueRank(
        barcodes(entry.$2),
        normalized,
        preferShorterPrefix: true,
      );
      if (rank != null) {
        matches.add((product: entry.$2, index: entry.$1, rank: rank));
      }
    }
    matches.sort((first, second) {
      final comparison = first.rank.compareTo(second.rank);
      return comparison != 0 ? comparison : first.index.compareTo(second.index);
    });
    return matches.map((entry) => entry.product).toList();
  }

  static List<String> names(GetProduct product) {
    final values = <String>[];

    void add(dynamic value) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) values.add(text);
    }

    void extract(dynamic value) {
      if (value == null) return;
      if (value is String || value is num || value is bool) {
        add(value);
      } else if (value is Map) {
        for (final key in const ['name', 'product_name', 'value', 'text']) {
          if (value.containsKey(key)) add(value[key]);
        }
        for (final entry in value.entries) {
          final key = entry.key.toString().toLowerCase();
          if (!key.contains('language') && key != 'id') extract(entry.value);
        }
      } else if (value is Iterable) {
        for (final item in value) {
          extract(item);
        }
      }
    }

    add(product.productName);
    extract(product.names);
    return values.toSet().toList();
  }

  static List<String> barcodes(GetProduct product) => <String>{
        if (_hasText(product.barcode)) product.barcode!.trim(),
        ...?product.variants
            ?.where((variant) => variant.active && _hasText(variant.barcode))
            .map((variant) => variant.barcode!.trim()),
        ...?product.saleUnits
            ?.where((unit) => _hasText(unit.barcode))
            .map((unit) => unit.barcode!.trim()),
      }.toList();

  static List<String> searchableValues(GetProduct product) => <String>{
        ...names(product),
        if (_hasText(product.itemCode)) product.itemCode!.trim(),
        if (_hasText(product.sku)) product.sku!.trim(),
        ...?product.variants
            ?.where((variant) => variant.active && _hasText(variant.sku))
            .map((variant) => variant.sku!.trim()),
        ...?product.stock
            ?.where((stock) => _hasText(stock.sku))
            .map((stock) => stock.sku!.trim()),
        if (_hasText(product.hsnCode)) product.hsnCode!.trim(),
        ...?product.stock
            ?.where((stock) => _hasText(stock.hsnCode))
            .map((stock) => stock.hsnCode!.trim()),
        ...barcodes(product),
      }.toList();

  static int? _bestRank(GetProduct product, String query) =>
      _bestValueRank(searchableValues(product), query);

  static int? _bestValueRank(
    Iterable<String> values,
    String query, {
    bool preferShorterPrefix = false,
  }) {
    int? best;
    for (final rawValue in values) {
      final value = _normalize(rawValue);
      final position = value.indexOf(query);
      if (position < 0) continue;

      // Exact > prefix > word-prefix > substring. For substring matches,
      // earlier positions and shorter values are considered more relevant.
      final int rank;
      if (value == query) {
        rank = 0;
      } else if (position == 0) {
        rank = 100 + (preferShorterPrefix ? value.length - query.length : 0);
      } else if (_isWordBoundary(value, position)) {
        rank = 1000 + position * 10 + value.length - query.length;
      } else {
        rank = 10000 + position * 10 + value.length - query.length;
      }
      if (best == null || rank < best) best = rank;
    }
    return best;
  }

  static bool _isWordBoundary(String value, int index) {
    if (index <= 0) return true;
    return !RegExp(r'[a-z0-9]').hasMatch(value[index - 1]);
  }

  static bool _hasText(String? value) => value?.trim().isNotEmpty ?? false;
  static String _normalize(String value) => value.trim().toLowerCase();
}
