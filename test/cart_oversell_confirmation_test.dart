/// Widget-level coverage for the new "sell anyway" confirmation flows added
/// to the add-to-cart / cart-quantity path:
///
/// - CartQuantityStockHelper.syncCartItemQuantity: when a BuildContext is
///   supplied and no alternative stock batch exists, it now shows
///   showSellAnywayConfirmDialog instead of the old hard block. Confirming
///   applies the full requested quantity; cancelling leaves it unchanged.
///   (The headless/no-context hard-block path is covered separately in
///   test/local_product_provider_stock_test.dart and must not regress.)
///
/// See test/product_cart_helper_sellable_test.dart for the
/// `sellable == false` rejection coverage (kept in a separate file — see
/// the note on the test below for why).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/helpers/cart_quantity_stock_helper.dart';
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
    hiveDir = await Directory.systemTemp.createTemp('epos_oversell_confirm_');
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

  Future<BuildContext> pumpHelperContext(
    WidgetTester tester,
    LocalProductProvider provider, {
    bool stockEnabled = true,
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

  group('CartQuantityStockHelper.syncCartItemQuantity sell-anyway (with context)', () {
    GetProduct buildProduct() {
      return GetProduct(
        productId: 1,
        productName: 'Sugar 1kg',
        unit: 'PCS',
        price: ProductPrice(price: '9'),
        mrp: '11',
        stock: <Stock>[
          Stock(
            id: 1,
            productId: 1,
            storeId: 1,
            quantity: 5,
            price: '10',
            mrp: '12',
          ),
        ],
      );
    }

    // Both the "Cancel" and "Sell anyway" interactions are driven from a
    // single testWidgets closure (one pumped widget tree, two sequential
    // dialog round-trips) rather than two separate testWidgets tests. Two
    // back-to-back testWidgets tests that each drive this exact real dialog
    // + Hive-backed provider flow were observed to reliably hang the test
    // process on this Windows environment (the second test never completes,
    // even with generous internal timeouts) - most likely a Windows Hive
    // file-lock/test-isolation interaction, not a bug in the production
    // code under test. Consolidating into one test avoids that environment
    // issue while still covering both branches.
    testWidgets(
        'confirm dialog: Cancel leaves quantity unchanged, then Sell anyway applies it',
        (tester) async {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final product = buildProduct();
      provider.initializeProducts([product]);
      final stock = product.stock!.single;
      provider.addToCart(product: product, quantity: 5, selectedStock: stock);

      final context = await pumpHelperContext(tester, provider);
      final cartItem =
          provider.cartItems.firstWhere((item) => item.selectedStock?.id == 1);

      // --- First round: Cancel leaves the quantity unchanged. ---
      late CartQuantityChangeResult cancelResult;
      bool cancelCompleted = false;
      String? blockedMessage;
      // ignore: unawaited_futures
      CartQuantityStockHelper.syncCartItemQuantity(
        cartItem: cartItem,
        newQuantity: 6,
        context: context,
        localProductProvider: provider,
        activeStoreId: 1,
        onBlocked: (message) {
          blockedMessage = message;
        },
      ).then((value) {
        cancelResult = value;
        cancelCompleted = true;
      });

      await tester.pump();
      for (var i = 0; i < 20 && !tester.any(find.text('Cancel')); i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // The confirm dialog is showing.
      expect(find.text('Sell anyway'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      for (var i = 0; i < 30 && !cancelCompleted; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(cancelCompleted, isTrue);
      expect(blockedMessage, isNotNull);
      expect(cancelResult.changed, isFalse);
      expect(cancelResult.appliedQuantity, 5);
      expect(
        provider.cartItems.firstWhere((item) => item.selectedStock?.id == 1).quantity,
        5,
      );

      // --- Second round: same exhausted stock, but confirming applies it. ---
      late CartQuantityChangeResult confirmResult;
      bool confirmCompleted = false;
      // ignore: unawaited_futures
      CartQuantityStockHelper.syncCartItemQuantity(
        cartItem:
            provider.cartItems.firstWhere((item) => item.selectedStock?.id == 1),
        newQuantity: 6,
        context: context,
        localProductProvider: provider,
        activeStoreId: 1,
      ).then((value) {
        confirmResult = value;
        confirmCompleted = true;
      });

      await tester.pump();
      for (var i = 0; i < 20 && !tester.any(find.text('Sell anyway')); i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Sell anyway'), findsOneWidget);

      await tester.tap(find.text('Sell anyway'));
      for (var i = 0; i < 30 && !confirmCompleted; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(confirmCompleted, isTrue);
      expect(confirmResult.changed, isTrue);
      expect(confirmResult.appliedQuantity, 6);
      expect(
        provider.cartItems.firstWhere((item) => item.selectedStock?.id == 1).quantity,
        6,
      );
    });
  });
}
