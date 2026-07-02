/// P2.3 — mobile saved-order rehydration restores every persisted field.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'test_support/hive_test_teardown.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/features/billing/controllers/billing_mobile_controller.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';

class _FakeMasterDataProvider extends MasterDataProvider {
  @override
  String? getPaymentMethodValue(int? id) {
    if (id == 99) return 'CHEQUE';
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;
  final controller = BillingMobileController();

  final paymentMethodJson = jsonEncode({
    'isMultiPayment': true,
    'methods': ['CASH', 'CARD', '99', 'DEBIT', 'ONLINE'],
    'amounts': {
      'CASH': '80',
      'CARD': '40',
      '99': '50',
      'DEBIT': '30',
    },
  });

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_rehydration_test_');
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
    SharedPreferences.setMockInitialValues({
      'general_stock_enabled': false,
    });

    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
  });

  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

  GetProduct buildProduct() {
    return GetProduct(
      productId: 101,
      productName: 'Rehydration Widget',
      price: ProductPrice(price: '200'),
      mrp: '220',
      purchasePrice: '150',
      unit: 'PCS',
      stock: const <Stock>[],
      taxes: const <ProductTax>[],
      saleUnits: [
        SaleUnit(
          id: 10,
          unitName: 'CASE',
          conversionRate: '12',
          barcode: 'CASEBAR101',
        ),
      ],
    );
  }

  Widget wrap({
    required LocalProductProvider localProductProvider,
    required BillingProvider billingProvider,
    required CustomerSelectionProvider customerSelectionProvider,
    required Widget child,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LocalProductProvider>.value(
          value: localProductProvider,
        ),
        ChangeNotifierProvider<BillingProvider>.value(
          value: billingProvider,
        ),
        ChangeNotifierProvider<CustomerSelectionProvider>.value(
          value: customerSelectionProvider,
        ),
        ChangeNotifierProvider<DeliveryMethodsProvider>(
          create: (_) => DeliveryMethodsProvider(),
        ),
        ChangeNotifierProvider<MasterDataProvider>(
          create: (_) => _FakeMasterDataProvider(),
        ),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('restoreOrderState rehydrates every saved order field', (tester) async {
    final localProductProvider = LocalProductProvider();
    late SavedOrder savedOrder;

    // testWidgets runs inside Flutter's FakeAsync zone, which never fires
    // Hive's internal write-flush Timer. Run every Hive-touching
    // LocalProductProvider call inside tester.runAsync() (a real async zone)
    // so all writes complete before this test exits — otherwise the next
    // test's setUp `box.clear()` or tearDownAll's `Hive.close()` hangs
    // waiting on a flush that will never happen. See the identical fix in
    // test/p0_4_mobile_quantity_stock_test.dart for the full rationale.
    await tester.runAsync(() async {
      localProductProvider.setStockEnabled(false);
      localProductProvider.initializeProducts([buildProduct()]);
      localProductProvider.addToCart(
        product: buildProduct(),
        quantity: 24,
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 12,
        markPriceAsManualOverride: true,
      );
      localProductProvider.applyDiscount(
        flatDiscount: 10,
        percentageDiscount: 5,
      );

      savedOrder = localProductProvider.saveCurrentCartAsOrder(
        customerId: 42,
        customerName: 'Test Customer',
        customerPhone: '9876543210',
        comment: 'Leave at door',
        deliveryMethod: 'Car Delivery',
        deliveryMethodId: '3',
        carNumber: 'MH12AB1234',
        address: '123 Main Street, Pune',
        deliveryDate: '2024-06-15T00:00:00.000',
        deliveryTime: '14:30',
        paymentMethod: paymentMethodJson,
        paidAmount: '170',
        balanceAmount: '0',
        transactionId: 'PL-TXN-12345',
        couponId: 'SAVE10',
        toCustomerCredit: true,
        deliveryCharge: 25,
        status: 'saved',
      );

      localProductProvider.clearCart();
      localProductProvider.loadOrderForEditing(savedOrder.id);
    });

    final billingProvider = BillingProvider();
    billingProvider.setCustomerList([
      CustomerListModelData(
        id: 42,
        name: 'Test Customer',
        phone: '9876543210',
      ),
    ]);
    final customerSelectionProvider = CustomerSelectionProvider();

    late BuildContext testContext;
    await tester.pumpWidget(
      wrap(
        localProductProvider: localProductProvider,
        billingProvider: billingProvider,
        customerSelectionProvider: customerSelectionProvider,
        child: Builder(
          builder: (context) {
            testContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    controller.restoreOrderState(testContext);

    // --- BillingProvider: customer ---
    expect(billingProvider.selectedCustomerID, 42);
    expect(billingProvider.selectedCustomer?.name, 'Test Customer');
    expect(billingProvider.selectedCustomer?.phone, '9876543210');
    expect(billingProvider.isCustomerManuallySelected, isTrue);
    expect(customerSelectionProvider.selectedCustomerID, 42);
    expect(customerSelectionProvider.selectedCustomer?.name, 'Test Customer');

    // --- BillingProvider: typed + dynamic payments ---
    expect(billingProvider.isCashSelected, isTrue);
    expect(billingProvider.cashAmountController.text, '80');
    expect(billingProvider.isCardSelected, isTrue);
    expect(billingProvider.cardAmountController.text, '40');
    expect(billingProvider.isDebitSelected, isTrue);
    expect(billingProvider.debitAmountController.text, '30');
    expect(billingProvider.isExtraMethodSelected('99'), isTrue);
    expect(billingProvider.extraPaymentAmounts['99'], '50');
    expect(billingProvider.extraPaymentValues['99'], 'CHEQUE');
    expect(billingProvider.getExtraAmountController('99').text, '50');

    // --- BillingProvider: ONLINE / Pine Labs ---
    expect(billingProvider.isOnlineSelected, isTrue);
    expect(billingProvider.pineLabsPaymentSuccess, isTrue);
    expect(
      billingProvider.transactionNumberController.text,
      'PL-TXN-12345',
    );

    // --- BillingProvider: delivery ---
    expect(billingProvider.deliveryMethod, 'Car Delivery');
    expect(billingProvider.deliveryMethodId, '3');
    expect(billingProvider.carNumberController.text, 'MH12AB1234');
    expect(billingProvider.orderAddress, '123 Main Street, Pune');
    expect(
      billingProvider.deliveryDate,
      DateTime.parse('2024-06-15T00:00:00.000'),
    );
    expect(billingProvider.deliveryTime, '14:30');
    expect(billingProvider.commentController.text, 'Leave at door');

    // --- BillingProvider: coupon / customer credit / totals ---
    expect(billingProvider.isCouponApplied, isTrue);
    expect(billingProvider.coupenCodeTextController.text, 'SAVE10');
    expect(billingProvider.toCustomerCreditEnabled, isTrue);
    expect(
      billingProvider.totalOrderAmount,
      localProductProvider.priceSummary?.netTotal ?? 0.0,
    );
    expect(billingProvider.balanceAmount, greaterThanOrEqualTo(0));

    // --- LocalProductProvider: cart + discounts ---
    expect(localProductProvider.currentOrder?.id, savedOrder.id);
    expect(localProductProvider.cartItems.length, 1);

    final cartItem = localProductProvider.cartItems.first;
    expect(cartItem.saleUnitId, 10);
    expect(cartItem.saleUnitName, 'CASE');
    expect(cartItem.saleUnitConversionRate, 12);
    expect(cartItem.isManualPriceOverride, isTrue);
    expect(cartItem.quantity, 24);

    expect(localProductProvider.priceSummary?.flatDiscount, 10);
    expect(localProductProvider.priceSummary?.percentageDiscount, 240);

    // --- LocalProductProvider: persisted order metadata ---
    expect(localProductProvider.currentOrder?.deliveryCharge, 25);
    expect(localProductProvider.currentOrder?.flatDiscount, 10);
    expect(localProductProvider.currentOrder?.percentageDiscount, 5);
    expect(localProductProvider.currentOrder?.address, '123 Main Street, Pune');
    expect(localProductProvider.currentOrder?.transactionId, 'PL-TXN-12345');
  });
}
