import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_add_product_test_');
    Hive.init(hiveDir.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HiveStringValueAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(HiveLocalCartItemAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(HiveSavedOrderAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(HiveProductAdapter());
    }

    await Hive.openBox<HiveProduct>('products');
    await Hive.openBox<HiveLocalCartItem>('cart_items');
    await Hive.openBox<HiveSavedOrder>('saved_orders');
    await Hive.openBox<HiveSavedOrder>('confirmed_orders');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  GetProduct makeProduct({
    required int id,
    required String barcode,
    String name = 'Test Product',
    String price = '100',
  }) {
    return GetProduct(
      productId: id,
      productName: name,
      barcode: barcode,
      price: ProductPrice(price: price),
      mrp: '120',
      purchasePrice: '80',
      unit: 'PCS',
      stock: const <Stock>[],
      taxes: const <ProductTax>[],
    );
  }

  // ── Core contract: addProduct() makes product findable immediately ──────────

  test('addProduct makes product findable by ID via getProductById', () {
    final provider = LocalProductProvider();
    final product = makeProduct(id: 1, barcode: 'BC-001');

    provider.addProduct(product);

    expect(provider.getProductById(1), isNotNull);
    expect(provider.getProductById(1)!.productName, 'Test Product');
  });

  test('addProduct makes product findable by barcode via filterProductByBarcode', () {
    final provider = LocalProductProvider();
    final product = makeProduct(id: 2, barcode: 'BC-002');

    provider.addProduct(product);

    final matches = provider.filterProductByBarcode(barCode: 'BC-002');
    expect(matches, hasLength(1));
    expect(matches.first.productId, 2);
  });

  test('addProduct increases products list length by one', () {
    final provider = LocalProductProvider();
    provider.initializeProducts([makeProduct(id: 1, barcode: 'BC-001')]);
    final countBefore = provider.products.length;

    provider.addProduct(makeProduct(id: 2, barcode: 'BC-002'));

    expect(provider.products.length, countBefore + 1);
  });

  // ── Duplicate barcode detection works after addProduct ─────────────────────

  test('filterProductByBarcode returns existing product after addProduct — '
      'duplicate check in AddProductWithBarcodeModal will fire', () {
    final provider = LocalProductProvider();
    provider.addProduct(makeProduct(id: 1, barcode: 'BC-DUP'));

    // Simulates the duplicate-check logic in the modal
    final duplicates = provider.filterProductByBarcode(barCode: 'BC-DUP');
    expect(duplicates, isNotEmpty);
  });

  test('filterProductByBarcode returns empty for unknown barcode', () {
    final provider = LocalProductProvider();
    provider.addProduct(makeProduct(id: 1, barcode: 'BC-001'));

    final matches = provider.filterProductByBarcode(barCode: 'BC-UNKNOWN');
    expect(matches, isEmpty);
  });

  // ── addProduct does NOT duplicate if called twice with same product ─────────

  test('addProduct with same productId does not add a duplicate entry', () {
    final provider = LocalProductProvider();
    final product = makeProduct(id: 1, barcode: 'BC-001');

    provider.addProduct(product);
    provider.addProduct(product);

    final matches = provider.products.where((p) => p.productId == 1).toList();
    // Should have exactly one entry regardless of how many times addProduct is called
    expect(matches.length, lessThanOrEqualTo(1),
        reason: 'addProduct must not create duplicates for the same productId');
  });

  // ── Stock screen autofill: product created → findable via products list ─────

  test('product added via addProduct is immediately in products (master list)', () {
    final provider = LocalProductProvider();
    final product = makeProduct(id: 5, barcode: 'BC-005', name: 'Newly Created');

    provider.addProduct(product);

    final found = provider.products.any((p) => p.productId == 5);
    expect(found, isTrue);
  });

  test('addProduct immediately appears in sellableFilteredProducts', () {
    final provider = LocalProductProvider();
    final product = makeProduct(id: 6, barcode: 'BC-006', name: 'Newly Created 2');

    provider.addProduct(product);

    final inFiltered = provider.sellableFilteredProducts.any((p) => p.productId == 6);
    expect(inFiltered, isTrue,
        reason: 'Newly created product must appear in sellableFilteredProducts '
            'immediately so the sidebar grid and stock screen show it without '
            'a manual refreshProducts call');
  });

  test('addProduct on existing product updates it in sellableFilteredProducts', () {
    final provider = LocalProductProvider();
    provider.addProduct(makeProduct(id: 7, barcode: 'BC-007', name: 'Old Name'));

    provider.addProduct(makeProduct(id: 7, barcode: 'BC-007', name: 'Updated Name'));

    final matches =
        provider.sellableFilteredProducts.where((p) => p.productId == 7).toList();
    expect(matches, hasLength(1));
    expect(matches.first.productName, 'Updated Name');
  });
}
