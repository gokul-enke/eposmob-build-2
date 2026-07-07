/// ProductCartHelper.handleProductSelection: products with `sellable ==
/// false` must be rejected up front with a scaffold error before any
/// customer/stock lookups, and the cart must stay empty.
///
/// This lives in its own file (rather than alongside
/// test/cart_oversell_confirmation_test.dart) because two testWidgets tests
/// that each drive a real Flutter dialog round-trip against a Hive-backed
/// LocalProductProvider were observed to reliably hang the second test when
/// run back-to-back in the same file/isolate on this Windows environment.
/// Splitting into separate files avoids that environment/isolation issue.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/models/get_general_settings.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/general_settings_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support/hive_test_teardown.dart';

class _FakeGeneralSettingsProvider extends GeneralSettingsProvider {
  _FakeGeneralSettingsProvider({required this.stockEnabled});

  final bool stockEnabled;

  @override
  Future<void> fetchGeneralSettings() async {}

  @override
  GeneralSettings? get generalSettings =>
      GeneralSettings(stockEnabled: stockEnabled);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_sellable_reject_');
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
    SharedPreferences.setMockInitialValues({'general_stock_enabled': false});
    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
  });

  tearDown(awaitPendingHiveBoxWrites);
  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

  Future<BuildContext> pumpHelperContext(
    WidgetTester tester,
    LocalProductProvider provider, {
    bool stockEnabled = false,
  }) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocalProductProvider>.value(value: provider),
          ChangeNotifierProvider<GeneralSettingsProvider>(
            create: (_) =>
                _FakeGeneralSettingsProvider(stockEnabled: stockEnabled),
          ),
          ChangeNotifierProvider<MasterDataProvider>(
            create: (_) => MasterDataProvider(),
          ),
          ChangeNotifierProvider<StoreSessionProvider>(
            create: (_) => StoreSessionProvider(),
          ),
          ChangeNotifierProvider<CustomerSelectionProvider>(
            create: (_) => CustomerSelectionProvider(),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    return capturedContext;
  }

  group('ProductCartHelper.handleProductSelection sellable == false', () {
    GetProduct buildNonSellableProduct() {
      return GetProduct(
        productId: 5,
        productName: 'Wholesale Crate',
        sellable: false,
        unit: 'PCS',
        price: ProductPrice(price: '20'),
        mrp: '25',
        stock: const <Stock>[],
      );
    }

    // Both cases (rejected / unaffected) are driven from a single
    // testWidgets closure. Two separate testWidgets tests that each pump a
    // fresh MaterialApp + Hive-backed LocalProductProvider tree and call
    // ProductCartHelper.handleProductSelection were observed to reliably
    // hang the second test on this Windows environment when run
    // back-to-back in the same file — not specific to dialogs; consolidating
    // into one test avoids the issue.
    testWidgets(
        'rejects non-sellable product but leaves sellable products unaffected',
        (tester) async {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final nonSellable = buildNonSellableProduct();
      final sellable = GetProduct(
        productId: 6,
        productName: 'Retail Crate',
        sellable: true,
        unit: 'PCS',
        price: ProductPrice(price: '20'),
        mrp: '25',
        stock: const <Stock>[],
      );
      provider.initializeProducts([nonSellable, sellable]);

      final context =
          await pumpHelperContext(tester, provider, stockEnabled: false);

      await ProductCartHelper.handleProductSelection(
        context: context,
        product: nonSellable,
        quantity: 1,
      );
      await tester.pump();

      expect(provider.cartItems, isEmpty);
      expect(find.text('Wholesale Crate is marked as not sellable'),
          findsOneWidget);

      // Flush the overlay auto-dismiss timer (2s) before the next add.
      await tester.pump(const Duration(seconds: 2));

      await ProductCartHelper.handleProductSelection(
        context: context,
        product: sellable,
        quantity: 1,
      );
      await tester.pump();

      expect(provider.cartItems, hasLength(1));
      expect(provider.cartItems.single.product.productId, 6);
      expect(find.text('Retail Crate is marked as not sellable'),
          findsNothing);

      await tester.pump(const Duration(seconds: 2));
    });
  });
}
