import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/features/billing/presentation/widgets/cart/cart_items_table.dart';
import 'package:pos_machine/features/offers/presentation/widgets/cart_offer_badge.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/features/offers/data/product_offer_repository.dart';
import 'package:pos_machine/features/offers/domain/product_offer.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/models/order_submission_payload.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/app_font_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_support/hive_test_teardown.dart';
import 'support/offer_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_cart_offer_test_');
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

  Stock stock({
    int id = 88,
    String price = '100',
    String? wholesalePrice,
    int? wholesaleMinUnit,
    String taxRate = '0',
  }) {
    return Stock(
      id: id,
      productId: 1,
      storeId: 1,
      storeName: 'Main Store',
      quantity: 50,
      price: price,
      mrp: '120',
      purchasePrice: '60',
      taxRate: taxRate,
      unit: 'PCS',
      wholesalePrice: wholesalePrice,
      wholesaleMinUnit: wholesaleMinUnit,
    );
  }

  GetProduct product({List<Stock> stocks = const []}) {
    return GetProduct(
      productId: 1,
      productName: 'Chocobar',
      price: ProductPrice(price: '100'),
      mrp: '120',
      purchasePrice: '60',
      unit: 'PCS',
      stock: stocks,
    );
  }

  LocalProductProvider providerWith(List<ProductOffer> offers,
      {bool enabled = true}) {
    final repository = ProductOfferRepository(clock: () => offerTestNow)
      ..debugSetCatalog(offerCatalog(offers, enabled: enabled));
    return LocalProductProvider()
      ..offerRepository = repository
      ..setStockEnabled(true);
  }

  final tenPercent = productOffer(
    version: 3,
    lines: [offerLine(productId: 1, value: 10)],
  );

  test('adding a product applies the active offer', () {
    final provider = providerWith([tenPercent]);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 2, selectedStock: batch);

    final line = provider.cartItems.single;
    expect(line.price, closeTo(90, 0.0001));
    expect(line.standardUnitPrice, 100);
    expect(line.offerId, 9);
    expect(line.offerVersion, 3);
    expect(line.displayStandardPrice, 100);
  });

  test('a batch offer follows the reserved batch within a pricing group', () {
    final firstBatch = stock(id: 87);
    final selectedBatch = stock(id: 88);
    final item = product(stocks: [firstBatch, selectedBatch]);
    final provider = providerWith([
      productOffer(lines: [offerLine(productId: 1, stockId: 87)]),
    ]);
    provider.initializeProducts([item]);
    provider.addToCart(
        product: item, quantity: 2, selectedStock: selectedBatch);

    final line = provider.cartItems.single;
    expect(line.stockGroupIds, [87, 88]);
    expect(line.stockReservations.single.stockId, 87);
    expect(line.price, 90);
    expect(provider.buildOrderItemsPayload().single['offer_id'], 9);

    // The allocator now needs both batches, so the batch offer must stop.
    provider.setCartItemQuantity(1, selectedBatch, 51);
    expect(line.stockReservations, hasLength(2));
    expect(line.price, 100);
    expect(line.hasOffer, isFalse);

    provider.setCartItemQuantity(1, selectedBatch, 2);
    expect(line.stockReservations.single.stockId, 87);
    expect(line.price, 90);
    expect(line.offerId, 9);
  });

  test('an unreserved selected batch does not lend its offer to another batch',
      () {
    final firstBatch = stock(id: 87);
    final selectedBatch = stock(id: 88);
    final item = product(stocks: [firstBatch, selectedBatch]);
    final provider = providerWith([
      productOffer(lines: [offerLine(productId: 1, stockId: 88)]),
    ]);
    provider.initializeProducts([item]);
    provider.addToCart(
        product: item, quantity: 2, selectedStock: selectedBatch);

    expect(provider.cartItems.single.stockReservations.single.stockId, 87);
    expect(provider.cartItems.single.hasOffer, isFalse);
  });

  test('the offer is also applied on top of an explicit standard price', () {
    final provider = providerWith([tenPercent]);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(
      product: item,
      quantity: 1,
      price: 100,
      selectedStock: batch,
    );
    expect(provider.cartItems.single.price, closeTo(90, 0.0001));
  });

  test('no offer while POS_OFFERS is off', () {
    final provider = providerWith([tenPercent], enabled: false);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 1, selectedStock: batch);

    final line = provider.cartItems.single;
    expect(line.price, 100);
    expect(line.hasOffer, isFalse);
  });

  test(
      'wholesale wins once the quantity qualifies, and the offer returns '
      'below it', () {
    final provider = providerWith([tenPercent]);
    final batch = stock(wholesalePrice: '80', wholesaleMinUnit: 5);
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 2, selectedStock: batch);
    expect(provider.cartItems.single.price, closeTo(90, 0.0001));

    provider.setCartItemQuantity(1, batch, 6);
    final line = provider.cartItems.single;
    expect(line.price, 80);
    expect(line.hasOffer, isFalse);

    provider.setCartItemQuantity(1, batch, 3);
    expect(provider.cartItems.single.price, closeTo(90, 0.0001));
    expect(provider.cartItems.single.offerId, 9);
  });

  test('a manual price edit removes the offer', () {
    final provider = providerWith([tenPercent]);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 1, selectedStock: batch);

    provider.updateItemPrice(1, batch, 95);
    final line = provider.cartItems.single;
    expect(line.price, 95);
    expect(line.isManualPriceOverride, isTrue);
    expect(line.hasOffer, isFalse);

    provider.setCartItemQuantity(1, batch, 2);
    expect(provider.cartItems.single.price, 95);
    expect(provider.cartItems.single.hasOffer, isFalse);
  });

  test('a flat_amount offer ignores the minimum sale price', () {
    final provider = providerWith([
      productOffer(lines: [
        offerLine(
          productId: 1,
          type: ProductOfferType.flatAmount,
          value: 50,
        ),
      ]),
    ]);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 1, selectedStock: batch);
    expect(provider.cartItems.single.price, 50);
  });

  OrderSubmissionPayload printedSale(
    List<Map<String, dynamic>> items, {
    String? orderId,
    String? clientSaleId = 'ab48eb7d-1495-4f8a-8815-3cf05200bca3',
  }) {
    return OrderSubmissionPayload(
      items: items,
      transactionNumber: 'T-1',
      orderId: orderId,
      clientSaleId: clientSaleId,
      receiptNumber: '1-01-261006-0001',
      issuedAt: '2026-10-06T10:00:00Z',
      posDeviceId: '2a5e060b-9c07-4b6b-a405-136a8344c327',
      storeId: 1,
    );
  }

  test('an offer line carries the offer, standard price and tax snapshot', () {
    final provider = providerWith([tenPercent]);
    final batch = stock(taxRate: '18');
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 2, selectedStock: batch);

    final line = provider.buildOrderItemsPayload().single;
    expect(line['price'], closeTo(90, 0.0001));
    expect(line['offer_id'], 9);
    expect(line['offer_version'], 3);
    expect(line['standard_unit_price'], 100);
    expect(line['total_price'], 180);
    expect(line['tax_rate'], 18);
    // 180 inclusive of 18% tax = 27.46
    expect(line['tax_amount'], 27.46);

    final body = printedSale([line]).toApiJson();
    expect(body['pricing_mode'], 'completed_sale');
    expect(body['delivery_tax_amount'], 0);
    expect((body['items'] as List).single['standard_unit_price'], 100);
  });

  test('a printed sale without an offer is a completed sale too', () {
    final provider = providerWith(const []);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 1, selectedStock: batch);

    final line = provider.buildOrderItemsPayload().single;
    expect(line.containsKey('offer_id'), isFalse);
    // The price is its own reference, so nothing looks like a discount.
    expect(line['standard_unit_price'], line['price']);

    final body = printedSale([line]).toApiJson();
    expect(body['pricing_mode'], 'completed_sale');
  });

  test('wholesale lines use the wholesale price as their reference', () {
    final provider = providerWith([tenPercent]);
    final batch = stock(wholesalePrice: '80', wholesaleMinUnit: 5);
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 6, selectedStock: batch);

    final line = provider.buildOrderItemsPayload().single;
    expect(line['price'], 80);
    expect(line['standard_unit_price'], 80);
    expect(line.containsKey('offer_id'), isFalse);
  });

  test('a manual price keeps the normal price as its reference', () {
    final provider = providerWith([tenPercent]);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 1, selectedStock: batch);
    provider.updateItemPrice(1, batch, 95);

    final line = provider.buildOrderItemsPayload().single;
    expect(line['price'], 95);
    expect(line['standard_unit_price'], 100);
    expect(line.containsKey('offer_id'), isFalse);
  });

  test('a manual price on a new line keeps the normal price as reference', () {
    final provider = providerWith(const []);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(
      product: item,
      quantity: 1,
      price: 90,
      selectedStock: batch,
      markPriceAsManualOverride: true,
    );

    final line = provider.buildOrderItemsPayload().single;
    expect(line['price'], 90);
    expect(line['standard_unit_price'], 100);
  });

  test('the snapshot is not sent on orders the backend prices itself', () {
    final provider = providerWith([tenPercent]);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 1, selectedStock: batch);
    final lines = provider.buildOrderItemsPayload();

    // An editable draft that already exists on the server.
    final draft = printedSale(lines, orderId: '55').toApiJson();
    // A sale without a receipt identity.
    final noIdentity = printedSale(lines, clientSaleId: null).toApiJson();
    for (final body in [draft, noIdentity]) {
      expect(body.containsKey('pricing_mode'), isFalse);
      expect(body.containsKey('delivery_tax_amount'), isFalse);
      final sent = (body['items'] as List).single as Map;
      for (final key in OrderSubmissionPayload.completedSaleLineKeys) {
        expect(sent.containsKey(key), isFalse, reason: key);
      }
      // The offer reference is still sent.
      expect(sent['offer_id'], 9);
    }
  });

  test('the offer survives a restart (cart restored from Hive)', () async {
    final provider = providerWith([tenPercent]);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 1, selectedStock: batch);
    await provider.flushPersistence();

    // Offers are switched off after the restart: the restored line keeps the
    // price it was rung up at until it is touched again.
    final restarted = providerWith(const [], enabled: false);
    await restarted.hydrated;
    final line = restarted.cartItems.single;
    expect(line.price, closeTo(90, 0.0001));
    expect(line.offerId, 9);
    expect(line.offerVersion, 3);
    expect(line.standardUnitPrice, 100);
  });

  test('an expired offer is not applied', () {
    final provider = providerWith([
      productOffer(
        validUntil: offerTestNow,
        lines: [offerLine(productId: 1)],
      ),
    ]);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 1, selectedStock: batch);
    expect(provider.cartItems.single.price, 100);
  });

  test('fractional offer price produces the printed 2-decimal line total', () {
    final provider = providerWith([
      productOffer(lines: [offerLine(productId: 1, value: 15)]),
    ]);
    final batch = stock(price: '19.99');
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 3, selectedStock: batch);
    expect(provider.cartItems.single.price, 16.992);
    expect(provider.cartTotal.toStringAsFixed(2), '50.98');
    expect(provider.buildOrderItemsPayload().single['total_price'], 50.98);
  });

  test('118 tax-inclusive offer extracts tax from the discounted price', () {
    final provider = providerWith([tenPercent]);
    final batch = stock(price: '118', taxRate: '18');
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 1, selectedStock: batch);
    expect(provider.cartItems.single.price, 106.2);
    expect(provider.cartItems.single.taxAmount, closeTo(16.2, 0.00001));
    expect(provider.buildOrderItemsPayload().single['tax_amount'], 16.2);
  });

  test('held offer cart resumes its frozen price after offers are disabled',
      () async {
    final provider = providerWith([tenPercent]);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 2, selectedStock: batch);
    final held = provider.saveCurrentCartAsOrder(comment: 'QA offer hold');
    await provider.flushPersistence();
    provider.clearCart();
    provider.offerRepository.debugSetCatalog(offerCatalog([], enabled: false));
    provider.loadOrderForEditing(held.id);
    expect(provider.cartItems.single.price, 90);
    expect(provider.cartItems.single.offerId, 9);
    expect(provider.cartItems.single.standardUnitPrice, 100);
    expect(provider.cartTotal, 180);
  });

  test('overall discount does not alter the offer line snapshot', () {
    final provider = providerWith([tenPercent]);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 2, selectedStock: batch);
    provider.applyDiscount(flatDiscount: 10, percentageDiscount: 5);
    expect(provider.cartTotal, 161);
    final line = provider.buildOrderItemsPayload().single;
    expect(line['price'], 90);
    expect(line['total_price'], 180);
    expect(line['offer_id'], 9);
  });

  test('a multi-batch offer sale uploads one frozen price per batch', () {
    final provider = providerWith([tenPercent]);
    final first = stock(id: 87).copyWith(quantity: 1);
    final second = stock(id: 88);
    final item = product(stocks: [first, second]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 2, selectedStock: first);
    expect(provider.cartItems.single.stockReservations, hasLength(2));
    final lines = provider.buildOrderItemsPayload();
    expect(lines, hasLength(2));
    expect(lines.map((line) => line['stock_id']).toSet(), {87, 88});
    for (final line in lines) {
      expect(line['price'], 90);
      expect(line['standard_unit_price'], 100);
      expect(line['offer_id'], 9);
      expect(line['total_price'], 90);
    }
  });

  test('base-unit product offers apply independently to each variant', () {
    final provider = providerWith([tenPercent]);
    final first = stock(id: 87).copyWith(productVariantId: 11);
    final second = stock(id: 88, price: '118', taxRate: '18')
        .copyWith(productVariantId: 12);
    final item = product(stocks: [first, second]).copyWith(variants: [
      ProductVariant(
          id: 11, price: 100, quantity: 50, attributes: {'Color': 'A'}),
      ProductVariant(
          id: 12, price: 118, quantity: 50, attributes: {'Color': 'B'}),
    ]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, selectedStock: first, variantId: 11);
    provider.addToCart(product: item, selectedStock: second, variantId: 12);
    expect(provider.cartItems, hasLength(2));
    final byVariant = {
      for (final line in provider.cartItems) line.variantId: line
    };
    expect(byVariant[11]!.price, 90);
    expect(byVariant[12]!.price, 106.2);
    expect(byVariant.values.every((line) => line.offerId == 9), isTrue);
  });

  testWidgets('desktop cart displays the offer and crossed-out normal price',
      (tester) async {
    late LocalProductProvider provider;
    await tester.runAsync(() async {
      provider = providerWith([tenPercent]);
      final batch = stock();
      final item = product(stocks: [batch]);
      provider.initializeProducts([item]);
      provider.addToCart(product: item, selectedStock: batch);
      await provider.flushPersistence();
    });
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<LocalProductProvider>.value(value: provider),
        ChangeNotifierProvider<KeyboardProvider>(
            create: (_) => KeyboardProvider()),
        ChangeNotifierProvider<AppFontProvider>(
            create: (_) => AppFontProvider()),
      ],
      child: const MaterialApp(home: Scaffold(body: CartItemsTable())),
    ));
    expect(find.byType(CartOfferBadge), findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Text &&
            widget.style?.decoration == TextDecoration.lineThrough),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(provider.flushPersistence);
  });
}
