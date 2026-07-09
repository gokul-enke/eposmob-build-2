/// F49 (docs/cart_billing_flows_analysis.csv): originally hypothesized (from
/// static reading of `_findVariantById`/`_resolveVariantPrice`) that a
/// variant deactivated server-side after being added to an open cart line
/// would silently lose its price on the next refresh (e.g. a quantity
/// change). Dynamic verification below DISPROVES that: `_refreshCartItemPricing`
/// (local_product_provider.dart:718-733) always resolves pricing against
/// `item.product` — the product/variant snapshot captured on the
/// `LocalCartItem` at add-to-cart time — and never re-reads the live
/// `_products` catalog. So deactivating/removing a variant afterward has no
/// effect on an already-added line's price; the cashier keeps selling at the
/// price/attributes the item was added with.
///
/// This test locks in that CORRECT frozen-snapshot behavior as a regression
/// guard. The CSV's F49 row has been corrected to match; if this assertion
/// ever starts failing (price no longer stays at the original variant rate),
/// that is a real regression worth investigating, not evidence of the
/// originally-hypothesized bug being "fixed".
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support/hive_test_teardown.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir =
        await Directory.systemTemp.createTemp('epos_variant_deactivated_');
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
    SharedPreferences.setMockInitialValues({'general_stock_enabled': true});
    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
  });

  tearDown(awaitPendingHiveBoxWrites);
  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

  Stock buildStock({required int id, required num quantity, int? variantId}) {
    return Stock(
      id: id,
      productId: 1,
      productVariantId: variantId,
      storeId: 1,
      quantity: quantity,
      price: '10',
      mrp: '12',
    );
  }

  test(
      'quantity refresh on a deactivated variant keeps the original variant price (frozen cart-line snapshot, not a live catalog lookup)',
      () {
    final provider = LocalProductProvider();
    provider.setStockEnabled(true);

    final variant = ProductVariant(
      id: 41,
      price: 500,
      mrp: 600,
      active: true,
      attributes: const {'COLOR': 'Green', 'SIZE': 'M'},
    );
    final scopedStock = buildStock(id: 1, quantity: 10, variantId: 41);
    final product = GetProduct(
      productId: 1,
      productName: 'Hoodie',
      unit: 'PCS',
      price: ProductPrice(price: '50'),
      mrp: '60',
      stock: <Stock>[scopedStock],
      variants: <ProductVariant>[variant],
    );

    provider.initializeProducts([product]);

    // Cashier adds the Green/M hoodie at its variant price (500), e.g. onto
    // a held order.
    provider.addToCart(
      product: product,
      quantity: 1,
      selectedStock: scopedStock,
      variantId: 41,
      variantAttributes: const {'COLOR': 'Green', 'SIZE': 'M'},
    );

    final addedItem = provider.cartItems.single;
    expect(addedItem.variantId, 41);
    expect(addedItem.price, 500,
        reason: 'line should price at the variant rate when added');

    // Admin deactivates the variant server-side (e.g. discontinued) before
    // the order is confirmed. Simulate the sync by re-initializing the
    // product catalog with the same variant now inactive.
    final deactivatedVariant = variant.copyWith(active: false);
    final refreshedProduct = GetProduct(
      productId: 1,
      productName: 'Hoodie',
      unit: 'PCS',
      price: ProductPrice(price: '50'),
      mrp: '60',
      stock: <Stock>[scopedStock],
      variants: <ProductVariant>[deactivatedVariant],
    );
    provider.initializeProducts([refreshedProduct]);

    // Cashier reopens the held order / bumps the quantity — this triggers a
    // price refresh via _refreshCartItemPricing -> _resolveUnitPrice.
    provider.setCartItemQuantity(1, scopedStock, 2, variantId: 41);

    final refreshedItem = provider.cartItems.single;

    // Correct/safe behavior: the line keeps pricing from its own frozen
    // product/variant snapshot, not from the live (now-deactivated-variant)
    // catalog, so the cashier keeps selling at the original variant price.
    expect(refreshedItem.variantId, 41,
        reason: 'variantId itself is untouched on the cart line');
    expect(
      refreshedItem.price,
      500,
      reason:
          'Cart line pricing must stay frozen to the product/variant '
          'snapshot captured at add-to-cart time. If this assertion starts '
          'failing (price no longer 500), a live catalog re-lookup has been '
          'introduced into _refreshCartItemPricing — re-check whether it '
          'now needs guarding against a deactivated variant before treating '
          'this as a fix.',
    );
  });
}
