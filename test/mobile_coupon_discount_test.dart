/// P2.1 — Coupon and discount mobile tests.
///
/// Unit tests target [BillingMobileCouponController]; one widget smoke test
/// mounts [CouponSection] for apply/clear wiring.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/coupon_section.dart';
import 'package:pos_machine/helpers/payment_auto_fill_helper.dart';
import 'package:pos_machine/models/discount_list_model.dart';
import 'package:pos_machine/services/print_service.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/discount_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

class _FakeDiscountProvider extends DiscountProvider {
  @override
  Future<void> fetchDiscounts({bool forceRefresh = false}) async {}
}

class _FakeCartProvider extends CartProvider {
  @override
  getData() async {}

  @override
  Future<void> fetchCartDataFromApi({
    required int customerId,
    required String accessToken,
    int? cartId,
  }) async {}
}

GetProduct _product({String price = '100'}) {
  return GetProduct(
    productId: 1,
    productName: 'Test Item',
    price: ProductPrice(price: price),
    mrp: price,
    purchasePrice: '50',
    unit: 'PCS',
    stock: const <Stock>[],
    taxes: const <ProductTax>[],
  );
}

LocalProductProvider _cartWithSubtotal(String price, {int quantity = 1}) {
  final provider = LocalProductProvider();
  final item = _product(price: price);
  provider.initializeProducts([item]);
  provider.addToCart(product: item, quantity: quantity);
  return provider;
}

class _FakeAppSettingsProvider extends AppSettingsProvider {
  @override
  Future<void> fetchAppSettings() async {}
}

class _SeededDiscountProvider extends _FakeDiscountProvider {
  _SeededDiscountProvider(this._seeded);

  final List<DiscountData> _seeded;

  @override
  List<DiscountData> get discounts => _seeded;
}

Map<String, dynamic> _couponJson({required String type, required int value}) {
  return {
    'id': 1,
    'coupon_code': 'SUNDAYOFFER',
    'discount_category_id': 1,
    'coupon_name': 'Sundayoffer',
    'store_id': 1,
    'category_id': null,
    'product_id': null,
    'discount_type': type,
    'valid_from_date': '',
    'valid_to_date': '',
    'discount_coupon_limit_count': 0,
    'discount_coupon_limit_amount': null,
    'discount_coupon_min_amount': null,
    'discount_coupon_max_amount': null,
    'discount_value': value,
    'company_id': 1,
    'created_at': null,
    'updated_at': null,
  };
}

Finder _percentageDiscountField() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration is InputDecoration &&
        (widget.decoration as InputDecoration).hintText == '0',
  );
}

