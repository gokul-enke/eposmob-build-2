import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/helpers/cart_quantity_stock_helper.dart';
import 'test_support/hive_test_teardown.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_stock_test_');
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

  tearDown(awaitPendingHiveBoxWrites);
  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

  GetProduct buildProduct({
    required int productId,
    required String basePrice,
    required String mrp,
    required List<Stock> stocks,
    String unit = 'PCS',
  }) {
    return GetProduct(
      productId: productId,
      productName: 'Product $productId',
      price: ProductPrice(price: basePrice),
      mrp: mrp,
      purchasePrice: '8',
      unit: unit,
      stock: stocks,
      taxes: const <ProductTax>[],
    );
  }

  Stock buildStock({
    required int id,
    required num quantity,
    required String price,
    required String mrp,
    String purchasePrice = '8',
    int storeId = 1,
    String storeName = 'Main Store',
    String taxRate = '5',
    String unit = 'PCS',
    String hsnCode = 'HSN-1',
    String? date,
    String? expiryDate,
  }) {
    return Stock(
      id: id,
      productId: 1,
      storeId: storeId,
      storeName: storeName,
      quantity: quantity,
      price: price,
      mrp: mrp,
      purchasePrice: purchasePrice,
      taxRate: taxRate,
      unit: unit,
      hsnCode: hsnCode,
      date: date,
      expiryDate: expiryDate,
    );
  }

  test('realtime catalog reapplies active cart reservations', () async {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);
    final initialStock =
        buildStock(id: 1, quantity: 10, price: '10', mrp: '12');
    final product = buildProduct(
      productId: 1,
      basePrice: '10',
      mrp: '12',
      stocks: <Stock>[initialStock],
    );
    provider.initializeProducts(<GetProduct>[product]);
    provider.addToCart(
      product: product,
      quantity: 3,
      selectedStock: initialStock,
    );

    final serverStock = buildStock(id: 1, quantity: 10, price: '10', mrp: '12');
    final serverProduct = buildProduct(
      productId: 1,
      basePrice: '10',
      mrp: '12',
      stocks: <Stock>[serverStock],
    );
    await provider.applyRealtimeCatalog(
      <GetProduct>[serverProduct],
      deletedProductIds: const <int>{},
    );

    expect(
      provider.getProductById(1)!.stock!.single.quantity,
      7,
    );

    provider.clearCart();
    expect(
      provider.getProductById(1)!.stock!.single.quantity,
      10,
    );
  });

  test('realtime catalog keeps a deleted product reserved in cart', () async {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);
    final stock = buildStock(id: 1, quantity: 5, price: '10', mrp: '12');
    final product = buildProduct(
      productId: 1,
      basePrice: '10',
      mrp: '12',
      stocks: <Stock>[stock],
    );
    provider.initializeProducts(<GetProduct>[product]);
    provider.addToCart(
      product: product,
      quantity: 1,
      selectedStock: stock,
    );

    await provider.applyRealtimeCatalog(
      const <GetProduct>[],
      deletedProductIds: const <int>{1},
    );

    expect(provider.getProductById(1), isNotNull);
    expect(provider.cartItems.single.product.productId, 1);
  });

  test('grouped stock reservations merge same pricing group and expand payload',
      () {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);

    final stockOne = buildStock(id: 1, quantity: 2, price: '10', mrp: '12');
    final stockTwo = buildStock(id: 2, quantity: 3, price: '10', mrp: '12');
    final product = buildProduct(
      productId: 1,
      basePrice: '10',
      mrp: '12',
      stocks: <Stock>[stockOne, stockTwo],
    );

    provider.initializeProducts(<GetProduct>[product]);

    provider.addToCart(
      product: product,
      quantity: 4,
      selectedStock: stockOne.copyWith(quantity: 5),
      stockGroupIds: const <int>[1, 2],
    );

    provider.addToCart(
      product: product,
      quantity: 1,
      selectedStock: stockTwo.copyWith(quantity: 1),
      stockGroupIds: const <int>[1, 2],
    );

    expect(provider.cartItems, hasLength(1));
    expect(provider.cartItems.first.quantity, 5);
    expect(provider.cartItems.first.stockGroupIds, <int>[1, 2]);
    expect(provider.cartItems.first.stockDeducted, 5);
    expect(
      provider.cartItems.first.stockReservations
          .map(
              (reservation) => '${reservation.stockId}:${reservation.quantity}')
          .toList(),
      <String>['1:2', '2:3'],
    );

    final updatedProduct = provider.getProductById(1)!;
    expect(
        updatedProduct.stock!.firstWhere((stock) => stock.id == 1).quantity, 0);
    expect(
        updatedProduct.stock!.firstWhere((stock) => stock.id == 2).quantity, 0);

    expect(
      provider.buildOrderItemsPayload(),
      <Map<String, dynamic>>[
        {
          'product_id': 1,
          'quantity': 2,
          'price': 10.0,
          'mrp': 12.0,
          'stock_id': 1,
          'warranty_enabled': false,
        },
        {
          'product_id': 1,
          'quantity': 3,
          'price': 10.0,
          'mrp': 12.0,
          'stock_id': 2,
          'warranty_enabled': false,
        },
      ],
    );
  });

  test(
      'same pricing group collapses into one line as FEFO shrinks stockGroupIds',
      () {
    // Reproduces the reported bug: one product, three same-price/unit batches.
    // Each successive add depletes a batch, so the available (qty>0) id set
    // shrinks ([1,2,3] -> [2,3] -> [3]). The cart must still merge them into a
    // single line because the pricing signature (price+unit) is unchanged.
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);

    final stockOne = buildStock(id: 1, quantity: 2, price: '2', mrp: '12');
    final stockTwo = buildStock(id: 2, quantity: 5, price: '2', mrp: '12');
    final stockThree = buildStock(id: 3, quantity: 1, price: '2', mrp: '12');
    final product = buildProduct(
      productId: 1,
      basePrice: '2',
      mrp: '12',
      stocks: <Stock>[stockOne, stockTwo, stockThree],
    );

    provider.initializeProducts(<GetProduct>[product]);

    // Add 2 -> drains batch 1.
    provider.addToCart(
      product: product,
      quantity: 2,
      selectedStock: stockOne.copyWith(quantity: 8),
      stockGroupIds: const <int>[1, 2, 3],
    );
    // Add 5 -> batch 1 is gone, so the grouped id set the UI computes is [2,3].
    provider.addToCart(
      product: product,
      quantity: 5,
      selectedStock: stockTwo.copyWith(quantity: 6),
      stockGroupIds: const <int>[2, 3],
    );
    // Add 1 -> only batch 3 remains, id set is [3].
    provider.addToCart(
      product: product,
      quantity: 1,
      selectedStock: stockThree.copyWith(quantity: 1),
      stockGroupIds: const <int>[3],
    );

    // One merged line, not three.
    expect(provider.cartItems, hasLength(1));
    expect(provider.cartItems.first.quantity, 8);
    // The line records every batch it drew from (union).
    expect(provider.cartItems.first.stockGroupIds, <int>[1, 2, 3]);
    expect(provider.cartItems.first.stockDeducted, 8);
    expect(
      provider.cartItems.first.stockReservations
          .map(
              (reservation) => '${reservation.stockId}:${reservation.quantity}')
          .toList(),
      <String>['1:2', '2:5', '3:1'],
    );

    // All three batches are exhausted.
    final updatedProduct = provider.getProductById(1)!;
    expect(updatedProduct.stock!.firstWhere((s) => s.id == 1).quantity, 0);
    expect(updatedProduct.stock!.firstWhere((s) => s.id == 2).quantity, 0);
    expect(updatedProduct.stock!.firstWhere((s) => s.id == 3).quantity, 0);

    // Order send body is unchanged: still one payload line per stock_id.
    expect(
      provider.buildOrderItemsPayload(),
      <Map<String, dynamic>>[
        {
          'product_id': 1,
          'quantity': 2,
          'price': 2.0,
          'mrp': 12.0,
          'stock_id': 1,
          'warranty_enabled': false,
        },
        {
          'product_id': 1,
          'quantity': 5,
          'price': 2.0,
          'mrp': 12.0,
          'stock_id': 2,
          'warranty_enabled': false,
        },
        {
          'product_id': 1,
          'quantity': 1,
          'price': 2.0,
          'mrp': 12.0,
          'stock_id': 3,
          'warranty_enabled': false,
        },
      ],
    );
  });

  test('different pricing groups stay on separate lines', () {
    // Guard against over-merging: same product, different selling price must
    // remain two distinct cart lines even though both are grouped selections.
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);

    final cheapStock = buildStock(id: 1, quantity: 3, price: '2', mrp: '12');
    final pricyStock = buildStock(id: 2, quantity: 3, price: '5', mrp: '15');
    final product = buildProduct(
      productId: 1,
      basePrice: '2',
      mrp: '12',
      stocks: <Stock>[cheapStock, pricyStock],
    );

    provider.initializeProducts(<GetProduct>[product]);

    provider.addToCart(
      product: product,
      quantity: 1,
      price: 2.0,
      selectedStock: cheapStock.copyWith(quantity: 3),
      stockGroupIds: const <int>[1],
    );
    provider.addToCart(
      product: product,
      quantity: 1,
      price: 5.0,
      selectedStock: pricyStock.copyWith(quantity: 3),
      stockGroupIds: const <int>[2],
    );

    expect(provider.cartItems, hasLength(2));
  });

  test('oversell mode consumes compatible stock before overselling', () {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);

    final stockOne = buildStock(id: 1, quantity: 10, price: '10', mrp: '12');
    final stockTwo = buildStock(id: 2, quantity: 5, price: '10', mrp: '12');
    final product = buildProduct(
      productId: 1,
      basePrice: '10',
      mrp: '12',
      stocks: <Stock>[stockOne, stockTwo],
    );
    provider.initializeProducts(<GetProduct>[product]);

    final added = provider.addToCart(
      product: product,
      quantity: 12,
      selectedStock: stockOne,
    );

    expect(added, isTrue);
    expect(provider.cartItems, hasLength(1));
    expect(provider.cartItems.single.quantity, 12);
    expect(provider.cartItems.single.stockDeducted, 12);
    expect(
      provider.cartItems.single.stockReservations
          .map(
              (reservation) => '${reservation.stockId}:${reservation.quantity}')
          .toList(),
      <String>['1:10', '2:2'],
    );
    expect(provider.getProductById(1)!.stock![0].quantity, 0);
    expect(provider.getProductById(1)!.stock![1].quantity, 3);
  });

  test('oversell mode does not silently consume differently priced stock', () {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);

    final stockOne = buildStock(id: 1, quantity: 10, price: '10', mrp: '12');
    final otherPrice = buildStock(id: 2, quantity: 5, price: '11', mrp: '13');
    final product = buildProduct(
      productId: 1,
      basePrice: '10',
      mrp: '12',
      stocks: <Stock>[stockOne, otherPrice],
    );
    provider.initializeProducts(<GetProduct>[product]);

    final added = provider.addToCart(
      product: product,
      quantity: 12,
      selectedStock: stockOne,
    );

    expect(added, isTrue);
    expect(provider.cartItems.single.quantity, 12);
    expect(provider.cartItems.single.stockDeducted, 10);
    expect(provider.cartItems.single.stockReservations, hasLength(1));
    expect(provider.cartItems.single.stockReservations.single.stockId, 1);
    expect(provider.getProductById(1)!.stock![0].quantity, 0);
    expect(provider.getProductById(1)!.stock![1].quantity, 5);
  });

  test(
      'quantity increase uses differently priced stock as a separate line before overselling',
      () async {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);

    final stockOne = buildStock(id: 1, quantity: 10, price: '10', mrp: '12');
    final otherPrice = buildStock(id: 2, quantity: 5, price: '11', mrp: '13');
    final product = buildProduct(
      productId: 1,
      basePrice: '10',
      mrp: '12',
      stocks: <Stock>[stockOne, otherPrice],
    );
    provider.initializeProducts(<GetProduct>[product]);
    provider.addToCart(
      product: product,
      quantity: 10,
      selectedStock: stockOne,
    );

    final originalLine = provider.cartItems.single;
    final result = await CartQuantityStockHelper.syncCartItemQuantity(
      cartItem: originalLine,
      newQuantity: 20,
      localProductProvider: provider,
      activeStoreId: 1,
      selectionResolver: (_, options) async {
        expect(options.map((stock) => stock.id), <int?>[2]);
        return CartQuantityStockSelection(
          selectedStock: options.single,
          stockGroupIds: const <int>[2],
        );
      },
    );

    expect(result.changed, isTrue);
    expect(result.appliedQuantity, 20);
    expect(provider.cartItems, hasLength(2));
    final firstPriceLine =
        provider.cartItems.firstWhere((item) => item.selectedStock?.id == 1);
    final secondPriceLine =
        provider.cartItems.firstWhere((item) => item.selectedStock?.id == 2);
    expect(firstPriceLine.quantity, 15); // 10 reserved + 5 oversold.
    expect(firstPriceLine.stockDeducted, 10);
    expect(firstPriceLine.price, 10);
    expect(secondPriceLine.quantity, 5);
    expect(secondPriceLine.stockDeducted, 5);
    expect(secondPriceLine.price, 11);
  });

  test('base-price fallback keeps stock null and increments same row', () {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);

    final zeroStock = buildStock(id: 11, quantity: 0, price: '15', mrp: '18');
    final product = buildProduct(
      productId: 1,
      basePrice: '20',
      mrp: '22',
      stocks: <Stock>[zeroStock],
    );

    provider.initializeProducts(<GetProduct>[product]);

    provider.addToCart(product: product, quantity: 1);
    provider.addToCart(product: product, quantity: 1);

    expect(provider.cartItems, hasLength(1));
    expect(provider.cartItems.first.quantity, 2);
    expect(provider.cartItems.first.selectedStock, isNull);
    expect(provider.cartItems.first.stockDeducted, 0);
    expect(provider.cartItems.first.stockReservations, isEmpty);
    expect(
      provider.buildOrderItemsPayload(),
      <Map<String, dynamic>>[
        {
          'product_id': 1,
          'quantity': 2,
          'price': 20.0,
          'mrp': 22.0,
          'stock_id': null,
          'warranty_enabled': false,
        },
      ],
    );
  });

  test('loadOrderForEditing restores and reapplies saved grouped reservations',
      () {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);

    final stockOne = buildStock(id: 1, quantity: 2, price: '10', mrp: '12');
    final stockTwo = buildStock(id: 2, quantity: 3, price: '10', mrp: '12');
    final product = buildProduct(
      productId: 1,
      basePrice: '10',
      mrp: '12',
      stocks: <Stock>[stockOne, stockTwo],
    );

    provider.initializeProducts(<GetProduct>[product]);

    provider.addToCart(
      product: product,
      quantity: 4,
      selectedStock: stockOne.copyWith(quantity: 5),
      stockGroupIds: const <int>[1, 2],
    );
    final savedOrder = provider.saveCurrentCartAsOrder(status: 'saved');

    provider.loadOrderForEditing(savedOrder.id);

    expect(provider.cartItems, hasLength(1));
    expect(provider.cartItems.first.quantity, 4);
    expect(provider.cartItems.first.stockGroupIds, <int>[1, 2]);
    expect(
      provider.cartItems.first.stockReservations
          .map(
              (reservation) => '${reservation.stockId}:${reservation.quantity}')
          .toList(),
      <String>['1:2', '2:2'],
    );

    final updatedProduct = provider.getProductById(1)!;
    expect(
        updatedProduct.stock!.firstWhere((stock) => stock.id == 1).quantity, 0);
    expect(
        updatedProduct.stock!.firstWhere((stock) => stock.id == 2).quantity, 1);
  });

  test(
      'increment beyond exhausted single stock uses another stock row instead of null overflow',
      () async {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);
    provider.setAllowOverselling(false);

    final stockOne = buildStock(id: 1, quantity: 5, price: '10', mrp: '12');
    final stockTwo = buildStock(id: 2, quantity: 4, price: '11', mrp: '13');
    final product = buildProduct(
      productId: 1,
      basePrice: '9',
      mrp: '11',
      stocks: <Stock>[stockOne, stockTwo],
    );

    provider.initializeProducts(<GetProduct>[product]);
    provider.addToCart(
      product: product,
      quantity: 5,
      selectedStock: stockOne,
    );

    final result = await CartQuantityStockHelper.syncCartItemQuantity(
      cartItem:
          provider.cartItems.firstWhere((item) => item.selectedStock?.id == 1),
      newQuantity: 6,
      localProductProvider: provider,
      selectionResolver: (currentProduct, stockOptions) async {
        expect(stockOptions.map((stock) => stock.id).toList(), <int?>[2]);
        final selectedStock = stockOptions.first;
        return CartQuantityStockSelection(
          selectedStock: selectedStock,
          stockGroupIds:
              provider.getSelectionStockIds(selectedStock: selectedStock),
        );
      },
    );

    expect(result.changed, isTrue);
    expect(result.appliedQuantity, 6);

    expect(provider.cartItems, hasLength(2));

    final originalRow =
        provider.cartItems.firstWhere((item) => item.selectedStock?.id == 1);
    final additionalRow = provider.cartItems.firstWhere(
      (item) => item.selectedStock?.id != 1,
    );

    expect(originalRow.quantity, 5);
    expect(originalRow.stockDeducted, 5);
    expect(additionalRow.quantity, 1);
    expect(additionalRow.selectedStock?.id, 2);
    expect(
      provider.buildOrderItemsPayload().every(
            (item) => item['stock_id'] != null,
          ),
      isTrue,
    );
  });

  test(
      'increment beyond exhausted grouped stock adds a new stock row instead of null overflow',
      () async {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);
    provider.setAllowOverselling(false);

    final stockOne = buildStock(id: 1, quantity: 2, price: '10', mrp: '12');
    final stockTwo = buildStock(id: 2, quantity: 3, price: '10', mrp: '12');
    final stockThree = buildStock(id: 3, quantity: 4, price: '14', mrp: '16');
    final product = buildProduct(
      productId: 1,
      basePrice: '9',
      mrp: '11',
      stocks: <Stock>[stockOne, stockTwo, stockThree],
    );

    provider.initializeProducts(<GetProduct>[product]);
    provider.addToCart(
      product: product,
      quantity: 5,
      selectedStock: stockOne.copyWith(quantity: 5),
      stockGroupIds: const <int>[1, 2],
    );

    final result = await CartQuantityStockHelper.syncCartItemQuantity(
      cartItem: provider.cartItems
          .firstWhere((item) => item.stockGroupIds.length == 2),
      newQuantity: 6,
      localProductProvider: provider,
      selectionResolver: (currentProduct, stockOptions) async {
        expect(stockOptions.map((stock) => stock.id).toList(), <int?>[3]);
        final selectedStock = stockOptions.first;
        return CartQuantityStockSelection(
          selectedStock: selectedStock,
          stockGroupIds:
              provider.getSelectionStockIds(selectedStock: selectedStock),
        );
      },
    );

    expect(result.changed, isTrue);
    expect(result.appliedQuantity, 6);

    expect(provider.cartItems, hasLength(2));

    final groupedRow =
        provider.cartItems.firstWhere((item) => item.stockGroupIds.length == 2);
    final additionalRow =
        provider.cartItems.firstWhere((item) => item.selectedStock?.id == 3);

    expect(groupedRow.quantity, 5);
    expect(groupedRow.stockReservations.length, 2);
    expect(additionalRow.quantity, 1);
    expect(
      provider.buildOrderItemsPayload().every(
            (item) => item['stock_id'] != null,
          ),
      isTrue,
    );
  });

  test('non-decimal unit floors a fractional batch when splitting reservations',
      () {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);

    // Batch A holds a fractional 1.3 PCS (bad source data); batch B has plenty.
    final stockOne = buildStock(id: 1, quantity: 1.3, price: '10', mrp: '12');
    final stockTwo = buildStock(id: 2, quantity: 5, price: '10', mrp: '12');
    final product = buildProduct(
      productId: 1,
      basePrice: '10',
      mrp: '12',
      stocks: <Stock>[stockOne, stockTwo],
    );

    provider.initializeProducts(<GetProduct>[product]);

    provider.addToCart(
      product: product,
      quantity: 2,
      selectedStock: stockOne.copyWith(quantity: 6.3),
      stockGroupIds: const <int>[1, 2],
    );

    // Batch A contributes only its whole unit (1), the remainder comes from B.
    final reservations = provider.cartItems.first.stockReservations;
    expect(reservations.map((r) => r.stockId).toList(), <int>[1, 2]);
    expect(reservations[0].quantity, closeTo(1, 0.0001));
    expect(reservations[1].quantity, closeTo(1, 0.0001));

    // Payload carries only integer quantities — no 1.3 / 0.7 lines.
    expect(
      provider.buildOrderItemsPayload(),
      <Map<String, dynamic>>[
        {
          'product_id': 1,
          'quantity': 1,
          'price': 10.0,
          'mrp': 12.0,
          'stock_id': 1,
          'warranty_enabled': false,
        },
        {
          'product_id': 1,
          'quantity': 1,
          'price': 10.0,
          'mrp': 12.0,
          'stock_id': 2,
          'warranty_enabled': false,
        },
      ],
    );

    // The stranded 0.3 dust stays in batch A (availability untouched).
    final updated = provider.getProductById(1)!;
    expect(
      updated.stock!.firstWhere((s) => s.id == 1).quantity,
      closeTo(0.3, 0.0001),
    );
  });

  test('decimal unit (KG) preserves fractional split', () {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);

    final stockOne =
        buildStock(id: 1, quantity: 1.3, price: '10', mrp: '12', unit: 'KG');
    final stockTwo =
        buildStock(id: 2, quantity: 5, price: '10', mrp: '12', unit: 'KG');
    final product = buildProduct(
      productId: 1,
      basePrice: '10',
      mrp: '12',
      unit: 'KG',
      stocks: <Stock>[stockOne, stockTwo],
    );

    provider.initializeProducts(<GetProduct>[product]);

    provider.addToCart(
      product: product,
      quantity: 2,
      selectedStock: stockOne.copyWith(quantity: 6.3),
      stockGroupIds: const <int>[1, 2],
    );

    // KG is decimal-capable: batch A gives its full 1.3, B covers the 0.7.
    final reservations = provider.cartItems.first.stockReservations;
    expect(reservations.map((r) => r.stockId).toList(), <int>[1, 2]);
    expect(reservations[0].quantity, closeTo(1.3, 0.0001));
    expect(reservations[1].quantity, closeTo(0.7, 0.0001));
  });

  test('increment is blocked when no alternative stock remains', () async {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);
    provider.setAllowOverselling(false);

    final stockOne = buildStock(id: 1, quantity: 5, price: '10', mrp: '12');
    final product = buildProduct(
      productId: 1,
      basePrice: '9',
      mrp: '11',
      stocks: <Stock>[stockOne],
    );

    provider.initializeProducts(<GetProduct>[product]);
    provider.addToCart(
      product: product,
      quantity: 5,
      selectedStock: stockOne,
    );

    String? blockedMessage;
    final result = await CartQuantityStockHelper.syncCartItemQuantity(
      cartItem:
          provider.cartItems.firstWhere((item) => item.selectedStock?.id == 1),
      newQuantity: 6,
      localProductProvider: provider,
      selectionResolver: (_, __) async {
        fail(
            'Selection should not be requested when no alternative stock exists.');
      },
      onBlocked: (message) {
        blockedMessage = message;
      },
    );

    expect(result.changed, isFalse);
    expect(result.appliedQuantity, 5);
    expect(blockedMessage,
        'Selected stock is exhausted. No other stock is available.');
    expect(provider.cartItems, hasLength(1));
    expect(provider.cartItems.first.quantity, 5);
    expect(provider.cartItems.first.stockDeducted, 5);
  });

  test(
      'oversell allows a variant with no stock row without borrowing another variant',
      () {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);
    provider.setAllowOverselling(true);

    final redVariant = ProductVariant(
      id: 101,
      price: 100,
      attributes: const {'COLOR': 'Red', 'SIZE': 'M'},
    );
    final blueVariant = ProductVariant(
      id: 102,
      price: 100,
      attributes: const {'COLOR': 'Blue', 'SIZE': 'M'},
    );
    final blueStock = Stock(
      id: 22,
      productId: 1,
      productVariantId: 102,
      storeId: 1,
      storeName: 'Main Store',
      quantity: 10,
      price: '100',
      mrp: '120',
      unit: 'PCS',
    );
    final product = GetProduct(
      productId: 1,
      productName: 'Variant Shirt',
      price: ProductPrice(price: '100'),
      mrp: '120',
      unit: 'PCS',
      variants: <ProductVariant>[redVariant, blueVariant],
      stock: <Stock>[blueStock],
    );
    provider.initializeProducts(<GetProduct>[product]);

    final added = provider.addToCart(
      product: product,
      quantity: 1,
      variantId: redVariant.id,
      variantAttributes: redVariant.attributes,
    );

    expect(added, isTrue);
    expect(provider.cartItems.single.variantId, redVariant.id);
    expect(provider.cartItems.single.stockReservations, isEmpty);
    expect(provider.buildOrderItemsPayload(), <Map<String, dynamic>>[
      {
        'product_id': 1,
        'quantity': 1,
        'price': 100.0,
        'mrp': 120.0,
        'stock_id': null,
        'product_variant_id': 101,
        'warranty_enabled': false,
      },
    ]);
    expect(
      provider.getProductById(1)!.stock!.single.quantity,
      10,
    );
  });
}
