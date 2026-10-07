import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/cart/mobile_cart_price_fields.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/mobile_market_add_sheet.dart';
import 'package:pos_machine/features/billing/presentation/widgets/price_fields.dart';
import 'package:pos_machine/features/offers/data/product_offer_repository.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/app_font_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../test_support/hive_test_teardown.dart';
import '../support/offer_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_offer_fields_test_');
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
    await awaitPendingHiveBoxWrites();
    SharedPreferences.setMockInitialValues({'general_stock_enabled': true});
    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
  });

  tearDown(awaitPendingHiveBoxWrites);
  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

  Stock stock({String price = '100'}) {
    return Stock(
      id: 88,
      productId: 1,
      storeId: 1,
      storeName: 'Main Store',
      quantity: 50,
      price: price,
      mrp: '120',
      purchasePrice: '60',
      taxRate: '0',
      unit: 'PCS',
    );
  }

  /// Standard price [price] with a 5% minimum margin: floor 95 at 100.
  GetProduct product({String price = '100', List<Stock> stocks = const []}) {
    return GetProduct(
      productId: 1,
      productName: 'Chocobar',
      price: ProductPrice(price: price),
      mrp: '120',
      purchasePrice: '60',
      unit: 'PCS',
      minMarginPercentage: '5',
      stock: stocks,
    );
  }

  final tenPercent = productOffer(
    lines: [offerLine(productId: 1, value: 10)],
  );

  /// Cart with one line of [quantity] at the 10% offer price.
  Future<LocalProductProvider> offerCart(
    WidgetTester tester, {
    String price = '100',
    num quantity = 1,
  }) async {
    late LocalProductProvider provider;
    await tester.runAsync(() async {
      final repository = ProductOfferRepository(clock: () => offerTestNow)
        ..debugSetCatalog(offerCatalog([tenPercent]));
      provider = LocalProductProvider()
        ..offerRepository = repository
        ..setStockEnabled(true);
      final batch = stock(price: price);
      final item = product(price: price, stocks: [batch]);
      provider.initializeProducts([item]);
      provider.addToCart(
          product: item, quantity: quantity, selectedStock: batch);
      await provider.flushPersistence();
    });
    return provider;
  }

  Future<void> tearDownWidgets(
    WidgetTester tester,
    LocalProductProvider provider,
  ) async {
    // Let any minimum-price toast time out before the tree goes away.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(provider.flushPersistence);
    // Price edits made by the widgets ran in the fake-async zone; disposing
    // cancels the offer boundary timer they scheduled.
    provider.dispose();
  }

  void expectOfferKept(LocalProductProvider provider, double price) {
    final line = provider.cartItems.single;
    expect(line.price, closeTo(price, 0.0001));
    expect(line.offerId, 9);
    expect(line.isManualPriceOverride, isFalse);
  }

  group('desktop PriceTextField on an offer line with a minimum margin', () {
    Future<void> pumpField(
      WidgetTester tester,
      LocalProductProvider provider,
    ) async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<LocalProductProvider>.value(value: provider),
          ChangeNotifierProvider<KeyboardProvider>(
              create: (_) => KeyboardProvider()),
          ChangeNotifierProvider<AppFontProvider>(
              create: (_) => AppFontProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  width: 120,
                  child: PriceTextField(
                    item: provider.cartItems.single,
                    localProductProvider: provider,
                  ),
                ),
                const TextField(key: ValueKey('other-field')),
              ],
            ),
          ),
        ),
      ));
    }

    testWidgets('focus then blur keeps the offer price', (tester) async {
      final provider = await offerCart(tester);
      expect(provider.minimumSalePriceForCartItem(provider.cartItems.single),
          closeTo(95, 0.0001));
      await pumpField(tester, provider);

      await tester.tap(find.byType(PriceTextField));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('other-field')));
      await tester.pump();

      expectOfferKept(provider, 90);
      await tearDownWidgets(tester, provider);
    });

    testWidgets('Enter without editing keeps the offer price', (tester) async {
      final provider = await offerCart(tester);
      await pumpField(tester, provider);

      await tester.tap(find.byType(PriceTextField));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expectOfferKept(provider, 90);
      await tearDownWidgets(tester, provider);
    });

    testWidgets('Tab without editing keeps the offer price', (tester) async {
      final provider = await offerCart(tester);
      await pumpField(tester, provider);

      await tester.tap(find.byType(PriceTextField));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expectOfferKept(provider, 90);
      await tearDownWidgets(tester, provider);
    });

    for (final action in ['blur', 'Enter', 'Tab']) {
      testWidgets(
          'offer removal while focused does not create a manual price on $action',
          (tester) async {
        final provider = await offerCart(tester);
        await pumpField(tester, provider);
        await tester.tap(find.byType(PriceTextField));
        await tester.pump();
        try {
          provider.offerRepository.debugSetCatalog(offerCatalog(const []));
          await tester.pump();
          expect(provider.cartItems.single.price, 100);
          if (action == 'blur') {
            await tester.tap(find.byKey(const ValueKey('other-field')));
          } else if (action == 'Enter') {
            await tester.testTextInput.receiveAction(TextInputAction.done);
          } else {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          }
          await tester.pump();
          final line = provider.cartItems.single;
          expect(line.price, 100);
          expect(line.isManualPriceOverride, isFalse);
          expect(line.hasOffer, isFalse);
        } finally {
          await tearDownWidgets(tester, provider);
        }
      });
    }

    testWidgets(
        'a better offer while focused stays automatic below the margin floor',
        (tester) async {
      final provider = await offerCart(tester);
      await pumpField(tester, provider);
      await tester.tap(find.byType(PriceTextField));
      await tester.pump();
      try {
        provider.offerRepository.debugSetCatalog(offerCatalog([
          productOffer(version: 4, lines: [offerLine(productId: 1, value: 20)]),
        ]));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('other-field')));
        await tester.pump();
        expectOfferKept(provider, 80);
        expect(provider.cartItems.single.offerVersion, 4);
      } finally {
        await tearDownWidgets(tester, provider);
      }
    });

    testWidgets('selection changes after offer removal do not edit the price',
        (tester) async {
      final provider = await offerCart(tester);
      await pumpField(tester, provider);
      await tester.tap(find.byType(PriceTextField));
      await tester.pump();
      try {
        provider.offerRepository.debugSetCatalog(offerCatalog(const []));
        final field = tester.widget<TextField>(find.descendant(
            of: find.byType(PriceTextField), matching: find.byType(TextField)));
        // Change the selection before the field rebuilds with its new price.
        field.controller!.selection = const TextSelection.collapsed(offset: 0);
        expect(provider.cartItems.single.price, 100);
        expect(provider.cartItems.single.isManualPriceOverride, isFalse);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('other-field')));
        await tester.pump();
        expect(provider.cartItems.single.price, 100);
        expect(provider.cartItems.single.isManualPriceOverride, isFalse);
      } finally {
        await tearDownWidgets(tester, provider);
      }
    });

    testWidgets('a virtual keyboard edit after offer removal is still manual',
        (tester) async {
      final provider = await offerCart(tester);
      await pumpField(tester, provider);
      await tester.tap(find.byType(PriceTextField));
      await tester.pump();
      try {
        provider.offerRepository.debugSetCatalog(offerCatalog(const []));
        await tester.pump();
        final field = tester.widget<TextField>(find.descendant(
            of: find.byType(PriceTextField), matching: find.byType(TextField)));
        // The virtual keyboard changes the controller without onChanged.
        field.controller!.text = '80';
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('other-field')));
        await tester.pump();
        expect(provider.cartItems.single.price, 95);
        expect(provider.cartItems.single.isManualPriceOverride, isTrue);
        expect(provider.cartItems.single.hasOffer, isFalse);
      } finally {
        await tearDownWidgets(tester, provider);
      }
    });

    testWidgets('a typed price below the floor is clamped and becomes manual',
        (tester) async {
      final provider = await offerCart(tester);
      await pumpField(tester, provider);

      await tester.tap(find.byType(PriceTextField));
      await tester.pump();
      await tester.enterText(
          find.descendant(
              of: find.byType(PriceTextField),
              matching: find.byType(TextField)),
          '80');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      final line = provider.cartItems.single;
      expect(line.price, closeTo(95, 0.0001));
      expect(line.isManualPriceOverride, isTrue);
      expect(line.offerId, isNull);
      await tearDownWidgets(tester, provider);
    });
  });

  group('mobile cart price field on an offer line', () {
    Future<void> pumpField(
      WidgetTester tester,
      LocalProductProvider provider,
    ) async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<LocalProductProvider>.value(value: provider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MobileCartPriceField(
                  item: provider.cartItems.single,
                  controller: const BillingMobileCartController(),
                ),
                const TextField(key: ValueKey('other-field')),
              ],
            ),
          ),
        ),
      ));
    }

    String fieldText(WidgetTester tester) => tester
        .widget<TextField>(find.descendant(
            of: find.byType(MobileCartPriceField),
            matching: find.byType(TextField)))
        .controller!
        .text;

    testWidgets('focus then blur keeps the offer price', (tester) async {
      final provider = await offerCart(tester);
      await pumpField(tester, provider);
      expect(fieldText(tester), '90.00');

      await tester.tap(find.byType(MobileCartPriceField));
      await tester.pump();
      expect(fieldText(tester), '90');
      await tester.tap(find.byKey(const ValueKey('other-field')));
      await tester.pump();

      expectOfferKept(provider, 90);
      expect(fieldText(tester), '90.00');
      await tearDownWidgets(tester, provider);
    });

    testWidgets('submit without editing keeps the offer price', (tester) async {
      final provider = await offerCart(tester);
      await pumpField(tester, provider);

      await tester.tap(find.byType(MobileCartPriceField));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expectOfferKept(provider, 90);
      await tearDownWidgets(tester, provider);
    });

    for (final submit in [false, true]) {
      testWidgets(
          'offer removal while focused does not create a manual price on ${submit ? 'submit' : 'blur'}',
          (tester) async {
        final provider = await offerCart(tester);
        await pumpField(tester, provider);
        await tester.tap(find.byType(MobileCartPriceField));
        await tester.pump();
        try {
          provider.offerRepository.debugSetCatalog(offerCatalog(const []));
          await tester.pump();
          expect(provider.cartItems.single.price, 100);
          if (submit) {
            await tester.testTextInput.receiveAction(TextInputAction.done);
          } else {
            await tester.tap(find.byKey(const ValueKey('other-field')));
          }
          await tester.pump();
          final line = provider.cartItems.single;
          expect(line.price, 100);
          expect(line.isManualPriceOverride, isFalse);
          expect(line.hasOffer, isFalse);
          expect(fieldText(tester), '100.00');
        } finally {
          await tearDownWidgets(tester, provider);
        }
      });
    }

    testWidgets(
        'a better offer while focused stays automatic below the margin floor',
        (tester) async {
      final provider = await offerCart(tester);
      await pumpField(tester, provider);
      await tester.tap(find.byType(MobileCartPriceField));
      await tester.pump();
      try {
        provider.offerRepository.debugSetCatalog(offerCatalog([
          productOffer(version: 4, lines: [offerLine(productId: 1, value: 20)]),
        ]));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('other-field')));
        await tester.pump();
        expectOfferKept(provider, 80);
        expect(provider.cartItems.single.offerVersion, 4);
        expect(fieldText(tester), '80.00');
      } finally {
        await tearDownWidgets(tester, provider);
      }
    });

    testWidgets('a typed price below the floor is clamped and becomes manual',
        (tester) async {
      final provider = await offerCart(tester);
      await pumpField(tester, provider);

      await tester.tap(find.byType(MobileCartPriceField));
      await tester.pump();
      await tester.enterText(find.byType(MobileCartPriceField), '80');
      await tester.tap(find.byKey(const ValueKey('other-field')));
      await tester.pump();

      final line = provider.cartItems.single;
      expect(line.price, closeTo(95, 0.0001));
      expect(line.isManualPriceOverride, isTrue);
      expect(line.offerId, isNull);
      expect(fieldText(tester), '95.00');
      await tearDownWidgets(tester, provider);
    });

    testWidgets('shows a 3-decimal offer price with 3 decimals',
        (tester) async {
      // 10% off 33.33 = 29.997; 3 x 29.997 = 89.991.
      final provider = await offerCart(tester, price: '33.33', quantity: 3);
      expect(provider.cartItems.single.price, closeTo(29.997, 0.0001));
      await pumpField(tester, provider);

      expect(fieldText(tester), '29.997');

      await tester.tap(find.byType(MobileCartPriceField));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('other-field')));
      await tester.pump();

      expectOfferKept(provider, 29.997);
      expect(fieldText(tester), '29.997');
      await tearDownWidgets(tester, provider);
    });

    testWidgets('re-syncs the text when the line is re-priced in place',
        (tester) async {
      final provider = await offerCart(tester);
      await pumpField(tester, provider);
      expect(fieldText(tester), '90.00');

      // The offer ends: the cart re-prices the same LocalCartItem object.
      final line = provider.cartItems.single;
      line
        ..price = 100
        ..clearOffer();
      provider.updateItemMrp(1, line.selectedStock, 120,
          stockGroupIds: line.stockGroupIds);
      await tester.pump();
      await tester.pump();

      expect(fieldText(tester), '100.00');
      await tearDownWidgets(tester, provider);
    });
  });

  group('mobile market add sheet', () {
    Future<MobileMarketAddFormValues?> submitSheet(
      WidgetTester tester, {
      String? typedPrice,
    }) async {
      MobileMarketAddFormValues? result;
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) => AppSettingsProvider()),
        ],
        child: MaterialApp(
          // The default ink sparkle shader is not available in tests.
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showMobileMarketAddSheet(
                    context: context,
                    product: product(),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Fields: quantity, unit price (MRP is hidden without settings).
      final priceField = find.byType(TextField).at(1);
      expect(tester.widget<TextField>(priceField).controller!.text, '100');
      if (typedPrice != null) {
        await tester.enterText(priceField, typedPrice);
      }
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('an untouched prefilled price is not a custom price',
        (tester) async {
      final values = await submitSheet(tester);

      expect(values, isNotNull);
      expect(values!.quantity, 1);
      expect(values.customPrice, isNull);
    });

    testWidgets('a changed price is passed as the custom price',
        (tester) async {
      final values = await submitSheet(tester, typedPrice: '80');

      expect(values!.customPrice, 80);
    });
  });

  group('BillingMobileMarketController.parseAddForm', () {
    const controller = BillingMobileMarketController();

    test('drops the price when it equals the prefilled default', () {
      final unchanged = controller.parseAddForm(
        quantityText: '2',
        priceText: '29.997',
        defaultPrice: 29.997,
      );
      expect(unchanged.values!.customPrice, isNull);

      final changed = controller.parseAddForm(
        quantityText: '2',
        priceText: '29.99',
        defaultPrice: 29.997,
      );
      expect(changed.values!.customPrice, 29.99);
    });
  });
}
