import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/models/delivery_method.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'test_support/hive_test_teardown.dart';

class _FakeDeliveryMethodsProvider extends DeliveryMethodsProvider {
  _FakeDeliveryMethodsProvider(
    this._methods, {
    bool isLoading = false,
  }) : _isLoading = isLoading;

  final List<DeliveryMethod> _methods;
  final bool _isLoading;

  @override
  List<DeliveryMethod> get deliveryMethods => _methods;

  @override
  bool get isLoading => _isLoading;

  @override
  DeliveryMethod? resolveDefaultDeliveryMethod({String? appSettingsDefault}) {
    final configuredDefault = appSettingsDefault?.trim();
    if (configuredDefault != null && configuredDefault.isNotEmpty) {
      for (final method in _methods) {
        final code = method.code?.trim();
        if (method.id == configuredDefault ||
            method.name.toLowerCase() == configuredDefault.toLowerCase() ||
            (code != null &&
                code.isNotEmpty &&
                code.toLowerCase() == configuredDefault.toLowerCase())) {
          return method;
        }
      }
    }

    try {
      return _methods.firstWhere(
        (method) => method.name.toLowerCase().contains('store takeaway'),
        orElse: () => _methods.isNotEmpty
            ? _methods.first
            : DeliveryMethod(id: '11', name: 'Store Takeaway'),
      );
    } catch (_) {
      return _methods.isNotEmpty
          ? _methods.first
          : DeliveryMethod(id: '11', name: 'Store Takeaway');
    }
  }
}

