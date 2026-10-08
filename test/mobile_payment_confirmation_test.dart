import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_controller.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/payment_methods_sheet.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/models/payment_method.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/discount_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';

import 'test_support/hive_test_teardown.dart';

class _CachedPaymentMethods extends MasterDataProvider {
  static const methods = [
    PaymentMethod(id: '1', code: 'CARD', label: 'Card'),
    PaymentMethod(id: '2', code: 'CASH', label: 'Cash'),
    PaymentMethod(
        id: '3',
        code: 'DEBIT',
        label: 'Credit',
        behavior: PaymentBehavior.credit),
  ];

  @override
  List<PaymentMethod>? get paymentMethodModels => methods;

  @override
  List<PaymentMethod> get enabledSortedPaymentMethods => methods;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const payment = BillingMobilePaymentController();
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('mobile_payment_confirm_');
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
    await awaitPendingHiveBoxWrites();
    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
  });

  tearDown(awaitPendingHiveBoxWrites);
  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

  BillingProvider billing() => BillingProvider()..setTotalOrderAmount(100);

  for (final code in ['CARD', 'CASH', 'UPI', 'COD']) {
    test('Done accepts autofilled $code without toggling the method', () {
      final bp = billing()..setPaymentMethod(code, true);
      payment.syncPaymentAutofillIfNeeded(bp);
      expect(bp.paymentStepVisited, isFalse);
      expect(payment.validatePaymentReadyForConfirm(bp).isValid, isFalse);
      expect(payment.completePaymentStep(bp).isValid, isTrue);
      expect(bp.paymentStepVisited, isTrue);
      expect(payment.validatePaymentReadyForConfirm(bp).isValid, isTrue);
      expect(bp.getTotalPaidAmount(), 100);
      expect(bp.isCodeSelected(code), isTrue);
    });
  }

  test('Done preserves split Card and Cash amounts', () {
    final bp = billing();
    bp.setPaymentMethod('CARD', true);
    bp.setPaymentMethod('CASH', true);
    bp.cardAmountController.text = '60';
    bp.cashAmountController.text = '40';
    expect(payment.completePaymentStep(bp).isValid, isTrue);
    expect(bp.cardAmountController.text, '60');
    expect(bp.cashAmountController.text, '40');
    expect(bp.getTotalPaidAmount(), 100);
  });

  test('Done accepts a dynamic payment method', () {
    final bp = billing()
      ..setExtraPaymentAmount('99', '100', displayValue: 'CHEQUE');
    expect(payment.completePaymentStep(bp).isValid, isTrue);
    expect(bp.selectedExtraMethodIds, {'99'});
    expect(bp.extraPaymentAmounts['99'], '100');
  });

  test('Done rejects insufficient payment without marking it reviewed', () {
    final bp = billing()..setPaymentMethod('CARD', true);
    bp.cardAmountController.text = '60';
    final result = payment.completePaymentStep(bp);
    expect(result.isValid, isFalse);
    expect(result.message, 'Payment amount is less than the amount due');
    expect(bp.paymentStepVisited, isFalse);
    expect(bp.remainingPaymentDue, 40);
  });

  test('Done rejects missing payment amounts', () {
    final bp = billing()..setPaymentMethod('CARD', true);
    expect(payment.completePaymentStep(bp).isValid, isFalse);
    expect(bp.paymentStepVisited, isFalse);
    expect(bp.remainingPaymentDue, 100);
  });

  test('Done retains the ONLINE terminal and reference gates', () {
    final bp = billing()..setPaymentMethod('ONLINE', true);
    bp.setPineLabsPaymentSuccess(false);
    expect(payment.completePaymentStep(bp).isValid, isFalse);
    bp.setPineLabsPaymentSuccess(true);
    expect(payment.completePaymentStep(bp).isValid, isFalse);
    bp.transactionNumberController.text = 'terminal-123';
    expect(payment.completePaymentStep(bp).isValid, isTrue);
  });

  test('focusing a selected Card field keeps its selection and amount', () {
    final bp = billing()..setPaymentMethod('CARD', true);
    bp.cardAmountController.text = '100';
    payment.selectMethodOnTap(
        MobilePaymentItem(
          name: 'Card',
          type: 'CARD',
          controller: bp.cardAmountController,
          selected: true,
        ),
        bp);
    expect(bp.isCardSelected, isTrue);
    expect(bp.cardAmountController.text, '100');
  });

  test('amount edits use live selection instead of a stale row snapshot', () {
    final bp = billing();
    bp.cardAmountController.text = '100';
    payment.onAmountChanged(
        MobilePaymentItem(
          name: 'Card',
          type: 'CARD',
          controller: bp.cardAmountController,
          selected: true,
        ),
        '100',
        bp);
    expect(bp.isCardSelected, isTrue);
    expect(payment.validatePaymentReadyForConfirm(bp).isValid, isTrue);
  });

  test('remaining due includes a credit sale and customer credit correctly',
      () {
    final bp = billing();
    bp.setPaymentMethod('CASH', true);
    bp.cashAmountController.text = '60';
    bp.setPaymentMethod('DEBIT', true);
    bp.debitAmountController.text = '40';
    expect(bp.remainingPaymentDue, 0);
    expect(payment.completePaymentStep(bp).isValid, isTrue);

    bp.setPaymentMethod('DEBIT', false);
    bp.setSelectedCustomer(
        CustomerListModelData(id: 1, name: 'Ali', balance: 25));
    bp.setToCustomerCreditEnabled(true);
    expect(bp.remainingPaymentDue, 15);
    bp.cashAmountController.text = '75';
    expect(bp.remainingPaymentDue, 0);
    expect(payment.completePaymentStep(bp).isValid, isTrue);
  });

  Widget wrapSheet(BillingProvider bp) => MultiProvider(
        providers: [
          ChangeNotifierProvider<BillingProvider>.value(value: bp),
          ChangeNotifierProvider<MasterDataProvider>(
              create: (_) => _CachedPaymentMethods()),
          ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) => AppSettingsProvider()),
          ChangeNotifierProvider<CustomerSelectionProvider>(
              create: (_) => CustomerSelectionProvider()),
          ChangeNotifierProvider<KeyboardProvider>(
              create: (_) => KeyboardProvider(enablePersistence: false)),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: Builder(
          builder: (context) => TextButton(
              onPressed: () => showPaymentMethodsSheet(context),
              child: const Text('Open payment')),
        ))),
      );

  testWidgets(
      'automatically opened sheet Done makes autofilled Card confirmable',
      (tester) async {
    final bp = billing()..setPaymentMethod('CARD', true);
    await tester.pumpWidget(wrapSheet(bp));
    await tester.tap(find.text('Open payment'));
    await tester.pumpAndSettle();
    expect(bp.cardAmountController.text, '100.00');
    expect(bp.paymentStepVisited, isFalse);
    await tester.tap(find.byKey(const ValueKey('mobile_payment_done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mobile_payment_done')), findsNothing);
    expect(payment.validatePaymentReadyForConfirm(bp).isValid, isTrue);
  });

  testWidgets(
      'Done stays open and shows Remaining when Card does not cover total',
      (tester) async {
    final bp = billing()..setPaymentMethod('CARD', true);
    bp.cardAmountController.text = '60';
    bp.calculateBalance();
    await tester.pumpWidget(wrapSheet(bp));
    await tester.tap(find.text('Open payment'));
    await tester.pumpAndSettle();
    expect(find.text('Remaining'), findsOneWidget);
    expect(find.text('Fully Paid'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('mobile_payment_done')));
    await tester.pump();
    expect(find.text('Payment amount is less than the amount due'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('mobile_payment_done')), findsOneWidget);
    expect(bp.paymentStepVisited, isFalse);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Clear payments followed by Done keeps payment empty',
      (tester) async {
    final bp = billing()..setPaymentMethod('CARD', true);
    await tester.pumpWidget(wrapSheet(bp));
    await tester.tap(find.text('Open payment'));
    await tester.pumpAndSettle();
    payment.clearAllCollectedPayments(bp);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mobile_payment_done')));
    await tester.pump();
    expect(bp.hasAnyPaymentSelected(), isFalse);
    expect(bp.getTotalPaidAmount(), 0);
    expect(
        find.text('Please enter at least one payment amount'), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile_payment_done')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('closing the sheet does not accept an untouched autofill',
      (tester) async {
    final bp = billing()..setPaymentMethod('CARD', true);
    await tester.pumpWidget(wrapSheet(bp));
    await tester.tap(find.text('Open payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(bp.paymentStepVisited, isFalse);
    expect(payment.validatePaymentReadyForConfirm(bp).isValid, isFalse);
  });

  Future<
      ({
        BillingMobileController controller,
        LocalProductProvider cart,
        BillingProvider bp
      })> trackedCart(WidgetTester tester) async {
    late LocalProductProvider cart;
    await tester.runAsync(() async {
      cart = LocalProductProvider();
      final product = GetProduct(
          productId: 1,
          productName: 'Payment Test',
          price: ProductPrice(price: '100'),
          mrp: '100',
          purchasePrice: '50',
          unit: 'PCS',
          stock: const <Stock>[],
          taxes: const <ProductTax>[]);
      cart.initializeProducts([product]);
      cart.addToCart(product: product);
    });
    final bp = billing();
    final controller = BillingMobileController();
    late BuildContext providerContext;
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<LocalProductProvider>.value(value: cart),
          ChangeNotifierProvider<BillingProvider>.value(value: bp),
          ChangeNotifierProvider<DeliveryMethodsProvider>(
              create: (_) => DeliveryMethodsProvider()),
        ],
        child: Builder(builder: (context) {
          providerContext = context;
          return const SizedBox.shrink();
        })));
    controller.startTrackingCartPayments(providerContext);
    void onChanged() => controller.onCartChanged(providerContext);
    cart.addListener(onChanged);
    addTearDown(() => cart.removeListener(onChanged));
    payment.toggleMethod('CARD', bp);
    return (controller: controller, cart: cart, bp: bp);
  }

  testWidgets('product-list refresh preserves reviewed Card payment',
      (tester) async {
    final state = await trackedCart(tester);
    state.cart.refreshProducts();
    expect(state.bp.cardAmountController.text, '100.00');
    expect(state.bp.paymentStepVisited, isTrue);
    expect(payment.validatePaymentReadyForConfirm(state.bp).isValid, isTrue);
  });

  testWidgets('quantity change requires payment review and Done resolves it',
      (tester) async {
    final state = await trackedCart(tester);
    state.cart.cartItems.single.quantity = 2;
    state.cart.notifyListeners();
    expect(state.bp.isCardSelected, isTrue);
    expect(state.bp.cardAmountController.text, isEmpty);
    expect(state.bp.paymentStepVisited, isFalse);
    expect(state.bp.totalOrderAmount, 200);
    payment.syncPaymentAutofillIfNeeded(state.bp);
    expect(payment.completePaymentStep(state.bp).isValid, isTrue);
    expect(state.bp.cardAmountController.text, '200.00');
    expect(payment.validatePaymentReadyForConfirm(state.bp).isValid, isTrue);
  });

  testWidgets('price change resets payment even when the item object is reused',
      (tester) async {
    final state = await trackedCart(tester);
    state.cart.cartItems.single.price = 120;
    state.cart.notifyListeners();
    expect(state.bp.cardAmountController.text, isEmpty);
    expect(state.bp.totalOrderAmount, 120);
    expect(state.bp.paymentStepVisited, isFalse);
  });

  testWidgets(
      'discount remap keeps reviewed Card payment on the real cart listener',
      (tester) async {
    final state = await trackedCart(tester);
    final result = await const BillingMobileCouponController().applyDiscount(
      localProductProvider: state.cart,
      billingProvider: state.bp,
      discountProvider: DiscountProvider(),
      paymentController: payment,
      flatDiscountText: '20',
      percentageDiscountText: '',
      selectedDiscount: null,
    );
    expect(result.success, isTrue);
    expect(state.bp.cardAmountController.text, '80.00');
    expect(state.bp.paymentStepVisited, isTrue);
    expect(payment.validatePaymentReadyForConfirm(state.bp).isValid, isTrue);
  });
}
