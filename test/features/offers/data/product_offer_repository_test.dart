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
import 'package:shared_preferences/shared_preferences.dart';

import '../../../test_support/hive_test_teardown.dart';

class _DelayedCache extends ProductOfferCache {
  final loaded = Completer<ProductOfferCatalog?>();
  final requested = Completer<void>();

  @override
  Future<ProductOfferCatalog?> load(int? storeId) {
    requested.complete();
    return loaded.future;
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

  String body({List<int> offerIds = const [9], List<int> removed = const []}) =>
      jsonEncode({
        'success': true,
        'server_time': '2026-10-06T12:00:00Z',
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

  ProductOfferRepository repository(
    List<http.Response> responses,
    List<Uri> urls,
  ) {
    return ProductOfferRepository(
      api: ProductOfferApi(
        httpGet: (url, {Map<String, String>? headers}) async {
          urls.add(url);
          return responses[urls.length - 1];
        },
      ),
      accessToken: () async => 'token',
      clock: () => now,
    );
  }

  test('does not sync while POS_OFFERS is off', () async {
    final urls = <Uri>[];
    final repo = repository([http.Response(body(), 200)], urls);
    await repo.loadCached();
    await repo.refresh();
    expect(urls, isEmpty);
    expect(repo.catalog.enabled, isFalse);
  });

  test('turning POS_OFFERS on downloads offers, then syncs deltas', () async {
    final urls = <Uri>[];
    final repo = repository([
      http.Response(body(), 200),
      http.Response(body(offerIds: [], removed: [9]), 200),
    ], urls);

    await repo.applySetting(enabled: true, storeId: 1);
    expect(urls.first.queryParameters.containsKey('since'), isFalse);
    expect(repo.catalog.offers.keys, [9]);

    await repo.refresh();
    expect(urls.last.queryParameters['since'], '2026-10-06T12:00:00.000Z');
    expect(repo.catalog.offers, isEmpty);
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

  test('a failed sync keeps the cached offers', () async {
    final urls = <Uri>[];
    final repo = repository([
      http.Response(body(), 200),
      http.Response('boom', 500),
    ], urls);
    await repo.applySetting(enabled: true, storeId: 1);
    await repo.refresh();
    expect(urls, hasLength(2));
    expect(repo.catalog.offers.keys, [9]);
  });

  test('turning POS_OFFERS off stops pricing immediately', () async {
    final urls = <Uri>[];
    final repo = repository([http.Response(body(), 200)], urls);
    await repo.applySetting(enabled: true, storeId: 1);
    await repo.applySetting(enabled: false, storeId: 1);
    expect(repo.catalog.enabled, isFalse);
  });

  test('clear forgets every offer', () async {
    final urls = <Uri>[];
    final repo = repository([http.Response(body(), 200)], urls);
    await repo.applySetting(enabled: true, storeId: 1);
    await repo.clear();
    expect(repo.catalog.offers, isEmpty);
    expect(await const ProductOfferCache().load(1), isNull);
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
    );
    final refresh = repo.applySetting(enabled: true, storeId: 1);
    await requested.future;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_store_id', 2);
    response.complete(http.Response(body(), 200));
    await refresh;

    expect(repo.catalog.offers, isEmpty);
    expect((await const ProductOfferCache().load(1))!.offers, isEmpty);
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
    expect((await const ProductOfferCache().load(1))!.offers.keys, [10]);
  });
}
