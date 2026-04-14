import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/helpers/cart_quantity_stock_helper.dart';
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

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  GetProduct buildProduct({
    required int productId,
    required String basePrice,
    required String mrp,
    required List<Stock> stocks,
  }) {
    return GetProduct(
      productId: productId,
      productName: 'Product $productId',
      price: ProductPrice(price: basePrice),
      mrp: mrp,
      purchasePrice: '8',
      unit: 'PCS',
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

  test('grouped stock reservations merge same pricing group and expand payload', () {
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
          .map((reservation) => '${reservation.stockId}:${reservation.quantity}')
          .toList(),
      <String>['1:2', '2:3'],
    );

    final updatedProduct = provider.getProductById(1)!;
    expect(updatedProduct.stock!.firstWhere((stock) => stock.id == 1).quantity, 0);
    expect(updatedProduct.stock!.firstWhere((stock) => stock.id == 2).quantity, 0);

    expect(
      provider.buildOrderItemsPayload(),
      <Map<String, dynamic>>[
        {
          'product_id': 1,
          'quantity': 2,
          'price': 10.0,
          'mrp': 12.0,
          'stock_id': 1,
        },
        {
          'product_id': 1,
          'quantity': 3,
          'price': 10.0,
          'mrp': 12.0,
          'stock_id': 2,
        },
      ],
    );
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
        },
      ],
    );
  });

  test('loadOrderForEditing restores and reapplies saved grouped reservations', () {
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
          .map((reservation) => '${reservation.stockId}:${reservation.quantity}')
          .toList(),
      <String>['1:2', '2:2'],
    );

    final updatedProduct = provider.getProductById(1)!;
    expect(updatedProduct.stock!.firstWhere((stock) => stock.id == 1).quantity, 0);
    expect(updatedProduct.stock!.firstWhere((stock) => stock.id == 2).quantity, 1);
  });

  test('increment beyond exhausted single stock uses another stock row instead of null overflow',
      () async {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);

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
      cartItem: provider.cartItems.firstWhere((item) => item.selectedStock?.id == 1),
      newQuantity: 6,
      localProductProvider: provider,
      selectionResolver: (currentProduct, stockOptions) async {
        expect(stockOptions.map((stock) => stock.id).toList(), <int?>[2]);
        final selectedStock = stockOptions.first;
        return CartQuantityStockSelection(
          selectedStock: selectedStock,
          stockGroupIds: provider.getSelectionStockIds(selectedStock: selectedStock),
        );
      },
    );

    expect(result.changed, isTrue);
    expect(result.appliedQuantity, 5);

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

  test('increment beyond exhausted grouped stock adds a new stock row instead of null overflow',
      () async {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);

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
      cartItem: provider.cartItems.firstWhere((item) => item.stockGroupIds.length == 2),
      newQuantity: 6,
      localProductProvider: provider,
      selectionResolver: (currentProduct, stockOptions) async {
        expect(stockOptions.map((stock) => stock.id).toList(), <int?>[3]);
        final selectedStock = stockOptions.first;
        return CartQuantityStockSelection(
          selectedStock: selectedStock,
          stockGroupIds: provider.getSelectionStockIds(selectedStock: selectedStock),
        );
      },
    );

    expect(result.changed, isTrue);
    expect(result.appliedQuantity, 5);

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

  test('increment is blocked when no alternative stock remains', () async {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);

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
      cartItem: provider.cartItems.firstWhere((item) => item.selectedStock?.id == 1),
      newQuantity: 6,
      localProductProvider: provider,
      selectionResolver: (_, __) async {
        fail('Selection should not be requested when no alternative stock exists.');
      },
      onBlocked: (message) {
        blockedMessage = message;
      },
    );

    expect(result.changed, isFalse);
    expect(result.appliedQuantity, 5);
    expect(blockedMessage, 'Selected stock is exhausted. No other stock is available.');
    expect(provider.cartItems, hasLength(1));
    expect(provider.cartItems.first.quantity, 5);
    expect(provider.cartItems.first.stockDeducted, 5);
  });
}
