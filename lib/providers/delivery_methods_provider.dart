import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/delivery_method.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeliveryMethodsProvider with ChangeNotifier {
  static const String _deliveryMethodsCacheKeyPrefix = 'delivery_methods_cache';
  static const String _tag = '🚚 [DeliveryMethodsProvider]';

  List<DeliveryMethod> _deliveryMethods = [];
  int? _loadedStoreId;
  bool _isLoading = false;
  bool _hasFetchedOnce = false; // Track if we've ever successfully loaded data

  List<DeliveryMethod> get deliveryMethods => _deliveryMethods;
  bool get isLoading => _isLoading;
  bool get hasMethods => _deliveryMethods.isNotEmpty;

  // Add method to get default delivery method (Store Takeaway)
  DeliveryMethod? get defaultDeliveryMethod {
    try {
      return _deliveryMethods.firstWhere(
        (method) => method.name.toLowerCase().contains('store takeaway'),
        orElse: () => _deliveryMethods.isNotEmpty
            ? _deliveryMethods.first
            : DeliveryMethod(id: "11", name: "Store Takeaway"),
      );
    } catch (e) {
      // Fallback to first method or default
      return _deliveryMethods.isNotEmpty
          ? _deliveryMethods.first
          : DeliveryMethod(id: "11", name: "Store Takeaway");
    }
  }

  DeliveryMethod? resolveDefaultDeliveryMethod({String? appSettingsDefault}) {
    final configuredDefault = appSettingsDefault?.trim();
    if (configuredDefault != null && configuredDefault.isNotEmpty) {
      for (final method in _deliveryMethods) {
        final code = method.code?.trim();
        if (method.id == configuredDefault ||
            method.name.toLowerCase() == configuredDefault.toLowerCase() ||
            (code != null &&
                code.isNotEmpty &&
                code.toLowerCase() == configuredDefault.toLowerCase())) {
          return method;
        }
      }
      debugPrint(
        '$_tag Default delivery method "$configuredDefault" not found in delivery methods',
      );
    }

    return defaultDeliveryMethod;
  }

  DeliveryMethodsProvider() {
    debugPrint('$_tag Initialized (no auto-fetch — waits for store bootstrap)');
  }

  List<DeliveryMethod> _parseDeliveryMethods(dynamic rawData) {
    final List<DeliveryMethod> parsedMethods = [];

    if (rawData is List) {
      for (final item in rawData) {
        if (item is Map<String, dynamic>) {
          final id = item['id']?.toString();
          final name = item['name']?.toString();
          final code = item['code']?.toString();

          if (id != null && id.isNotEmpty && name != null && name.isNotEmpty) {
            // Parse prices array if available
            final List<DeliveryPrice> prices = [];
            if (item['prices'] is List) {
              for (final priceItem in item['prices']) {
                if (priceItem is Map<String, dynamic>) {
                  try {
                    prices.add(DeliveryPrice.fromJson(priceItem));
                  } catch (e) {
                    debugPrint('Error parsing delivery price: $e');
                  }
                }
              }
            }

            parsedMethods.add(DeliveryMethod(
              id: id,
              name: name,
              code: code,
              prices: prices,
            ));
          }
        }
      }
      return parsedMethods;
    }

    if (rawData is Map<String, dynamic>) {
      rawData.forEach((key, value) {
        if (value is String) {
          parsedMethods.add(DeliveryMethod.fromJson(key, value));
        } else if (value is Map<String, dynamic>) {
          final id = value['id']?.toString() ?? key;
          final name = value['name']?.toString() ?? value['label']?.toString();

          if (name != null && name.isNotEmpty) {
            parsedMethods.add(DeliveryMethod(id: id, name: name));
          }
        }
      });
    }

    return parsedMethods;
  }

  /// Fetches delivery methods.
  ///
  /// **Caching strategy (same as payment methods):**
  /// 1. In-memory (`_deliveryMethods`) — fastest, survives across page navigations
  /// 2. SharedPreferences — survives app restart
  /// 3. API call — last resort, result is saved to both layers
  ///
  /// Called once during store bootstrap (`StoreSessionProvider.bootstrapStore`).
  /// Subsequent calls (e.g. from RestaurantPage) return immediately from memory.
  Future<void> fetchDeliveryMethods({bool forceRefresh = false}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? activeStoreId = prefs.getInt('active_store_id');
    debugPrint(
        '$_tag Fetching delivery methods (forceRefresh=$forceRefresh, storeId=$activeStoreId)');

    // ── 1. In-memory cache hit for the current store ──
    if (!forceRefresh &&
        _deliveryMethods.isNotEmpty &&
        _loadedStoreId == activeStoreId) {
      debugPrint(
          '$_tag ✅ Returning ${_deliveryMethods.length} methods from MEMORY for storeId=$activeStoreId (no API call)');
      return;
    }

    // ── 2. SharedPreferences cache hit ──
    if (!forceRefresh) {
      final cachedMethods = _loadDeliveryMethodsFromLocalCache(
        prefs,
        activeStoreId,
      );
      if (cachedMethods.isNotEmpty) {
        _setDeliveryMethods(cachedMethods, activeStoreId);
        _hasFetchedOnce = true;
        debugPrint(
            '$_tag ✅ Loaded ${cachedMethods.length} methods from LOCAL CACHE (SharedPreferences)');
        notifyListeners();
        return;
      }
      debugPrint('$_tag ⚠️ No local cache found, will hit API');
    }

    // ── 3. API fetch ──
    _isLoading = true;
    notifyListeners();

    try {
      String? apiKey = prefs.getString('api_key');
      String? accessToken = prefs.getString('access_token');

      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('$_tag ⚠️ No API key found, skipping API fetch');
        _setDeliveryMethods(
          _loadDeliveryMethodsFromLocalCache(
            prefs,
            activeStoreId,
          ),
          activeStoreId,
        );
        debugPrint(
            '$_tag Fallback to local cache: ${_deliveryMethods.length} methods');
        return;
      }

      final Map<String, String> queryParameters = {};
      if (activeStoreId != null) {
        queryParameters['store_id'] = activeStoreId.toString();
      }

      final url = Uri.parse(APPUrl.getDeliveryMethods)
          .replace(queryParameters: queryParameters);
      debugPrint('$_tag 🌐 API call → $url');

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Tenant': apiKey,
        if (accessToken != null && accessToken.isNotEmpty)
          'Authorization': 'Bearer $accessToken',
      };
      debugPrint(
          '$_tag Headers: X-Tenant=${apiKey.substring(0, apiKey.length > 8 ? 8 : apiKey.length)}..., hasAuth=${accessToken != null && accessToken.isNotEmpty}');

      final response = await http.get(url, headers: headers);

      debugPrint('$_tag API response status: ${response.statusCode}');
      // Log first 200 chars of body for debugging (catches HTML responses early)
      final bodyPreview = response.body.length > 200
          ? response.body.substring(0, 200)
          : response.body;
      debugPrint('$_tag API response body preview: $bodyPreview');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          _setDeliveryMethods(
              _parseDeliveryMethods(data['data']), activeStoreId);
          _hasFetchedOnce = true;
          await _saveDeliveryMethodsToLocalCache(
            prefs,
            activeStoreId,
            _deliveryMethods,
          );
          debugPrint(
              '$_tag ✅ Fetched ${_deliveryMethods.length} methods from API and saved to cache');
          for (final m in _deliveryMethods) {
            debugPrint(
                '$_tag   → [${m.id}] ${m.name} (${m.prices.length} prices)');
          }
        } else {
          debugPrint('$_tag ❌ API returned non-success: ${data['message']}');
          _fallbackToCache(
              prefs, activeStoreId, 'API returned non-success status');
        }
      } else {
        debugPrint('$_tag ❌ API HTTP error: ${response.statusCode}');
        _fallbackToCache(prefs, activeStoreId, 'HTTP ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('$_tag ❌ API fetch exception: $error');
      _fallbackToCache(prefs, activeStoreId, error.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Falls back to local cache after an API failure.
  /// If cache also empty and we had previous in-memory data, keep it.
  void _fallbackToCache(
      SharedPreferences prefs, int? activeStoreId, String reason) {
    final cachedMethods =
        _loadDeliveryMethodsFromLocalCache(prefs, activeStoreId);
    if (cachedMethods.isNotEmpty) {
      _setDeliveryMethods(cachedMethods, activeStoreId);
      _hasFetchedOnce = true;
      debugPrint(
          '$_tag 📦 Fallback: Using ${cachedMethods.length} methods from LOCAL CACHE (reason: $reason)');
    } else if (_deliveryMethods.isNotEmpty && _loadedStoreId == activeStoreId) {
      // Keep whatever was already in memory — don't wipe it
      debugPrint(
          '$_tag 📦 Fallback: Keeping ${_deliveryMethods.length} existing in-memory methods (reason: $reason)');
    } else {
      _setDeliveryMethods([], activeStoreId);
      debugPrint(
          '$_tag ⚠️ No cached or in-memory methods available (reason: $reason)');
    }
  }

  void _setDeliveryMethods(List<DeliveryMethod> methods, int? storeId) {
    _deliveryMethods = methods;
    _loadedStoreId = storeId;
  }

  List<DeliveryMethod> _loadDeliveryMethodsFromLocalCache(
    SharedPreferences prefs,
    int? activeStoreId,
  ) {
    final key = _deliveryMethodsCacheKey(activeStoreId);
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      debugPrint('$_tag SharedPreferences key "$key" is empty');
      return [];
    }

    try {
      final decoded = json.decode(raw) as List<dynamic>;
      final result = decoded
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => DeliveryMethod(
              id: item['id']?.toString() ?? '',
              name: item['name']?.toString() ?? '',
              code: item['code']?.toString(),
              prices: ((item['prices'] as List<dynamic>?) ?? const [])
                  .whereType<Map<String, dynamic>>()
                  .map(DeliveryPrice.fromJson)
                  .toList(),
            ),
          )
          .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
          .toList();
      debugPrint(
          '$_tag SharedPreferences cache read: ${result.length} methods from key "$key"');
      return result;
    } catch (error) {
      debugPrint('$_tag ❌ Failed to read cached delivery methods: $error');
      return [];
    }
  }

  Future<void> _saveDeliveryMethodsToLocalCache(
    SharedPreferences prefs,
    int? activeStoreId,
    List<DeliveryMethod> methods,
  ) async {
    final key = _deliveryMethodsCacheKey(activeStoreId);
    try {
      await prefs.setString(
        key,
        json.encode(methods.map((item) => item.toJson()).toList()),
      );
      debugPrint(
          '$_tag 💾 Saved ${methods.length} methods to SharedPreferences key "$key"');
    } catch (error) {
      debugPrint('$_tag ❌ Failed to cache delivery methods locally: $error');
    }
  }

  /// Clears in-memory and SharedPreferences delivery method cache.
  Future<void> clearCachedDeliveryMethods() async {
    final prefs = await SharedPreferences.getInstance();
    final activeStoreId = prefs.getInt('active_store_id');

    await prefs.remove(_deliveryMethodsCacheKey(activeStoreId));
    await prefs.remove(_deliveryMethodsCacheKeyPrefix);

    _setDeliveryMethods([], null);
    _hasFetchedOnce = false;
    notifyListeners();
    debugPrint('$_tag Cleared delivery methods cache');
  }

  String _deliveryMethodsCacheKey(int? activeStoreId) {
    return activeStoreId == null
        ? _deliveryMethodsCacheKeyPrefix
        : '${_deliveryMethodsCacheKeyPrefix}_$activeStoreId';
  }
}
