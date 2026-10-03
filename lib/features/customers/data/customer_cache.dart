import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../domain/models/customer_list.dart';

/// Per-store offline copy of the customer directory, kept in Hive.
class CustomerCache {
  const CustomerCache();

  static const boxName = 'customer_cache';

  static String keyFor(int? storeId) =>
      storeId == null ? 'store_unknown' : 'store_$storeId';

  Future<Box> _box() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box(boxName);
    return Hive.openBox(boxName);
  }

  Future<void> save(int? storeId, List<CustomerListModelData> customers) async {
    final box = await _box();
    await box.put(keyFor(storeId), {
      'cached_at': DateTime.now().toIso8601String(),
      'data': customers.map((customer) => customer.toJson()).toList(),
    });
  }

  /// The cached customers for [storeId], or `null` when nothing usable is
  /// stored.
  Future<List<CustomerListModelData>?> load(int? storeId) async {
    final box = await _box();
    final cached = box.get(keyFor(storeId));
    if (cached is! Map) return null;
    final rawData = cached['data'];
    if (rawData is! List) return null;

    try {
      return rawData
          .map((item) => CustomerListModelData.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();
    } catch (error) {
      debugPrint('Failed to parse cached customers: $error');
      return null;
    }
  }

  /// Removes the cached directory for [storeId] if the box is open. Does not
  /// open the box just to clear it.
  Future<void> clear(int? storeId) async {
    if (!Hive.isBoxOpen(boxName)) return;
    await Hive.box(boxName).delete(keyFor(storeId));
  }
}
