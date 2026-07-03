import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/models/delivery_method.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/delivery_options_section.dart';

class _FakeAppSettingsProvider extends AppSettingsProvider {
  _FakeAppSettingsProvider(this._testSettings);

  final AppSettings _testSettings;

  @override
  AppSettings? get appSettings => _testSettings;

  @override
  Future<void> fetchAppSettings() async {}
}

class _FakeDeliveryMethodsProvider extends DeliveryMethodsProvider {
  _FakeDeliveryMethodsProvider(this._methods);

  final List<DeliveryMethod> _methods;

  @override
  List<DeliveryMethod> get deliveryMethods => _methods;
}

AppSettings _appSettings({required bool askDeliveryDate}) {
  return AppSettings(
    barcodeSales: true,
    customerCarePhone: '',
    customerCareEmail: '',
    printTitle: '',
    showCustomerLastBuyedPriceList: false,
    askDeliveryDate: askDeliveryDate,
    priceRoundOff: false,
    discountAndCoupon: false,
    autoAssignDefaultCustomer: false,
    autoAssignDefaultCustomerPhone: '',
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
    pineLabPayment: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_delivery_test_');
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
    await Hive.close();
    if (await hiveDir.exists()) await hiveDir.delete(recursive: true);
  });

  Widget wrap({required bool askDeliveryDate}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BillingProvider>(
          create: (_) => BillingProvider(),
        ),
        ChangeNotifierProvider<DeliveryMethodsProvider>(
          create: (_) => _FakeDeliveryMethodsProvider([
            DeliveryMethod(id: '1', name: 'Store Takeaway'),
          ]),
        ),
        ChangeNotifierProvider<AppSettingsProvider>(
          create: (_) => _FakeAppSettingsProvider(
            _appSettings(askDeliveryDate: askDeliveryDate),
          ),
        ),
        ChangeNotifierProvider<CustomerSelectionProvider>(
          create: (_) => CustomerSelectionProvider(),
        ),
        ChangeNotifierProvider<LocalProductProvider>(
          create: (_) => LocalProductProvider(),
        ),
        ChangeNotifierProvider<KeyboardProvider>(
          create: (_) => KeyboardProvider(),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: DeliveryOptionsSection()),
      ),
    );
  }

  testWidgets('shows delivery date/time when askDeliveryDate is enabled',
      (tester) async {
    await tester.pumpWidget(wrap(askDeliveryDate: true));
    await tester.pump();

    expect(find.byKey(const Key('delivery_date_label')), findsOneWidget);
    expect(find.byKey(const Key('delivery_time_label')), findsOneWidget);
    expect(find.text('Delivery Date:'), findsOneWidget);
    expect(find.text('Delivery Time:'), findsOneWidget);
  });

  testWidgets('hides delivery date/time when askDeliveryDate is disabled',
      (tester) async {
    await tester.pumpWidget(wrap(askDeliveryDate: false));
    await tester.pump();

    expect(find.byKey(const Key('delivery_date_label')), findsNothing);
    expect(find.byKey(const Key('delivery_time_label')), findsNothing);
  });
}
