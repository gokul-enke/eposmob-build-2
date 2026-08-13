// Tests for P0.4: Mobile quantity +/- must go through the stock-aware helper.
//
// Seam: BillingMobileCartController.changeQuantity now delegates to
// CartQuantityStockHelper.syncCartItemQuantity with `localProductProvider:`
// injected. This means tests can call the helper directly with
// `localProductProvider:` and an injected `selectionResolver:` to stay
// fully hermetic (no Flutter widget tree / Provider.of / modal needed).
// One thin testWidgets case checks that the controller correctly converts
// display → base quantity before forwarding to the helper.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'test_support/hive_test_teardown.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/helpers/cart_quantity_stock_helper.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_p04_test_');
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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  GetProduct plainProduct({
    int id = 1,
    String price = '10',
    List<Stock> stocks = const [],
    List<SaleUnit> saleUnits = const [],
  }) {
    return GetProduct(
      productId: id,
      productName: 'Product $id',
      price: ProductPrice(price: price),
      mrp: price,
      purchasePrice: '5',
      unit: 'PCS',
      stock: stocks,
      taxes: const <ProductTax>[],
      saleUnits: saleUnits.isEmpty ? null : saleUnits,
    );
  }

  Stock buildStock({
    required int id,
    required num quantity,
    String price = '10',
    String mrp = '10',
    int storeId = 1,
    String storeName = 'Main Store',
    String hsnCode = 'HSN-1',
  }) {
    return Stock(
      id: id,
      productId: 1,
      storeId: storeId,
      storeName: storeName,
      quantity: quantity,
      price: price,
      mrp: mrp,
      purchasePrice: '5',
      taxRate: '0',
      unit: 'PCS',
      hsnCode: hsnCode,
    );
  }

  // ---------------------------------------------------------------------------
  // Group 1: Helper-level tests (hermetic, no widget tree)
  // ---------------------------------------------------------------------------

  group('P0.4 CartQuantityStockHelper — mobile quantity change parity', () {
    // 1. Increase without stock management enabled — plain setCartItemQuantity.
    test('increase with stock disabled calls setCartItemQuantity directly',
        () async {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);

      final prod = plainProduct(id: 1);
      provider.initializeProducts([prod]);
      provider.addToCart(product: prod, quantity: 2);
      final item = provider.cartItems.first;

      final result = await CartQuantityStockHelper.syncCartItemQuantity(
        cartItem: item,
        newQuantity: 3, // base units: 2 + 1
        localProductProvider: provider,
      );

      expect(result.changed, isTrue);
      expect(provider.cartItems.single.quantity, 3);
    });

    // 2. Decrease — helper short-circuits and releases reservation.
    test('decrease with stock enabled short-circuits to setCartItemQuantity',
        () async {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);

      final stock = buildStock(id: 1, quantity: 5);
      final prod = plainProduct(id: 1, stocks: [stock]);
      provider.initializeProducts([prod]);

      // Cart starts with 3, selected stock.
      final groupedStock = stock.copyWith(quantity: 5);
      provider.addToCart(
        product: prod,
        quantity: 3,
        selectedStock: groupedStock,
        stockGroupIds: const [1],
      );
      final item = provider.cartItems.first;

      // Decrease by 1: newBaseQty = 2 < currentQty = 3 → short-circuit.
      final result = await CartQuantityStockHelper.syncCartItemQuantity(
        cartItem: item,
        newQuantity: 2,
        localProductProvider: provider,
      );

      expect(result.changed, isTrue);
      expect(provider.cartItems.single.quantity, 2);
    });

    // 3. Sale-unit step snapping on increase.
    //    Sale unit CASE = 12 PCS. Cart has 12 PCS (1 CASE display).
    //    Increasing by 1 display step should add 12 base units.
    //    If only 10 base units remain in stock, the increase snaps to
    //    the largest multiple-of-12 that fits (0) and blocks.
    test('sale-unit increase snaps to sale-unit base step', () async {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);

      // Stock has 24 units available (enough for 2 CASE steps).
      final stock = buildStock(id: 1, quantity: 24);
      final prod = plainProduct(
        id: 1,
        stocks: [stock],
        saleUnits: [
          SaleUnit(
            id: 10,
            unitId: 100,
            unitName: 'CASE',
            conversionRate: '12',
          ),
        ],
      );
      provider.initializeProducts([prod]);

      final groupedStock = stock.copyWith(quantity: 24);
      // Add 1 CASE (= 12 base units) to cart with sale-unit selected.
      provider.addToCart(
        product: prod,
        quantity: 12,
        selectedStock: groupedStock,
        stockGroupIds: const [1],
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 12,
      );
      final item = provider.cartItems.first;

      // displayQuantity = 1 CASE, step +1 → newDisplay = 2 CASE = 24 base.
      final newDisplayQty = item.displayQuantity + 1; // 2
      final newBaseQty = item.toBaseQuantity(newDisplayQty); // 24

      final result = await CartQuantityStockHelper.syncCartItemQuantity(
        cartItem: item,
        newQuantity: newBaseQty,
        localProductProvider: provider,
      );

      expect(result.changed, isTrue);
      // After adding 12 more base units (1 CASE), total = 24.
      expect(provider.cartItems.single.quantity, 24);
    });

    // 4. Insufficient current stock — no alternate stocks → onBlocked fires,
    //    quantity remains unchanged.
    test('increase blocked when current stock exhausted and no alternates',
        () async {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      provider.setAllowOverselling(false);

      // Stock only has 2, cart already holds 2.
      final stock = buildStock(id: 1, quantity: 2);
      final prod = plainProduct(id: 1, stocks: [stock]);
      provider.initializeProducts([prod]);

      final groupedStock = stock.copyWith(quantity: 2);
      provider.addToCart(
        product: prod,
        quantity: 2,
        selectedStock: groupedStock,
        stockGroupIds: const [1],
      );
      final item = provider.cartItems.first;

      final List<String> blockedMessages = [];

      // newBaseQty = 3, current = 2 → increase path, stock exhausted.
      await CartQuantityStockHelper.syncCartItemQuantity(
        cartItem: item,
        newQuantity: 3,
        localProductProvider: provider,
        // No selectionResolver or context → alternativeStocks empty → blocked.
        selectionResolver: (product, options) async => null,
        onBlocked: blockedMessages.add,
      );

      expect(blockedMessages, isNotEmpty);
      // Quantity must not have increased beyond what was available.
      expect(provider.cartItems.single.quantity, lessThanOrEqualTo(2));
    });

    // 5. Alternate group selection via injected selectionResolver.
    //    Current stock exhausted; resolver returns an alternate stock;
    //    helper adds from it.
    test('increase resolves alternate stock via injected selectionResolver',
        () async {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      provider.setAllowOverselling(false);

      // Two stocks at same price (same pricing group).
      final stockA = buildStock(id: 1, quantity: 2);
      final stockB =
          buildStock(id: 2, quantity: 5, storeId: 2, storeName: 'Branch Store');
      final prod = plainProduct(id: 1, stocks: [stockA, stockB]);
      provider.initializeProducts([prod]);

      // Cart holds all of stockA (2 units).
      final groupedStockA = stockA.copyWith(quantity: 2);
      provider.addToCart(
        product: prod,
        quantity: 2,
        selectedStock: groupedStockA,
        stockGroupIds: const [1],
      );
      final item = provider.cartItems.first;

      // Resolver picks stockB when asked.
      final alternateSelection = CartQuantityStockSelection(
        selectedStock: stockB.copyWith(quantity: 5),
        stockGroupIds: const [2],
      );

      // Try to increase to 4 (need 2 more, all from stockB).
      final result = await CartQuantityStockHelper.syncCartItemQuantity(
        cartItem: item,
        newQuantity: 4,
        localProductProvider: provider,
        selectionResolver: (_, __) async => alternateSelection,
        onBlocked: (msg) => fail('Should not block: $msg'),
      );

      expect(result.changed, isTrue);
      // Total across both cart lines should be 4.
      final totalQty =
          provider.cartItems.fold<num>(0, (sum, ci) => sum + ci.quantity);
      expect(totalQty, 4);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 2: Thin controller test — proves base-quantity conversion is forwarded
  // ---------------------------------------------------------------------------
  //
  // WHY tester.runAsync():
  // testWidgets runs inside Flutter's FakeAsync zone, which intercepts all
  // Timer() calls and turns them into fake timers. Hive uses an internal
  // write-flush timer (debouncing multiple consecutive writes). Inside
  // FakeAsync that timer never fires, so Hive writes are permanently buffered.
  // This leaves pending operations when the test body exits; the next setUp's
  // `await box.clear()` and tearDownAll's `await Hive.close()` both wait for
  // those writes and hang forever.
  //
  // tester.runAsync() runs its callback in a real async zone (clock is NOT
  // fake), so Hive's flush timer fires and all writes complete before
  // returning. The BuildContext is captured by a prior pumpWidget call and
  // remains valid for the duration of the runAsync block.

  group('P0.4 BillingMobileCartController.changeQuantity', () {
    const controller = BillingMobileCartController();

    testWidgets('forwards correct base quantity to helper for a plain product',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      // Mount a minimal widget first — this runs inside FakeAsync (no Hive
      // involved) and captures a valid BuildContext for use below.
      late BuildContext capturedContext;
      await tester.pumpWidget(
        Builder(builder: (ctx) {
          capturedContext = ctx;
          return const SizedBox();
        }),
      );

      // All provider and controller calls that touch Hive run inside runAsync
      // so that Hive's write-flush timer fires in the real event loop and
      // every write completes before we return.
      await tester.runAsync(() async {
        final provider = LocalProductProvider();
        provider.setStockEnabled(false);

        final prod = plainProduct(id: 5, price: '15');
        provider.initializeProducts([prod]);
        provider.addToCart(product: prod, quantity: 3);

        // +1 step: displayQuantity = 3, newBaseQty = 3 + 1 = 4.
        await controller.changeQuantity(
            capturedContext, provider, provider.cartItems.first, 1);
        expect(provider.cartItems.single.quantity, 4);

        // -1 step: displayQuantity = 4, newBaseQty = 4 - 1 = 3.
        await controller.changeQuantity(
            capturedContext, provider, provider.cartItems.first, -1);
        expect(provider.cartItems.single.quantity, 3);
      });
    });

    testWidgets(
        'converts sale-unit display quantity to base quantity before forwarding',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      // Capture BuildContext outside runAsync (pumpWidget is FakeAsync-safe and
      // does not touch Hive).
      late BuildContext capturedContext;
      await tester.pumpWidget(
        Builder(builder: (ctx) {
          capturedContext = ctx;
          return const SizedBox();
        }),
      );

      // Run all Hive-touching operations in the real async zone.
      await tester.runAsync(() async {
        final provider = LocalProductProvider();
        provider.setStockEnabled(false);

        // CASE = 6 base units.
        final prod = plainProduct(
          id: 6,
          saleUnits: [
            SaleUnit(
              id: 20,
              unitId: 200,
              unitName: 'CASE',
              conversionRate: '6',
            ),
          ],
        );
        provider.initializeProducts([prod]);
        // Add 2 CASE (= 12 base) with sale-unit attached.
        provider.addToCart(
          product: prod,
          quantity: 12,
          saleUnitId: 20,
          saleUnitName: 'CASE',
          saleUnitConversionRate: 6,
        );

        final item = provider.cartItems.first;
        // displayQuantity = 2 CASE.  +1 step → newDisplay = 3 → newBase = 18.
        await controller.changeQuantity(capturedContext, provider, item, 1);
        expect(provider.cartItems.single.quantity, 18);
      });
    });
  });
}
