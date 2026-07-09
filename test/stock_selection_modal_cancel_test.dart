/// F26 (docs/cart_billing_flows_analysis.csv): when a product has multiple
/// stock pricing groups, ProductCartHelper shows the StockSelectionModal so
/// the cashier can choose a batch. If the cashier dismisses that modal
/// (close icon / outside tap) without picking a batch, the product must NOT
/// be added, and the cashier must see an explicit "not added" toast rather
/// than the add silently doing nothing.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/models/get_general_settings.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
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
    hiveDir =
        await Directory.systemTemp.createTemp('epos_stock_modal_cancel_');
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

  Future<BuildContext> pumpHelperContext(
    WidgetTester tester,
    LocalProductProvider provider,
  ) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocalProductProvider>.value(value: provider),
          ChangeNotifierProvider<GeneralSettingsProvider>(
            create: (_) => _FakeGeneralSettingsProvider(stockEnabled: true),
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
          ChangeNotifierProvider<AppSettingsProvider>(
            create: (_) => AppSettingsProvider(),
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

  group('ProductCartHelper.handleProductSelection stock modal cancel', () {
    GetProduct buildTwoBatchProduct() {
      return GetProduct(
        productId: 12,
        productName: 'Basmati Rice 5kg',
        unit: 'PCS',
        price: ProductPrice(price: '20'),
        mrp: '25',
        stock: <Stock>[
          Stock(
            id: 101,
            productId: 12,
            storeId: 1,
            quantity: 10,
            price: '18',
            mrp: '22',
          ),
          Stock(
            id: 102,
            productId: 12,
            storeId: 1,
            quantity: 10,
            price: '24',
            mrp: '28',
          ),
        ],
      );
    }

    testWidgets(
        'dismissing the stock-batch modal without a selection aborts the add and shows a not-added toast',
        (tester) async {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final product = buildTwoBatchProduct();
      provider.initializeProducts([product]);

      final context = await pumpHelperContext(tester, provider);

      // ignore: unawaited_futures
      ProductCartHelper.handleProductSelection(
        context: context,
        product: product,
        quantity: 1,
      );

      // Wait for the multi-batch modal to appear.
      await tester.pump();
      for (var i = 0;
          i < 20 && !tester.any(find.text('Multiple Stock Options Available'));
          i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Multiple Stock Options Available'), findsOneWidget);

      // Cashier dismisses the modal via the close icon rather than picking a
      // batch. The default test viewport can render the icon partially
      // behind the modal's own barrier in this tree, so skip the hit-test
      // visibility check (warnIfMissed) — the tap itself is what we're
      // asserting reaches the real onPressed handler.
      await tester.tap(find.byIcon(Icons.close), warnIfMissed: false);
      await tester.pumpAndSettle();

      // The product must not have been added to the cart...
      expect(provider.cartItems, isEmpty);
      // ...and the cashier must see an explicit "not added" toast rather
      // than silence.
      expect(
        find.text('No batch selected — item was not added to cart'),
        findsOneWidget,
      );

      // Flush the overlay auto-dismiss timer (2s) so no pending timer trips
      // the test framework's invariant check on teardown.
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
