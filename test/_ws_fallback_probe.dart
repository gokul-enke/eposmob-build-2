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
    hiveDir = await Directory.systemTemp.createTemp('epos_ws_fb_');
    Hive.init(hiveDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(HiveStringValueAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(HiveLocalCartItemAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(HiveSavedOrderAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(HiveProductAdapter());
    await Hive.openBox<HiveProduct>('products');
    await Hive.openBox<HiveLocalCartItem>('cart_items');
    await Hive.openBox<HiveSavedOrder>('saved_orders');
    await Hive.openBox<HiveSavedOrder>('confirmed_orders');
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({'general_stock_enabled': true});
    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
  });
  tearDownAll(() async { await Hive.close(); await hiveDir.delete(recursive: true); });

  test('fallback keeps wholesale when stock.price missing on decrease', () {
    final stockNoRetail = Stock(id: 1, productId: 1, storeId: 1, storeName: 'S', quantity: 100, price: null, mrp: '12', purchasePrice: '8', taxRate: '5', unit: 'PCS', hsnCode: '1', wholesalePrice: '8', wholesaleMinUnit: 5);
    final product = GetProduct(productId: 1, productName: 'P1', price: null, mrp: '12', purchasePrice: '8', unit: 'PCS', stock: [stockNoRetail]);
    final provider = LocalProductProvider()..setStockEnabled(true);
    provider.initializeProducts([product]);
    provider.addToCart(product: product, quantity: 8, selectedStock: stockNoRetail);
    expect(provider.cartItems.first.price, 8.0);
    provider.setCartItemQuantity(1, stockNoRetail, 3);
    expect(provider.cartItems.first.price, 8.0, reason: 'BUG: falls back to stale wholesale when retail unavailable');
  });

  test('manual override blocks wholesale revert', () {
    final stock = Stock(id: 1, productId: 1, storeId: 1, storeName: 'S', quantity: 100, price: '10', mrp: '12', purchasePrice: '8', taxRate: '5', unit: 'PCS', hsnCode: '1', wholesalePrice: '8', wholesaleMinUnit: 5);
    final product = GetProduct(productId: 1, productName: 'P1', price: ProductPrice(price: '10'), mrp: '12', purchasePrice: '8', unit: 'PCS', stock: [stock]);
    final provider = LocalProductProvider()..setStockEnabled(true);
    provider.initializeProducts([product]);
    provider.addToCart(product: product, quantity: 8, selectedStock: stock);
    provider.updateItemPrice(1, stock, 8.0);
    provider.setCartItemQuantity(1, stock, 3);
    expect(provider.cartItems.first.price, 8.0);
  });
}
