import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/features/offers/data/product_offer_api.dart';
import 'package:pos_machine/features/offers/data/product_offer_cache.dart';
import 'package:pos_machine/features/offers/data/product_offer_repository.dart';
import 'package:pos_machine/features/offers/domain/product_offer_catalog.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../test_support/hive_test_teardown.dart';

class _DelayedCache extends ProductOfferCache {
  final loaded = Completer<ProductOfferCatalog?>();
  final requested = Completer<void>();

  @override
  Future<ProductOfferCatalog?> load(int? storeId, {String? tenant}) {
    requested.complete();
    return loaded.future;
  }
}

class _DelayedSaveCache extends ProductOfferCache {
  bool delayNextSave = false;
  final saveStarted = Completer<void>();
  final releaseSave = Completer<void>();

  @override
  Future<void> save(ProductOfferCatalog catalog, {String? tenant}) async {
    if (delayNextSave) {
      delayNextSave = false;
      saveStarted.complete();
      await releaseSave.future;
    }
    await super.save(catalog, tenant: tenant);
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this.delay, this.callback);

  final Duration delay;
  final void Function() callback;
  bool cancelled = false;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;

  @override
  void cancel() => cancelled = true;

  /// Fires the retry, as the real timer would after [delay].
  void fire() {
    cancelled = true;
    callback();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;
  final now = DateTime.utc(2026, 10, 6, 12);

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_offer_repo_test_');
    Hive.init(hiveDir.path);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'api_key': 'tenant',
      'active_store_id': 1,
    });
    await const ProductOfferCache().clearAll();
  });

  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

  String body({
    List<int> offerIds = const [9],
    List<int> removed = const [],
    String serverTime = '2026-10-06T12:00:00Z',
  }) =>
      jsonEncode({
        'success': true,
        'server_time': serverTime,
        'offers': [
          for (final id in offerIds)
            {
              'id': id,
              'version': 1,
              'valid_from': '2026-10-01T00:00:00Z',
              'valid_until': '2026-11-01T00:00:00Z',
              'lines': [
                {'product_id': 1, 'type': 'percentage', 'value': 10},
              ],
            },
        ],
        'removed_offer_ids': removed,
      });

  /// Retry timers started by repositories built with [repository].
  late List<_FakeTimer> timers;
  setUp(() => timers = []);

  Timer fakeTimer(Duration delay, void Function() retry) {
    final timer = _FakeTimer(delay, retry);
    timers.add(timer);
    return timer;
  }

  ProductOfferRepository repository(
    List<http.Response> responses,
    List<Uri> urls, {
    DateTime Function()? clock,
  }) {
    return ProductOfferRepository(
      api: ProductOfferApi(
        httpGet: (url, {Map<String, String>? headers}) async {
          urls.add(url);
          return responses[urls.length - 1];
        },
      ),
      accessToken: () async => 'token',
      clock: clock ?? () => now,
      retryTimer: fakeTimer,
    );
  }

  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 400 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue);
  }

  test('does not sync while POS_OFFERS is off', () async {
    final urls = <Uri>[];
    final repo = repository([http.Response(body(), 200)], urls);
    await repo.loadCached();
    expect(await repo.refresh(), isTrue);
    expect(urls, isEmpty);
    expect(repo.catalog.enabled, isFalse);
    expect(timers, isEmpty);
  });

  test('every refresh downloads the full catalog and removes absent offers',
      () async {
    final urls = <Uri>[];
    final repo = repository([
      http.Response(body(), 200),
      http.Response(body(offerIds: []), 200),
    ], urls);

    await repo.applySetting(enabled: true, storeId: 1);
    expect(urls.first.queryParameters.containsKey('since'), isFalse);
    expect(repo.catalog.offers.keys, [9]);

    expect(await repo.refresh(), isTrue);
    expect(urls.last.queryParameters.containsKey('since'), isFalse);
    expect(repo.catalog.offers, isEmpty);
  });

  test('turning POS_OFFERS back on downloads everything, not a delta',
      () async {
    final urls = <Uri>[];
    final repo = repository([
      http.Response(body(), 200),
      http.Response(body(offerIds: [10]), 200),
    ], urls);
    await repo.applySetting(enabled: true, storeId: 1);
    expect(repo.catalog.lastSyncedAt, isNotNull);

    await repo.applySetting(enabled: false, storeId: 1);
    await repo.applySetting(enabled: true, storeId: 1);
    expect(urls, hasLength(2));
    expect(urls.last.queryParameters.containsKey('since'), isFalse);
    expect(repo.catalog.offers.keys, [10]);
  });

  test('offers survive a restart through the cache', () async {
    final urls = <Uri>[];
    final repo = repository([http.Response(body(), 200)], urls);
    await repo.applySetting(enabled: true, storeId: 1);

    final restarted = repository(const [], <Uri>[]);
    await restarted.loadCached();
    expect(restarted.catalog.enabled, isTrue);
    expect(restarted.catalog.offers.keys, [9]);
  });

  test('settings refresh recovers an enabled empty cache with a stale cursor',
      () async {
    await const ProductOfferCache().save(
      ProductOfferCatalog(enabled: true, storeId: 1, lastSyncedAt: now),
      tenant: ProductOfferCache.tenantFingerprint('tenant'),
    );
    final urls = <Uri>[];
    final repo = repository([
      http.Response(body(offerIds: [28]), 200)
    ], urls);
    await repo.applySetting(enabled: true, storeId: 1);
    expect(urls.single.queryParameters.containsKey('since'), isFalse);
    expect(repo.catalog.offers.keys, [28]);
    repo.dispose();
  });

  test('the cache survives closing and reopening the Hive box', () async {
    final urls = <Uri>[];
    final repo = repository([http.Response(body(), 200)], urls);
    await repo.applySetting(enabled: true, storeId: 1);
    await Hive.box(ProductOfferCache.boxName).close();

    final restarted = repository(const [], <Uri>[]);
    await restarted.loadCached();
    expect(Hive.isBoxOpen(ProductOfferCache.boxName), isTrue);
    expect(restarted.catalog.enabled, isTrue);
    expect(restarted.catalog.offers.keys, [9]);
    expect(restarted.catalog.lastSyncedAt, now);
  });

  test('every refresh repairs a populated cache missing unchanged offers',
      () async {
    final initial = repository([http.Response(body(), 200)], <Uri>[]);
    await initial.applySetting(enabled: true, storeId: 1);
    initial.dispose();

    final urls = <Uri>[];
    final restarted = repository([
      http.Response(body(offerIds: [9, 28]), 200),
      http.Response(body(offerIds: [9, 28]), 200),
    ], urls);
    await restarted.loadCached();
    expect(restarted.catalog.offers.keys, [9]);
    await restarted.refresh();
    expect(urls.first.queryParameters.containsKey('since'), isFalse);
    expect(restarted.catalog.offers.keys, [9, 28]);
    // Simulate losing one entry during this session, while the cursor and
    // another offer survive. Ordinary refresh must recover the missing rule.
    restarted.debugSetCatalog(restarted.catalog.copyWith(offers: {
      9: restarted.catalog.offers[9]!,
    }));
    await restarted.refresh();
    expect(urls.last.queryParameters.containsKey('since'), isFalse);
    expect(restarted.catalog.offers.keys, [9, 28]);
    restarted.dispose();
  });

  test('automatic refresh rebuilds an empty cache without a settings fetch',
      () async {
    final urls = <Uri>[];
    final repo = repository([
      http.Response(body(), 200),
      http.Response(body(offerIds: [], removed: [9]), 200),
      http.Response('unavailable', 503),
      http.Response(body(offerIds: [28]), 200),
      http.Response(body(offerIds: [28]), 200),
    ], urls);
    await repo.applySetting(enabled: true, storeId: 1);
    await repo.refresh();
    expect(repo.catalog.offers, isEmpty);
    expect(repo.catalog.lastSyncedAt, now);
    expect(await repo.refresh(), isFalse);
    expect(urls[2].queryParameters.containsKey('since'), isFalse);
    await until(() => timers.isNotEmpty);
    timers.single.fire();
    await until(() => repo.catalog.offers.containsKey(28));
    expect(urls[3].queryParameters.containsKey('since'), isFalse);
    await repo.refresh();
    expect(urls.last.queryParameters.containsKey('since'), isFalse);
    expect(repo.catalog.offers.keys, [28]);
    repo.dispose();
  });

  test('returning to a cached store rebuilds its offer baseline', () async {
    final urls = <Uri>[];
    final repo = repository([
      http.Response(body(), 200),
      http.Response(body(offerIds: [10]), 200),
      http.Response(body(offerIds: [9, 28]), 200),
    ], urls);
    await repo.applySetting(enabled: true, storeId: 1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_store_id', 2);
    await repo.applySetting(enabled: true, storeId: 2);
    expect(repo.catalog.offers.keys, [10]);
    await prefs.setInt('active_store_id', 1);
    await repo.refresh();
    expect(urls.last.queryParameters['store_id'], '1');
    expect(urls.last.queryParameters.containsKey('since'), isFalse);
    expect(repo.catalog.offers.keys, [9, 28]);
    repo.dispose();
  });

  test('failed startup rebuild retains cached prices and retries the full list',
      () async {
    final initial = repository([http.Response(body(), 200)], <Uri>[]);
    await initial.applySetting(enabled: true, storeId: 1);
    initial.dispose();

    final urls = <Uri>[];
    final restarted = repository([
      http.Response('unavailable', 503),
      http.Response(body(offerIds: [9, 28]), 200),
    ], urls);
    await restarted.loadCached();
    expect(await restarted.refresh(), isFalse);
    expect(restarted.catalog.offers.keys, [9]);
    expect(restarted.catalog.lastSyncedAt, now);
    await until(() => timers.isNotEmpty);
    timers.single.fire();
    await until(() => restarted.catalog.offers.containsKey(28));
    expect(urls, hasLength(2));
    expect(
        urls.every((url) => !url.queryParameters.containsKey('since')), isTrue);
    restarted.dispose();
  });

  test('a failed sync keeps the cached offers and reports false', () async {
    final urls = <Uri>[];
    final repo = repository([
      http.Response(body(), 200),
      http.Response('boom', 500),
    ], urls);
    await repo.applySetting(enabled: true, storeId: 1);
    expect(await repo.refresh(), isFalse);
    expect(urls, hasLength(2));
    expect(repo.catalog.offers.keys, [9]);
  });

  test(
      'a missing endpoint does not retry automatically and manual sync can recover',
      () async {
    final urls = <Uri>[];
    final repo = repository([
      http.Response('Not found', 404),
      http.Response(body(), 200),
    ], urls);
    await repo.applySetting(enabled: true, storeId: 1);
    await Future<void>.delayed(Duration.zero);
    expect(timers, isEmpty);
    expect(await repo.refresh(), true);
    expect(repo.catalog.offers.keys, [9]);
    repo.dispose();
  });

  test(
      'identical offer sync advances cursor without notifying pricing listeners',
      () async {
    final urls = <Uri>[];
    final repo = repository([
      http.Response(body(), 200),
      http.Response(body(serverTime: '2026-10-06T12:00:00.500Z'), 200),
      http.Response(body(offerIds: [10]), 200),
    ], urls);
    await repo.applySetting(enabled: true, storeId: 1);
    var notifications = 0;
    repo.addListener(() => notifications++);
    expect(await repo.refresh(), true);
    expect(notifications, 0);
    expect(
        repo.catalog.lastSyncedAt, now.add(const Duration(milliseconds: 500)));
    expect(await repo.refresh(), true);
    expect(notifications, 1);
    repo.dispose();
  });

  test('a failed sync is retried with backoff until it succeeds', () async {
    final urls = <Uri>[];
    final repo = repository([
      http.Response(body(), 200),
      http.Response('boom', 500),
      http.Response('boom', 500),
      http.Response('boom', 500),
      http.Response(body(offerIds: [10]), 200),
      http.Response('boom', 500),
    ], urls);
    await repo.applySetting(enabled: true, storeId: 1);
    expect(timers, isEmpty);

    expect(await repo.refresh(), isFalse);
    expect(timers.single.delay, const Duration(seconds: 30));

    timers.last.fire();
    await until(() => timers.length == 2);
    expect(urls, hasLength(3));
    expect(timers.last.delay, const Duration(seconds: 60));

    timers.last.fire();
    await until(() => timers.length == 3);
    expect(timers.last.delay, const Duration(seconds: 120));

    // The retry succeeds: offers update and no further retry is scheduled.
    timers.last.fire();
    await until(() => repo.catalog.offers.containsKey(10));
    expect(urls, hasLength(5));
    expect(timers, hasLength(3));

    // The next failure starts again from the first delay.
    expect(await repo.refresh(), isFalse);
    expect(timers.last.delay, const Duration(seconds: 30));
  });

  test('a successful retry resets backoff before a queued refresh fails',
      () async {
    final cache = _DelayedSaveCache();
    final responses = [
      http.Response(body(), 200),
      http.Response('boom', 500),
      http.Response(body(offerIds: [10]), 200),
      http.Response('boom', 500),
    ];
    var requests = 0;
    final repo = ProductOfferRepository(
      api: ProductOfferApi(
        httpGet: (url, {headers}) async => responses[requests++],
      ),
      cache: cache,
      accessToken: () async => 'token',
      clock: () => now,
      retryTimer: fakeTimer,
    );
    try {
      await repo.applySetting(enabled: true, storeId: 1);
      expect(await repo.refresh(), isFalse);
      expect(timers.single.delay, const Duration(seconds: 30));

      // Hold the successful retry's cache write so a refresh is definitely
      // queued before that successful request finishes.
      cache.delayNextSave = true;
      timers.last.fire();
      await cache.saveStarted.future;
      final queued = repo.refresh();
      cache.releaseSave.complete();
      expect(await queued, isFalse);

      expect(requests, 4);
      expect(repo.catalog.offers.containsKey(10), isTrue);
      expect(timers.map((timer) => timer.delay.inSeconds), [30, 30]);
    } finally {
      repo.dispose();
    }
  });

  test('the retry delay is capped at ten minutes', () async {
    final urls = <Uri>[];
    final repo = repository([
      http.Response(body(), 200),
      for (var i = 0; i < 8; i++) http.Response('boom', 500),
    ], urls);
    await repo.applySetting(enabled: true, storeId: 1);
    expect(await repo.refresh(), isFalse);
    for (var i = 1; i < 7; i++) {
      timers.last.fire();
      await until(() => timers.length == i + 1);
    }
    expect(timers.map((t) => t.delay.inSeconds),
        [30, 60, 120, 240, 480, 600, 600]);
  });

  test('clearing, disabling or switching store cancels a scheduled retry',
      () async {
    Future<ProductOfferRepository> failedOnce() async {
      final repo = repository([
        http.Response(body(), 200),
        http.Response('boom', 500),
      ], <Uri>[]);
      await repo.applySetting(enabled: true, storeId: 1);
      expect(await repo.refresh(), isFalse);
      expect(timers.last.isActive, isTrue);
      return repo;
    }

    await (await failedOnce()).clear();
    expect(timers.last.cancelled, isTrue);

    await (await failedOnce()).applySetting(enabled: false, storeId: 1);
    expect(timers.last.cancelled, isTrue);

    final repo = await failedOnce();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_store_id', 2);
    await repo.loadCached();
    expect(timers.last.cancelled, isTrue);
  });

  test('a full refresh requested during a sync completes after the full run',
      () async {
    final first = Completer<http.Response>();
    final urls = <Uri>[];
    final repo = ProductOfferRepository(
      api: ProductOfferApi(httpGet: (url, {headers}) {
        urls.add(url);
        if (urls.length == 1) return Future.value(http.Response(body(), 200));
        if (urls.length == 2) return first.future;
        return Future.value(http.Response(body(offerIds: [10]), 200));
      }),
      accessToken: () async => 'token',
      clock: () => now,
      retryTimer: fakeTimer,
    );
    await repo.applySetting(enabled: true, storeId: 1);

    final delta = repo.refresh();
    await until(() => urls.length == 2);
    var fullDone = false;
    final full = repo.refresh(full: true).then((synced) {
      fullDone = true;
      return synced;
    });

    first.complete(http.Response(body(offerIds: [9]), 200));
    expect(await delta, isTrue);
    expect(fullDone, isFalse);

    expect(await full, isTrue);
    expect(urls, hasLength(3));
    expect(urls.last.queryParameters.containsKey('since'), isFalse);
    expect(repo.catalog.offers.keys, [10]);
  });

  test('turning POS_OFFERS off stops pricing immediately', () async {
    final urls = <Uri>[];
    final repo = repository([http.Response(body(), 200)], urls);
    await repo.applySetting(enabled: true, storeId: 1);
    await repo.applySetting(enabled: false, storeId: 1);
    expect(repo.catalog.enabled, isFalse);
  });

  test('turning POS_OFFERS off is remembered after a restart', () async {
    final urls = <Uri>[];
    final repo = repository([http.Response(body(), 200)], urls);
    await repo.applySetting(enabled: true, storeId: 1);
    await repo.applySetting(enabled: false, storeId: 1);

    final restarted = repository(const [], <Uri>[]);
    await restarted.loadCached();
    expect(restarted.catalog.enabled, isFalse);
  });

  test('another tenant never loads the cache of a store with the same id',
      () async {
    final urls = <Uri>[];
    final repo = repository([http.Response(body(), 200)], urls);
    await repo.applySetting(enabled: true, storeId: 1);

    // The API key screen changes the tenant without a session reset.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', 'other-tenant');
    await repo.loadCached();
    expect(repo.catalog.enabled, isFalse);
    expect(repo.catalog.offers, isEmpty);

    final restarted = repository(const [], <Uri>[]);
    await restarted.loadCached();
    expect(restarted.catalog.enabled, isFalse);
    expect(restarted.catalog.offers, isEmpty);

    await prefs.setString('api_key', 'tenant');
    await restarted.loadCached();
    expect(restarted.catalog.offers.keys, [9]);
  });

  test('the cache never stores the raw API key', () async {
    final repo = repository([http.Response(body(), 200)], <Uri>[]);
    await repo.applySetting(enabled: true, storeId: 1);
    final stored = Hive.box(ProductOfferCache.boxName)
        .get(ProductOfferCache.keyFor(1)) as Map;
    expect(stored['tenant'], ProductOfferCache.tenantFingerprint('tenant'));
    expect(jsonEncode(stored), isNot(contains('"tenant":"tenant"')));
  });

  test('clear forgets every offer', () async {
    final urls = <Uri>[];
    final repo = repository([http.Response(body(), 200)], urls);
    await repo.applySetting(enabled: true, storeId: 1);
    await repo.clear();
    expect(repo.catalog.offers, isEmpty);
    expect(
      await const ProductOfferCache()
          .load(1, tenant: ProductOfferCache.tenantFingerprint('tenant')),
      isNull,
    );
  });

  test('a settings response after a session reset does not refill the cache',
      () async {
    final urls = <Uri>[];
    final repo = repository([http.Response(body(), 200)], urls);
    await repo.applySetting(enabled: true, storeId: 1);

    // SessionResetService: preferences are cleared, then offers.
    SharedPreferences.setMockInitialValues({'api_key': 'tenant'});
    await repo.clear();
    // The app-settings request started before the reset lands now.
    await repo.applySetting(enabled: true, storeId: 1);

    expect(repo.catalog.enabled, isFalse);
    expect(Hive.box(ProductOfferCache.boxName).isEmpty, isTrue);
    expect(urls, hasLength(1));
  });

  test('changing stores loads its cached switch even without a settings fetch',
      () async {
    final urls = <Uri>[];
    final repo = repository([http.Response(body(), 200)], urls);
    await repo.applySetting(enabled: true, storeId: 1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_store_id', 2);
    await repo.loadCached();
    expect(repo.catalog.storeId, 2);
    expect(repo.catalog.enabled, isFalse);
    expect(repo.catalog.offers, isEmpty);

    await prefs.setInt('active_store_id', 1);
    await repo.loadCached();
    expect(repo.catalog.enabled, isTrue);
    expect(repo.catalog.offers.keys, [9]);
    expect(urls, hasLength(1));
  });

  test('clear invalidates an unfinished cache load', () async {
    final cache = _DelayedCache();
    final repo = ProductOfferRepository(cache: cache);
    final loading = repo.loadCached();
    await cache.requested.future;
    await repo.clear();
    cache.loaded.complete(ProductOfferCatalog(storeId: 1, enabled: true));
    await loading;
    expect(repo.catalog.storeId, isNull);
    expect(repo.catalog.enabled, isFalse);
  });

  test('ignores a response after the active store changes', () async {
    final response = Completer<http.Response>();
    final requested = Completer<void>();
    final repo = ProductOfferRepository(
      api: ProductOfferApi(httpGet: (url, {headers}) {
        requested.complete();
        return response.future;
      }),
      accessToken: () async => 'token',
      clock: () => now,
      retryTimer: fakeTimer,
    );
    final refresh = repo.applySetting(enabled: true, storeId: 1);
    await requested.future;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_store_id', 2);
    response.complete(http.Response(body(), 200));
    await refresh;

    expect(repo.catalog.offers, isEmpty);
    final cached = await const ProductOfferCache()
        .load(1, tenant: ProductOfferCache.tenantFingerprint('tenant'));
    expect(cached!.offers, isEmpty);
  });

  test(
      'an old tenant response cannot overwrite a new tenant with the same store',
      () async {
    final oldResponse = Completer<http.Response>();
    final requested = Completer<void>();
    var requests = 0;
    final repo = ProductOfferRepository(
      api: ProductOfferApi(httpGet: (url, {headers}) {
        requests++;
        if (requests == 1) {
          requested.complete();
          return oldResponse.future;
        }
        return Future.value(http.Response(body(offerIds: [10]), 200));
      }),
      accessToken: () async => 'token',
      clock: () => now,
      retryTimer: fakeTimer,
    );
    final oldRefresh = repo.applySetting(enabled: true, storeId: 1);
    await requested.future;
    await repo.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', 'new-tenant');
    final newRefresh = repo.applySetting(enabled: true, storeId: 1);
    // Resolve the old request while the new session is being initialized.
    await Future<void>.delayed(Duration.zero);
    oldResponse.complete(http.Response(body(), 200));
    await oldRefresh;
    await newRefresh;

    expect(repo.catalog.offers.keys, [10]);
    final cached = await const ProductOfferCache()
        .load(1, tenant: ProductOfferCache.tenantFingerprint('new-tenant'));
    expect(cached!.offers.keys, [10]);
  });

  test('offer validity and receipts share the DateHelper clock', () async {
    // The server is one hour ahead of this device.
    final serverTime = DateTime.now().toUtc().add(const Duration(hours: 1));
    final repo = ProductOfferRepository(
      api: ProductOfferApi(
        httpGet: (url, {headers}) async => http.Response(
          body(serverTime: serverTime.toIso8601String()),
          200,
        ),
      ),
      accessToken: () async => 'token',
      retryTimer: fakeTimer,
    );
    addTearDown(() => DateHelper.setServerTime(DateTime.now()));

    await repo.applySetting(enabled: true, storeId: 1);
    expect(repo.catalog.lastSyncedAt, serverTime);

    final expected = DateTime.now().toUtc().add(const Duration(hours: 1));
    expect(
      DateHelper.now().toUtc().difference(expected).inSeconds.abs(),
      lessThan(5),
    );
    expect(
      repo.trustedNow().difference(DateHelper.now().toUtc()).inSeconds.abs(),
      lessThan(1),
    );
  });

  test('a stale missing endpoint does not suppress the new session retry',
      () async {
    final oldResponse = Completer<http.Response>();
    final newResponse = Completer<http.Response>();
    var requests = 0;
    final repo = ProductOfferRepository(
      api: ProductOfferApi(httpGet: (url, {headers}) {
        requests++;
        return requests == 1 ? oldResponse.future : newResponse.future;
      }),
      accessToken: () async => 'token',
      clock: () => now,
      retryTimer: fakeTimer,
    );
    final oldRefresh = repo.applySetting(enabled: true, storeId: 1);
    await until(() => requests == 1);
    await repo.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', 'new-tenant');
    final newRefresh = repo.applySetting(enabled: true, storeId: 1);
    await until(() => requests == 2);

    oldResponse.complete(http.Response('{}', 404));
    await oldRefresh;
    newResponse.complete(http.Response('{}', 500));
    await newRefresh;
    await until(() => timers.isNotEmpty);
    expect(timers.single.delay, ProductOfferRepository.firstRetryDelay);
    repo.dispose();
  });
}
