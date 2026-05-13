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
    hiveDir = await Directory.systemTemp.createTemp('epos_unit_change_test_');
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
      'general_stock_enabled': false,
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

  GetProduct buildProduct() => GetProduct(
        productId: 1,
        productName: 'Rice',
        unit: 'PCS',
        price: ProductPrice(price: '10'),
        mrp: '12',
        saleUnits: [
          SaleUnit(
            id: 10,
            unitId: 100,
            unitName: 'CASE',
            conversionRate: '12',
          ),
          SaleUnit(
            id: 11,
            unitId: 101,
            unitName: 'BOX',
            conversionRate: '6',
          ),
        ],
      );

  group('changeCartItemSaleUnit', () {
    test('changes base row to sale unit without changing base quantity', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct();
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 24, price: 10, mrp: 12);

      final changed = provider.changeCartItemSaleUnit(
        product.productId!,
        null,
        newSaleUnitId: 10,
        newSaleUnitName: 'CASE',
        newSaleUnitConversionRate: 12,
      );

      expect(changed, isTrue);
      expect(provider.cartItems, hasLength(1));
      final item = provider.cartItems.single;
      expect(item.quantity, 24);
      expect(item.displayQuantity, 2);
      expect(item.displayPrice, 120);
      expect(item.displayMrp, 144);
      expect(item.saleUnitId, 10);
      expect(item.displayUnitName, 'CASE');

      final payload = provider.buildOrderItemsPayload();
      expect(payload.single['quantity'], 2);
      expect(payload.single['price'], 120);
      expect(payload.single['mrp'], 144);
      expect(payload.single['sale_unit_id'], 10);
    });

    test('changes sale-unit row back to base unit without changing quantity',
        () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct();
      provider.initializeProducts([product]);
      provider.addToCart(
        product: product,
        quantity: 24,
        price: 10,
        mrp: 12,
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 12,
      );

      final changed = provider.changeCartItemSaleUnit(
        product.productId!,
        null,
        currentSaleUnitId: 10,
      );

      expect(changed, isTrue);
      expect(provider.cartItems, hasLength(1));
      final item = provider.cartItems.single;
      expect(item.quantity, 24);
      expect(item.displayQuantity, 24);
      expect(item.displayPrice, 10);
      expect(item.saleUnitId, isNull);
      expect(item.displayUnitName, 'PCS');

      final payload = provider.buildOrderItemsPayload();
      expect(payload.single['quantity'], 24);
      expect(payload.single['price'], 10);
      expect(payload.single.containsKey('sale_unit_id'), isFalse);
    });

    test('merges into an existing target unit cart row', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct();
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 5, price: 10, mrp: 12);
      provider.addToCart(
        product: product,
        quantity: 24,
        price: 10,
        mrp: 12,
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 12,
      );

      final changed = provider.changeCartItemSaleUnit(
        product.productId!,
        null,
        currentSaleUnitId: 10,
      );

      expect(changed, isTrue);
      expect(provider.cartItems, hasLength(1));
      final item = provider.cartItems.single;
      expect(item.saleUnitId, isNull);
      expect(item.quantity, 29);
      expect(item.displayQuantity, 29);
    });
  });
}
