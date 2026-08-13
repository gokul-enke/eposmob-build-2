import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'test_support/hive_test_teardown.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/cart/cart_item_card.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAppSettingsProvider extends AppSettingsProvider {
  _FakeAppSettingsProvider(this.settings);

  final AppSettings settings;

  @override
  Future<void> fetchAppSettings() async {}

  @override
  AppSettings? get appSettings => settings;
}

class _FakeRoleProvider extends RoleProvider {
  @override
  bool currentUserHasPermissionSync(String permission) => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;
  const controller = BillingMobileCartController();

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_mobile_cart_unit_');
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

  GetProduct buildProduct({
    String price = '10',
    String? minMarginPercentage,
    String? minMarginPrice,
    List<SaleUnit>? saleUnits,
    List<ProductTax>? taxes,
    List<Stock>? stock,
    List<ProductVariant>? variants,
  }) {
    return GetProduct(
      productId: 1,
      productName: 'Rice',
      unit: 'PCS',
      price: ProductPrice(price: price),
      mrp: '120',
      minMarginPercentage: minMarginPercentage,
      minMarginPrice: minMarginPrice,
      stock: stock,
      variants: variants,
      saleUnits: saleUnits ??
          [
            SaleUnit(
              id: 10,
              unitId: 100,
              unitName: 'CASE',
              conversionRate: '12',
            ),
            SaleUnit(
              id: 10,
              unitId: 100,
              unitName: 'CASE',
              conversionRate: '12',
            ),
            SaleUnit(
              id: 11,
              unitId: 101,
              unitName: 'BOX',
              conversionRate: '6',
            ),
          ],
      taxes: taxes ?? [ProductTax(rate: '5')],
    );
  }

  group('BillingMobileCartController sale units', () {
    test('dedupes sale units by id when building menu options', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct();
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 24, price: 10, mrp: 12);

      final item = provider.cartItems.single;
      final options = controller.cartUnitOptionsForItem(item);

      expect(options.map((option) => option.label), ['PCS', 'CASE', 'BOX']);
      expect(options.where((option) => option.label == 'CASE'), hasLength(1));
    });

    test('changeSaleUnit preserves display quantity and converts price', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct();
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 24, price: 10, mrp: 12);

      final item = provider.cartItems.single;
      final result = controller.changeSaleUnit(
        provider: provider,
        item: item,
        value: '10',
      );

      expect(result.success, isTrue);
      final updated = provider.cartItems.single;
      expect(updated.quantity, 288);
      expect(updated.displayQuantity, 24);
      expect(updated.displayPrice, 120);
      expect(updated.saleUnitId, 10);

