import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/product_offer_catalog.dart';
import 'product_offer_api.dart';
import 'product_offer_cache.dart';

/// Holds the offer catalog for the active store and keeps it in sync.
///
/// Pricing reads [catalog] synchronously; everything that talks to the
/// network or Hive is async and never throws to callers. One shared
/// [instance] is used by the cart provider, app settings and sync.
class ProductOfferRepository extends ChangeNotifier {
  ProductOfferRepository({
    ProductOfferApi? api,
    ProductOfferCache cache = const ProductOfferCache(),
    TenantSession session = const TenantSession(),
    Future<String?> Function()? accessToken,
    DateTime Function()? clock,
  })  : _api = api ?? ProductOfferApi(),
        _cache = cache,
        _session = session,
        _accessToken = accessToken ?? _readAccessToken,
        _clock = clock ?? DateTime.now;

  static final ProductOfferRepository instance = ProductOfferRepository();

  final ProductOfferApi _api;
  final ProductOfferCache _cache;
  final TenantSession _session;
  final Future<String?> Function() _accessToken;
  final DateTime Function() _clock;

  ProductOfferCatalog _catalog = ProductOfferCatalog.empty;
  Future<void>? _refreshing;
  bool _refreshQueued = false;
  bool _queuedFull = false;
  bool _storeInitialized = false;
  int _generation = 0;
  Future<ProductOfferCatalog?>? _loadingStore;

  /// The catalog pricing should use right now.
  ProductOfferCatalog get catalog => _catalog;

  /// Device time corrected by the last measured server clock offset.
  DateTime trustedNow() => _catalog.trustedNow(_clock());

  static Future<String?> _readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return token == null || token.isEmpty ? null : token;
  }

  /// Loads the cached catalog of the active store. Safe to call repeatedly.
  Future<void> loadCached() async {
    try {
      final storeId = await _session.activeStoreId();
      await _ensureStore(storeId);
    } catch (error) {
      debugPrint('Product offers: loading cache failed: $error');
    }
  }

  Future<int?> _ensureStore(int? storeId) async {
    if (_storeInitialized && _catalog.storeId == storeId) {
      final generation = _generation;
      await _loadingStore;
      return generation == _generation ? generation : null;
    }
    final generation = ++_generation;
    _storeInitialized = true;
    _catalog = ProductOfferCatalog(storeId: storeId);
    final loading = _loadingStore = _cache.load(storeId);
    notifyListeners();
    try {
      final cached = await loading;
      if (generation != _generation) return null;
      _catalog = cached ?? ProductOfferCatalog(storeId: storeId);
      notifyListeners();
      return generation;
    } finally {
      if (generation == _generation) _loadingStore = null;
    }
  }

  /// Applies the `POS_OFFERS` setting from a successful app-settings fetch.
  /// Turning it on triggers a sync; turning it off stops pricing at once.
  Future<void> applySetting({required bool enabled, int? storeId}) async {
    try {
      final generation =
          await _ensureStore(storeId ?? await _session.activeStoreId());
      if (generation == null) return;
      if (_catalog.enabled != enabled) {
        _catalog = _catalog.copyWith(enabled: enabled);
        await _cache.save(_catalog);
        if (generation != _generation) return;
        notifyListeners();
      }
      if (enabled && generation == _generation) await refresh();
    } catch (error) {
      debugPrint('Product offers: applying POS_OFFERS failed: $error');
    }
  }

  /// Pulls offer changes from the backend. A sync already running absorbs
  /// the request and runs once more afterwards. Never throws.
  Future<void> refresh({bool full = false}) {
    final running = _refreshing;
    if (running != null) {
      _refreshQueued = true;
      _queuedFull = _queuedFull || full;
      return running;
    }
    late final Future<void> run;
    run = _refresh(full: full).whenComplete(() {
      // clear() permits a new session to start its own request immediately.
      if (!identical(_refreshing, run)) return;
      _refreshing = null;
      if (_refreshQueued) {
        final queuedFull = _queuedFull;
        _refreshQueued = false;
        _queuedFull = false;
        unawaited(refresh(full: queuedFull));
      }
    });
    _refreshing = run;
    return run;
  }

  Future<void> _refresh({required bool full}) async {
    try {
      final storeId = await _session.activeStoreId();
      final generation = await _ensureStore(storeId);
      if (generation == null || !_catalog.enabled || storeId == null) return;

      final apiKey = await _session.apiKey();
      final accessToken = await _accessToken();
      if (generation != _generation || apiKey == null || accessToken == null) {
        return;
      }

      final since = full ? null : _catalog.lastSyncedAt;
      final response = await _api.fetch(
        accessToken: accessToken,
        apiKey: apiKey,
        storeId: storeId,
        since: since,
      );
      // Store ids may be reused by another tenant, or after switching away
      // and back. Check both the request generation and current session.
      final activeStoreId = await _session.activeStoreId();
      final activeApiKey = await _session.apiKey();
      if (generation != _generation ||
          activeStoreId != storeId ||
          activeApiKey != apiKey) {
        return;
      }

      _catalog = _catalog.applySync(
        response,
        fullSync: since == null,
        deviceNow: _clock(),
      );
      await _cache.save(_catalog);
      notifyListeners();
    } on ProductOfferEndpointMissing catch (error) {
      debugPrint('Product offers: $error');
    } catch (error) {
      debugPrint('Product offers: sync failed, keeping cached offers: $error');
    }
  }

  /// Forgets every cached offer (logout or tenant switch).
  Future<void> clear() async {
    _generation++;
    _storeInitialized = false;
    _loadingStore = null;
    _refreshing = null;
    _refreshQueued = false;
    _queuedFull = false;
    _catalog = ProductOfferCatalog.empty;
    notifyListeners();
    try {
      await _cache.clearAll();
    } catch (error) {
      debugPrint('Product offers: clearing cache failed: $error');
    }
  }

  @visibleForTesting
  void debugSetCatalog(ProductOfferCatalog catalog) {
    _catalog = catalog;
    notifyListeners();
  }
}
