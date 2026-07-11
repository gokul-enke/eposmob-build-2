/// P-05 slice 2 — variant cart lines survive Hive persistence and saved-draft reload.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support/hive_test_teardown.dart';

GetProduct _variantProduct() {
  return GetProduct(
    productId: 501,
    productName: 'Variant Tee',
    price: ProductPrice(price: '299'),
    mrp: '499',
    unit: 'PCS',
    variants: [
      ProductVariant(
        id: 45,
        price: 349,
        attributes: const {'COLOR': 'Red', 'SIZE': 'L'},
        quantity: 8,
      ),
      ProductVariant(
        id: 46,
        price: 359,
        attributes: const {'COLOR': 'Blue', 'SIZE': 'M'},
        quantity: 3,
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_variant_rehyd_');
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
    SharedPreferences.setMockInitialValues({'general_stock_enabled': false});
    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
  });

  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

  group('variant cart rehydration', () {
    test('active cart survives provider restart via Hive fields 16–17',
        () async {
      final product = _variantProduct();
      final writer = LocalProductProvider();
      writer.setStockEnabled(false);
      writer.initializeProducts([product]);
      writer.addToCart(
        product: product,
        quantity: 2,
        price: 349,
        mrp: 499,
        variantId: 45,
        variantAttributes: const {'COLOR': 'Red', 'SIZE': 'L'},
      );
      await writer.flushPersistence();

      expect(Hive.box<HiveLocalCartItem>('cart_items').length, 1);
      final hiveRow = Hive.box<HiveLocalCartItem>('cart_items').values.first;
      expect(hiveRow.variantId, 45);
      expect(
        hiveRow.serializedVariantAttributes?.value,
        contains('Red'),
      );

      // Simulate app restart — new provider reads the same Hive boxes.
      final reader = LocalProductProvider();
      expect(reader.cartItems.length, 1);

      final item = reader.cartItems.first;
      expect(item.variantId, 45);
      expect(item.variantAttributes, const {'COLOR': 'Red', 'SIZE': 'L'});
      expect(item.displayName, 'Variant Tee (Red | L)');
      expect(item.quantity, 2);
      expect(item.price, 349);
    });

    test('saved draft reload preserves variant identity and display name',
        () async {
      final product = _variantProduct();
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      provider.initializeProducts([product]);
      provider.addToCart(
        product: product,
        quantity: 3,
        price: 359,
        mrp: 499,
        variantId: 46,
        variantAttributes: const {'COLOR': 'Blue', 'SIZE': 'M'},
      );

      final saved = provider.saveCurrentCartAsOrder(status: 'saved');
      expect(saved.items.first.variantId, 46);
      expect(
        saved.items.first.variantAttributes,
        const {'COLOR': 'Blue', 'SIZE': 'M'},
      );

      provider.clearCart();
      await provider.flushPersistence();
      expect(provider.cartItems, isEmpty);

      // Reload from Hive-backed saved orders list.
      final reloaded = LocalProductProvider();
      reloaded.loadOrderForEditing(saved.id);

      expect(reloaded.cartItems.length, 1);
      final cartItem = reloaded.cartItems.first;
      expect(cartItem.variantId, 46);
      expect(
        cartItem.variantAttributes,
        const {'COLOR': 'Blue', 'SIZE': 'M'},
      );
      expect(cartItem.displayName, 'Variant Tee (Blue | M)');
      expect(cartItem.quantity, 3);

      // Hive round-trip for saved order items.
      final hiveOrder = Hive.box<HiveSavedOrder>('saved_orders').values.first;
      expect(hiveOrder.items.first.variantId, 46);
      expect(
        hiveOrder.items.first.serializedVariantAttributes?.value,
        contains('Blue'),
      );
    });

    test('two variant lines on same product stay separate after reload',
        () async {
      final product = _variantProduct();
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      provider.initializeProducts([product]);

      provider.addToCart(
        product: product,
        quantity: 1,
        price: 349,
        variantId: 45,
        variantAttributes: const {'COLOR': 'Red', 'SIZE': 'L'},
      );
      provider.addToCart(
        product: product,
        quantity: 2,
        price: 359,
        variantId: 46,
        variantAttributes: const {'COLOR': 'Blue', 'SIZE': 'M'},
      );

      final saved = provider.saveCurrentCartAsOrder(status: 'saved');
      provider.clearCart();
      await provider.flushPersistence();

      final reloaded = LocalProductProvider();
      reloaded.loadOrderForEditing(saved.id);

      expect(reloaded.cartItems.length, 2);
      expect(
        reloaded.cartItems.map((item) => item.variantId).toSet(),
        {45, 46},
      );
    });

    test('rapid mutations persist one keyed line with exact quantity',
        () async {
      final product = _variantProduct();
      final writer = LocalProductProvider();
      writer.setStockEnabled(false);
      writer.initializeProducts([product]);

      for (var index = 0; index < 100; index++) {
        expect(
          writer.addToCart(
            product: product,
            quantity: 1,
            variantId: 45,
            variantAttributes: const {'COLOR': 'Red', 'SIZE': 'L'},
          ),
          isTrue,
        );
      }
      final lineId = writer.cartItems.single.lineId;
      await writer.flushPersistence();

      final box = Hive.box<HiveLocalCartItem>('cart_items');
      expect(box.length, 1);
      expect(box.keys.single, lineId);
      expect(box.values.single.lineId, lineId);

      final reader = LocalProductProvider();
      expect(reader.cartItems.single.quantity, 100);
      expect(reader.cartItems.single.lineId, lineId);
    });

    test('legacy integer cart key migrates to stable line id', () async {
      final product = _variantProduct();
      final box = Hive.box<HiveLocalCartItem>('cart_items');
      await box.put(
        0,
        HiveLocalCartItem(
          productId: product.productId!,
          quantity: 1,
          // Integer key plus null lineId represents the legacy schema.
          serializedProduct: HiveStringValue(jsonEncode(product.toJson())),
        ),
      );

      final provider = LocalProductProvider();
      expect(provider.cartItems, hasLength(1));
      final generatedLineId = provider.cartItems.single.lineId;
      provider.setStockEnabled(false);
      provider.setCartItemQuantity(501, null, 2);
      await provider.flushPersistence();

      expect(box.length, 1);
      expect(box.keys.single, generatedLineId);
      expect(box.keys.single, isA<String>());
      expect(box.values.single.lineId, generatedLineId);
    });

    test('one corrupt Hive row does not hide valid cart lines', () async {
      final product = _variantProduct();
      final validWriter = LocalProductProvider();
      validWriter.setStockEnabled(false);
      validWriter.initializeProducts([product]);
      validWriter.addToCart(
        product: product,
        quantity: 2,
        variantId: 45,
        variantAttributes: const {'COLOR': 'Red', 'SIZE': 'L'},
      );
      await validWriter.flushPersistence();

      final box = Hive.box<HiveLocalCartItem>('cart_items');
      await box.put(
        'corrupt-row',
        HiveLocalCartItem(
          lineId: 'corrupt-row',
          productId: 999,
          quantity: 1,
          serializedProduct: HiveStringValue('{not-valid-json'),
        ),
      );

      final reader = LocalProductProvider();
      expect(reader.cartItems, hasLength(1));
      expect(reader.cartItems.single.product.productId, 501);
      expect(reader.cartItems.single.variantId, 45);
    });
  });
}
