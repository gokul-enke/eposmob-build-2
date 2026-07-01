import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/get_product.dart';
import 'test_support/hive_test_teardown.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_bc_test_');
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

  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

  group('Barcode Index & Filtering', () {
    test('initializeProducts indexes base product barcodes', () {
      final provider = LocalProductProvider();
      final product = GetProduct(
        productId: 1,
        barcode: '123456',
        productName: 'P1',
        unit: 'PCS',
      );
      provider.initializeProducts([product]);
      expect(provider.filterProductByBarcode(barCode: '123456'), hasLength(1));
    });

    test('initializeProducts indexes sale unit barcodes', () {
      final provider = LocalProductProvider();
      final product = GetProduct(
        productId: 1,
        barcode: 'BASE123',
        productName: 'P1',
        unit: 'PCS',
        saleUnits: [
          SaleUnit(
            id: 10,
            unitName: 'CASE',
            barcode: 'CASE123',
            conversionRate: '12',
          ),
        ],
      );
      provider.initializeProducts([product]);
      expect(provider.filterProductByBarcode(barCode: 'CASE123'), hasLength(1));
      expect(
        provider.filterProductByBarcode(barCode: 'CASE123').first.productId,
        1,
      );
    });

    test('addProduct updates barcode index', () {
      final provider = LocalProductProvider();
      provider.initializeProducts([]);
      final product = GetProduct(
        productId: 1,
        barcode: 'NEW123',
        productName: 'P1',
        unit: 'PCS',
      );
      provider.addProduct(product);
      expect(provider.filterProductByBarcode(barCode: 'NEW123'), hasLength(1));
    });

    test('filterProductByBarcode returns empty for unknown barcode', () {
      final provider = LocalProductProvider();
      provider.initializeProducts([]);
      expect(provider.filterProductByBarcode(barCode: 'UNKNOWN'), isEmpty);
    });

    test('filterProductByBarcode normalizes whitespace', () {
      final provider = LocalProductProvider();
      final product = GetProduct(
        productId: 1,
        barcode: 'TRIM123',
        productName: 'P1',
        unit: 'PCS',
      );
      provider.initializeProducts([product]);
      expect(
        provider.filterProductByBarcode(barCode: '  TRIM123  '),
        hasLength(1),
      );
    });

    test('multiple products with same barcode are all returned', () {
      final provider = LocalProductProvider();
      final productOne = GetProduct(
        productId: 1,
        barcode: 'SHARED',
        productName: 'P1',
        unit: 'PCS',
      );
      final productTwo = GetProduct(
        productId: 2,
        barcode: 'SHARED',
        productName: 'P2',
        unit: 'PCS',
      );
      provider.initializeProducts([productOne, productTwo]);
      final results = provider.filterProductByBarcode(barCode: 'SHARED');
      expect(results.length, 2);
      expect(results.map((p) => p.productId).toList()..sort(), [1, 2]);
    });

    test('updateProduct refreshes barcode index', () {
      final provider = LocalProductProvider();
      final product = GetProduct(
        productId: 1,
        barcode: 'OLD',
        productName: 'P1',
        unit: 'PCS',
      );
      provider.initializeProducts([product]);
      expect(provider.filterProductByBarcode(barCode: 'OLD'), hasLength(1));

      final updatedProduct = GetProduct(
        productId: 1,
        barcode: 'NEW',
        productName: 'P1',
        unit: 'PCS',
      );
      provider.updateProduct(updatedProduct);
      expect(provider.filterProductByBarcode(barCode: 'OLD'), isEmpty);
      expect(provider.filterProductByBarcode(barCode: 'NEW'), hasLength(1));
    });

    test('deleteProduct removes barcode index entry', () {
      final provider = LocalProductProvider();
      final product = GetProduct(
        productId: 1,
        barcode: 'DEL123',
        productName: 'P1',
        unit: 'PCS',
      );
      provider.initializeProducts([product]);
      expect(provider.filterProductByBarcode(barCode: 'DEL123'), hasLength(1));

      provider.deleteProduct(1);
      expect(provider.filterProductByBarcode(barCode: 'DEL123'), isEmpty);
    });
  });

  group('Store Filtering', () {
    test('getStockOptionsForStore returns all positive stocks when no store filter',
        () {
      final provider = LocalProductProvider();
      final product = GetProduct(
        productId: 1,
        productName: 'P1',
        unit: 'PCS',
        stock: [
          Stock(id: 1, quantity: 5, price: '10', mrp: '12', storeId: 1),
          Stock(id: 2, quantity: 3, price: '10', mrp: '12', storeId: 2),
        ],
      );
      provider.initializeProducts([product]);
      final stocks = provider.getStockOptionsForStore(product);
      expect(stocks.length, 2);
    });

    test('getStockOptionsForStore filters by active store id', () {
      final provider = LocalProductProvider();
      final product = GetProduct(
        productId: 1,
        productName: 'P1',
        unit: 'PCS',
        stock: [
          Stock(id: 1, quantity: 5, price: '10', mrp: '12', storeId: 1),
          Stock(id: 2, quantity: 3, price: '10', mrp: '12', storeId: 2),
        ],
      );
      provider.initializeProducts([product]);
      final stocks = provider.getStockOptionsForStore(
        product,
        activeStoreId: 2,
      );
      expect(stocks.length, 1);
      expect(stocks.first.id, 2);
    });

    test('getStockOptionsForStore falls back to store name when id is null', () {
      final provider = LocalProductProvider();
      final product = GetProduct(
        productId: 1,
        productName: 'P1',
        unit: 'PCS',
        stock: [
          Stock(
            id: 1,
            quantity: 5,
            price: '10',
            mrp: '12',
            storeName: 'Main Store',
          ),
          Stock(
            id: 2,
            quantity: 3,
            price: '10',
            mrp: '12',
            storeName: 'Branch',
          ),
        ],
      );
      provider.initializeProducts([product]);
      final stocks = provider.getStockOptionsForStore(
        product,
        activeStoreName: 'Main Store',
      );
      expect(stocks.length, 1);
      expect(stocks.first.id, 1);
    });

    test('getStockOptionsForStore excludes zero and negative quantities', () {
      final provider = LocalProductProvider();
      final product = GetProduct(
        productId: 1,
        productName: 'P1',
        unit: 'PCS',
        stock: [
          Stock(id: 1, quantity: 5, price: '10', mrp: '12'),
          Stock(id: 2, quantity: 0, price: '10', mrp: '12'),
          Stock(id: 3, quantity: -1, price: '10', mrp: '12'),
        ],
      );
      provider.initializeProducts([product]);
      final stocks = provider.getStockOptions(product);
      expect(stocks.length, 1);
      expect(stocks.first.id, 1);
    });
  });
}
