import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/features/billing/controllers/billing_mobile_controller.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/customer_summary_card.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/delivery_method.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/models/payment_method.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

import 'test_support/hive_test_teardown.dart';

class _FakeCartProvider extends CartProvider {
  int? fetchedCustomerId;
  String? fetchedAccessToken;

  @override
  getData() async {
    // no-op: the real constructor reads stored customer state.
  }

  @override
  Future<void> fetchCartDataFromApi({
    required int customerId,
    required String accessToken,
    int? cartId,
  }) async {
    fetchedCustomerId = customerId;
    fetchedAccessToken = accessToken;
  }
}

class _FakeAppSettingsProvider extends AppSettingsProvider {
  _FakeAppSettingsProvider(this.settings);

  final AppSettings settings;

  @override
  AppSettings? get appSettings => settings;

  @override
  Future<void> fetchAppSettings() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_mobile_ui_test_');
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
    SharedPreferences.setMockInitialValues({});
    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
  });

  tearDown(() async {
    await awaitPendingHiveBoxWrites();
  });

  tearDownAll(() async {
    try {
      await Hive.close().timeout(const Duration(seconds: 3));
    } on Object {
      // Ignore Hive lock issues when other test isolates are still shutting down.
    }
    // On Windows, the OS may briefly hold the directory's file handle open
    // (antivirus/indexer scan) right after Hive.close() returns, so a
    // delete attempted immediately can fail with a PathAccessException even
    // though the directory is unused. Retry a few times before giving up —
    // this is temp-dir cleanup, not a test assertion, so it must never fail
    // the suite.
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        if (await hiveDir.exists()) {
          await hiveDir.delete(recursive: true);
        }
        break;
      } on Object {
        if (attempt == 4) break;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
  });

  GetProduct product({
    required int id,
    required String name,
    String category = 'Snacks',
    String price = '10',
  }) {
    return GetProduct(
      productId: id,
      productName: name,
      category: ProductCategory(name: category),
      price: ProductPrice(price: price),
      mrp: price,
      purchasePrice: '5',
      unit: 'PCS',
      stock: const <Stock>[],
      taxes: const <ProductTax>[],
    );
  }

  group('BillingMobileMarketController', () {
    const controller = BillingMobileMarketController();

    test('filters sellable products by search text and category', () {
      final products = [
        product(id: 1, name: 'Apple Juice', category: 'Drinks'),
        product(id: 2, name: 'Apple Chips', category: 'Snacks'),
        product(id: 3, name: 'Orange Soda', category: 'Drinks'),
      ];

      final result = controller.visibleProducts(
        products: products,
        query: 'apple',
        selectedCategory: 'Drinks',
      );

      expect(result.map((item) => item.productId), [1]);
    });

    test('builds category chips with All products first', () {
      final categories = controller.categories([
        product(id: 1, name: 'A', category: 'Drinks'),
        product(id: 2, name: 'B', category: 'Snacks'),
        product(id: 3, name: 'C', category: 'Drinks'),
      ]);

      expect(categories, ['All products', 'Drinks', 'Snacks']);
    });

    test('default add form values mirror desktop billing header defaults', () {
      final tea = GetProduct(
        productId: 10,
        productName: 'Tea',
        price: ProductPrice(price: '42.5'),
        mrp: '50',
      );

      expect(controller.defaultQuantityText(), '1');
      expect(controller.defaultUnitPrice(tea), 42.5);
      expect(controller.defaultMrp(tea), 50);
    });

    test('parseAddForm validates quantity and price', () {
      final ok = controller.parseAddForm(
        quantityText: '2',
        priceText: '15',
        mrpText: '20',
      );
      expect(ok.success, isTrue);
      expect(ok.values?.quantity, 2);
      expect(ok.values?.customPrice, 15);
      expect(ok.values?.customMrp, 20);

      final badQty = controller.parseAddForm(
        quantityText: '0',
        priceText: '10',
      );
      expect(badQty.success, isFalse);
    });
  });

  group('BillingMobileCartController', () {
    const controller = BillingMobileCartController();

    test('dedupes duplicate sale units when building unit menu options', () {
      final provider = LocalProductProvider();
      final saleProduct = GetProduct(
        productId: 5,
        productName: 'Sugar',
        unit: 'PCS',
        price: ProductPrice(price: '10'),
        mrp: '12',
        saleUnits: [
          SaleUnit(id: 1, unitName: 'CASE', conversionRate: '12'),
          SaleUnit(id: 1, unitName: 'CASE', conversionRate: '12'),
          SaleUnit(id: 2, unitName: 'BOX', conversionRate: '6'),
        ],
      );
      provider.initializeProducts([saleProduct]);
      provider.addToCart(product: saleProduct, quantity: 1, price: 10);

      final options =
          controller.cartUnitOptionsForItem(provider.cartItems.single);
      expect(options.map((option) => option.label), ['PCS', 'CASE', 'BOX']);
    });

    test('inclusiveTaxAmount matches desktop inclusive formula', () {
      final tax = controller.inclusiveTaxAmount(
        unitPrice: 105,
        quantity: 2,
        taxRate: 5,
      );
      expect(tax, closeTo(10, 0.001));
    });

    test('commitDisplayPrice enforces minimum sale price floor', () {
      final provider = LocalProductProvider();
      final pricedProduct = GetProduct(
        productId: 6,
        productName: 'Tea',
        unit: 'PCS',
        price: ProductPrice(price: '100'),
        mrp: '120',
        minMarginPercentage: '10',
      );
      provider.initializeProducts([pricedProduct]);
      provider.addToCart(product: pricedProduct, quantity: 1, price: 100);

      final result = controller.commitDisplayPrice(
        provider: provider,
        item: provider.cartItems.single,
        displayPrice: 80,
      );

      expect(result.clampedToDisplayPrice, 90);
      expect(provider.cartItems.single.price, 90);
    });
  });

  group('BillingMobilePaymentController', () {
    const controller = BillingMobilePaymentController();

    test('sorts payment methods and maps IDs onto known payment types', () {
      final sorted = controller.sortPaymentMethods([
        MasterDataValue(id: 2, value: 'CARD', description: ''),
        MasterDataValue(id: 1, value: 'CASH', description: ''),
        MasterDataValue(id: 4, value: 'COD', description: ''),
        MasterDataValue(id: 3, value: 'UPI', description: ''),
      ]);
      final ids = controller.paymentMethodIds(sorted);

      expect(sorted.map((item) => item.value), ['CASH', 'CARD', 'COD', 'UPI']);
      expect(ids.cashId, '1');
      expect(ids.cardId, '2');
      expect(ids.upiId, '3');
      expect(ids.codId, '4');
    });

    test('toggleMethod selects and autofills the remaining payable amount', () {
      final bp = BillingProvider();
      bp.setTotalOrderAmount(125);

      controller.toggleMethod('CASH', bp);

      expect(bp.isCashSelected, isTrue);
      expect(bp.cashAmountController.text, '125.00');
    });

    test('syncPaymentAutofillIfNeeded prefills default CARD when amounts empty',
        () {
      final bp = BillingProvider();
      bp.setTotalOrderAmount(99.5);
      bp.setPaymentMethod('CARD', true);

      final applied = controller.syncPaymentAutofillIfNeeded(bp);

      expect(applied, isTrue);
      expect(bp.cardAmountController.text, '99.50');
      expect(bp.getTotalPaidAmount(), 99.5);
    });

    test('syncPaymentAutofillIfNeeded falls back to CASH when nothing selected',
        () {
      final bp = BillingProvider();
      bp.setTotalOrderAmount(42);

      final applied = controller.syncPaymentAutofillIfNeeded(bp);

      expect(applied, isTrue);
      expect(bp.isCashSelected, isTrue);
      expect(bp.cashAmountController.text, '42.00');
    });

    test('syncPaymentAutofillIfNeeded skips when amounts already entered', () {
      final bp = BillingProvider();
      bp.setTotalOrderAmount(50);
      bp.setPaymentMethod('CASH', true);
      bp.cashAmountController.text = '25';

      expect(controller.syncPaymentAutofillIfNeeded(bp), isFalse);
      expect(bp.cashAmountController.text, '25');
    });

    test('syncPaymentAutofillIfNeeded does not replace full credit with cash',
        () {
      final bp = BillingProvider();
      bp.setTotalOrderAmount(50);
      bp.setPaymentMethod('CREDIT', true);
      bp.debitAmountController.text = '50.00';

      expect(controller.syncPaymentAutofillIfNeeded(bp), isFalse);
      expect(bp.isDebitSelected, isTrue);
      expect(bp.debitAmountController.text, '50.00');
      expect(bp.isCashSelected, isFalse);
      expect(bp.cashAmountController.text, isEmpty);
    });

    test('fillExactCash selects cash for the full payable total', () {
      final bp = BillingProvider();
      bp.setTotalOrderAmount(88.5);
      bp.cardAmountController.text = '20';
      bp.setPaymentMethod('CARD', true);

      controller.fillExactCash(bp);

      expect(bp.isCashSelected, isTrue);
      expect(bp.isCardSelected, isFalse);
      expect(bp.cashAmountController.text, '88.50');
      expect(bp.getTotalPaidAmount(), 88.5);
    });

    test('clearAllCollectedPayments resets every method and amount', () {
      final bp = BillingProvider();
      bp.setTotalOrderAmount(50);
      bp.cashAmountController.text = '30';
      bp.setPaymentMethod('CASH', true);
      bp.setExtraPaymentAmount('99', '20', displayValue: 'CHEQUE');

      controller.clearAllCollectedPayments(bp);

      expect(bp.isCashSelected, isFalse);
      expect(bp.cashAmountController.text, isEmpty);
      expect(bp.isExtraMethodSelected('99'), isFalse);
      expect(bp.getTotalPaidAmount(), 0);
      expect(bp.paymentAutofillSuppressed, isTrue);

      expect(controller.syncPaymentAutofillIfNeeded(bp), isFalse);
      expect(bp.isCashSelected, isFalse);
      expect(bp.cashAmountController.text, isEmpty);
    });

    test('syncDebitAmount mirrors the unpaid balance for customer credit', () {
      final bp = BillingProvider();
      bp.setSelectedCustomer(
        CustomerListModelData(id: 7, name: 'Mira', phone: '123'),
      );
      bp.setTotalOrderAmount(100);
      bp.cashAmountController.text = '35';
      bp.setPaymentMethod('CASH', true);
      bp.setPaymentMethod('DEBIT', true);

      final changed = controller.syncDebitAmount(bp);

      expect(changed, isTrue);
      expect(bp.debitAmountController.text, '65.00');
    });

    test(
        'CHEQUE dynamic method contributes to collected total and paid methods',
        () {
      final bp = BillingProvider();
      bp.setTotalOrderAmount(200);
      bp.cashAmountController.text = '50';
      bp.setPaymentMethod('CASH', true);
      bp.setExtraPaymentAmount('99', '75', displayValue: 'CHEQUE');

      expect(bp.getTotalPaidAmount(), 125);
      expect(bp.getExtraPaidTotal(), 75);
      expect(bp.isExtraMethodSelected('99'), isTrue);

      final paidMethods = bp.getPaidMethods();
      expect(
        paidMethods
            .any((entry) => entry['method'] == '99' && entry['amount'] == 75),
        isTrue,
      );
      expect(bp.getSelectedPaymentMethodsForApi(), contains('99'));
    });

    test('paymentItems includes dynamic backend methods beyond typed ones', () {
      final bp = BillingProvider();
      final backendMethods = [
        MasterDataValue(id: 1, value: 'CASH', description: ''),
        MasterDataValue(id: 2, value: 'CARD', description: ''),
        MasterDataValue(id: 99, value: 'CHEQUE', description: 'Cheque'),
      ].map(PaymentMethod.fromMasterDataValue).toList();

      final items = controller.paymentItems(bp, backendMethods);
      final dynamicItems =
          items.where((item) => item.isDynamic).toList(growable: false);

      expect(dynamicItems, hasLength(1));
      expect(dynamicItems.single.methodId, '99');
      expect(dynamicItems.single.type, 'CHEQUE');
      expect(dynamicItems.single.name, 'Cheque');
    });

    test('CREDIT backend code uses the core credit-sale state', () {
      final bp = BillingProvider();
      bp.setTotalOrderAmount(100);
      final creditMethod = PaymentMethod.fromMasterDataValue(
        MasterDataValue(id: 5, value: 'CREDIT', description: 'Credit'),
      );

      final item = controller.paymentItems(bp, [creditMethod]).single;
      expect(item.isDynamic, isFalse);
      expect(item.behavior, PaymentBehavior.credit);
      expect(item.controller, same(bp.debitAmountController));

      controller.toggleMethod('CREDIT', bp);

      expect(bp.isDebitSelected, isTrue);
      expect(bp.debitAmountController.text, '100.00');
      expect(bp.validatePayment(), isTrue);
    });

    test('remainingPayable subtracts dynamic method amounts', () {
      final bp = BillingProvider();
      bp.setTotalOrderAmount(150);
      bp.setExtraPaymentAmount('99', '40', displayValue: 'CHEQUE');

      expect(controller.remainingPayable(bp), 110);
    });

    test('remapPaymentsAfterDiscountChange adjusts single full cash payment',
        () {
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

    test('remapPaymentsAfterDiscountChange preserves split cash and card', () {
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
    });

    test(
        'remapPaymentsAfterDiscountChange remaps coupon-style cash after discount',
        () {
      final bp = BillingProvider();
      bp.setTotalOrderAmount(200);
      bp.cashAmountController.text = '200.00';
      bp.setPaymentMethod('CASH', true);

      controller.remapPaymentsAfterDiscountChange(
        bp: bp,
        oldEffectiveTotal: 200,
        newEffectiveTotal: 170,
      );

      expect(bp.cashAmountController.text, '170.00');
      expect(bp.balanceAmount, 0);
    });

    test('remapPaymentsAfterDiscountChange remaps single extra method payment',
        () {
      final bp = BillingProvider();
      bp.setTotalOrderAmount(200);
      bp.setExtraPaymentAmount('99', '200.00', displayValue: 'CHEQUE');

      controller.remapPaymentsAfterDiscountChange(
        bp: bp,
        oldEffectiveTotal: 200,
        newEffectiveTotal: 150,
      );

      expect(bp.getExtraAmountController('99').text, '150.00');
      expect(bp.getTotalPaidAmount(), 150);
    });

    test('remapPaymentsAfterDiscountChange syncs debit after cash remap', () {
      final bp = BillingProvider();
      bp.setSelectedCustomer(
        CustomerListModelData(id: 1, name: 'Test', phone: '1'),
      );
      bp.setTotalOrderAmount(100);
      bp.cashAmountController.text = '100.00';
      bp.setPaymentMethod('CASH', true);
      bp.setPaymentMethod('DEBIT', true);
      bp.debitAmountController.text = '0.00';

      controller.remapPaymentsAfterDiscountChange(
        bp: bp,
        oldEffectiveTotal: 100,
        newEffectiveTotal: 80,
      );

      expect(bp.cashAmountController.text, '80.00');
      expect(bp.debitAmountController.text, '0.00');
      expect(bp.getTotalPaidAmount(), 80);
    });

    test('toggleToCustomerCredit prefills excess and hides pay-from-credit row',
        () {
      final bp = BillingProvider();
      bp.setSelectedCustomer(
        CustomerListModelData(id: 3, name: 'Ali', phone: '555', balance: 0),
      );
      bp.setTotalOrderAmount(80);
      bp.cashAmountController.text = '100';
      bp.setPaymentMethod('CASH', true);

      controller.toggleToCustomerCredit(bp, true);

      expect(bp.toCustomerCreditEnabled, isTrue);
      expect(bp.debitAmountController.text, '20.00');
      expect(
        controller.shouldShowItem(
          MobilePaymentItem(
            name: 'Credit',
            type: 'DEBIT',
            controller: bp.debitAmountController,
            selected: false,
          ),
          bp,
        ),
        isFalse,
      );
    });

    test('toggleToCustomerCredit off clears debit allocation amount', () {
      final bp = BillingProvider();
      bp.setSelectedCustomer(
        CustomerListModelData(id: 4, name: 'Sara', phone: '666'),
      );
      bp.setTotalOrderAmount(50);
      bp.cashAmountController.text = '60';
      bp.setPaymentMethod('CASH', true);

      controller.toggleToCustomerCredit(bp, true);
      controller.toggleToCustomerCredit(bp, false);

      expect(bp.toCustomerCreditEnabled, isFalse);
      expect(bp.debitAmountController.text, isEmpty);
    });
  });

  group('BillingMobileDeliveryController', () {
    const controller = BillingMobileDeliveryController();

    test('shouldShowDeliveryDateTime follows askDeliveryDate setting', () {
      expect(controller.shouldShowDeliveryDateTime(true), isTrue);
      expect(controller.shouldShowDeliveryDateTime(false), isFalse);
    });

    test('parses and formats 24-hour delivery time', () {
      final parsed = controller.parseDeliveryTime('14:30');
      expect(parsed, isNotNull);
      expect(parsed!.hour, 14);
      expect(parsed.minute, 30);
      expect(controller.formatDeliveryTime(parsed), '14:30');
    });

    test('formats paid and free delivery fee labels', () {
      expect(
        controller.feeLabel(
          DeliveryMethod(id: '1', name: 'Store Takeaway'),
          'SAR',
        ),
        'Free',
      );
      expect(
        controller.feeLabel(
          DeliveryMethod(
            id: '2',
            name: 'Door Delivery',
            prices: [
              DeliveryPrice(
                id: 'p1',
                deliveryMethodId: '2',
                price: 12.5,
              ),
            ],
          ),
          'SAR',
        ),
        '(SAR 12.50)',
      );
    });

    test('formats customer addresses without null fragments', () {
      expect(
        controller.formatAddress(Address(address: 'Main Road', city: 'Riyadh')),
        'Main Road, Riyadh',
      );
      expect(
        controller.formatAddress(Address(address: 'Main Road')),
        'Main Road',
      );
    });
  });

  group('BillingMobileCustomerController', () {
    const controller = BillingMobileCustomerController();

    AppSettings appSettings({
      bool autoAssignDefaultCustomer = false,
      String autoAssignDefaultCustomerPhone = '',
      bool skipCustomerSelection = false,
    }) {
      return AppSettings(
        barcodeSales: true,
        customerCarePhone: '',
        customerCareEmail: '',
        printTitle: '',
        showCustomerLastBuyedPriceList: false,
        askDeliveryDate: false,
        priceRoundOff: false,
        discountAndCoupon: false,
        autoAssignDefaultCustomer: autoAssignDefaultCustomer,
        autoAssignDefaultCustomerPhone: autoAssignDefaultCustomerPhone,
        currency: 'SAR',
        workingTime: '',
        zatcaPhase1Enabled: false,
        zatcaPhase2Enabled: false,
        showTaxPos: false,
        showMrpPos: false,
        showTaxRatePos: false,
        showConfirmOrderButton: true,
        enableKOTPrint: false,
        defaultDeliveryMethod: 'Store Takeaway',
        defaultPaymentMethod: 'CASH',
        posPrintDoubleBill: false,
        skipCustomerSelection: skipCustomerSelection,
        hideDefaultPhone: false,
        freeDeliveryEnabled: false,
        freeDeliveryMinimumAmount: '0',
        itemCodeEnabled: false,
        companyB2BEnabled: false,
        enableSendToKitchenButton: false,
        enableKotBillButton: false,
        kotBillAutoMarkServed: false,
        kotBillAllowedForDineIn: false,
        pineLabPayment: false,
      );
    }

    test('filters customers and limits frequent customers to 10', () {
      final customers = List.generate(
        12,
        (index) => CustomerListModelData(
          id: index,
          name: 'Customer $index',
          phone: index == 11 ? '555-match' : '100$index',
        ),
      );

      expect(controller.filterCustomers(customers, 'match').single.id, 11);
      expect(controller.frequentCustomers(customers), hasLength(10));
    });

    test('applySelection updates billing, selection, and cart providers', () {
      final customer = CustomerListModelData(
        id: 44,
        name: 'Ravi',
        phone: '9000',
        balance: 25,
      );
      final selectionProvider = CustomerSelectionProvider();
      final billingProvider = BillingProvider();
      final cartProvider = _FakeCartProvider();
      final auth = AuthModel()..login('token-1', 1);

      controller.applySelection(
        customer: customer,
        customerSelectionProvider: selectionProvider,
        billingProvider: billingProvider,
        cartProvider: cartProvider,
        auth: auth,
      );

      expect(selectionProvider.selectedCustomerID, 44);
      expect(billingProvider.selectedCustomer?.id, 44);
      expect(billingProvider.mobileNumberTextController.text, 'Ravi 9000');
      expect(billingProvider.customerBalance, 25);
      expect(cartProvider.fetchedCustomerId, 44);
      expect(cartProvider.fetchedAccessToken, 'token-1');
    });

    test('clearSelection resets providers and cart context to auth user', () {
      final customer = CustomerListModelData(id: 9, name: 'Sam', phone: '111');
      final selectionProvider = CustomerSelectionProvider();
      final billingProvider = BillingProvider();
      final cartProvider = _FakeCartProvider();
      final auth = AuthModel()..login('token-2', 77);

      controller.applySelection(
        customer: customer,
        customerSelectionProvider: selectionProvider,
        billingProvider: billingProvider,
        cartProvider: cartProvider,
        auth: auth,
      );

      controller.clearSelection(
        customerSelectionProvider: selectionProvider,
        billingProvider: billingProvider,
        cartProvider: cartProvider,
        auth: auth,
      );

      expect(selectionProvider.hasSelectedCustomer, isFalse);
      expect(billingProvider.selectedCustomer, isNull);
      expect(billingProvider.mobileNumberTextController.text, isEmpty);
      expect(cartProvider.fetchedCustomerId, 77);
      expect(cartProvider.fetchedAccessToken, 'token-2');
    });

    test('handleSalesExecutiveChanged clears auto-assigned customer', () {
      final customer = CustomerListModelData(id: 9, name: 'Sam', phone: '111');
      final selectionProvider = CustomerSelectionProvider();
      final billingProvider = BillingProvider()
        ..setSalesExecutiveMobileNumberText('111')
        ..setMobileNumberText('111');

      selectionProvider.setSelectedCustomer(customer, isDefault: true);
      billingProvider.setSelectedCustomer(customer, isManual: false);

      final changed = controller.handleSalesExecutiveChanged(
        billingProvider: billingProvider,
        customerSelectionProvider: selectionProvider,
        autoAssignEnabled: true,
      );

      expect(changed, isTrue);
      expect(selectionProvider.hasSelectedCustomer, isFalse);
      expect(billingProvider.selectedCustomer, isNull);
      expect(billingProvider.salesExecutivemobileNumberText, isEmpty);
      expect(billingProvider.isCustomerManuallySelected, isFalse);
    });

    test('handleSalesExecutiveChanged skips manually selected customer', () {
      final customer = CustomerListModelData(id: 9, name: 'Sam', phone: '111');
      final selectionProvider = CustomerSelectionProvider();
      final billingProvider = BillingProvider();

      selectionProvider.setSelectedCustomer(customer);
      billingProvider.setSelectedCustomer(customer, isManual: true);

      final changed = controller.handleSalesExecutiveChanged(
        billingProvider: billingProvider,
        customerSelectionProvider: selectionProvider,
        autoAssignEnabled: true,
      );

      expect(changed, isFalse);
      expect(selectionProvider.selectedCustomer?.id, 9);
      expect(billingProvider.selectedCustomer?.id, 9);
    });

    test('handleUserSwitched clears customer but keeps manual flag', () {
      final customer = CustomerListModelData(id: 9, name: 'Sam', phone: '111');
      final selectionProvider = CustomerSelectionProvider();
      final billingProvider = BillingProvider();

      selectionProvider.setSelectedCustomer(customer);
      billingProvider.setSelectedCustomer(customer, isManual: true);

      final changed = controller.handleUserSwitched(
        billingProvider: billingProvider,
        customerSelectionProvider: selectionProvider,
        autoAssignEnabled: true,
      );

      expect(changed, isTrue);
      expect(selectionProvider.hasSelectedCustomer, isFalse);
      expect(billingProvider.selectedCustomer, isNull);
      expect(billingProvider.isCustomerManuallySelected, isTrue);
    });

    test('defaultSalesExecutivePhoneCustomer mirrors read-only phone field',
        () {
      final selectionProvider = CustomerSelectionProvider();
      final billingProvider = BillingProvider()
        ..setSalesExecutiveMobileNumberText('5555')
        ..setMobileNumberText('5555');
      final localProvider = LocalProductProvider();

      final customer = controller.defaultSalesExecutivePhoneCustomer(
        billingProvider: billingProvider,
        localProductProvider: localProvider,
        customerSelectionProvider: selectionProvider,
      );

      expect(customer?.phone, '5555');
      expect(
        controller.shouldShowDefaultSalesExecutivePhone(
          billingProvider: billingProvider,
          localProductProvider: localProvider,
          customerSelectionProvider: selectionProvider,
        ),
        isTrue,
      );
    });

    test(
        'applyDefaultCustomerFromCacheIfNeeded assigns matched default customer',
        () {
      final localProvider = LocalProductProvider();
      final billingProvider = BillingProvider();
      final selectionProvider = CustomerSelectionProvider();
      final customers = [
        CustomerListModelData(id: 1, name: 'Walk-in', phone: '9999'),
        CustomerListModelData(id: 2, name: 'Regular', phone: '8888'),
      ];
      final settings = appSettings(
        autoAssignDefaultCustomer: true,
        autoAssignDefaultCustomerPhone: '8888',
      );

      final result = controller.applyDefaultCustomerFromCacheIfNeeded(
        localProductProvider: localProvider,
        billingProvider: billingProvider,
        customerSelectionProvider: selectionProvider,
        appSettings: settings,
        customers: customers,
      );

      expect(result.applied, isTrue);
      expect(result.matchedCustomer?.id, 2);

      final cartProvider = _FakeCartProvider();
      final auth = AuthModel()..login('token-3', 5);
      controller.applyDefaultCustomerResult(
        result: result,
        customerSelectionProvider: selectionProvider,
        billingProvider: billingProvider,
        cartProvider: cartProvider,
        auth: auth,
      );

      expect(selectionProvider.isDefaultCustomer, isTrue);
      expect(billingProvider.selectedCustomer?.id, 2);
      expect(billingProvider.isCustomerManuallySelected, isFalse);
      expect(cartProvider.fetchedCustomerId, 2);
    });

    test(
        'applyDefaultCustomerFromCacheIfNeeded fills phone when no match exists',
        () {
      final billingProvider = BillingProvider();
      final selectionProvider = CustomerSelectionProvider();
      final settings = appSettings(
        autoAssignDefaultCustomer: true,
        autoAssignDefaultCustomerPhone: '7777',
      );

      final result = controller.applyDefaultCustomerFromCacheIfNeeded(
        localProductProvider: LocalProductProvider(),
        billingProvider: billingProvider,
        customerSelectionProvider: selectionProvider,
        appSettings: settings,
        customers: [
          CustomerListModelData(id: 1, name: 'Other', phone: '1111'),
        ],
      );

      expect(result.phoneOnlyText, '7777');

      controller.applyDefaultCustomerResult(
        result: result,
        customerSelectionProvider: selectionProvider,
        billingProvider: billingProvider,
        cartProvider: _FakeCartProvider(),
        auth: AuthModel()..login('token-4', 1),
      );

      expect(selectionProvider.hasSelectedCustomer, isFalse);
      expect(billingProvider.mobileNumberText, '7777');
      expect(billingProvider.selectedCustomerPhone, '7777');
      expect(billingProvider.salesExecutivemobileNumberText, '7777');
      expect(billingProvider.selectedCustomer, isNull);
    });

    test('phone-only automatic default upgrades when full cache arrives', () {
      final billingProvider = BillingProvider();
      final selectionProvider = CustomerSelectionProvider();
      final cartProvider = _FakeCartProvider();
      final auth = AuthModel()..login('token-upgrade', 1);
      final settings = appSettings(
        autoAssignDefaultCustomer: true,
        autoAssignDefaultCustomerPhone: '7777',
      );

      final phoneOnly = controller.applyDefaultCustomerFromCacheIfNeeded(
        localProductProvider: LocalProductProvider(),
        billingProvider: billingProvider,
        customerSelectionProvider: selectionProvider,
        appSettings: settings,
        customers: [
          CustomerListModelData(id: 1, name: 'Other', phone: '1111'),
        ],
      );
      controller.applyDefaultCustomerResult(
        result: phoneOnly,
        customerSelectionProvider: selectionProvider,
        billingProvider: billingProvider,
        cartProvider: cartProvider,
        auth: auth,
      );

      final resolvedCustomer = CustomerListModelData(
          id: 77, name: 'Default Customer', phone: '7777');
      final upgraded = controller.applyDefaultCustomerFromCacheIfNeeded(
        localProductProvider: LocalProductProvider(),
        billingProvider: billingProvider,
        customerSelectionProvider: selectionProvider,
        appSettings: settings,
        customers: [resolvedCustomer],
      );
      controller.applyDefaultCustomerResult(
        result: upgraded,
        customerSelectionProvider: selectionProvider,
        billingProvider: billingProvider,
        cartProvider: cartProvider,
        auth: auth,
      );

      expect(upgraded.matchedCustomer?.id, 77);
      expect(selectionProvider.selectedCustomerID, 77);
      expect(selectionProvider.isDefaultCustomer, isTrue);
      expect(billingProvider.selectedCustomer?.id, 77);
      expect(cartProvider.fetchedCustomerId, 77);
    });

    test('reset can defer auth cart fetch while default is being resolved', () {
      final billingProvider = BillingProvider();
      final selectionProvider = CustomerSelectionProvider();
      final cartProvider = _FakeCartProvider();
      final auth = AuthModel()..login('token-reset', 41);

      controller.clearSelection(
        customerSelectionProvider: selectionProvider,
        billingProvider: billingProvider,
        cartProvider: cartProvider,
        auth: auth,
        resetCartContext: false,
      );

      expect(cartProvider.fetchedCustomerId, isNull);
    });

    testWidgets('phone-only default card shows the phone instead of dummy name',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerSummaryCard(
              customer: CustomerListModelData(phone: '7777'),
            ),
          ),
        ),
      );

      expect(find.text('7777'), findsOneWidget);
      expect(find.text('Default B2C'), findsNothing);
    });

    testWidgets(
        'clear-cart and post-order resets select the real default customer once',
        (tester) async {
      final settings = appSettings(
        autoAssignDefaultCustomer: true,
        autoAssignDefaultCustomerPhone: '7777',
      );
      final defaultCustomer = CustomerListModelData(
        id: 77,
        name: 'Default Customer',
        phone: '7777',
      );
      final manualCustomer =
          CustomerListModelData(id: 9, name: 'Manual', phone: '9999');
      final billingProvider = BillingProvider()
        ..setCustomerList([manualCustomer, defaultCustomer])
        ..setSelectedCustomer(manualCustomer, isManual: true);
      final selectionProvider = CustomerSelectionProvider()
        ..setSelectedCustomer(manualCustomer);
      final cartProvider = _FakeCartProvider();
      final auth = AuthModel()..login('token-reset-flow', 41);
      final localProductProvider = LocalProductProvider();
      late BuildContext providerContext;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BillingProvider>.value(
                value: billingProvider),
            ChangeNotifierProvider<CustomerSelectionProvider>.value(
                value: selectionProvider),
            ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
            ChangeNotifierProvider<AuthModel>.value(value: auth),
            ChangeNotifierProvider<LocalProductProvider>.value(
                value: localProductProvider),
            ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) => _FakeAppSettingsProvider(settings),
            ),
            ChangeNotifierProvider<DeliveryMethodsProvider>(
              create: (_) => DeliveryMethodsProvider(),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                providerContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      final mobileController = BillingMobileController();
      mobileController.clearCartData(providerContext);

      expect(selectionProvider.selectedCustomerID, 77);
      expect(selectionProvider.isDefaultCustomer, isTrue);
      expect(billingProvider.selectedCustomer?.id, 77);
      expect(cartProvider.fetchedCustomerId, 77);

      selectionProvider.setSelectedCustomer(manualCustomer);
      billingProvider.setSelectedCustomer(manualCustomer, isManual: true);
      cartProvider.fetchedCustomerId = null;

      mobileController.resetBillingWorkspaceAfterOrder(providerContext);

      expect(selectionProvider.selectedCustomerID, 77);
      expect(selectionProvider.isDefaultCustomer, isTrue);
      expect(billingProvider.selectedCustomer?.id, 77);
      expect(cartProvider.fetchedCustomerId, 77);
    });

    test('isCustomerSatisfiedForCheckout respects skipCustomerSelection', () {
      final billingProvider = BillingProvider();

      expect(
        controller.isCustomerSatisfiedForCheckout(
          billingProvider: billingProvider,
          skipCustomerSelection: true,
        ),
        isTrue,
      );
      expect(
        controller.isCustomerSatisfiedForCheckout(
          billingProvider: billingProvider,
          skipCustomerSelection: false,
        ),
        isFalse,
      );

      billingProvider.setMobileNumberText('9000');
      expect(
        controller.isCustomerSatisfiedForCheckout(
          billingProvider: billingProvider,
          skipCustomerSelection: false,
        ),
        isTrue,
      );
    });

    test('shouldShowCustomerBalance hides default and sales-executive phones',
        () {
      final selectionProvider = CustomerSelectionProvider();
      final defaultCustomer = CustomerListModelData(
        id: 1,
        name: 'Default',
        phone: '1000',
        balance: 50,
      );
      selectionProvider.setSelectedCustomer(defaultCustomer, isDefault: true);

      expect(
        controller.shouldShowCustomerBalance(
          customer: defaultCustomer,
          customerSelectionProvider: selectionProvider,
          defaultCustomerPhone: '1000',
          isQuotationDraft: false,
        ),
        isFalse,
      );

      final executiveCustomer = CustomerListModelData(
        id: 2,
        name: 'Exec',
        phone: '5555',
        balance: -10,
      );
      expect(
        controller.shouldShowCustomerBalance(
          customer: executiveCustomer,
          customerSelectionProvider: selectionProvider,
          defaultCustomerPhone: '1000',
          isQuotationDraft: false,
          salesExecutivePhone: '5555',
        ),
        isFalse,
      );

      expect(
        controller.balanceDisplay(balance: -12.5, currency: 'SAR').label,
        'Previous balance (debt)',
      );
    });
  });

  group('BillingMobileCartController widget integration', () {
    const controller = BillingMobileCartController();

    testWidgets(
        'calculates totals and changes item quantities through provider',
        (tester) async {
      final provider = LocalProductProvider();
      addTearDown(provider.dispose);
      final itemProduct = product(id: 10, name: 'Cart Product', price: '20');
      provider.initializeProducts([itemProduct]);
      provider.addToCart(product: itemProduct, quantity: 2);

      final totals = controller.totals(provider);
      expect(totals.total, 40);
      expect(totals.subtotal, 40);

      late BuildContext capturedContext;
      await tester.pumpWidget(
        Builder(builder: (ctx) {
          capturedContext = ctx;
          return const SizedBox();
        }),
      );

      await controller.changeQuantity(
          capturedContext, provider, provider.cartItems.first, 1);
      expect(provider.cartItems.single.quantity, 3);

      controller.removeItem(provider, provider.cartItems.first);
      expect(provider.cartItems, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