AppSettings _appSettings({
  bool barcodeSales = true,
  bool discountAndCoupon = false,
  bool showCustomerLastBuyedPriceList = false,
  bool askDeliveryDate = false,
  String defaultDeliveryMethod = 'Store Takeaway',
  String defaultPaymentMethod = 'CASH',
}) {
  return AppSettings(
    barcodeSales: barcodeSales,
    customerCarePhone: '',
    customerCareEmail: '',
    printTitle: '',
    showCustomerLastBuyedPriceList: showCustomerLastBuyedPriceList,
    askDeliveryDate: askDeliveryDate,
    priceRoundOff: false,
    discountAndCoupon: discountAndCoupon,
    autoAssignDefaultCustomer: false,
    autoAssignDefaultCustomerPhone: '',
    currency: 'SAR',
    zatcaPhase1Enabled: false,
    zatcaPhase2Enabled: false,
    showTaxPos: false,
    showMrpPos: false,
    showTaxRatePos: false,
    showConfirmOrderButton: true,
    enableKOTPrint: false,
    defaultDeliveryMethod: defaultDeliveryMethod,
    defaultPaymentMethod: defaultPaymentMethod,
    posPrintDoubleBill: false,
    skipCustomerSelection: false,
    hideDefaultPhone: false,
    freeDeliveryEnabled: false,
    freeDeliveryMinimumAmount: '0',
    itemCodeEnabled: false,
    companyB2BEnabled: false,
    enableSendToKitchenButton: false,
    enableKotBillButton: false,
    kotBillAutoMarkServed: false,
    kotBillAllowedForDineIn: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;
  const controller = BillingMobileSettingsController();

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_settings_sync_test_');
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

  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

  group('BillingMobileSettingsController predicates', () {
    test('isBarcodeSalesEnabled reflects app setting', () {
      expect(
        controller.isBarcodeSalesEnabled(_appSettings(barcodeSales: true)),
        isTrue,
      );
      expect(
        controller.isBarcodeSalesEnabled(_appSettings(barcodeSales: false)),
        isFalse,
      );
      expect(controller.isBarcodeSalesEnabled(null), isFalse);
    });

    test('shouldShowCouponSection reflects discountAndCoupon', () {
      expect(
        controller.shouldShowCouponSection(
          _appSettings(discountAndCoupon: true),
        ),
        isTrue,
      );
      expect(
        controller.shouldShowCouponSection(
          _appSettings(discountAndCoupon: false),
        ),
        isFalse,
      );
      expect(controller.shouldShowCouponSection(null), isFalse);
    });

    test('shouldShowDeliveryDateTime reflects askDeliveryDate', () {
      expect(
        controller.shouldShowDeliveryDateTime(
          _appSettings(askDeliveryDate: true),
        ),
        isTrue,
      );
      expect(
        controller.shouldShowDeliveryDateTime(
          _appSettings(askDeliveryDate: false),
        ),
        isFalse,
      );
    });

    test('shouldShowPurchaseHistoryAction requires setting and customer', () {
      final enabled = _appSettings(showCustomerLastBuyedPriceList: true);

      expect(
        controller.shouldShowPurchaseHistoryAction(
          appSettings: enabled,
          hasSelectedCustomer: true,
          isDefaultCustomer: false,
        ),
        isTrue,
      );
      expect(
        controller.shouldShowPurchaseHistoryAction(
          appSettings: enabled,
          hasSelectedCustomer: false,
          isDefaultCustomer: false,
        ),
        isFalse,
      );
      expect(
        controller.shouldShowPurchaseHistoryAction(
          appSettings: enabled,
          hasSelectedCustomer: true,
          isDefaultCustomer: true,
        ),
        isFalse,
      );
      expect(
        controller.shouldShowPurchaseHistoryAction(
          appSettings: _appSettings(showCustomerLastBuyedPriceList: false),
          hasSelectedCustomer: true,
          isDefaultCustomer: false,
        ),
        isFalse,
      );
    });
  });

  group('BillingMobileSettingsController sync', () {
    test('syncStockEnabled writes to LocalProductProvider', () {
      final localProductProvider = LocalProductProvider();

      expect(
        controller.syncStockEnabled(
          stockEnabled: true,
          localProductProvider: localProductProvider,
        ),
        isTrue,
      );
      expect(localProductProvider.isStockEnabled, isTrue);

      expect(
        controller.syncStockEnabled(
          stockEnabled: false,
          localProductProvider: localProductProvider,
        ),
        isFalse,
      );
      expect(localProductProvider.isStockEnabled, isFalse);
    });

    test('syncAppSettingsFlags updates billing provider toggles', () {
      final billingProvider = BillingProvider();

      controller.syncAppSettingsFlags(
        appSettings: _appSettings(
          barcodeSales: false,
          discountAndCoupon: true,
        ),
        billingProvider: billingProvider,
      );

      expect(billingProvider.barcodeSalesEnabled, isFalse);
      expect(billingProvider.discountsEnabled, isTrue);
    });

    test('applyDefaultPaymentMethodIfNeeded selects configured method', () {
      final billingProvider = BillingProvider();

      final applied = controller.applyDefaultPaymentMethodIfNeeded(
        billingProvider: billingProvider,
        appSettings: _appSettings(defaultPaymentMethod: 'CARD'),
      );

      expect(applied, isTrue);
      expect(billingProvider.isCardSelected, isTrue);
      expect(billingProvider.isCashSelected, isFalse);
    });

    test('applyDefaultPaymentMethodIfNeeded skips when payment already selected',
        () {
      final billingProvider = BillingProvider()..setPaymentMethod('CASH', true);

      final applied = controller.applyDefaultPaymentMethodIfNeeded(
        billingProvider: billingProvider,
        appSettings: _appSettings(defaultPaymentMethod: 'CARD'),
      );

      expect(applied, isFalse);
      expect(billingProvider.isCardSelected, isFalse);
      expect(billingProvider.isCashSelected, isTrue);
    });

    test('syncDefaultDeliveryMethod applies app-settings default', () {
      final billingProvider = BillingProvider();
      final deliveryProvider = _FakeDeliveryMethodsProvider([
        DeliveryMethod(id: '1', name: 'Store Takeaway'),
        DeliveryMethod(id: '2', name: 'Door Delivery'),
      ]);

      final result = controller.syncDefaultDeliveryMethod(
        billingProvider: billingProvider,
        deliveryMethodsProvider: deliveryProvider,
        appSettings: _appSettings(defaultDeliveryMethod: 'Door Delivery'),
      );

      expect(result.applied, isTrue);
      expect(result.method?.name, 'Door Delivery');
      expect(billingProvider.deliveryMethod, 'Door Delivery');
      expect(billingProvider.deliveryMethodId, '2');
    });

    test('syncDefaultDeliveryMethod skips while loading or empty', () {
      final billingProvider = BillingProvider();

      final loadingResult = controller.syncDefaultDeliveryMethod(
        billingProvider: billingProvider,
        deliveryMethodsProvider: _FakeDeliveryMethodsProvider(
          const [],
          isLoading: true,
        ),
        appSettings: _appSettings(),
      );
      expect(loadingResult.applied, isFalse);

      final emptyResult = controller.syncDefaultDeliveryMethod(
        billingProvider: billingProvider,
        deliveryMethodsProvider: _FakeDeliveryMethodsProvider(const []),
        appSettings: _appSettings(),
      );
      expect(emptyResult.applied, isFalse);
    });

    test('syncDefaultDeliveryMethod skips when already on default', () {
      final billingProvider = BillingProvider()
        ..setDeliveryMethod('Store Takeaway', '1');
      final deliveryProvider = _FakeDeliveryMethodsProvider([
        DeliveryMethod(id: '1', name: 'Store Takeaway'),
      ]);

      final result = controller.syncDefaultDeliveryMethod(
        billingProvider: billingProvider,
        deliveryMethodsProvider: deliveryProvider,
        appSettings: _appSettings(defaultDeliveryMethod: 'Store Takeaway'),
      );

      expect(result.applied, isFalse);
      expect(billingProvider.deliveryMethod, 'Store Takeaway');
    });
  });
}