Finder _flatDiscountField() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration is InputDecoration &&
        (widget.decoration as InputDecoration).hintText == '0.00',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_coupon_test_');
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
    SharedPreferences.setMockInitialValues({});
    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
  });

  tearDownAll(() async {
    try {
      await Hive.close().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Widget tests can leave Hive flush timers pending in FakeAsync.
    }
    if (await hiveDir.exists()) await hiveDir.delete(recursive: true);
  });

  group('BillingMobileCouponController.validateDiscountInputs', () {
    const controller = BillingMobileCouponController();

    test('rejects negative flat discount', () {
      final result = controller.validateDiscountInputs(
        flatDiscountText: '-5',
        percentageDiscountText: '',
        originalSubTotal: 100,
      );
      expect(result.isValid, isFalse);
      expect(result.errorMessage, BillingMobileErrorMessages.discountNegative);
    });

    test('rejects negative percentage discount', () {
      final result = controller.validateDiscountInputs(
        flatDiscountText: '',
        percentageDiscountText: '-10',
        originalSubTotal: 100,
      );
      expect(result.isValid, isFalse);
      expect(result.errorMessage, BillingMobileErrorMessages.discountNegative);
    });

    test('rejects percentage discount above 100', () {
      final result = controller.validateDiscountInputs(
        flatDiscountText: '',
        percentageDiscountText: '150',
        originalSubTotal: 100,
      );
      expect(result.isValid, isFalse);
      expect(
        result.errorMessage,
        BillingMobileErrorMessages.discountPercentMax,
      );
    });

    test('rejects flat discount exceeding cart subtotal', () {
      final result = controller.validateDiscountInputs(
        flatDiscountText: '150',
        percentageDiscountText: '',
        originalSubTotal: 100,
      );
      expect(result.isValid, isFalse);
      expect(
        result.errorMessage,
        BillingMobileErrorMessages.discountFlatExceedsTotal,
      );
    });

    test('accepts valid flat discount within subtotal', () {
      final result = controller.validateDiscountInputs(
        flatDiscountText: '20',
        percentageDiscountText: '',
        originalSubTotal: 100,
      );
      expect(result.isValid, isTrue);
    });
  });

  group('BillingMobileCouponController coupon field sync', () {
    const controller = BillingMobileCouponController();
    final coupon =
        DiscountData.fromJson(_couponJson(type: 'percent', value: 20));

    test('coupon field values drop trailing .0', () {
      final values = controller.fieldValuesForSelectedDiscount(coupon);
      expect(values.flat, '');
      expect(values.percent, '20');
    });

    test('does not clear coupon while fields still hold its values', () {
      expect(
        controller.shouldClearSelectedCouponOnManualInput(
          flatDiscountText: '',
          percentageDiscountText: '20',
          selectedDiscount: coupon,
        ),
        isFalse,
      );
      expect(
        controller.shouldClearSelectedCouponOnManualInput(
          flatDiscountText: '',
          percentageDiscountText: '20.0',
          selectedDiscount: coupon,
        ),
        isFalse,
      );
    });

    test('clears coupon when user edits the values', () {
      expect(
        controller.shouldClearSelectedCouponOnManualInput(
          flatDiscountText: '5',
          percentageDiscountText: '20',
          selectedDiscount: coupon,
        ),
        isTrue,
      );
    });

    test('does not wipe un-applied fields while cart discount is zero', () {
      expect(
        controller.shouldSyncClearedDiscountFields(
          previousFlatDiscount: 0,
          previousPercentageDiscount: 0,
          flatDiscount: 0,
          percentageDiscount: 0,
          flatFieldText: '',
          percentageFieldText: '20',
        ),
        isFalse,
      );
    });

    test('wipes fields when an applied discount is cleared externally', () {
      expect(
        controller.shouldSyncClearedDiscountFields(
          previousFlatDiscount: 0,
          previousPercentageDiscount: 20,
          flatDiscount: 0,
          percentageDiscount: 0,
          flatFieldText: '',
          percentageFieldText: '20',
        ),
        isTrue,
      );
    });
  });

  group('BillingMobileCouponController.applyDiscount', () {
    const couponController = BillingMobileCouponController();
    const paymentController = BillingMobilePaymentController();

    test('applies valid flat discount to cart', () async {
      final lpp = _cartWithSubtotal('100');
      final bp = BillingProvider();

      final result = await couponController.applyDiscount(
        localProductProvider: lpp,
        billingProvider: bp,
        discountProvider: _FakeDiscountProvider(),
        paymentController: paymentController,
        flatDiscountText: '20',
        percentageDiscountText: '',
        selectedDiscount: null,
      );

      expect(result.success, isTrue);
      expect(lpp.getCurrentDiscount()['flatDiscount'], 20.0);
      expect(lpp.getCurrentDiscount()['percentageDiscount'], 0.0);
    });

    test('downloaded coupon applies locally and records the code', () async {
      final lpp = _cartWithSubtotal('100');
      final bp = BillingProvider();
      final coupon =
          DiscountData.fromJson(_couponJson(type: 'percent', value: 20));

      final result = await couponController.applyDiscount(
        localProductProvider: lpp,
        billingProvider: bp,
        discountProvider: _FakeDiscountProvider(),
        paymentController: paymentController,
        flatDiscountText: '',
        percentageDiscountText: '20',
        selectedDiscount: coupon,
      );

      expect(result.success, isTrue);
      expect(lpp.getCurrentDiscount()['percentageDiscount'], 0.0);
      expect(lpp.getCurrentDiscount()['flatDiscount'], 20.0);
      expect(lpp.appliedCoupon?.discountValue, 20);
      expect(lpp.priceSummary!.netTotal, 80.0);
      expect(bp.coupenCodeTextController.text, 'SUNDAYOFFER');
      expect(bp.couponCode, 'SUNDAYOFFER');
      expect(bp.isCouponApplied, isTrue);
    });

    test('flat coupon replaces the previous discount and remaps full payment',
        () async {
      final lpp = _cartWithSubtotal('100');
      final bp = BillingProvider();
      lpp.applyDiscount(flatDiscount: 5, percentageDiscount: 0);
      bp.setCouponApplied(true, code: 'SAVE5', discount: 5);
      bp.setTotalOrderAmount(95);
      bp.cashAmountController.text = '95';
      bp.setPaymentMethod('CASH', true);
      final coupon =
          DiscountData.fromJson(_couponJson(type: 'fixed', value: 20));

      for (var attempt = 0; attempt < 2; attempt++) {
        final result = await couponController.applyDiscount(
          localProductProvider: lpp,
          billingProvider: bp,
          discountProvider: _FakeDiscountProvider(),
          paymentController: paymentController,
          flatDiscountText: '20',
          percentageDiscountText: '',
          selectedDiscount: coupon,
        );

        expect(result.success, isTrue);
        expect(lpp.priceSummary!.netTotal, 80);
        expect(bp.couponCode, 'SUNDAYOFFER');
        expect(bp.totalOrderAmount, 80);
        expect(bp.getTotalPaidAmount(), 80);
      }
    });

    for (final scenario in <String, Map<String, dynamic>>{
      'expired': {'valid_to_date': '2001-01-01'},
      'future': {'valid_from_date': '2999-01-01'},
      'below minimum': {'discount_coupon_min_amount': 150},
      'above maximum': {'discount_coupon_max_amount': 50},
    }.entries) {
      test('${scenario.key} coupon leaves previous discount and payment intact',
          () async {
        final lpp = _cartWithSubtotal('100');
        final bp = BillingProvider();
        lpp.applyDiscount(flatDiscount: 5, percentageDiscount: 0);
        bp.setCouponApplied(true, code: 'SAVE5', discount: 5);
        bp.setTotalOrderAmount(95);
        bp.cashAmountController.text = '95';
        bp.setPaymentMethod('CASH', true);
        final coupon = DiscountData.fromJson({
          ..._couponJson(type: 'fixed', value: 20),
          'valid_from_date': '2000-01-01',
          'valid_to_date': '3000-01-01',
          ...scenario.value,
        });

        final result = await couponController.applyDiscount(
          localProductProvider: lpp,
          billingProvider: bp,
          discountProvider: _FakeDiscountProvider(),
          paymentController: paymentController,
          flatDiscountText: '20',
          percentageDiscountText: '',
          selectedDiscount: coupon,
        );

        expect(result.success, isFalse);
        expect(result.errorMessage,
            BillingMobileErrorMessages.couponInvalid('Sundayoffer'));
        expect(lpp.priceSummary!.netTotal, 95);
        expect(lpp.getCurrentDiscount()['flatDiscount'], 5);
        expect(bp.isCouponApplied, isTrue);
        expect(bp.couponCode, 'SAVE5');
        expect(bp.coupenCodeTextController.text, 'SAVE5');
        expect(bp.totalOrderAmount, 95);
        expect(bp.getTotalPaidAmount(), 95);
      });
    }

    test('rejects apply when cart is empty', () async {
      final lpp = LocalProductProvider();
      final bp = BillingProvider();

      final result = await couponController.applyDiscount(
        localProductProvider: lpp,
        billingProvider: bp,
        discountProvider: _FakeDiscountProvider(),
        paymentController: paymentController,
        flatDiscountText: '10',
        percentageDiscountText: '',
        selectedDiscount: null,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, BillingMobileErrorMessages.emptyCartDiscount);
    });
  });

  group('BillingMobileCouponController.clearDiscount', () {
    const couponController = BillingMobileCouponController();
    const paymentController = BillingMobilePaymentController();

    test('clearDiscounts and clearDiscount reset coupon and local discount',
        () {
      final lpp = _cartWithSubtotal('100');
      final bp = BillingProvider();

      lpp.applyDiscount(flatDiscount: 15, percentageDiscount: 0);
      bp.setCouponApplied(true, code: 'SAVE15', discount: 15);
      bp.coupenCodeTextController.text = 'SAVE15';
      bp.setManualDiscount(amount: 15);

      expect(lpp.getCurrentDiscount()['flatDiscount'], 15.0);
      expect(bp.isCouponApplied, isTrue);
      expect(bp.couponCode, 'SAVE15');

      couponController.clearDiscount(
        localProductProvider: lpp,
        billingProvider: bp,
        paymentController: paymentController,
      );

      expect(lpp.getCurrentDiscount()['flatDiscount'], 0.0);
      expect(lpp.getCurrentDiscount()['percentageDiscount'], 0.0);
      expect(bp.isCouponApplied, isFalse);
      expect(bp.couponCode, isEmpty);
      expect(bp.coupenCodeTextController.text, isEmpty);
      expect(bp.isManualDiscountApplied, isFalse);
    });
  });

  group('BillingMobilePaymentController.remapPaymentsAfterDiscountChange', () {
    const controller = BillingMobilePaymentController();

    test('adjusts single full cash payment after discount', () {
      final bp = BillingProvider();
      bp.setTotalOrderAmount(100);
      bp.cashAmountController.text = '100.00';
      bp.setPaymentMethod('CASH', true);

      controller.remapPaymentsAfterDiscountChange(
        bp: bp,
        oldEffectiveTotal: 100,
        newEffectiveTotal: 80,
      );

      expect(bp.cashAmountController.text, '80.00');
      expect(bp.totalOrderAmount, 80);
      expect(bp.getTotalPaidAmount(), 80);
    });

    test('preserves split cash and card when not single-method full pay', () {
      final bp = BillingProvider();
      bp.setTotalOrderAmount(105);
      bp.cashAmountController.text = '50';
      bp.cardAmountController.text = '55';
      bp.setPaymentMethod('CASH', true);
      bp.setPaymentMethod('CARD', true);

      controller.remapPaymentsAfterDiscountChange(
        bp: bp,
        oldEffectiveTotal: 105,
        newEffectiveTotal: 95,
      );

      expect(bp.cashAmountController.text, '50');
      expect(bp.cardAmountController.text, '55');
      expect(bp.totalOrderAmount, 95);
    });
  });

  group('PaymentAutoFillHelper.remapAmountsAfterDiscount', () {
    test('remaps full cash to new payable total', () {
      final result = PaymentAutoFillHelper.remapAmountsAfterDiscount(
        isCashSelected: true,
        isCardSelected: false,
        isUpiSelected: false,
        isCodSelected: false,
        cashAmount: '100.00',
        cardAmount: '',
        upiAmount: '',
        codAmount: '',
        oldEffectiveTotal: 100,
        newEffectiveTotal: 80,
      );

      expect(result.cash, '80.00');
    });

    test('keeps manual cash+card split unchanged', () {
      final result = PaymentAutoFillHelper.remapAmountsAfterDiscount(
        isCashSelected: true,
        isCardSelected: true,
        isUpiSelected: false,
        isCodSelected: false,
        cashAmount: '50',
        cardAmount: '55',
        upiAmount: '',
        codAmount: '',
        oldEffectiveTotal: 105,
        newEffectiveTotal: 95,
      );

      expect(result.cash, '50');
      expect(result.card, '55');
    });
  });

  group('coupon rules remain attached to the cart', () {
    test('quantity changes recalculate a capped percentage and check minimum',
        () {
      final cart = _cartWithSubtotal('100');
      final coupon = DiscountData.fromJson({
        ..._couponJson(type: 'percent', value: 20),
        'discount_coupon_limit_amount': 30,
        'discount_coupon_min_amount': 100
      });
      cart.applyDiscount(
          flatDiscount: 0, percentageDiscount: 20, coupon: coupon);
      expect(cart.cartTotal, 80);
      cart.cartItems.single.quantity = 2;
      expect(cart.cartTotal, 170);
      cart.cartItems.single.quantity = 1;
      cart.cartItems.single.price = 50;
      expect(cart.cartTotal, 50);
      expect(cart.discountValidationError, contains('minimum'));
      expect(() => cart.saveCurrentCartAsConfirmedOrder(), throwsStateError);
      cart.cartItems.single.quantity = 1;
      cart.cartItems.single.price = 100;
      expect(cart.cartTotal, 80);
      expect(cart.discountValidationError, isNull);
    });
    test('held rules survive Hive while confirmed receipt amounts stay frozen',
        () async {
      final cart = _cartWithSubtotal('100');
      final coupon =
          DiscountData.fromJson(_couponJson(type: 'percent', value: 20));
      cart.applyDiscount(
          flatDiscount: 0, percentageDiscount: 20, coupon: coupon);
      final draft = cart.saveCurrentCartAsOrder(couponId: coupon.couponCode);
      final sale =
          cart.saveCurrentCartAsConfirmedOrder(couponId: coupon.couponCode);
      await cart.flushPersistence();
      expect(
          Hive.box<HiveSavedOrder>('saved_orders')
              .values
              .firstWhere((value) => value.id == draft.id)
              .couponDetails!['coupon']['id'],
          coupon.id);
      cart.clearCart();
      cart.loadOrderForEditing(draft.id);
      expect(cart.appliedCoupon?.id, coupon.id);
      cart.cartItems.single.quantity = 2;
      expect(cart.cartTotal, 160);
      expect(sale.total, 80);
      expect(sale.flatDiscount, 20);
      final rows = PrintService.savedOrderReceiptItems(
          sale.items, sale.flatDiscount!,
          couponCode: sale.couponId, couponName: coupon.couponName);
      expect(rows.single['discounted_total'], '80.00');
      expect(rows.single['order_discount_allocations'].single['code'],
          coupon.couponCode);
      expect(sale.withOrderNumber('server-order').couponDetails,
          sale.couponDetails);
    });
    test('manual replacement and cart clear remove the coupon rule', () {
      final cart = _cartWithSubtotal('100');
      cart.applyDiscount(
          flatDiscount: 0,
          percentageDiscount: 20,
          coupon:
              DiscountData.fromJson(_couponJson(type: 'percent', value: 20)));
      cart.applyDiscount(flatDiscount: 5, percentageDiscount: 0);
      expect(cart.appliedCoupon, isNull);
      expect(cart.cartTotal, 95);
      cart.clearCart();
      expect(cart.discountValidationError, isNull);
      expect(cart.getCurrentDiscount()['flatDiscount'], 0);
    });
  });

  group('CouponSection smoke', () {
    Widget wrapCouponSection(
      LocalProductProvider localProductProvider, {
      DiscountProvider? discountProvider,
      BillingProvider? billingProvider,
      Key? sectionKey,
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<LocalProductProvider>.value(
            value: localProductProvider,
          ),
          if (billingProvider == null)
            ChangeNotifierProvider<BillingProvider>(
              create: (_) => BillingProvider(),
            )
          else
            ChangeNotifierProvider<BillingProvider>.value(
              value: billingProvider,
            ),
          ChangeNotifierProvider<DiscountProvider>(
            create: (_) => discountProvider ?? _FakeDiscountProvider(),
          ),
          ChangeNotifierProvider<AppSettingsProvider>(
            create: (_) => _FakeAppSettingsProvider(),
          ),
          ChangeNotifierProvider<AuthModel>(
            create: (_) => AuthModel(),
          ),
          ChangeNotifierProvider<CartProvider>(
            create: (_) => _FakeCartProvider(),
          ),
          ChangeNotifierProvider<KeyboardProvider>(
            create: (_) => KeyboardProvider(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: CouponSection(key: sectionKey)),
        ),
      );
    }

    testWidgets('switching coupon type preserves its cap and code',
        (tester) async {
      late LocalProductProvider cart;
      await tester.runAsync(() async {
        cart = _cartWithSubtotal('100');
      });
      final bp = BillingProvider()..setTotalOrderAmount(100);
      final fixed =
          DiscountData.fromJson(_couponJson(type: 'fixed', value: 20));
      final percentage = DiscountData.fromJson({
        ..._couponJson(type: 'percent', value: 50),
        'coupon_code': 'CAPPED50',
        'discount_coupon_limit_amount': 5,
      });
      await tester.pumpWidget(wrapCouponSection(cart,
          billingProvider: bp,
          discountProvider: _SeededDiscountProvider([fixed, percentage])));
      await tester.pump();
      final dropdown = tester.widget<CustomDropDownWithSearch<DiscountData>>(
          find.byType(CustomDropDownWithSearch<DiscountData>));
      dropdown.onChanged(fixed);
      await tester.pump();
      await tester.tap(find.text('Apply Discount'));
      await tester.pump();
      expect(cart.cartTotal, 80);
      dropdown.onChanged(percentage);
      await tester.pump();
      await tester.tap(find.text('Apply Discount'));
      await tester.pump();
      expect(cart.cartTotal, 95);
      expect(cart.appliedCoupon?.couponCode, 'CAPPED50');
      expect(bp.couponCode, 'CAPPED50');
    });

    testWidgets('Apply Discount button applies flat discount via controller',
        (tester) async {
      late LocalProductProvider lpp;
      await tester.runAsync(() async {
        lpp = _cartWithSubtotal('100');
      });

      await tester.pumpWidget(wrapCouponSection(lpp));
      await tester.pump();

      await tester.enterText(_flatDiscountField(), '20');
      await tester.tap(find.text('Apply Discount'));
      await tester.pump();

      expect(lpp.getCurrentDiscount()['flatDiscount'], 20.0);

      // showScaffold success snackbar schedules a 2s dismiss timer.
      await tester.pump(const Duration(seconds: 3));

      // Let Hive flush debounced writes outside FakeAsync.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
    });

    testWidgets('selecting a coupon keeps its value in the fields',
        (tester) async {
      late LocalProductProvider lpp;
      await tester.runAsync(() async {
        lpp = _cartWithSubtotal('100');
      });
      final coupon =
          DiscountData.fromJson(_couponJson(type: 'percent', value: 20));

      await tester.pumpWidget(wrapCouponSection(
        lpp,
        discountProvider: _SeededDiscountProvider([coupon]),
      ));
      await tester.pump();

      final dropdown = tester.widget<CustomDropDownWithSearch<DiscountData>>(
        find.byType(CustomDropDownWithSearch<DiscountData>),
      );
      dropdown.onChanged(coupon);
      await tester.pump();
      // A second, unrelated rebuild used to wipe the coupon-filled fields.
      lpp.notifyListeners();
      await tester.pump();

      final percentField = tester.widget<TextField>(_percentageDiscountField());
      expect(percentField.controller!.text, '20');
      expect(find.text('Sundayoffer'), findsOneWidget);

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
    });

    testWidgets(
        'cached coupon applies without authentication and survives reopen',
        (tester) async {
      late LocalProductProvider lpp;
      await tester.runAsync(() async {
        lpp = _cartWithSubtotal('100');
      });
      final bp = BillingProvider();
      bp.setTotalOrderAmount(100);
      final coupon =
          DiscountData.fromJson(_couponJson(type: 'fixed', value: 20));
      final discounts = _SeededDiscountProvider([coupon]);

      await tester.pumpWidget(wrapCouponSection(
        lpp,
        billingProvider: bp,
        discountProvider: discounts,
        sectionKey: const ValueKey('first-open'),
      ));
      await tester.pump();
      final dropdown = tester.widget<CustomDropDownWithSearch<DiscountData>>(
        find.byType(CustomDropDownWithSearch<DiscountData>),
      );
      dropdown.onChanged(coupon);
      await tester.pump();
      await tester.tap(find.text('Apply Discount'));
      await tester.pump();

      expect(lpp.priceSummary!.netTotal, 80);
      expect(bp.isCouponApplied, isTrue);
      expect(bp.couponCode, 'SUNDAYOFFER');
      expect(bp.coupenCodeTextController.text, 'SUNDAYOFFER');
      expect(bp.totalOrderAmount, 80);

      await tester.pumpWidget(wrapCouponSection(
        lpp,
        billingProvider: bp,
        discountProvider: discounts,
        sectionKey: const ValueKey('second-open'),
      ));
      await tester.pump();

      expect(tester.widget<TextField>(_flatDiscountField()).controller!.text,
          '20');
      expect(find.text('Sundayoffer'), findsOneWidget);
      expect(
        tester
            .widget<CustomDropDownWithSearch<DiscountData>>(
                find.byType(CustomDropDownWithSearch<DiscountData>))
            .value,
        coupon,
      );

      await tester.pump(const Duration(seconds: 3));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
    });

    testWidgets(
        'expired coupon shows an error and preserves the applied discount',
        (tester) async {
      late LocalProductProvider lpp;
      await tester.runAsync(() async {
        lpp = _cartWithSubtotal('100');
        lpp.applyDiscount(flatDiscount: 5, percentageDiscount: 0);
      });
      final bp = BillingProvider();
      bp.setCouponApplied(true, code: 'SAVE5', discount: 5);
      bp.setTotalOrderAmount(95);
      bp.cashAmountController.text = '95';
      bp.setPaymentMethod('CASH', true);
      final expiredCoupon = DiscountData.fromJson({
        ..._couponJson(type: 'fixed', value: 20),
        'valid_from_date': '2000-01-01',
        'valid_to_date': '2001-01-01',
      });
      await tester.pumpWidget(wrapCouponSection(
        lpp,
        billingProvider: bp,
        discountProvider: _SeededDiscountProvider([expiredCoupon]),
      ));
      await tester.pump();
      tester
          .widget<CustomDropDownWithSearch<DiscountData>>(
              find.byType(CustomDropDownWithSearch<DiscountData>))
          .onChanged(expiredCoupon);
      await tester.pump();
      expect(find.text('Coupon has expired'), findsOneWidget);

      await tester.tap(find.text('Apply Discount'));
      await tester.pump();

      expect(find.text(BillingMobileErrorMessages.couponInvalid('Sundayoffer')),
          findsOneWidget);
      expect(lpp.priceSummary!.netTotal, 95);
      expect(bp.couponCode, 'SAVE5');
      expect(bp.totalOrderAmount, 95);
      expect(bp.getTotalPaidAmount(), 95);

      await tester.pump(const Duration(seconds: 5));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
    });
  });
}
