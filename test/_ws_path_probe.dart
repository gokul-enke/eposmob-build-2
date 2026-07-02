import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/helpers/cart_quantity_stock_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDir;
  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_ws_path_');
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

  Stock stock() => Stock(id: 1, productId: 1, storeId: 1, storeName: 'S', quantity: 100, price: '10', mrp: '12', purchasePrice: '8', taxRate: '5', unit: 'PCS', hsnCode: '1', wholesalePrice: '8', wholesaleMinUnit: 5);
  GetProduct product() => GetProduct(productId: 1, productName: 'P1', price: ProductPrice(price: '10'), mrp: '12', purchasePrice: '8', unit: 'PCS', stock: [stock()]);

  test('helper path: increment with explicit price then decrease via sync', () async {
    final provider = LocalProductProvider()..setStockEnabled(true);
    provider.initializeProducts([product()]);
    provider.addToCart(product: product(), quantity: 3, selectedStock: stock());
    expect(provider.cartItems.first.price, 10.0);
    provider.addToCart(product: product(), quantity: 3, price: provider.cartItems.first.price, isIncreamentUsingCompactQuantityControl: true, selectedStock: stock());
    expect(provider.cartItems.first.quantity, 6);
    expect(provider.cartItems.first.price, 8.0);
    final item = provider.cartItems.first;
    final result = await CartQuantityStockHelper.syncCartItemQuantity(cartItem: item, newQuantity: 3, localProductProvider: provider);
    expect(result.changed, isTrue);
    expect(provider.cartItems.first.price, 10.0);
  });

  test('helper path: explicit retail price on new add at wholesale qty stays retail', () {
    final provider = LocalProductProvider()..setStockEnabled(true);
    provider.initializeProducts([product()]);
    provider.addToCart(product: product(), quantity: 8, price: 10.0, selectedStock: stock());
    expect(provider.cartItems.first.price, 10.0);
  });

  test('decrementCartItem reverts wholesale', () {
    final provider = LocalProductProvider()..setStockEnabled(true);
    provider.initializeProducts([product()]);
    provider.addToCart(product: product(), quantity: 8, selectedStock: stock());
    expect(provider.cartItems.first.price, 8.0);
    provider.decrementCartItem(1, stock());
    provider.decrementCartItem(1, stock());
    provider.decrementCartItem(1, stock());
    expect(provider.cartItems.first.quantity, 5);
    expect(provider.cartItems.first.price, 8.0);
    provider.decrementCartItem(1, stock());
    expect(provider.cartItems.first.quantity, 4);
    expect(provider.cartItems.first.price, 10.0);
  });
}
