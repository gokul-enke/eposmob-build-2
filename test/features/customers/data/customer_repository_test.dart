import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/features/customers/data/customer_api.dart';
import 'package:pos_machine/features/customers/data/customer_cache.dart';
import 'package:pos_machine/features/customers/data/customer_payloads.dart';
import 'package:pos_machine/features/customers/data/customer_repository.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';

import '../support/customer_test_doubles.dart';

void main() {
  late Directory hiveDirectory;
  var nextStoreId = 500;
  late int storeId;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('customer-repo-');
    Hive.init(hiveDirectory.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  setUp(() => storeId = nextStoreId++);

  CustomerRepository repository({
    String? apiKey = 'k',
    Future<http.Response> Function(Uri url)? get,
    Future<http.Response> Function(Uri url, Object? body)? post,
  }) {
    return CustomerRepository(
      api: CustomerApi(
        httpGet: (url, {headers}) =>
            get?.call(url) ??
            Future.value(jsonResponse(customersPage(const []))),
        httpPost: (url, {headers, body}) =>
            post?.call(url, body) ?? Future.value(jsonResponse({})),
        session: FakeTenantSession(key: apiKey, storeId: storeId),
      ),
    );
  }

  Future<void> seedCache(List<CustomerListModelData> customers) =>
      const CustomerCache().save(storeId, customers);

  group('list (full directory)', () {
    test('loads from the server and refreshes the cache', () async {
      final repo = repository(
        get: (_) async => jsonResponse(customersPage([
          {'id': 1, 'name': 'Ann'},
        ])),
      );

      final result = await repo.list('t', const CustomerQuery(loadAll: true));

      expect(result, isA<CustomerDirectoryLoaded>());
      final loaded = result as CustomerDirectoryLoaded;
      expect(loaded.fromCache, isFalse);
      expect(loaded.customers.single.name, 'Ann');
      expect((await const CustomerCache().load(storeId))!.single.id, 1);
    });

    test('falls back to the cache when the server fails', () async {
      await seedCache([CustomerListModelData(id: 7, name: 'Cached')]);
      final repo = repository(get: (_) async => http.Response('', 500));

      final result = await repo.list('t', const CustomerQuery(loadAll: true));

      expect((result as CustomerDirectoryLoaded).fromCache, isTrue);
      expect(result.customers.single.name, 'Cached');
      expect(result.legacyResponse['message'], CustomerRepository.cacheMessage);
    });

    test('uses the cache when no API key is stored', () async {
      await seedCache([CustomerListModelData(id: 8)]);
      final result = await repository(apiKey: null)
          .list('t', const CustomerQuery(loadAll: true));
      expect((result as CustomerDirectoryLoaded).fromCache, isTrue);
    });

    test('fails with the legacy messages when nothing is available', () async {
      final noKey = await repository(apiKey: null)
          .list('t', const CustomerQuery(loadAll: true));
      expect(noKey.legacyResponse, {
        'status': 'error',
        'message': CustomerApi.missingApiKeyMessage,
      });

      final offline = await repository(
              get: (_) async => throw const SocketException('down'))
          .list('t', const CustomerQuery(loadAll: true));
      expect(offline, isA<CustomerListFailed>());
      expect(offline.legacyResponse['message'], startsWith('Error: '));
    });
  });

  group('list (single page)', () {
    test('passes the server filters and never touches the cache', () async {
      Uri? requested;
      final repo = repository(get: (url) async {
        requested = url;
        return jsonResponse(customersPage([
          {'id': 2},
        ]));
      });

      final result = await repo.list(
        't',
        const CustomerQuery(
            name: 'an', phone: '5', page: 3, sortAscending: true),
      );

      expect(result, isA<CustomerPageLoaded>());
      expect(requested!.queryParameters, {
        'page': '3',
        'sort_asc': 'true',
        'filter_name': 'an',
        'filter_phone': '5',
        'store_id': '$storeId',
      });
      expect(await const CustomerCache().load(storeId), isNull);
    });
  });

  group('snapshot', () {
    test('is sorted by display label', () async {
      final repo = repository(
        get: (_) async => jsonResponse(customersPage([
          {'id': 1, 'name': 'zed'},
          {'id': 2, 'name': 'Amy'},
        ])),
      );
      final names = (await repo.snapshot('t')).map((c) => c.name);
      expect(names, ['Amy', 'zed']);
    });

    test('falls back to the cache, and throws when it is empty', () async {
      final failing = repository(get: (_) async => http.Response('', 500));
      await expectLater(failing.snapshot('t'), throwsA(isA<HttpException>()));

      await seedCache([CustomerListModelData(id: 3, name: 'Offline')]);
      expect((await failing.snapshot('t')).single.name, 'Offline');
    });
  });

  test('create and update build the payloads', () async {
    final bodies = <String>[];
    final repo = repository(post: (url, body) async {
      bodies.add(body! as String);
      return jsonResponse({'status': 'success'});
    });

    await repo.create('t', const CustomerFields(name: 'Ann'), storeId: '4');
    await repo.update('t', 9, const CustomerFields(email: 'a@b.c'));

    expect(bodies[0], contains('"store_id":"4"'));
    expect(bodies[1], '{"customer_id":9,"email":"a@b.c"}');
  });

  test('fetchById parses the customer only on success', () async {
    var payload = <String, dynamic>{
      'status': 'success',
      'data': {'id': 5, 'name': 'Ann'},
    };
    final repo = repository(get: (_) async => jsonResponse(payload));

    expect((await repo.fetchById('t', 5)).customer?.name, 'Ann');

    payload = {'status': 'error'};
    expect((await repo.fetchById('t', 5)).customer, isNull);
  });
}
