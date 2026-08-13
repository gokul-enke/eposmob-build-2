/// P-05 — variant cart identity: different variants must not merge; same variant merges.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/helpers/cart_quantity_stock_helper.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support/hive_test_teardown.dart';

GetProduct _variantProduct() {
  return GetProduct(
    productId: 1,
    productName: 'T-Shirt',
    price: ProductPrice(price: '299'),
    mrp: '499',
    unit: 'PCS',
    stock: const <Stock>[],
    taxes: const <ProductTax>[],
    variants: [
      ProductVariant(
        id: 10,
        price: 349,
        attributes: const {'COLOR': 'Red', 'SIZE': 'L'},
      ),
      ProductVariant(
        id: 20,
        price: 359,
        attributes: const {'COLOR': 'Blue', 'SIZE': 'M'},
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_variant_cart_test_');
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
    await awaitPendingHiveBoxWrites();
    SharedPreferences.setMockInitialValues({});
    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
  });

  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

  group('P-05 variant cart merge keys', () {
    test('different variants create separate cart lines', () {
      final provider = LocalProductProvider()..setStockEnabled(false);
      final product = _variantProduct();
      provider.addProduct(product);

      provider.addToCart(
        product: product,
        quantity: 1,
        price: 349,
        variantId: 10,
        variantAttributes: const {'COLOR': 'Red', 'SIZE': 'L'},
      );
      provider.addToCart(
        product: product,
        quantity: 1,
        price: 359,
        variantId: 20,
        variantAttributes: const {'COLOR': 'Blue', 'SIZE': 'M'},
      );

      expect(provider.cartItems, hasLength(2));
      expect(
        provider.cartItems.map((item) => item.variantId).toSet(),
        {10, 20},
      );
      expect(
        provider.cartItems.any((item) => item.displayName.contains('Red')),
        isTrue,
      );
      expect(
        provider.cartItems.any((item) => item.displayName.contains('Blue')),
        isTrue,
      );
    });

    test('same variant merges quantity onto one line', () {
      final provider = LocalProductProvider()..setStockEnabled(false);
      final product = _variantProduct();
      provider.addProduct(product);

      provider.addToCart(
        product: product,
        quantity: 1,
        price: 349,
        variantId: 10,
        variantAttributes: const {'COLOR': 'Red', 'SIZE': 'L'},
      );
      provider.addToCart(
        product: product,
        quantity: 2,
        price: 349,
        variantId: 10,
        variantAttributes: const {'COLOR': 'Red', 'SIZE': 'L'},
      );

      expect(provider.cartItems, hasLength(1));
      expect(provider.cartItems.single.variantId, 10);
      expect(provider.cartItems.single.quantity, 3);
      expect(provider.cartItems.single.price, 349);
    });

    test('order payload carries distinct product_variant_id per line', () {
      final provider = LocalProductProvider()..setStockEnabled(false);
      final product = _variantProduct();
      provider.addProduct(product);

      provider.addToCart(
        product: product,
        quantity: 1,
        price: 349,
        variantId: 10,
        variantAttributes: const {'COLOR': 'Red'},
      );
      provider.addToCart(
        product: product,
        quantity: 1,
        price: 359,
        variantId: 20,
        variantAttributes: const {'COLOR': 'Blue'},
      );

      final payload = provider.buildOrderItemsPayload();
      expect(payload, hasLength(2));
      expect(
        payload.map((row) => row['product_variant_id']).toList(),
        containsAll([10, 20]),
      );
    });

    test('variant mutation APIs target the selected variant line', () {
      final provider = LocalProductProvider()..setStockEnabled(false);
      final product = _variantProduct();
      provider.addProduct(product);

      provider.addToCart(
        product: product,
        quantity: 2,
        price: 349,
        variantId: 10,
        variantAttributes: const {'COLOR': 'Red'},
      );
      provider.addToCart(
        product: product,
        quantity: 3,
        price: 359,
        variantId: 20,
        variantAttributes: const {'COLOR': 'Blue'},
      );

      provider.updateItemPrice(1, null, 300, variantId: 10);
      provider.updateItemMrp(1, null, 450, variantId: 20);
      provider.updateItemTax(1, null, 12, variantId: 10);

      final red = provider.cartItems.firstWhere((item) => item.variantId == 10);
      final blue =
          provider.cartItems.firstWhere((item) => item.variantId == 20);
      expect(red.price, 300);
      expect(red.taxRate, 12);
      expect(blue.price, 359);
      expect(blue.mrp, 450);

      provider.removeFromCart(1, null, variantId: 10);

      expect(provider.cartItems, hasLength(1));
      expect(provider.cartItems.single.variantId, 20);
    });

    test('quantity helper can reduce and remove variant cart lines', () async {
      final provider = LocalProductProvider()..setStockEnabled(false);
      final product = _variantProduct();
      provider.addProduct(product);

      provider.addToCart(
        product: product,
        quantity: 4,
        price: 349,
        variantId: 10,
        variantAttributes: const {'COLOR': 'Red'},
      );

      await CartQuantityStockHelper.syncCartItemQuantity(
        cartItem: provider.cartItems.single,
        newQuantity: 2,
        localProductProvider: provider,
      );

      expect(provider.cartItems.single.quantity, 2);
      expect(provider.cartItems.single.variantId, 10);
      expect(provider.cartItems.single.price, 349);

      await CartQuantityStockHelper.syncCartItemQuantity(
        cartItem: provider.cartItems.single,
        newQuantity: 0,
        localProductProvider: provider,
      );

      expect(provider.cartItems, isEmpty);
    });

    test('addToCart rejects non-positive quantities at provider boundary', () {
      final provider = LocalProductProvider()..setStockEnabled(false);
      final product = _variantProduct();
      provider.addProduct(product);

      provider.addToCart(product: product, quantity: 0, price: 349);
      provider.addToCart(product: product, quantity: -2, price: 349);

      expect(provider.cartItems, isEmpty);
    });
  });
}
