/// Widget tests for P1.1: Mobile Home tab respects [AppSettings.barcodeSales].
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/market_home_widget.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home_tab.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';

class _TestAppSettingsProvider extends AppSettingsProvider {
  _TestAppSettingsProvider({required bool barcodeSales}) {
    _settings = AppSettings.fromJson({
      'data': [
        {
          'code': 'BARCODE_SALES',
          'status': barcodeSales ? 'true' : 'false',
          'value': barcodeSales.toString(),
        },
      ],
    });
  }

  late final AppSettings _settings;

  @override
  AppSettings? get appSettings => _settings;

  @override
  Future<void> fetchAppSettings() async {}
}

class _TestRoleProvider extends RoleProvider {
  @override
  bool currentUserHasPermissionSync(String permission) => false;
}

class _TestBillingProvider extends BillingProvider {
  @override
  void initConnectivityListener({Function(String)? onConnectivityChanged}) {}

  @override
  Future<bool> fetchCustomers({
    required String accessToken,
    bool sortAscending = true,
  }) async =>
      true;

  @override
  void initializeDeliveryMethod() {}
}

Finder _hintTextField(String hint) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration?.hintText == hint,
  );
}

Widget _wrap({
  required bool barcodeSales,
  required Widget child,
  LocalProductProvider? localProductProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppSettingsProvider>(
        create: (_) => _TestAppSettingsProvider(barcodeSales: barcodeSales),
      ),
      ChangeNotifierProvider<BillingProvider>(
        create: (_) => _TestBillingProvider(),
      ),
      ChangeNotifierProvider<LocalProductProvider>(
        create: (_) => localProductProvider ?? LocalProductProvider(),
      ),
      ChangeNotifierProvider<CustomerSelectionProvider>(
        create: (_) => CustomerSelectionProvider(),
      ),
      ChangeNotifierProvider<KeyboardProvider>(
        create: (_) => KeyboardProvider(),
      ),
      ChangeNotifierProvider<RoleProvider>(
        create: (_) => _TestRoleProvider(),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_mobile_home_barcode_');
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

  group('MarketHomeWidget — barcodeSales enabled', () {
    testWidgets('shows barcode field and hides product autocomplete',
        (tester) async {
      await tester.pumpWidget(_wrap(
        barcodeSales: true,
        child: MarketHomeWidget(
          autocompleteProductKey: GlobalKey(),
          onProcessBarcode: (_) {},
          onClearProductFields: () {},
          focusTextField: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(_hintTextField('Barcode'), findsOneWidget);
      expect(_hintTextField('Search product'), findsNothing);
    });

    testWidgets('submitting barcode calls onProcessBarcode', (tester) async {
      final processed = <String>[];

      await tester.pumpWidget(_wrap(
        barcodeSales: true,
        child: MarketHomeWidget(
          autocompleteProductKey: GlobalKey(),
          onProcessBarcode: processed.add,
          onClearProductFields: () {},
          focusTextField: () {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(_hintTextField('Barcode'), '9988776655');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(processed, ['9988776655']);
    });
  });

  group('MarketHomeWidget — barcodeSales disabled', () {
    testWidgets('shows product autocomplete and hides barcode field',
        (tester) async {
      await tester.pumpWidget(_wrap(
        barcodeSales: false,
        child: MarketHomeWidget(
          autocompleteProductKey: GlobalKey(),
          onProcessBarcode: (_) {},
          onClearProductFields: () {},
          focusTextField: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(_hintTextField('Search product'), findsOneWidget);
      expect(_hintTextField('Barcode'), findsNothing);
    });
  });

  group('MobileHomeTab — wires callbacks to MarketHomeWidget', () {
    testWidgets('forwards barcode submit through onProcessBarcode callback',
        (tester) async {
      final processed = <String>[];

      await tester.pumpWidget(_wrap(
        barcodeSales: true,
        child: MobileHomeTab(
          autocompleteProductKey: GlobalKey(),
          onProcessBarcode: processed.add,
          onClearProductFields: () {},
          focusTextField: () {},
          onClearCart: () {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(_hintTextField('Barcode'), '1122334455');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(processed, ['1122334455']);
    });
  });
}
