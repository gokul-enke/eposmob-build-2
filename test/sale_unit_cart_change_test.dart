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
    test('changes base row to sale unit reinterpreting the displayed number',
        () {
      // Semantics: the on-screen number is preserved when switching units.
      // 24 PCS -> switch to CASE means "24 CASE", so base = 24 * 12 = 288.
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
      expect(item.quantity, 288); // base = 24 CASE * 12
      expect(item.displayQuantity, 24); // displayed number unchanged
      expect(item.displayPrice, 120);
      expect(item.displayMrp, 144);
      expect(item.saleUnitId, 10);
      expect(item.displayUnitName, 'CASE');

      final payload = provider.buildOrderItemsPayload();
      expect(payload.single['quantity'], 24);
      expect(payload.single['price'], 120);
      expect(payload.single['mrp'], 144);
      expect(payload.single['sale_unit_id'], 10);
    });

    test('changes sale-unit row back to base reinterpreting the displayed number',
        () {
      // Cart holds 24 base PCS shown as 2 CASE. Switching back to PCS keeps the
      // displayed "2", so base becomes 2 PCS.
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
      expect(item.quantity, 2); // displayed 2 CASE -> 2 PCS
      expect(item.displayQuantity, 2);
      expect(item.displayPrice, 10);
      expect(item.saleUnitId, isNull);
      expect(item.displayUnitName, 'PCS');

      final payload = provider.buildOrderItemsPayload();
      expect(payload.single['quantity'], 2);
      expect(payload.single['price'], 10);
      expect(payload.single.containsKey('sale_unit_id'), isFalse);
    });

    test('merges into an existing target unit cart row', () {
      // Base row: 5 PCS. CASE row: 24 base PCS shown as 2 CASE.
      // Switching the CASE row to PCS reinterprets its displayed 2 as 2 PCS,
      // then merges into the existing base row: 5 + 2 = 7.
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
      expect(item.quantity, 7); // 5 + 2
      expect(item.displayQuantity, 7);
    });
  });
}
