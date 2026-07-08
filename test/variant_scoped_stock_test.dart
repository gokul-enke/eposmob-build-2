import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support/hive_test_teardown.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_variant_stock_test_');
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
    SharedPreferences.setMockInitialValues({
      'general_stock_enabled': true,
      'api_key': 'test-api-key',
    });

    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
  });

  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

  Stock buildStock({
    required int id,
    required num quantity,
    int? productVariantId,
    String price = '10',
    String mrp = '12',
  }) {
    return Stock(
      id: id,
      productId: 1,
      productVariantId: productVariantId,
      storeId: 1,
      storeName: 'Main Store',
      quantity: quantity,
      price: price,
      mrp: mrp,
      purchasePrice: '8',
      taxRate: '5',
      unit: 'PCS',
      hsnCode: 'HSN-1',
    );
  }

  GetProduct buildProduct({
    required List<Stock> stocks,
    List<ProductVariant>? variants,
  }) {
    return GetProduct(
      productId: 1,
      productName: 'Product 1',
      price: ProductPrice(price: '10'),
      mrp: '12',
      purchasePrice: '8',
      unit: 'PCS',
      stock: stocks,
      variants: variants,
      taxes: const <ProductTax>[],
    );
  }

  test('Stock.fromJson parses product_variant_id (int and string)', () {
    final fromInt = Stock.fromJson(<String, dynamic>{
      'id': 5,
      'product_id': 1,
      'product_variant_id': 41,
      'quantity': 3,
    });
    expect(fromInt.productVariantId, 41);

    final fromString = Stock.fromJson(<String, dynamic>{
      'id': 6,
      'product_id': 1,
      'product_variant_id': '42',
      'quantity': 3,
    });
    expect(fromString.productVariantId, 42);

    final general = Stock.fromJson(<String, dynamic>{
      'id': 7,
      'product_id': 1,
      'quantity': 3,
    });
    expect(general.productVariantId, isNull);
  });

  test('Stock.toJson and copyWith carry product_variant_id', () {
    final stock = buildStock(id: 1, quantity: 3, productVariantId: 41);
    expect(stock.toJson()['product_variant_id'], 41);
    expect(stock.copyWith().productVariantId, 41);
    expect(stock.copyWith(productVariantId: 99).productVariantId, 99);
  });

  test('variant-scoped filtering picks only matching variant stocks', () {
    final scopedA = buildStock(id: 1, quantity: 5, productVariantId: 41);
    final scopedB = buildStock(id: 2, quantity: 5, productVariantId: 42);
    final general = buildStock(id: 3, quantity: 5);

    final result = LocalProductProvider.filterStocksForVariant(
      <Stock>[scopedA, scopedB, general],
      41,
    );

    expect(result.map((s) => s.id).toList(), <int>[1]);
  });

  test('falls back to general stock when variant has no scoped rows', () {
    final scopedA = buildStock(id: 1, quantity: 5, productVariantId: 41);
    final general = buildStock(id: 3, quantity: 5);

    final result = LocalProductProvider.filterStocksForVariant(
      <Stock>[scopedA, general],
      99, // no scoped rows for this variant
    );

    expect(result.map((s) => s.id).toList(), <int>[3]);
  });

  test('null variant returns the stock list unchanged', () {
    final scopedA = buildStock(id: 1, quantity: 5, productVariantId: 41);
    final general = buildStock(id: 3, quantity: 5);
    final input = <Stock>[scopedA, general];

    final result = LocalProductProvider.filterStocksForVariant(input, null);

    expect(identical(result, input), isTrue);
  });

  test('reservation for a variant draws only from that variant stock', () {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);

    final scoped41 = buildStock(id: 1, quantity: 5, productVariantId: 41);
    final scoped42 = buildStock(id: 2, quantity: 5, productVariantId: 42);
    final variant41 = ProductVariant(id: 41, quantity: 5, attributes: {'COLOR': 'Red'});
    final variant42 = ProductVariant(id: 42, quantity: 5, attributes: {'COLOR': 'Blue'});
    final product = buildProduct(
      stocks: <Stock>[scoped41, scoped42],
      variants: <ProductVariant>[variant41, variant42],
    );

    provider.initializeProducts(<GetProduct>[product]);

    provider.addToCart(
      product: product,
      quantity: 2,
      selectedStock: scoped41,
      variantId: 41,
      variantAttributes: const {'COLOR': 'Red'},
    );

    final updated = provider.getProductById(1)!;
    // Only variant 41's stock row was drained.
    expect(updated.stock!.firstWhere((s) => s.id == 1).quantity, 3);
    expect(updated.stock!.firstWhere((s) => s.id == 2).quantity, 5);
    // Cached variant quantity decremented for the picker freshness.
    expect(updated.variants!.firstWhere((v) => v.id == 41).quantity, 3);
    expect(updated.variants!.firstWhere((v) => v.id == 42).quantity, 5);
  });

  test('getAvailableQuantityForSelection is variant-scoped', () {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);

    final scoped41 = buildStock(id: 1, quantity: 5, productVariantId: 41);
    final general = buildStock(id: 2, quantity: 7);
    final product = buildProduct(stocks: <Stock>[scoped41, general]);

    provider.initializeProducts(<GetProduct>[product]);

    final scopedQty = provider.getAvailableQuantityForSelection(
      product: product,
      selectedStock: scoped41,
      variantId: 41,
    );
    expect(scopedQty, 5);
  });

  test('null-variant reservation behavior is unchanged', () {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);

    final general = buildStock(id: 1, quantity: 5);
    final product = buildProduct(stocks: <Stock>[general]);

    provider.initializeProducts(<GetProduct>[product]);

    provider.addToCart(
      product: product,
      quantity: 2,
      selectedStock: general,
    );

    final updated = provider.getProductById(1)!;
    expect(updated.stock!.first.quantity, 3);
    expect(provider.cartItems.first.variantId, isNull);
  });

  test('variant quantity restores when cart quantity is reduced', () {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);

    final scoped41 = buildStock(id: 1, quantity: 5, productVariantId: 41);
    final variant41 = ProductVariant(id: 41, quantity: 5, attributes: {'COLOR': 'Red'});
    final product = buildProduct(
      stocks: <Stock>[scoped41],
      variants: <ProductVariant>[variant41],
    );

    provider.initializeProducts(<GetProduct>[product]);

    provider.addToCart(
      product: product,
      quantity: 3,
      selectedStock: scoped41,
      variantId: 41,
      variantAttributes: const {'COLOR': 'Red'},
    );
    expect(provider.getProductById(1)!.variants!.first.quantity, 2);

    provider.setCartItemQuantity(1, scoped41, 1, variantId: 41);

    final updated = provider.getProductById(1)!;
    // Restored 2 units back to the variant (5 - 1 sold = 4).
    expect(updated.variants!.first.quantity, 4);
    expect(updated.stock!.first.quantity, 4);
  });
}
