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
    hiveDir = await Directory.systemTemp.createTemp('epos_ol_test_');
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
    String basePrice = '10',
    String mrp = '12',
    List<Stock> stocks = const [],
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
    );
  }

  group('Saved Order CRUD', () {
    test('saveCurrentCartAsOrder preserves grouped stock and sale units', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final stockOne = buildStock(id: 1, quantity: 2, price: '10', mrp: '12');
      final stockTwo = buildStock(id: 2, quantity: 3, price: '10', mrp: '12');
      final product = buildProduct(
        productId: 1,
        stocks: [stockOne, stockTwo],
      );
      provider.initializeProducts([product]);
      provider.addToCart(
        product: product,
        quantity: 4,
        selectedStock: stockOne.copyWith(quantity: 5),
        stockGroupIds: const [1, 2],
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 12,
      );

      final order = provider.saveCurrentCartAsOrder(status: 'saved');
      expect(order.items.length, 1);
      expect(order.items.first.stockGroupIds, [1, 2]);
      expect(order.items.first.saleUnitId, 10);
      expect(order.items.first.saleUnitName, 'CASE');
      expect(order.items.first.saleUnitConversionRate, 12);
      expect(order.status, 'saved');
    });

    test('loadOrderForEditing restores stock reservations', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final stockOne = buildStock(id: 1, quantity: 5, price: '10', mrp: '12');
      final stockTwo = buildStock(id: 2, quantity: 5, price: '10', mrp: '12');
      final product = buildProduct(
        productId: 1,
        stocks: [stockOne, stockTwo],
      );
      provider.initializeProducts([product]);
      provider.addToCart(
        product: product,
        quantity: 4,
        selectedStock: stockOne.copyWith(quantity: 10),
        stockGroupIds: const [1, 2],
      );

      final savedOrder = provider.saveCurrentCartAsOrder(status: 'saved');

      // saveCurrentCartAsOrder does not clear the cart, so stock is still
      // reserved. Release it with clearCart (which restores stock) before
      // reloading the order for editing.
      provider.clearCart();
      provider.loadOrderForEditing(savedOrder.id);

      expect(provider.cartItems.length, 1);
      expect(provider.cartItems.first.quantity, 4);
      expect(provider.cartItems.first.stockGroupIds, [1, 2]);
      expect(provider.cartItems.first.stockDeducted, 4);

      final updatedProduct = provider.getProductById(1)!;
      expect(updatedProduct.stock!.firstWhere((s) => s.id == 1).quantity, 1);
      expect(updatedProduct.stock!.firstWhere((s) => s.id == 2).quantity, 5);
    });

    test('switching saved orders releases current stock before reloading', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final stock = buildStock(id: 1, quantity: 10, price: '10', mrp: '12');
      final product = buildProduct(productId: 1, stocks: [stock]);
      provider.initializeProducts([product]);

      provider.addToCart(product: product, quantity: 3, selectedStock: stock);
      final firstOrder = provider.saveCurrentCartAsOrder(status: 'saved');
      provider.clearCart();

      provider.addToCart(product: product, quantity: 2, selectedStock: stock);
      final secondOrder = provider.saveCurrentCartAsOrder(status: 'saved');
      provider.clearCart();

      provider.loadOrderForEditing(firstOrder.id);
      expect(provider.getProductById(1)!.stock!.first.quantity, 7);

      provider.loadOrderForEditing(secondOrder.id);
      expect(provider.cartItems.single.quantity, 2);
      expect(provider.currentOrder?.id, secondOrder.id);
      expect(provider.getProductById(1)!.stock!.first.quantity, 8);
    });

    test('rapid local saves get unique ids', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct(productId: 1);
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 1);

      final firstOrder = provider.saveCurrentCartAsOrder();
      final secondOrder = provider.saveCurrentCartAsOrder();

      expect(firstOrder.id, isNot(secondOrder.id));
      expect(firstOrder.orderNumber, isNot(secondOrder.orderNumber));
    });

    test('clearCart restores all deducted stock', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final stock = buildStock(id: 1, quantity: 5, price: '10', mrp: '12');
      final product = buildProduct(productId: 1, stocks: [stock]);
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 3, selectedStock: stock);

      expect(provider.getProductById(1)!.stock!.first.quantity, 2);
      provider.clearCart();
      expect(provider.getProductById(1)!.stock!.first.quantity, 5);
      expect(provider.cartItems, isEmpty);
    });

    test('clearCartAfterOrder does not restore stock', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final stock = buildStock(id: 1, quantity: 5, price: '10', mrp: '12');
      final product = buildProduct(productId: 1, stocks: [stock]);
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 3, selectedStock: stock);

      expect(provider.getProductById(1)!.stock!.first.quantity, 2);
      provider.clearCartAfterOrder();
      expect(provider.getProductById(1)!.stock!.first.quantity, 2);
      expect(provider.cartItems, isEmpty);
    });

    test('updateSavedOrder replaces items and preserves metadata', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct(productId: 1, basePrice: '10');
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 1);
      final order = provider.saveCurrentCartAsOrder(
        customerName: 'Alice',
        customerPhone: '555-1234',
        status: 'saved',
      );

      // Modify cart
      provider.addToCart(product: product, quantity: 2);
      provider.updateSavedOrder(
        order.id,
        customerName: 'Bob',
        status: 'updated',
      );

      final updatedOrder = provider.findOrderById(order.id)!;
      expect(updatedOrder.items.length, 1);
      expect(updatedOrder.items.first.quantity, 3);
      expect(updatedOrder.customerName, 'Bob');
      // phone should be preserved from original
      expect(updatedOrder.customerPhone, '555-1234');
      expect(updatedOrder.status, 'updated');
    });

    test('deleteSavedOrder removes from list', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct(productId: 1);
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 1);
      final order = provider.saveCurrentCartAsOrder();
      expect(provider.savedOrders.length, 1);

      provider.deleteSavedOrder(order.id);
      expect(provider.savedOrders, isEmpty);
      expect(provider.findOrderById(order.id), isNull);
    });

    test('moveToConfirmedOrders creates CONF- prefix order', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct(productId: 1);
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 1);
      final order = provider.saveCurrentCartAsOrder();
      final confirmed = provider.moveToConfirmedOrders(order.id);

      expect(confirmed, isNotNull);
      expect(confirmed!.orderNumber.startsWith('CONF-'), isTrue);
      expect(provider.savedOrders, isEmpty);
      expect(provider.confirmedOrders.length, 1);
      expect(provider.confirmedOrders.first.orderNumber, confirmed.orderNumber);
    });

    test('discounts persist through save and load', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct(productId: 1, basePrice: '100');
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 1);
      provider.applyDiscount(flatDiscount: 10, percentageDiscount: 5);
      final order = provider.saveCurrentCartAsOrder();

      provider.clearCart();
      provider.loadOrderForEditing(order.id);

      final discounts = provider.getCurrentDiscount();
      expect(discounts['flatDiscount'], 10.0);
      expect(discounts['percentageDiscount'], 5.0);
    });
  });

  group('Stock-Enabled Cart Operations', () {
    test('removeFromCart restores only deducted stock', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final stock = buildStock(id: 1, quantity: 5, price: '10', mrp: '12');
      final product = buildProduct(productId: 1, stocks: [stock]);
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 8, selectedStock: stock);

      // Deducted 5, cart qty 8
      expect(provider.cartItems.first.stockDeducted, 5);
      expect(provider.getProductById(1)!.stock!.first.quantity, 0);

      provider.removeFromCart(1, stock);
      expect(provider.getProductById(1)!.stock!.first.quantity, 5);
      expect(provider.cartItems, isEmpty);
    });

    test('setCartItemQuantity increase deducts additional stock', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final stock = buildStock(id: 1, quantity: 5, price: '10', mrp: '12');
      final product = buildProduct(productId: 1, stocks: [stock]);
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 2, selectedStock: stock);
      expect(provider.getProductById(1)!.stock!.first.quantity, 3);

      provider.setCartItemQuantity(1, stock, 4);
      expect(provider.cartItems.first.quantity, 4);
      expect(provider.getProductById(1)!.stock!.first.quantity, 1);
    });

    test('setCartItemQuantity decrease restores stock', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final stock = buildStock(id: 1, quantity: 5, price: '10', mrp: '12');
      final product = buildProduct(productId: 1, stocks: [stock]);
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 4, selectedStock: stock);
      expect(provider.getProductById(1)!.stock!.first.quantity, 1);

      provider.setCartItemQuantity(1, stock, 2);
      expect(provider.cartItems.first.quantity, 2);
      expect(provider.getProductById(1)!.stock!.first.quantity, 3);
    });

    test('decrementCartItem restores one unit and removes at zero', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final stock = buildStock(id: 1, quantity: 5, price: '10', mrp: '12');
      final product = buildProduct(productId: 1, stocks: [stock]);
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 2, selectedStock: stock);
      expect(provider.getProductById(1)!.stock!.first.quantity, 3);

      provider.decrementCartItem(1, stock);
      expect(provider.cartItems.first.quantity, 1);
      expect(provider.getProductById(1)!.stock!.first.quantity, 4);

      provider.decrementCartItem(1, stock);
      expect(provider.cartItems, isEmpty);
      expect(provider.getProductById(1)!.stock!.first.quantity, 5);
    });

    test('merged grouped stock row increments preserve group ids', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final stockOne = buildStock(id: 1, quantity: 2, price: '10', mrp: '12');
      final stockTwo = buildStock(id: 2, quantity: 3, price: '10', mrp: '12');
      final product = buildProduct(productId: 1, stocks: [stockOne, stockTwo]);
      provider.initializeProducts([product]);

      provider.addToCart(
        product: product,
        quantity: 3,
        selectedStock: stockOne.copyWith(quantity: 5),
        stockGroupIds: const [1, 2],
      );
      provider.addToCart(
        product: product,
        quantity: 1,
        selectedStock: stockTwo.copyWith(quantity: 5),
        stockGroupIds: const [1, 2],
      );

      expect(provider.cartItems.length, 1);
      expect(provider.cartItems.first.stockGroupIds, [1, 2]);
      expect(provider.cartItems.first.quantity, 4);
    });

    test('different stock id creates separate cart row', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final stockOne = buildStock(id: 1, quantity: 5, price: '10', mrp: '12');
      final stockTwo = buildStock(id: 2, quantity: 5, price: '11', mrp: '13');
      final product = buildProduct(productId: 1, stocks: [stockOne, stockTwo]);
      provider.initializeProducts([product]);

      provider.addToCart(
          product: product, quantity: 1, selectedStock: stockOne);
      provider.addToCart(
          product: product, quantity: 1, selectedStock: stockTwo);

      expect(provider.cartItems.length, 2);
    });
  });
}
