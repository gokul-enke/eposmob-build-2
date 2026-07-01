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
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
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
        applyCouponApi: () async => true,
      );

      expect(result.success, isTrue);
      expect(lpp.getCurrentDiscount()['flatDiscount'], 20.0);
      expect(lpp.getCurrentDiscount()['percentageDiscount'], 0.0);
    });

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
        applyCouponApi: () async => true,
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

  group('CouponSection smoke', () {
    Widget wrapCouponSection(LocalProductProvider localProductProvider) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<LocalProductProvider>.value(
            value: localProductProvider,
          ),
          ChangeNotifierProvider<BillingProvider>(
            create: (_) => BillingProvider(),
          ),
          ChangeNotifierProvider<DiscountProvider>(
            create: (_) => _FakeDiscountProvider(),
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
        child: const MaterialApp(
          home: Scaffold(body: CouponSection()),
        ),
      );
    }

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
  });
}
