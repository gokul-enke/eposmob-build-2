import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/services/order_submission_coordinator.dart';
import 'package:pos_machine/services/review_stock_reconciliation.dart';
import 'package:pos_machine/features/realtime_sync/data/realtime_entity_api.dart';
import 'package:pos_machine/features/realtime_sync/domain/realtime_sync_models.dart';

import 'test_support/hive_test_teardown.dart';

class _ReviewCatalogApi extends RealtimeEntityApi {
  _ReviewCatalogApi(this.load);
  final Future<RealtimeCatalogSnapshot> Function() load;
  @override
  Future<RealtimeCatalogSnapshot> fetchCatalog(RealtimeSyncSession session,
          {String? updatedFrom,
          String? updatedTo,
          bool allowFullFallback = true}) =>
      load();
}

/// Covers the Hive persistence contract of [LocalProductProvider]:
///
///  * the products box is keyed by product id,
///  * cart/stock changes write single rows instead of the whole catalog,
///  * a full rewrite upserts then prunes (the box is never truncated),
///  * legacy auto-increment rows are migrated and de-duplicated,
///  * unreadable rows are skipped and dropped,
///  * large boxes hydrate in chunks and a catalog replaced mid-hydration wins,
///  * confirmed orders are keyed by order id.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir =
        await Directory.systemTemp.createTemp('epos_hive_persistence_test_');
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
    await Hive.openBox('order_submissions');
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
    await Hive.box('order_submissions').clear();
  });

  tearDown(awaitPendingHiveBoxWrites);
  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

  Box<HiveProduct> productsBox() => Hive.box<HiveProduct>('products');
  Box<HiveSavedOrder> confirmedBox() =>
      Hive.box<HiveSavedOrder>('confirmed_orders');

  GetProduct makeProduct(int id, {num stockQuantity = 10}) {
    return GetProduct(
      productId: id,
      productName: 'Product $id',
      barcode: 'BC-$id',
      price: ProductPrice(price: '10'),
      mrp: '12',
      purchasePrice: '8',
      unit: 'PCS',
      stock: <Stock>[
        Stock(
          id: id * 100,
          productId: id,
          quantity: stockQuantity,
          price: '10',
          mrp: '12',
          purchasePrice: '8',
          storeId: 1,
        ),
      ],
      taxes: const <ProductTax>[],
    );
  }

  test(
      'cart identity changes only for a new sale and survives provider restart',
      () async {
    final first = LocalProductProvider();
    await first.hydrated;
    final original = first.cartSessionId;
    first.addToCart(product: makeProduct(902), quantity: 1);
    await first.flushPersistence();
    expect(first.cartSessionId, original);
    first.dispose();
    final restored = LocalProductProvider();
    await restored.hydrated;
    expect(restored.cartSessionId, original);
    expect(restored.cartItems.length, 1);
    restored.clearCartAfterOrder();
    await restored.flushPersistence();
    final freshId = restored.cartSessionId;
    expect(freshId, isNot(original));
    restored.dispose();
    final fresh = LocalProductProvider();
    await fresh.hydrated;
    expect(fresh.cartSessionId, freshId);
    expect(fresh.cartItems, isEmpty);
    expect(await HiveSubmissionStore().readAll(), isEmpty);
    fresh.dispose();
  });

  /// A row exactly as older builds wrote it (the key is chosen by the caller).
  HiveProduct rowFor(GetProduct product) {
    return HiveProduct(
      productId: product.productId,
      categoryId: product.categoryId,
      productName: product.productName,
      barcode: product.barcode,
      serializedData: HiveStringValue(json.encode(product.toJson())),
    );
  }

  num storedStockQuantity(int productId) {
    final row = productsBox().get(productId)!;
    final decoded = GetProduct.fromJson(
      json.decode(row.serializedData.value) as Map<String, dynamic>,
    );
    return decoded.stock!.first.quantity!;
  }

  /// Lets Hive's broadcast watch stream deliver pending events.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('product-id keys', () {
    test('initializeProducts and addProduct store rows keyed by product id',
        () async {
      final provider = LocalProductProvider();
      provider.initializeProducts([makeProduct(1), makeProduct(2)]);
      await provider.flushPersistence();
      expect(productsBox().keys.toSet(), {1, 2});

      provider.addProduct(makeProduct(3));
      await provider.flushPersistence();
      expect(productsBox().keys.toSet(), {1, 2, 3});
      expect(productsBox().get(3)!.productId, 3);
    });

    test('deleteProduct removes exactly that row', () async {
      final provider = LocalProductProvider();
      provider.initializeProducts([makeProduct(1), makeProduct(2)]);
      await provider.flushPersistence();

      provider.deleteProduct(1);
      await provider.flushPersistence();
      expect(productsBox().keys.toSet(), {2});
    });
  });

  group('review stock reconciliation', () {
    const session = RealtimeSyncSession(
        backendBaseUrl: 'https://example.invalid',
        companyId: 1,
        storeId: 1,
        tenantApiKey: 'test',
        accessToken: 'test');
    test(
        'repeated refresh replaces stale quantities and preserves active reservations',
        () async {
      final provider = LocalProductProvider();
      await provider.hydrated;
      addTearDown(provider.dispose);
      provider.setStockEnabled(true);
      provider.initializeProducts([makeProduct(1)]);
      final product = provider.getProductById(1)!;
      expect(
          provider.addToCart(
              product: product,
              quantity: 2,
              selectedStock: product.stock!.first),
          isTrue);
      await provider.flushPersistence();
      final api = _ReviewCatalogApi(() async => RealtimeCatalogSnapshot(
          products: [makeProduct(1, stockQuantity: 15)],
          deletedProductIds: {}));
      addTearDown(api.close);
      for (var i = 0; i < 2; i++) {
        await ReviewStockReconciliation().refresh(
            session: session,
            products: provider,
            isCurrent: () => true,
            api: api);
        expect(provider.getProductById(1)!.stock!.first.quantity, 13);
        expect(storedStockQuantity(1), 13);
      }
    });

    test('store change during fetch prevents applying another store stock',
        () async {
      final provider = LocalProductProvider();
      await provider.hydrated;
      addTearDown(provider.dispose);
      provider.initializeProducts([makeProduct(1)]);
      await provider.flushPersistence();
      var current = true;
      final api = _ReviewCatalogApi(() async {
        current = false;
        return RealtimeCatalogSnapshot(
            products: [makeProduct(1, stockQuantity: 50)],
            deletedProductIds: {});
      });
      addTearDown(api.close);
      await expectLater(
          ReviewStockReconciliation().refresh(
              session: session,
              products: provider,
              isCurrent: () => current,
              api: api),
          throwsStateError);
      expect(storedStockQuantity(1), 10);
    });

    test('failed fetch keeps stock and releases the sync gate for retry',
        () async {
      final provider = LocalProductProvider();
      await provider.hydrated;
      addTearDown(provider.dispose);
      provider.initializeProducts([makeProduct(1)]);
      await provider.flushPersistence();
      var fail = true;
      final api = _ReviewCatalogApi(() async {
        if (fail) throw StateError('offline');
        return RealtimeCatalogSnapshot(
            products: [makeProduct(1, stockQuantity: 12)],
            deletedProductIds: {});
      });
      addTearDown(api.close);
      Future<void> refresh() => ReviewStockReconciliation().refresh(
          session: session,
          products: provider,
          isCurrent: () => true,
          api: api);
      await expectLater(refresh(), throwsStateError);
      expect(storedStockQuantity(1), 10);
      fail = false;
      await refresh();
      expect(storedStockQuantity(1), 12);
    });
  });

  group('write granularity', () {
    test('a cart stock change persists only the touched product', () async {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      provider
          .initializeProducts([makeProduct(1), makeProduct(2), makeProduct(3)]);
      await provider.flushPersistence();
      final untouchedBefore = productsBox().get(2)!.serializedData.value;

      final events = <BoxEvent>[];
      final subscription = productsBox().watch().listen(events.add);
      addTearDown(subscription.cancel);

      final product = provider.getProductById(1)!;
      final added = provider.addToCart(
        product: product,
        quantity: 1,
        selectedStock: product.stock!.first,
      );
      expect(added, isTrue);
      await provider.flushPersistence();
      await settle();

      expect(events.map((event) => event.key).toSet(), {1});
      expect(events.any((event) => event.deleted), isFalse);
      expect(storedStockQuantity(1), 9);
      expect(productsBox().get(2)!.serializedData.value, untouchedBefore);
      expect(productsBox().length, 3);
    });

    test('a full rewrite upserts then prunes and never clears the box',
        () async {
      final provider = LocalProductProvider();
      provider
          .initializeProducts([makeProduct(1), makeProduct(2), makeProduct(3)]);
      await provider.flushPersistence();

      final events = <BoxEvent>[];
      final subscription = productsBox().watch().listen(events.add);
      addTearDown(subscription.cancel);

      provider.initializeProducts([makeProduct(2, stockQuantity: 4)]);
      await provider.flushPersistence();
      await settle();

      expect(productsBox().keys.toSet(), {2});
      expect(storedStockQuantity(2), 4);
      // The surviving row was overwritten in place, never deleted.
      expect(
        events.where((event) => event.key == 2 && event.deleted),
        isEmpty,
      );
      expect(
        events.where((event) => event.deleted).map((event) => event.key),
        unorderedEquals([1, 3]),
      );
    });
  });

  group('hydration', () {
    test('legacy auto-increment rows are migrated and de-duplicated', () async {
      // Older builds appended with auto-increment keys, and a product could
      // end up stored twice. The latest row must win.
      await productsBox().addAll([
        rowFor(makeProduct(7)),
        rowFor(makeProduct(8)),
        rowFor(makeProduct(7, stockQuantity: 5)),
      ]);
      expect(productsBox().keys.toSet(), {0, 1, 2});

      final provider = LocalProductProvider();
      await provider.hydrated;
      expect(
          provider.products.map((p) => p.productId), unorderedEquals([7, 8]));
      expect(provider.getProductById(7)!.stock!.first.quantity, 5);

      await provider.flushPersistence();
      expect(productsBox().keys.toSet(), {7, 8});
      expect(storedStockQuantity(7), 5);
    });

    test('an unreadable row is skipped and dropped by the migration', () async {
      await productsBox().put(5, rowFor(makeProduct(5)));
      await productsBox().put(
        6,
        HiveProduct(
          productId: 6,
          serializedData: HiveStringValue('this is not json'),
        ),
      );

      final provider = LocalProductProvider();
      await provider.hydrated;
      expect(provider.products.map((p) => p.productId), [5]);

      await provider.flushPersistence();
      expect(productsBox().keys.toSet(), {5});
    });

    test('a large catalog hydrates in chunks and completes fully', () async {
      const count = 1000; // several chunks of 300
      await productsBox().putAll({
        for (var id = 1; id <= count; id++) id: rowFor(makeProduct(id)),
      });

      final provider = LocalProductProvider();
      // Only the first chunk runs inside the constructor.
      expect(provider.isHydrated, isFalse);
      expect(provider.products, isEmpty);

      var notified = false;
      provider.addListener(() => notified = true);

      await provider.hydrated;
      expect(provider.isHydrated, isTrue);
      expect(provider.products.length, count);
      expect(provider.getProductById(count), isNotNull);
      expect(provider.filterProductByBarcode(barCode: 'BC-500'), hasLength(1));
      expect(notified, isTrue);

      // Rows were already id-keyed, so no migration rewrite was needed.
      await provider.flushPersistence();
      expect(productsBox().length, count);
    });

    test('a small catalog is available synchronously after construction',
        () async {
      await productsBox().putAll({
        for (var id = 1; id <= 20; id++) id: rowFor(makeProduct(id)),
      });

      final provider = LocalProductProvider();
      expect(provider.isHydrated, isTrue);
      expect(provider.products.length, 20);
    });

    test('a catalog replaced during hydration is not clobbered', () async {
      await productsBox().putAll({
        for (var id = 1; id <= 1000; id++) id: rowFor(makeProduct(id)),
      });

      final provider = LocalProductProvider();
      provider.initializeProducts([makeProduct(99999)]);
      await provider.hydrated;
      await provider.flushPersistence();

      expect(provider.products.map((p) => p.productId), [99999]);
      expect(productsBox().keys.toSet(), {99999});
    });

    test('a product added while hydrating survives the swap', () async {
      await productsBox().putAll({
        for (var id = 1; id <= 1000; id++) id: rowFor(makeProduct(id)),
      });

      final provider = LocalProductProvider();
      provider.addProduct(makeProduct(5000));
      await provider.hydrated;
      await provider.flushPersistence();

      expect(provider.products.length, 1001);
      expect(provider.getProductById(5000), isNotNull);
      expect(provider.getProductById(1), isNotNull);
      expect(productsBox().containsKey(5000), isTrue);
    });
  });

  group('confirmed orders', () {
    test('rows are keyed by order id and legacy rows are pruned', () async {
      // A row as older builds wrote it, with an auto-increment key.
      await confirmedBox().add(HiveSavedOrder(
        id: 'legacy-order',
        orderNumber: 'CONF-1',
        items: const <HiveLocalCartItem>[],
        createdAt: DateTime(2024).toIso8601String(),
        total: 1,
      ));

      final provider = LocalProductProvider();
      provider.initializeProducts([makeProduct(1)]);
      final product = provider.getProductById(1)!;
      provider.addToCart(product: product, quantity: 1);

      final first = provider.saveCurrentCartAsConfirmedOrder();
      await provider.flushPersistence();
      // The in-memory list was loaded from the legacy row, so it is kept
      // (now keyed by its id) and its auto-increment copy is gone.
      expect(confirmedBox().keys.toSet(), {'legacy-order', first.id});

      final second = provider.saveCurrentCartAsConfirmedOrder();
      await provider.flushPersistence();
      expect(
        confirmedBox().keys.toSet(),
        {'legacy-order', first.id, second.id},
      );

      provider.deleteConfirmedOrder('legacy-order');
      await provider.flushPersistence();
      expect(confirmedBox().keys.toSet(), {first.id, second.id});
    });
  });
}
