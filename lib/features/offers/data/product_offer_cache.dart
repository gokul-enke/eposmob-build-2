import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../domain/product_offer_catalog.dart';

/// Per-store offline copy of the offer catalog, kept in Hive so offers keep
/// applying when the app starts without a connection.
///
/// Store ids are only unique within a tenant, so every entry also records a
/// fingerprint of the tenant it belongs to, and another tenant's entry is
/// never loaded.
class ProductOfferCache {
  const ProductOfferCache();

  static const boxName = 'product_offers';
  static const _tenantKey = 'tenant';

  static String keyFor(int? storeId) =>
      storeId == null ? 'store_unknown' : 'store_$storeId';

  /// A one-way fingerprint of [apiKey], so the cache never stores the key.
  static String? tenantFingerprint(String? apiKey) {
    if (apiKey == null || apiKey.isEmpty) return null;
    return sha256.convert(utf8.encode(apiKey)).toString().substring(0, 16);
  }

  Future<Box> _box() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box(boxName);
    return Hive.openBox(boxName);
  }

  Future<void> save(ProductOfferCatalog catalog, {String? tenant}) async {
    final box = await _box();
    await box.put(keyFor(catalog.storeId), {
      ...catalog.toJson(),
      _tenantKey: tenant,
    });
  }

  /// The cached catalog for [storeId] of [tenant], or null when nothing
  /// usable is stored.
  Future<ProductOfferCatalog?> load(int? storeId, {String? tenant}) async {
    final box = await _box();
    final cached = box.get(keyFor(storeId));
    if (cached is! Map) return null;
    if (cached[_tenantKey] != tenant) {
      debugPrint('Product offers: ignoring the cache of another tenant.');
      return null;
    }
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
