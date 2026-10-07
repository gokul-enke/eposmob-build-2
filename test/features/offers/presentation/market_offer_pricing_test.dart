import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/market_product_grid.dart';
import 'package:pos_machine/features/offers/data/product_offer_repository.dart';
import 'package:pos_machine/features/offers/presentation/widgets/cart_offer_badge.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/models/get_general_settings.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/general_settings_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../test_support/hive_test_teardown.dart';
import '../support/offer_fixtures.dart';

class _Settings extends AppSettingsProvider {
  final settings = AppSettings.fromJson({
    'data': [
      {'code': 'CURRENCY', 'value': 'SAR', 'status': true},
      {'code': 'MULTI_SALE_UNIT_ENABLED', 'status': true},
    ]
  });
  @override
  AppSettings get appSettings => settings;
  @override
  Future<void> fetchAppSettings() async {}
}

class _General extends GeneralSettingsProvider {
  @override
  GeneralSettings get generalSettings => GeneralSettings(stockEnabled: true);
  @override
  Future<void> fetchGeneralSettings() async {}
}

class _Roles extends RoleProvider {
  @override
  bool currentUserHasPermissionSync(String permission) => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDir;
  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_market_offer_');
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

  Stock batch({int id = 88, num quantity = 50, String price = '100'}) => Stock(
        id: id,
        productId: 1,
        storeId: 1,
        quantity: quantity,
        price: price,
        mrp: '120',
        unit: 'PCS',
        wholesalePrice: '80',
        wholesaleMinUnit: 5,
      );
  GetProduct product({List<Stock>? stocks, List<SaleUnit>? units}) =>
      GetProduct(
        productId: 1,
        productName: 'Offer product',
        sellable: true,
        unit: 'PCS',
        price: ProductPrice(price: '100'),
        mrp: '120',
        stock: stocks ?? [batch()],
        saleUnits: units,
      );

