import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/product_offer_catalog.dart';
import 'product_offer_api.dart';
import 'product_offer_cache.dart';

/// Starts the timer that retries a failed offer sync. Injected by tests.
typedef ProductOfferRetryTimer = Timer Function(
  Duration delay,
  void Function() retry,
);

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
    ProductOfferRetryTimer? retryTimer,
  })  : _api = api ?? ProductOfferApi(),
        _cache = cache,
        _session = session,
        _accessToken = accessToken ?? _readAccessToken,
        _clock = clock,
        _retryTimer = retryTimer ?? Timer.new;

  static final ProductOfferRepository instance = ProductOfferRepository();

  /// Wait before retrying a failed sync. Doubles after every further
  /// failure, up to [maxRetryDelay].
  static const firstRetryDelay = Duration(seconds: 30);
  static const maxRetryDelay = Duration(minutes: 10);

  final ProductOfferApi _api;
  final ProductOfferCache _cache;
  final TenantSession _session;
  final Future<String?> Function() _accessToken;
  final DateTime Function()? _clock;
  final ProductOfferRetryTimer _retryTimer;

  ProductOfferCatalog _catalog = ProductOfferCatalog.empty;

  /// Fingerprint of the tenant [_catalog] belongs to.
  String? _tenant;
  Future<bool>? _refreshing;
  Completer<bool>? _queued;
  bool _queuedFull = false;
  bool _storeInitialized = false;
  int _generation = 0;
  Future<ProductOfferCatalog?>? _loadingStore;
  Timer? _retry;
  Duration? _retryDelay;
  bool _endpointMissing = false;

  /// The catalog pricing should use right now.
  ProductOfferCatalog get catalog => _catalog;

  /// The server-corrected time offer validity is checked against. It is
  /// [DateHelper.now], the clock receipts are stamped with, whose offset
  /// every offer sync refreshes. An injected test clock is corrected by the
  /// catalog's own offset instead.
  DateTime trustedNow() {
    final clock = _clock;
    return clock == null
        ? DateHelper.now().toUtc()
        : _catalog.trustedNow(clock());
  }

  static Future<String?> _readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return token == null || token.isEmpty ? null : token;
  }

  Future<String?> _activeTenant() async =>
      ProductOfferCache.tenantFingerprint(await _session.apiKey());

  /// Loads the cached catalog of the active store. Safe to call repeatedly.
  Future<void> loadCached() async {
    try {
      final storeId = await _session.activeStoreId();
      await _ensureStore(storeId, await _activeTenant());
    } catch (error) {
      debugPrint('Product offers: loading cache failed: $error');
    }
  }

  Future<int?> _ensureStore(int? storeId, String? tenant) async {
    if (_storeInitialized && _catalog.storeId == storeId && _tenant == tenant) {
      final generation = _generation;
      await _loadingStore;
      return generation == _generation ? generation : null;
    }
    final generation = ++_generation;
    _cancelRetry();
    _storeInitialized = true;
    _tenant = tenant;
    _catalog = ProductOfferCatalog(storeId: storeId);
    final loading = _loadingStore = _cache.load(storeId, tenant: tenant);
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

  /// Writes the catalog unless [clear] or a store switch has superseded
  /// [generation], so a late write cannot refill a cleared cache.
  Future<void> _save(int generation) async {
    if (generation != _generation) return;
    await _cache.save(_catalog, tenant: _tenant);
  }

  /// Applies the `POS_OFFERS` setting from a successful app-settings fetch.
  /// Turning it on triggers a full sync; turning it off stops pricing at
  /// once.
  Future<void> applySetting({required bool enabled, int? storeId}) async {
    try {
      final activeStoreId = await _session.activeStoreId();
      // The response belongs to a store that is no longer active (switched,
      // or the session was reset meanwhile).
      if (storeId != null && storeId != activeStoreId) return;
      final generation =
          await _ensureStore(activeStoreId, await _activeTenant());
      if (generation == null) return;
      final wasEnabled = _catalog.enabled;
      if (wasEnabled != enabled) {
        _catalog = _catalog.copyWith(enabled: enabled);
        if (!enabled) _cancelRetry();
        await _save(generation);
        if (generation != _generation) return;
        notifyListeners();
      }
      // Offers that changed while the switch was off may be older than the
      // cached `since`, so switching on downloads everything.
      if (enabled && generation == _generation) {
        await refresh(full: !wasEnabled);
      }
    } catch (error) {
      debugPrint('Product offers: applying POS_OFFERS failed: $error');
    }
  }

  /// Pulls offer changes from the backend. Completes with true when the
  /// catalog is up to date or there is nothing to sync (offers off, no
  /// store or no login), and false when the download failed. A failure
  /// while offers are on is retried with backoff.
  ///
  /// A request made while a sync is running runs once more afterwards
  /// (full if any queued request was full) and completes with that run.
  /// Never throws.
  Future<bool> refresh({bool full = false}) {
    if (_refreshing != null) {
      _queuedFull = _queuedFull || full;
      return (_queued ??= Completer<bool>()).future;
    }
    return _startRefresh(full: full);
  }

  Future<bool> _startRefresh({required bool full}) {
    _endpointMissing = false;
    // This run replaces a scheduled retry; its outcome schedules the next.
    _retry?.cancel();
    _retry = null;
    final run = _refresh(full: full);
    _refreshing = run;
    unawaited(run.then((synced) => _refreshFinished(run, synced, full)));
    return run;
  }

  void _refreshFinished(Future<bool> run, bool synced, bool full) {
    // clear() permits a new session to start its own request immediately.
    if (!identical(_refreshing, run)) return;
    _refreshing = null;
    // A success ends the failure streak even when another pull is queued.
    if (synced) _retryDelay = null;
    final queued = _queued;
    if (queued != null) {
      final queuedFull = _queuedFull;
      _queued = null;
      _queuedFull = false;
      queued.complete(_startRefresh(full: queuedFull));
      return;
    }
    if (!synced && !_endpointMissing) {
      _scheduleRetry(full: full);
    }
  }

  void _scheduleRetry({required bool full}) {
    if (!_catalog.enabled) return;
    final previous = _retryDelay;
    final delay = previous == null
        ? firstRetryDelay
        : previous * 2 > maxRetryDelay
            ? maxRetryDelay
            : previous * 2;
    _retryDelay = delay;
    final generation = _generation;
    _retry?.cancel();
    _retry = _retryTimer(delay, () {
      _retry = null;
      if (generation == _generation) unawaited(refresh(full: full));
    });
    debugPrint('Product offers: retrying the sync in ${delay.inSeconds} s.');
  }

  void _cancelRetry() {
    _retry?.cancel();
    _retry = null;
    _retryDelay = null;
  }

  Future<bool> _refresh({required bool full}) async {
    int? requestGeneration;
    try {
      final storeId = await _session.activeStoreId();
      final apiKey = await _session.apiKey();
      final generation = await _ensureStore(
        storeId,
        ProductOfferCache.tenantFingerprint(apiKey),
      );
      if (generation == null || !_catalog.enabled || storeId == null) {
        return true;
      }
      requestGeneration = generation;

      final accessToken = await _accessToken();
      if (generation != _generation || apiKey == null || accessToken == null) {
        return true;
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
        return true;
      }

      final clock = _clock;
      final serverTime = response.serverTime;
      final previous = _catalog;
      _catalog = _catalog.applySync(
        response,
        fullSync: since == null,
        deviceNow: clock?.call() ?? response.receivedAt ?? DateTime.now(),
      );
      final clockChanged = previous.lastSyncedAt == null ||
          (_catalog.clockOffset - previous.clockOffset).inMilliseconds.abs() >= 1000;
      if (!clockChanged) {
        _catalog = _catalog.copyWith(clockOffset: previous.clockOffset);
      }
      if (clock == null && serverTime != null && clockChanged) {
        // Offer validity and receipt timestamps share DateHelper's clock.
        DateHelper.setServerTime(serverTime, deviceTime: response.receivedAt);
      }
      await _save(generation);
      if (clockChanged || _pricingFingerprint(previous) != _pricingFingerprint(_catalog)) {
        notifyListeners();
      }
      return true;
    } on ProductOfferEndpointMissing catch (error) {
      if (requestGeneration != _generation) return true;
      _endpointMissing = true;
      debugPrint('Product offers: $error');
      return false;
    } catch (error) {
      debugPrint('Product offers: sync failed, keeping cached offers: $error');
      return false;
    }
  }

  static String _pricingFingerprint(ProductOfferCatalog catalog) {
    final ids = catalog.offers.keys.toList()..sort();
    return jsonEncode([
      catalog.enabled,
      catalog.storeId,
      for (final id in ids) catalog.offers[id]!.toJson(),
    ]);
  }

  /// Forgets every cached offer (logout or tenant switch).
  Future<void> clear() async {
    _generation++;
    _storeInitialized = false;
    _tenant = null;
    _loadingStore = null;
    _refreshing = null;
    final queued = _queued;
    _queued = null;
    _queuedFull = false;
    _cancelRetry();
    _catalog = ProductOfferCatalog.empty;
    notifyListeners();
    // The session these requests were made for is gone.
    queued?.complete(true);
    try {
      await _cache.clearAll();
    } catch (error) {
      debugPrint('Product offers: clearing cache failed: $error');
    }
  }

  @override
  void dispose() {
    _cancelRetry();
    super.dispose();
  }

  @visibleForTesting
  void debugSetCatalog(ProductOfferCatalog catalog) {
    _catalog = catalog;
    notifyListeners();
  }
}
