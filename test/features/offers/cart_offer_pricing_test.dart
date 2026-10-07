import 'dart:io';
import 'package:pos_machine/services/print_service.dart';
import 'package:pos_machine/features/kiosk/presentation/models/kiosk_order_draft.dart';

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

  LocalProductProvider providerWith(
    List<ProductOffer> offers, {
    bool enabled = true,
    DateTime Function()? clock,
    Duration clockOffset = Duration.zero,
  }) {
    final repository =
        ProductOfferRepository(clock: clock ?? () => offerTestNow)
          ..debugSetCatalog(offerCatalog(offers, enabled: enabled)
              .copyWith(clockOffset: clockOffset));
    final provider = LocalProductProvider()
      ..offerRepository = repository
      ..setStockEnabled(true);
    addTearDown(provider.dispose);
    return provider;
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

  test('three rounded lines agree across cart, receipt and upload', () {
    final provider = providerWith([]);
    provider.cartItems.addAll([
      for (var id = 1; id <= 3; id++)
        LocalCartItem(product: GetProduct(productId: id, unit: 'PCS'),
          price: 16.992, quantity: 1)
    ]);
    expect(provider.subTotalBeforeDiscount, provider.cartTotal);
    expect(KioskOrderDraft.fromCartItems(provider.cartItems).subtotal, provider.cartTotal);
    expect(provider.cartItems.fold<double>(0, (sum, item) => sum + double.parse(PrintService.savedOrderReceiptItem(item)['totalPrice'] as String)), closeTo(provider.cartTotal, 0.000001));
    final upload = provider.buildOrderItemsPayload().fold<double>(0, (sum, item) => sum + (item['total_price'] as num).toDouble());
    expect(provider.cartTotal.toStringAsFixed(2), '50.97');
    expect(upload.toStringAsFixed(2), '50.97');
  });

  test('batch split total agrees across cart, receipt and upload', () {
    final provider = providerWith([]);
    provider.cartItems.add(LocalCartItem(product: GetProduct(productId: 1, unit: 'PCS'),
      price: 9.315, quantity: 2, stockReservations: [
        StockReservation(stockId: 87, quantity: 1),
        StockReservation(stockId: 88, quantity: 1)]));
    expect(provider.subTotalBeforeDiscount, provider.cartTotal);
    expect(KioskOrderDraft.fromCartItems(provider.cartItems).subtotal, provider.cartTotal);
    expect(provider.cartItems.fold<double>(0, (sum, item) => sum + double.parse(PrintService.savedOrderReceiptItem(item)['totalPrice'] as String)), closeTo(provider.cartTotal, 0.000001));
    final upload = provider.buildOrderItemsPayload().fold<double>(0, (sum, item) => sum + (item['total_price'] as num).toDouble());
    expect(provider.cartTotal.toStringAsFixed(2), '18.64');
    expect(upload.toStringAsFixed(2), '18.64');
  });

  test('weighed batch split agrees across cart, receipt and upload', () {
    final provider = providerWith([]);
    provider.cartItems.add(LocalCartItem(product: GetProduct(productId: 1, unit: 'KG'),
      price: 12.35, quantity: 1, stockReservations: [
        StockReservation(stockId: 87, quantity: 0.5),
        StockReservation(stockId: 88, quantity: 0.5)]));
    expect(provider.subTotalBeforeDiscount, provider.cartTotal);
    expect(KioskOrderDraft.fromCartItems(provider.cartItems).subtotal, provider.cartTotal);
    expect(provider.cartItems.fold<double>(0, (sum, item) => sum + double.parse(PrintService.savedOrderReceiptItem(item)['totalPrice'] as String)), closeTo(provider.cartTotal, 0.000001));
    final upload = provider.buildOrderItemsPayload().fold<double>(0, (sum, item) => sum + (item['total_price'] as num).toDouble());
    expect(provider.cartTotal.toStringAsFixed(2), '12.36');
    expect(upload.toStringAsFixed(2), '12.36');
  });

  test('explicit subset preview expands the same batches as real add', () {
    final first = stock(id: 87).copyWith(quantity: 1);
    final second = stock(id: 88).copyWith(quantity: 10);
    final item = product(stocks: [first, second]);
    final provider = providerWith([
      tenPercent,
      productOffer(id: 10, lines: [offerLine(productId: 1, stockId: 87, value: 20)]),
    ]);
    provider.initializeProducts([item]);
    final preview = provider.previewProductPrice(product: item, quantity: 2,
      selectedStock: first, stockGroupIds: [87]);
    provider.addToCart(product: item, quantity: 2,
      selectedStock: first, stockGroupIds: [87]);
    expect(preview.unitPrice, 90);
    expect(provider.cartItems.single.price, 90);
  });

  test('rounded explicit offer price retains its discount reference', () {
    final batch = stock(price: '10.35');
    final item = product(stocks: [batch]);
    final provider = providerWith([tenPercent]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 2, selectedStock: batch, price: 9.32);
    final line = provider.cartItems.single;
    final payload = provider.buildOrderItemsPayload().single;
    // The rounded echo of the 9.315 offer price goes back to the exact offer
    // price: 2 units total 18.63, not 18.64.
    expect(line.price, 9.315);
    expect(line.amounts.total, 18.63);
    expect(payload['price'], 9.315);
    expect(payload['offer_id'], 9);
    expect(line.hasOffer, true);
    expect(line.isManualPriceOverride, false);
    expect(payload['standard_unit_price'], 10.35);
  });
  test('tiny batch amounts and taxes stay nonnegative and match the receipt', () {
    final provider = providerWith([]);
    for (final price in [0.005, 0.04]) {
      provider.cartItems.clear();
      provider.cartItems.add(LocalCartItem(
        product: GetProduct(productId: 1, unit: 'PCS'),
        price: price,
        quantity: 4,
        taxRate: 18,
        stockReservations: [
          for (var id = 1; id <= 4; id++)
            StockReservation(stockId: id, quantity: 1),
        ],
      ));
      final payload = provider.buildOrderItemsPayload();
      expect(payload, hasLength(4));
      for (final line in payload) {
        expect(line['total_price'], greaterThanOrEqualTo(0));
        expect(line['tax_amount'], greaterThanOrEqualTo(0));
      }
      final total = payload.fold<double>(0, (sum, line) => sum + (line['total_price'] as num));
      final tax = payload.fold<double>(0, (sum, line) => sum + (line['tax_amount'] as num));
      expect(provider.cartTotal, closeTo(total, 0.000001));
      expect(provider.priceSummary!.totalTax, closeTo(tax, 0.000001));
      expect(double.parse(PrintService.savedOrderReceiptItem(provider.cartItems.single)['tax_amount'] as String), closeTo(tax, 0.000001));
    }
  });

  test('normal whole-unit totals and order discounts agree with rounded lines', () {
    final provider = providerWith([]);
    provider.cartItems.add(LocalCartItem(
      product: GetProduct(productId: 1, unit: 'PCS'),
      price: 12.35, quantity: 4, taxRate: 18,
      stockReservations: [
        StockReservation(stockId: 87, quantity: 2),
        StockReservation(stockId: 88, quantity: 2),
      ],
    ));
    expect(provider.cartTotal, 49.4);
    provider.applyDiscount(flatDiscount: 2, percentageDiscount: 10);
    expect(provider.priceSummary!.discount, 6.94);
    expect(provider.cartTotal, 42.46);
    expect(provider.buildOrderItemsPayload().fold<double>(0, (sum, line) => sum + (line['total_price'] as num)), 49.4);
  });

  test('price preview shares batch allocation and never reserves stock', () {
    final first = stock(id: 87).copyWith(quantity: 2);
    final second = stock(id: 88).copyWith(quantity: 10);
    final item = product(stocks: [first, second]);
    final provider = providerWith([
      tenPercent,
      productOffer(
          id: 10, lines: [offerLine(productId: 1, stockId: 87, value: 20)]),
    ]);
    provider.initializeProducts([item]);
    final oneBatch = provider.previewProductPrice(product: item, quantity: 2);
    final twoBatches = provider.previewProductPrice(product: item, quantity: 3);
    expect(oneBatch.unitPrice, 80);
    expect(twoBatches.unitPrice, 90);
    expect(provider.cartItems, isEmpty);
    expect(provider.products.single.stock!.map((stock) => stock.quantity),
        [2, 10]);
    provider.addToCart(product: item, quantity: 3, selectedStock: first);
    expect(provider.cartItems.single.price, twoBatches.baseUnitPrice);
    expect(provider.cartItems.single.stockReservations.map((r) => r.stockId),
        [87, 88]);
  });

  test('a preview includes existing reservations when adding across batches',
      () {
    final first = stock(id: 87).copyWith(quantity: 2);
    final second = stock(id: 88).copyWith(quantity: 10);
    final item = product(stocks: [first, second]);
    final provider = providerWith([
      tenPercent,
      productOffer(
          id: 10, lines: [offerLine(productId: 1, stockId: 87, value: 20)]),
    ]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 2, selectedStock: first);
    final preview = provider.previewProductPrice(
        product: item, quantity: 1, includeCartQuantity: true);
    expect(preview.unitPrice, 90);
    expect(provider.cartItems.single.price, 80);
    expect(second.quantity, 10);
    provider.addToCart(product: item, quantity: 1, selectedStock: second);
    expect(provider.cartItems.single.price, preview.baseUnitPrice);
    expect(provider.cartItems.single.quantity, 3);
  });

  test('preview keeps a manual line price when the popup will merge into it',
      () {
    final batch = stock(wholesalePrice: '80', wholesaleMinUnit: 5);
    final item = product(stocks: [batch]);
    final provider = providerWith([tenPercent]);
    provider.initializeProducts([item]);
    provider.addToCart(
        product: item,
        quantity: 1,
        selectedStock: batch,
        price: 95,
        markPriceAsManualOverride: true);
    final preview = provider.previewProductPrice(
        product: item, quantity: 4, includeCartQuantity: true);
    expect(preview.unitPrice, 95);
    expect(preview.hasOffer, isFalse);
    expect(provider.cartItems.single.quantity, 1);
    provider.addToCart(product: item, quantity: 4, selectedStock: batch);
    expect(provider.cartItems.single.price, preview.baseUnitPrice);
    expect(provider.cartItems.single.isManualPriceOverride, isTrue);
  });

  test(
      'preview preserves three decimal offer prices and ignores manual margin floors',
      () {
    final batch = stock(price: '19.99');
    final item = product(stocks: [batch]);
    final provider = providerWith([
      productOffer(lines: [offerLine(productId: 1, value: 15)]),
    ]);
    provider.initializeProducts([item]);
    final preview = provider.previewProductPrice(product: item, quantity: 3);
    expect(preview.unitPrice, 16.992);
    expect(preview.standardUnitPrice, 19.99);
    expect(preview.total, 50.98);
    provider.addToCart(product: item, quantity: 3, selectedStock: batch);
    expect(provider.cartItems.single.price, preview.baseUnitPrice);
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

  test('a line re-added at its offer price keeps it and the offer', () {
    // Restaurant checkout re-adds kitchen lines at the price they carry.
    final provider = providerWith([tenPercent]);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(
      product: item,
      quantity: 2,
      price: 90,
      selectedStock: batch,
    );

    final line = provider.cartItems.single;
    expect(line.price, 90);
    expect(line.offerId, 9);
    expect(line.offerVersion, 3);
    expect(line.standardUnitPrice, 100);
    expect(line.isManualPriceOverride, isFalse);
    expect(provider.cartTotal, 180);
  });

  test('a line re-added at another price keeps it without an offer', () {
    final provider = providerWith([tenPercent]);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(
      product: item,
      quantity: 1,
      price: 95,
      selectedStock: batch,
    );

    final line = provider.cartItems.single;
    expect(line.price, 95);
    expect(line.hasOffer, isFalse);
    expect(line.standardUnitPrice, 100);
    expect(line.isManualPriceOverride, isFalse);
  });

  test('a stock spill at the offer price is not discounted twice', () {
    final provider = providerWith([tenPercent])
      ..setActiveStockGroupingFields({'price', 'mrp', 'unit'});
    final first = stock(id: 88);
    // Another pricing group, so the spill creates a new line.
    final other = stock(id: 89).copyWith(mrp: '130');
    final item = product(stocks: [first, other]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 1, selectedStock: first);
    final offerLine = provider.cartItems.single;
    expect(offerLine.price, closeTo(90, 0.0001));

    // What CartQuantityStockHelper does when the batch runs out.
    provider.addToCart(
      product: item,
      quantity: 1,
      price: offerLine.price,
      mrp: offerLine.mrp,
      markPriceAsManualOverride: offerLine.isManualPriceOverride,
      isIncreamentUsingCompactQuantityControl: true,
      selectedStock: other,
    );

    expect(provider.cartItems, hasLength(2));
    for (final line in provider.cartItems) {
      expect(line.price, closeTo(90, 0.0001));
      expect(line.offerId, 9);
      expect(line.standardUnitPrice, 100);
    }
    expect(provider.cartTotal, 180);
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

  test('committing the unchanged price keeps the offer line automatic', () {
    final provider = providerWith([tenPercent]);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 1, selectedStock: batch);
    var notifications = 0;
    provider.addListener(() => notifications++);

    // Enter / Tab / blur on the price field commits the same value.
    provider.updateItemPrice(1, batch, 90);
    final line = provider.cartItems.single;
    expect(line.price, closeTo(90, 0.0001));
    expect(line.offerId, 9);
    expect(line.isManualPriceOverride, isFalse);
    expect(notifications, 0);

    // A real change still becomes a manual price.
    provider.updateItemPrice(1, batch, 85);
    expect(line.price, 85);
    expect(line.isManualPriceOverride, isTrue);
    expect(line.hasOffer, isFalse);
    expect(line.standardUnitPrice, 100);
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

    final restarted = providerWith([tenPercent]);
    await restarted.hydrated;
    final line = restarted.cartItems.single;
    expect(line.price, closeTo(90, 0.0001));
    expect(line.offerId, 9);
    expect(line.offerVersion, 3);
    expect(line.standardUnitPrice, 100);
    await restarted.flushPersistence();
  });

  test('a restored cart is re-priced when offers were switched off', () async {
    final provider = providerWith([tenPercent]);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 1, selectedStock: batch);
    await provider.flushPersistence();

    final restarted = providerWith(const [], enabled: false);
    await restarted.hydrated;
    final line = restarted.cartItems.single;
    expect(line.price, 100);
    expect(line.hasOffer, isFalse);
    expect(line.standardUnitPrice, 100);
    await restarted.flushPersistence();
    expect(Hive.box<HiveLocalCartItem>('cart_items').values.single.offerId,
        isNull);
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

  test('held offer cart is re-priced when resumed after offers are disabled',
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
    // Offers must be valid when the sale is completed.
    expect(provider.cartItems.single.price, 100);
    expect(provider.cartItems.single.hasOffer, isFalse);
    expect(provider.cartItems.single.standardUnitPrice, 100);
    expect(provider.cartTotal, 200);
  });

  test('held offer cart is re-priced when resumed after the offer ended',
      () async {
    var now = offerTestNow;
    final provider = providerWith([
      productOffer(
        version: 3,
        validUntil: offerTestNow.add(const Duration(hours: 1)),
        lines: [offerLine(productId: 1, value: 10)],
      ),
    ], clock: () => now);
    final batch = stock(taxRate: '18');
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 2, selectedStock: batch);
    expect(provider.cartItems.single.price, closeTo(90, 0.0001));
    final held = provider.saveCurrentCartAsOrder(comment: 'QA offer hold');
    await provider.flushPersistence();
    provider.clearCart();
    // Product previews still need the timer after the cart is held.
    expect(provider.debugNextOfferBoundary,
        offerTestNow.add(const Duration(hours: 1)));

    now = offerTestNow.add(const Duration(hours: 2));
    provider.loadOrderForEditing(held.id);
    final line = provider.cartItems.single;
    expect(line.price, 100);
    expect(line.hasOffer, isFalse);
    // 100 inclusive of 18% tax.
    expect(line.taxAmount, closeTo(15.254, 0.001));
    expect(provider.cartTotal, 200);
    await provider.flushPersistence();
  });

  test('removing the offer while it is in the cart restores the standard price',
      () async {
    final provider = providerWith([tenPercent]);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 2, selectedStock: batch);
    expect(provider.cartTotal, 180);

    provider.offerRepository.debugSetCatalog(offerCatalog(const []));
    final line = provider.cartItems.single;
    expect(line.price, 100);
    expect(line.hasOffer, isFalse);
    // The cart badge shows nothing without an offer.
    expect(line.displayStandardPrice, isNull);
    expect(provider.cartTotal, 200);
    expect(provider.buildOrderItemsPayload().single.containsKey('offer_id'),
        isFalse);
    await provider.flushPersistence();
    expect(Hive.box<HiveLocalCartItem>('cart_items').values.single.price, 100);
  });

  test('switching POS_OFFERS off re-prices the open cart', () {
    final provider = providerWith([tenPercent]);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 1, selectedStock: batch);

    provider.offerRepository
        .debugSetCatalog(offerCatalog([tenPercent], enabled: false));
    expect(provider.cartItems.single.price, 100);
    expect(provider.cartItems.single.hasOffer, isFalse);
  });

  test('an offer synced while a line is in the cart is applied', () {
    final provider = providerWith(const []);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 2, selectedStock: batch);
    expect(provider.cartItems.single.price, 100);

    provider.offerRepository.debugSetCatalog(offerCatalog([tenPercent]));
    final line = provider.cartItems.single;
    expect(line.price, closeTo(90, 0.0001));
    expect(line.offerId, 9);
    expect(line.offerVersion, 3);
    expect(provider.cartTotal, 180);
  });

  test('offer changes never touch manual or explicit-price lines', () {
    final provider = providerWith(const [])
      ..setActiveStockGroupingFields({'price', 'mrp', 'unit'});
    final batch = stock();
    final otherBatch = stock(id: 89).copyWith(mrp: '130');
    final item = product(stocks: [batch, otherBatch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 1, selectedStock: batch);
    provider.updateItemPrice(1, batch, 95);
    provider.addToCart(
      product: item,
      quantity: 1,
      price: 97,
      selectedStock: otherBatch,
    );

    provider.offerRepository.debugSetCatalog(offerCatalog([tenPercent]));
    final byStock = {
      for (final line in provider.cartItems) line.selectedStock!.id: line
    };
    expect(byStock[88]!.price, 95);
    expect(byStock[88]!.isManualPriceOverride, isTrue);
    expect(byStock[89]!.price, 97);
    for (final line in provider.cartItems) {
      expect(line.hasOffer, isFalse);
    }
  });

  test('the boundary timer ends the offer at valid_until', () {
    var now = offerTestNow;
    final validUntil = offerTestNow.add(const Duration(hours: 1));
    final provider = providerWith([
      productOffer(validUntil: validUntil, lines: [offerLine(productId: 1)]),
    ], clock: () => now);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 1, selectedStock: batch);
    expect(provider.cartItems.single.price, 90);
    expect(provider.debugNextOfferBoundary, validUntil);

    now = validUntil;
    provider.debugRunOfferBoundaryTimer();
    expect(provider.cartItems.single.price, 100);
    expect(provider.cartItems.single.hasOffer, isFalse);
    expect(provider.debugNextOfferBoundary, isNull);
  });

  test('nested checkout holds keep prices stable and catch up after cancellation', () async {
    var now = offerTestNow;
    final end = now.add(const Duration(minutes: 1));
    final provider = providerWith([
      productOffer(validUntil: end, lines: [offerLine(productId: 1)]),
    ], clock: () => now);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, selectedStock: batch);
    final checkoutDone = provider.holdOfferPricesForCheckout();
    final paymentDone = provider.holdOfferPricesForCheckout();
    now = end;
    provider.debugRunOfferBoundaryTimer();
    provider.offerRepository.debugSetCatalog(offerCatalog([]));
    expect(provider.cartItems.single.price, 90);
    paymentDone();
    paymentDone(); // Releasing a closed dialog twice is harmless.
    await Future<void>.delayed(Duration.zero);
    expect(provider.cartItems.single.price, 90);
    checkoutDone();
    await Future<void>.delayed(Duration.zero);
    expect(provider.cartItems.single.price, 100);
    expect(provider.cartItems.single.hasOffer, false);
  });

  test('the boundary timer starts an offer at valid_from', () {
    var now = offerTestNow;
    final validFrom = offerTestNow.add(const Duration(minutes: 30));
    final provider = providerWith([
      productOffer(validFrom: validFrom, lines: [offerLine(productId: 1)]),
    ], clock: () => now);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 1, selectedStock: batch);
    expect(provider.cartItems.single.price, 100);
    expect(provider.debugNextOfferBoundary, validFrom);

    now = validFrom;
    provider.debugRunOfferBoundaryTimer();
    expect(provider.cartItems.single.price, 90);
    expect(provider.cartItems.single.offerId, 9);
    expect(provider.debugNextOfferBoundary, DateTime.utc(2026, 11, 1));
  });

  test('the boundary timer fires on its own when the offer ends', () async {
    final realNow = DateTime.now().toUtc();
    final provider = providerWith([
      productOffer(
        validFrom: realNow.subtract(const Duration(hours: 1)),
        validUntil: realNow.add(const Duration(milliseconds: 300)),
        lines: [offerLine(productId: 1)],
      ),
    ], clock: DateTime.now);
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 1, selectedStock: batch);
    expect(provider.cartItems.single.price, 90);

    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(provider.cartItems.single.price, 100);
    expect(provider.cartItems.single.hasOffer, isFalse);
    await provider.flushPersistence();
  });

  test('offer validity is judged with the trusted clock, not DateTime.now', () {
    // The device clock is 3 hours behind the server; the offer starts at
    // 12:00 server time, years away from today.
    final deviceNow = DateTime.utc(2031, 3, 1, 10);
    final provider = providerWith([
      productOffer(
        validFrom: DateTime.utc(2031, 3, 1, 12),
        validUntil: DateTime.utc(2031, 3, 2),
        lines: [offerLine(productId: 1)],
      ),
    ], clock: () => deviceNow, clockOffset: const Duration(hours: 3));
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 1, selectedStock: batch);
    expect(provider.cartItems.single.price, 90);
    expect(provider.cartItems.single.offerId, 9);
  });

  test('an offer running today is not applied at another trusted time', () {
    final realNow = DateTime.now().toUtc();
    final provider = providerWith([
      productOffer(
        validFrom: realNow.subtract(const Duration(days: 1)),
        validUntil: realNow.add(const Duration(days: 1)),
        lines: [offerLine(productId: 1)],
      ),
    ], clock: () => DateTime.utc(2031, 3, 1, 10));
    final batch = stock();
    final item = product(stocks: [batch]);
    provider.initializeProducts([item]);
    provider.addToCart(product: item, quantity: 1, selectedStock: batch);
    expect(provider.cartItems.single.price, 100);
    expect(provider.cartItems.single.hasOffer, isFalse);
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
