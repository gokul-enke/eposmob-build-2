// Synthetic disk reopen/hydration probe, not a device-reboot benchmark.
// Run with: flutter test --no-pub test/hive_startup_probe_test.dart -r expanded
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support/hive_test_teardown.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reopen and hydrate a synthetic 30000-product catalog', () async {
    final directory = await Directory.systemTemp.createTemp('cloudpos_probe_');
    addTearDown(() => closeHiveAndDeleteTestDir(directory));
    Hive.init(directory.path);
    Hive.registerAdapter(HiveStringValueAdapter());
    Hive.registerAdapter(HiveProductAdapter());
    Hive.registerAdapter(HiveLocalCartItemAdapter());
    Hive.registerAdapter(HiveSavedOrderAdapter());
    SharedPreferences.setMockInitialValues({'general_stock_enabled': false});

    var products = await Hive.openBox<HiveProduct>('products');
    const count = 30000;
    for (var offset = 0; offset < count; offset += 300) {
      final rows = <int, HiveProduct>{};
      for (var id = offset; id < offset + 300; id++) {
        final product = GetProduct(
          productId: id,
          productName: 'Synthetic product $id',
          barcode: 'PROBE-$id',
          price: ProductPrice(price: '10'),
          mrp: '12',
          unit: 'PCS',
          stock: [
            Stock(
                id: id + 1,
                productId: id,
                quantity: 10,
                price: '10',
                mrp: '12'),
          ],
          taxes: const <ProductTax>[],
        );
        rows[id] = HiveProduct(
          productId: id,
          productName: product.productName,
          barcode: product.barcode,
          serializedData: HiveStringValue(jsonEncode(product.toJson())),
        );
      }
      await products.putAll(rows);
    }
    final bytes = await File(products.path!).length();
    await products.close();
    final clock = Stopwatch()..start();
    products = await Hive.openBox<HiveProduct>('products');
    final openMs = clock.elapsedMilliseconds;
    expect(products.length, count);
    await Hive.openBox<HiveLocalCartItem>('cart_items');
    await Hive.openBox<HiveSavedOrder>('saved_orders');
    await Hive.openBox<HiveSavedOrder>('confirmed_orders');
    clock.reset();
    final provider = LocalProductProvider();
    addTearDown(provider.dispose);
    await provider.hydrated;
    final hydrateMs = clock.elapsedMilliseconds;
    expect(provider.products.length, count);
    // Measurements describe only this test process and these synthetic rows.
    // The OS file cache is warm because this process just wrote the file.
    debugPrint('STARTUP_PROBE products=$count bytes=$bytes '
        'reopen_ms=$openMs hydrate_ms=$hydrateMs');
  });
}
