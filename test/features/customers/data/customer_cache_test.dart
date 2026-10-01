import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/features/customers/data/customer_cache.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';

void main() {
  late Directory hiveDirectory;
  const cache = CustomerCache();

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('customer-cache-');
    Hive.init(hiveDirectory.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('keys are per store', () {
    expect(CustomerCache.keyFor(3), 'store_3');
    expect(CustomerCache.keyFor(null), 'store_unknown');
  });

  test('saves and loads customers per store', () async {
    await cache.save(1, [CustomerListModelData(id: 1, name: 'One')]);
    await cache.save(2, [CustomerListModelData(id: 2, name: 'Two')]);

    expect((await cache.load(1))!.single.name, 'One');
    expect((await cache.load(2))!.single.name, 'Two');
    expect(await cache.load(3), isNull);
  });

  test('clear removes only that store', () async {
    await cache.save(10, [CustomerListModelData(id: 1)]);
    await cache.save(11, [CustomerListModelData(id: 2)]);

    await cache.clear(10);

    expect(await cache.load(10), isNull);
    expect(await cache.load(11), isNotNull);
  });

  test('unreadable entries load as null', () async {
    final box = await Hive.openBox(CustomerCache.boxName);
    await box.put(CustomerCache.keyFor(20), 'garbage');
    await box.put(CustomerCache.keyFor(21), {'data': 'not a list'});
    await box.put(CustomerCache.keyFor(22), {
      'data': ['not a map'],
    });

    expect(await cache.load(20), isNull);
    expect(await cache.load(21), isNull);
    expect(await cache.load(22), isNull);
  });
}