  Future<LocalProductProvider> setup(
    WidgetTester tester,
    GetProduct item, {
    ProductViewMode mode = ProductViewMode.grid,
    DateTime Function()? clock,
    DateTime? validFrom,
  }) async {
    late LocalProductProvider provider;
    await tester.runAsync(() async {
      final offers = ProductOfferRepository(clock: clock ?? () => offerTestNow)
        ..debugSetCatalog(offerCatalog([
          productOffer(validFrom: validFrom, lines: [offerLine(productId: 1)]),
        ]));
      provider = LocalProductProvider()
        ..offerRepository = offers
        ..setStockEnabled(true);
      provider.initializeProducts([item]);
      await provider.flushPersistence();
    });
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<LocalProductProvider>.value(value: provider),
        ChangeNotifierProvider<AppSettingsProvider>(create: (_) => _Settings()),
        ChangeNotifierProvider<GeneralSettingsProvider>(
            create: (_) => _General()),
        ChangeNotifierProvider<MasterDataProvider>(
            create: (_) => MasterDataProvider()),
        ChangeNotifierProvider<CustomerSelectionProvider>(
            create: (_) => CustomerSelectionProvider()),
        ChangeNotifierProvider<RoleProvider>(create: (_) => _Roles()),
      ],
      child: MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: Scaffold(
            body: SizedBox(
                width: 375,
                height: 700,
                child: MarketProductGrid(
                    products: [item],
                    viewMode: mode,
                    currency: 'SAR',
                    onProductAdded: () {}))),
      ),
    ));
    await tester.pumpAndSettle();
    return provider;
  }

  Future<void> finish(
      WidgetTester tester, LocalProductProvider provider) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(provider.flushPersistence);
    provider.dispose();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
  }

  String priceText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text;
  Future<void> quantity(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  }

  for (final mode in ProductViewMode.values) {
    testWidgets(
        '$mode shows offer price and updates when offers turn off with an empty cart',
        (tester) async {
      final provider = await setup(tester, product(), mode: mode);
      try {
        expect(find.text('SAR 90.00'), findsOneWidget);
        expect(find.byType(OfferPriceBadge), findsOneWidget);
        expect(provider.cartItems, isEmpty);
        expect(provider.products.single.stock!.single.quantity, 50);
        provider.offerRepository
            .debugSetCatalog(offerCatalog([], enabled: false));
        await tester.pumpAndSettle();
        expect(find.text('SAR 100.00'), findsOneWidget);
        expect(find.byType(OfferPriceBadge), findsNothing);
      } finally {
        await finish(tester, provider);
      }
    });
  }

  testWidgets('quantity-only popup addition keeps the offer and offer metadata',
      (tester) async {
    final provider = await setup(tester, product());
    try {
      await open(tester);
      expect(priceText(tester), '90');
      await quantity(tester, '4');
      expect(priceText(tester), '90');
      expect(find.textContaining('SAR 360.00'), findsOneWidget);
      expect(provider.cartItems, isEmpty);
      expect(provider.products.single.stock!.single.quantity, 50);
      await submit(tester);
      final line = provider.cartItems.single;
      expect(line.quantity, 4);
      expect(line.price, 90);
      expect(line.isManualPriceOverride, isFalse);
      expect(line.offerId, 9);
      final payload = provider.buildOrderItemsPayload().single;
      expect(payload['price'], 90);
      expect(payload['standard_unit_price'], 100);
      expect(payload['offer_id'], 9);
    } finally {
      await finish(tester, provider);
    }
  });

  testWidgets(
      'popup changes from offer to wholesale and back without a manual override',
      (tester) async {
    final provider = await setup(tester, product());
    try {
      await open(tester);
      await quantity(tester, '5');
      expect(priceText(tester), '80');
      expect(find.textContaining('SAR 400.00'), findsOneWidget);
      // The listing keeps its quantity-one preview; the popup no longer has an offer.
      expect(find.byType(OfferPriceBadge), findsOneWidget);
      await quantity(tester, '4');
      expect(priceText(tester), '90');
      expect(find.byType(OfferPriceBadge), findsNWidgets(2));
      await submit(tester);
      expect(provider.cartItems.single.price, 90);
      expect(provider.cartItems.single.isManualPriceOverride, isFalse);
    } finally {
      await finish(tester, provider);
    }
  });

  testWidgets(
      'direct add and popup add share pricing and combine quantity for wholesale',
      (tester) async {
    final provider = await setup(tester, product());
    try {
      await tester.tap(find.text('Offer product'));
      await tester.pumpAndSettle();
      expect(provider.cartItems.single.price, 90);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await open(tester);
      await quantity(tester, '4');
      expect(priceText(tester), '80');
      await submit(tester);
      final line = provider.cartItems.single;
      expect(line.quantity, 5);
      expect(line.price, 80);
      expect(line.hasOffer, isFalse);
      expect(line.isManualPriceOverride, isFalse);
    } finally {
      await finish(tester, provider);
    }
  });

  testWidgets(
      'manual popup price survives quantity changes and removes the offer',
      (tester) async {
    final provider = await setup(tester, product());
    try {
      await open(tester);
      await tester.enterText(find.byType(TextField).at(1), '85');
      await quantity(tester, '5');
      expect(priceText(tester), '85');
      await submit(tester);
      expect(provider.cartItems.single.price, 85);
      expect(provider.cartItems.single.isManualPriceOverride, isTrue);
      expect(provider.cartItems.single.hasOffer, isFalse);
    } finally {
      await finish(tester, provider);
    }
  });

  testWidgets(
      'a manual price stays manual when the automatic price becomes equal',
      (tester) async {
    final provider = await setup(tester, product());
    try {
      await open(tester);
      await tester.enterText(find.byType(TextField).at(1), '80');
      await quantity(tester, '5');
      await submit(tester);
      expect(provider.cartItems.single.isManualPriceOverride, isTrue);
      provider.setCartItemQuantity(
          1, provider.cartItems.single.selectedStock, 4);
      expect(provider.cartItems.single.price, 80);
      expect(provider.cartItems.single.hasOffer, isFalse);
    } finally {
      await finish(tester, provider);
    }
  });

  testWidgets(
      'a trailing decimal can be typed before completing a manual price',
      (tester) async {
    final provider = await setup(tester, product());
    try {
      await open(tester);
      final field = tester.widget<TextField>(find.byType(TextField).at(1));
      field.controller!.text = '90.';
      await tester.pumpAndSettle();
      expect(priceText(tester), '90.');
      field.controller!.text = '90.5';
      await tester.pumpAndSettle();
      await submit(tester);
      expect(provider.cartItems.single.price, 90.5);
      expect(provider.cartItems.single.isManualPriceOverride, isTrue);
    } finally {
      await finish(tester, provider);
    }
  });

  testWidgets(
      'virtual keyboard edits are manual but selection-only changes are not',
      (tester) async {
    final provider = await setup(tester, product());
    try {
      await open(tester);
      final field = tester.widget<TextField>(find.byType(TextField).at(1));
      field.controller!.selection = const TextSelection.collapsed(offset: 0);
      await quantity(tester, '4');
      expect(priceText(tester), '90');
      field.controller!.text = '86';
      await quantity(tester, '2');
      expect(priceText(tester), '86');
      await submit(tester);
      expect(provider.cartItems.single.price, 86);
      expect(provider.cartItems.single.isManualPriceOverride, isTrue);
    } finally {
      await finish(tester, provider);
    }
  });

  testWidgets('a pack uses its own price and converts quantity before adding',
      (tester) async {
    final unit =
        SaleUnit(id: 7, unitName: 'Pack', conversionRate: '10', price: 750);
    final provider = await setup(tester, product(units: [unit]));
    try {
      await open(tester);
      final dropdown = tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
      dropdown.onChanged!('7');
      await tester.pumpAndSettle();
      expect(priceText(tester), '750');
      await quantity(tester, '2');
      expect(find.textContaining('SAR 1500.00'), findsOneWidget);
      await submit(tester);
      final line = provider.cartItems.single;
      expect(line.saleUnitId, 7);
      expect(line.quantity, 20);
      expect(line.displayQuantity, 2);
      expect(line.displayPrice, 750);
      expect(line.price, 75);
      expect(line.hasOffer, isFalse);
      expect(line.isManualPriceOverride, isFalse);
    } finally {
      await finish(tester, provider);
    }
  });

  testWidgets('offer removal while popup is open refreshes the automatic price',
      (tester) async {
    final provider = await setup(tester, product());
    try {
      await open(tester);
      provider.offerRepository.debugSetCatalog(offerCatalog([]));
      await tester.pumpAndSettle();
      expect(priceText(tester), '100');
      await quantity(tester, '4');
      await submit(tester);
      expect(provider.cartItems.single.price, 100);
      expect(provider.cartItems.single.isManualPriceOverride, isFalse);
    } finally {
      await finish(tester, provider);
    }
  });

  testWidgets(
      'offer starts offline and refreshes the listing before anything is in the cart',
      (tester) async {
    var now = offerTestNow;
    final start = now.add(const Duration(minutes: 1));
    final provider =
        await setup(tester, product(), clock: () => now, validFrom: start);
    try {
      expect(find.text('SAR 100.00'), findsOneWidget);
      now = start;
      provider.debugRunOfferBoundaryTimer();
      await tester.pumpAndSettle();
      expect(find.text('SAR 90.00'), findsOneWidget);
      expect(provider.cartItems, isEmpty);
    } finally {
      await finish(tester, provider);
    }
  });

  testWidgets(
      'an unresolved pricing group advertises availability without an applied offer price',
      (tester) async {
    final provider = await setup(
        tester, product(stocks: [batch(), batch(id: 89, price: '110')]));
    try {
      expect(find.text('offers.available'.tr), findsOneWidget);
      expect(find.byType(OfferPriceBadge), findsNothing);
      await open(tester);
      expect(find.text('offers.price_pending_selection'.tr), findsOneWidget);
      expect(find.byType(OfferPriceBadge), findsNothing);
      expect(provider.cartItems, isEmpty);
    } finally {
      await finish(tester, provider);
    }
  });
}
