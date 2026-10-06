import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../domain/product_offer_catalog.dart';

/// Per-store offline copy of the offer catalog, kept in Hive so offers keep
/// applying when the app starts without a connection.
class ProductOfferCache {
  const ProductOfferCache();

  static const boxName = 'product_offers';

  static String keyFor(int? storeId) =>
      storeId == null ? 'store_unknown' : 'store_$storeId';

  Future<Box> _box() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box(boxName);
    return Hive.openBox(boxName);
  }

  Future<void> save(ProductOfferCatalog catalog) async {
    final box = await _box();
    await box.put(keyFor(catalog.storeId), catalog.toJson());
  }

  /// The cached catalog for [storeId], or null when nothing usable is stored.
  Future<ProductOfferCatalog?> load(int? storeId) async {
    final box = await _box();
    final cached = box.get(keyFor(storeId));
    if (cached is! Map) return null;
    try {
      return ProductOfferCatalog.fromJson(
        Map<String, dynamic>.from(cached),
      );
    } catch (error) {
      debugPrint('Failed to parse cached product offers: $error');
      return null;
    }
  }

  Future<void> clearAll() async {
    final box = await _box();
    await box.clear();
  }
}
