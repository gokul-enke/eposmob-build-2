import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Uses the same login-cached store directory as the legacy listing. A missing
/// or malformed directory must not prevent the table from loading.
Future<Map<String, String>> consumedStocksStores() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('stores');
  if (raw == null || raw.isEmpty) return {};
  final entries = jsonDecode(raw);
  if (entries is! List) throw const FormatException('Invalid store directory');
  return {
    for (final store in entries)
      // Login serializes Store.toJson with store_id; retain older id caches.
      if (store is Map &&
          (store['store_id'] ?? store['id']) != null &&
          store['store_name'] is String)
        (store['store_id'] ?? store['id']).toString():
            store['store_name'] as String,
  };
}
