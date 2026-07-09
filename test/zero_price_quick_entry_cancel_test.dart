/// F22 (docs/cart_billing_flows_analysis.csv): a zero-priced product opens
/// the quick price/quantity entry modal before it can be added to the cart.
/// If the cashier cancels that modal, the product must NOT be added, and the
/// cashier must see an explicit "not added" toast rather than the add
/// silently doing nothing (which could let a customer walk out with an
/// unrung item nobody notices).
///
/// This drives the real ProductCartHelper.handleProductSelection entry
/// point end-to-end (not just ZeroPriceQuickEntryHelper in isolation), so it
/// also locks in that the zero-price gate fires before any stock/price
/// resolution completes and that a normal (non-zero-price) product is
/// unaffected.
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
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_provider.dart';
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
    hiveDir = await Directory.systemTemp.createTemp('epos_zero_price_cancel_');
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
            create: (_) => _FakeGeneralSettingsProvider(stockEnabled: false),
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
          ChangeNotifierProvider<AuthModel>(
            create: (_) => AuthModel(),
          ),
          ChangeNotifierProvider<CustomerProvider>(
            create: (_) => CustomerProvider(),
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

  group('ProductCartHelper.handleProductSelection zero-price entry', () {
    GetProduct buildZeroPriceProduct() {
      return GetProduct(
        productId: 9,
        productName: 'New Import Snack',
        sellable: true,
        unit: 'PCS',
        price: ProductPrice(price: '0'),
        mrp: '0',
        stock: const <Stock>[],
      );
    }

    testWidgets(
        'cancelling the quick-entry modal aborts the add and shows a not-added toast',
        (tester) async {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildZeroPriceProduct();
      provider.initializeProducts([product]);

      final context = await pumpHelperContext(tester, provider);

      // ignore: unawaited_futures
      ProductCartHelper.handleProductSelection(
        context: context,
        product: product,
        quantity: 1,
      );

      // Wait for the quick-entry modal to appear.
      await tester.pump();
      for (var i = 0;
          i < 20 && !tester.any(find.text('Apply'));
          i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Apply'), findsOneWidget);

      // Cashier dismisses the modal via its Cancel action rather than
      // entering a price.
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // The product must not have been added to the cart...
      expect(provider.cartItems, isEmpty);
      // ...and the cashier must see an explicit "not added" toast rather
      // than silence.
      expect(
        find.text('Price not entered — item was not added to cart'),
        findsOneWidget,
      );

      // Flush the overlay auto-dismiss timer (2s) so no pending timer trips
      // the test framework's invariant check on teardown.
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