      final payload = provider.buildOrderItemsPayload();
      expect(payload.single['quantity'], 24);
      expect(payload.single['price'], 120);
      expect(payload.single['sale_unit_id'], 10);
    });

    test('changeSaleUnit back to base reinterprets displayed quantity', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct();
      provider.initializeProducts([product]);
      provider.addToCart(
        product: product,
        quantity: 24,
        price: 10,
        mrp: 12,
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 12,
      );

      final item = provider.cartItems.single;
      final result = controller.changeSaleUnit(
        provider: provider,
        item: item,
        value: 'base',
      );

      expect(result.success, isTrue);
      final updated = provider.cartItems.single;
      expect(updated.quantity, 2);
      expect(updated.displayQuantity, 2);
      expect(updated.displayPrice, 10);
      expect(updated.saleUnitId, isNull);
    });
  });

  group('BillingMobileCartController price and tax', () {
    test('inclusiveTaxAmount uses price * quantity * rate / (100 + rate)', () {
      final tax = controller.inclusiveTaxAmount(
        unitPrice: 105,
        quantity: 2,
        taxRate: 5,
      );

      expect(tax, closeTo(10, 0.001));
    });

    test('commitDisplayPrice clamps below minimum sale price', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct(
        price: '100',
        minMarginPercentage: '10',
        saleUnits: const [],
        taxes: const [],
      );
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 1, price: 100, mrp: 120);

      final item = provider.cartItems.single;
      final result = controller.commitDisplayPrice(
        provider: provider,
        item: item,
        displayPrice: 80,
      );

      expect(result.committed, isTrue);
      expect(result.clampedToDisplayPrice, 90);
      expect(provider.cartItems.single.price, 90);
    });

    test('combined amount and percentage limits use the stricter limit', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct(
        price: '100',
        minMarginPercentage: '15',
        minMarginPrice: '10',
        saleUnits: const [],
      );
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 1, price: 100);

      expect(
        provider.minimumSalePriceForCartItem(provider.cartItems.single),
        90,
      );
    });

    test('stock price is the discount reference price', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final stock = Stock(id: 1, price: '80', quantity: 20);
      final product = buildProduct(
        price: '100',
        minMarginPercentage: '10',
        saleUnits: const [],
        stock: [stock],
      );
      provider.initializeProducts([product]);
      provider.addToCart(
        product: product,
        quantity: 1,
        selectedStock: stock,
      );

      expect(provider.cartItems.single.price, 80);
      expect(
        provider.minimumSalePriceForCartItem(provider.cartItems.single),
        72,
      );
    });

    test('wholesale price is the discount reference after its threshold', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final stock = Stock(
        id: 1,
        price: '100',
        wholesalePrice: '70',
        wholesaleMinUnit: 5,
        quantity: 20,
      );
      final product = buildProduct(
        price: '100',
        minMarginPrice: '7',
        saleUnits: const [],
        stock: [stock],
      );
      provider.initializeProducts([product]);
      provider.addToCart(
        product: product,
        quantity: 5,
        selectedStock: stock,
      );

      expect(provider.cartItems.single.price, 70);
      expect(
        provider.minimumSalePriceForCartItem(provider.cartItems.single),
        63,
      );
    });

    test('variant price is the discount reference price', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct(
        price: '100',
        minMarginPercentage: '10',
        saleUnits: const [],
        variants: [ProductVariant(id: 7, price: 60)],
      );
      provider.initializeProducts([product]);
      provider.addToCart(
        product: product,
        quantity: 1,
        variantId: 7,
      );

      expect(provider.cartItems.single.price, 60);
      expect(
        provider.minimumSalePriceForCartItem(provider.cartItems.single),
        54,
      );
    });

    test('explicit sale-unit price is the discount reference price', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct(
        price: '10',
        minMarginPercentage: '10',
        saleUnits: [
          SaleUnit(
            id: 10,
            unitId: 100,
            unitName: 'CASE',
            conversionRate: '12',
            price: 240,
          ),
        ],
      );
      provider.initializeProducts([product]);
      provider.addToCart(
        product: product,
        quantity: 12,
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 12,
      );

      final item = provider.cartItems.single;
      expect(item.price, 20);
      expect(provider.minimumSalePriceForCartItem(item), 18);

      final result = controller.commitDisplayPrice(
        provider: provider,
        item: item,
        displayPrice: 200,
      );
      expect(result.clampedToDisplayPrice, 216);
      expect(provider.cartItems.single.price, 18);
    });

    test('manual price does not replace a configured discount reference', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct(
        price: '100',
        minMarginPrice: '10',
        saleUnits: const [],
      );
      provider.initializeProducts([product]);
      provider.addToCart(
        product: product,
        quantity: 1,
        price: 50,
        markPriceAsManualOverride: true,
      );

      expect(
        provider.minimumSalePriceForCartItem(provider.cartItems.single),
        90,
      );
      expect(provider.cartItems.single.price, 90);
    });

    test('commitDisplayPrice converts sale-unit display price to base price',
        () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct(saleUnits: [
        SaleUnit(
          id: 10,
          unitId: 100,
          unitName: 'CASE',
          conversionRate: '12',
        ),
      ]);
      provider.initializeProducts([product]);
      provider.addToCart(
        product: product,
        quantity: 12,
        price: 10,
        mrp: 12,
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 12,
      );

      final item = provider.cartItems.single;
      controller.commitDisplayPrice(
        provider: provider,
        item: item,
        displayPrice: 132,
      );

      expect(provider.cartItems.single.price, closeTo(11, 0.001));
      expect(provider.cartItems.single.isManualPriceOverride, isTrue);
    });

    test('updateDisplayPriceWhileEditing persists manual override while typing',
        () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct(saleUnits: const [], taxes: const []);
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 1, price: 100, mrp: 120);

      provider.updateItemPrice(product.productId!, null, 100);
      expect(provider.cartItems.single.price, 100);

      controller.updateDisplayPriceWhileEditing(
        provider: provider,
        item: provider.cartItems.single,
        text: '95',
      );
      expect(provider.cartItems.single.price, 95);
    });
  });

  group('CartItemCard widget', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      required LocalProductProvider provider,
      LocalCartItem? item,
      bool showMrp = true,
      bool showTaxRate = true,
      bool showTaxAmount = true,
    }) async {
      final cartItem = item ?? provider.cartItems.single;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocalProductProvider>.value(value: provider),
            ChangeNotifierProvider<RoleProvider>(
              create: (_) => _FakeRoleProvider(),
            ),
            ChangeNotifierProvider<CustomerSelectionProvider>(
              create: (_) => CustomerSelectionProvider(),
            ),
            ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) => _FakeAppSettingsProvider(
                AppSettings(
                  barcodeSales: false,
                  customerCarePhone: '',
                  customerCareEmail: '',
                  printTitle: '',
                  showCustomerLastBuyedPriceList: false,
                  askDeliveryDate: false,
                  priceRoundOff: false,
                  discountAndCoupon: false,
                  autoAssignDefaultCustomer: false,
                  autoAssignDefaultCustomerPhone: '',
                  currency: 'SAR',
                  workingTime: '',
                  zatcaPhase1Enabled: false,
                  zatcaPhase2Enabled: false,
                  showTaxPos: showTaxAmount,
                  showMrpPos: showMrp,
                  showTaxRatePos: showTaxRate,
                  showConfirmOrderButton: true,
                  enableKOTPrint: false,
                  defaultDeliveryMethod: '',
                  defaultPaymentMethod: '',
                  posPrintDoubleBill: false,
                  skipCustomerSelection: false,
                  hideDefaultPhone: false,
                  freeDeliveryEnabled: false,
                  freeDeliveryMinimumAmount: '',
                  itemCodeEnabled: false,
                  companyB2BEnabled: false,
                  enableSendToKitchenButton: false,
                  enableKotBillButton: false,
                  kotBillAutoMarkServed: false,
                  kotBillAllowedForDineIn: false,
                  pineLabPayment: false,
                  multiSaleUnitEnabled: true,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CartItemCard(
                item: cartItem,
                controller: controller,
                onDecrease: () {},
                onIncrease: () {},
                onRemove: () {},
                onSaleUnitChanged: (_) {},
                showMrp: showMrp,
                showTaxRate: showTaxRate,
                showTaxAmount: showTaxAmount,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows sale unit selector and current unit label',
        (tester) async {
      final provider = LocalProductProvider();

      // testWidgets runs inside Flutter's FakeAsync zone, which never fires
      // Hive's internal write-flush Timer. Run every Hive-touching
      // LocalProductProvider call inside tester.runAsync() (a real async
      // zone) so all writes complete before this test exits — otherwise
      // tearDownAll's `Hive.close()` hangs waiting on a flush that will
      // never happen. See the identical fix in
      // test/p0_4_mobile_quantity_stock_test.dart for the full rationale.
      await tester.runAsync(() async {
        provider.setStockEnabled(false);
        final product = buildProduct();
        provider.initializeProducts([product]);
        provider.addToCart(
          product: product,
          quantity: 24,
          price: 10,
          mrp: 12,
          saleUnitId: 10,
          saleUnitName: 'CASE',
          saleUnitConversionRate: 12,
        );
      });

      await pumpCard(tester, provider: provider);

      expect(find.text('CASE'), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });
  });
}
