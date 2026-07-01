library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/billing_action_buttons.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

class _OfflineBillingProvider extends BillingProvider {
  @override
  bool get hasInternet => false;
}

class _FakeAppSettingsProvider extends AppSettingsProvider {
  @override
  Future<void> fetchAppSettings() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_offline_buttons_');
    Hive.init(hiveDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HiveStringValueAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(HiveProductAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(HiveLocalCartItemAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(HiveSavedOrderAdapter());
    }
    await Hive.openBox<HiveProduct>('products');
    await Hive.openBox<HiveLocalCartItem>('cart_items');
    await Hive.openBox<HiveSavedOrder>('saved_orders');
    await Hive.openBox<HiveSavedOrder>('confirmed_orders');
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('offline shows Save & Print instead of Confirm buttons',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocalProductProvider>(
            create: (_) => LocalProductProvider(),
          ),
          ChangeNotifierProvider<BillingProvider>(
            create: (_) => _OfflineBillingProvider(),
          ),
          ChangeNotifierProvider<AppSettingsProvider>(
            create: (_) => _FakeAppSettingsProvider(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: BillingActionButtons(
              onSaveOrder: () {},
              onCreateOrderAndPrint: () {},
              onConfirmOrder: () {},
              onSaveAndPrint: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Save Order'), findsOneWidget);
    expect(find.text('Save & Print'), findsOneWidget);
    expect(find.text('Confirm'), findsNothing);
    expect(find.text('Confirm & Print'), findsNothing);
  });

  testWidgets('online shows Save Order plus confirm actions', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocalProductProvider>(
            create: (_) => LocalProductProvider(),
          ),
          ChangeNotifierProvider<BillingProvider>(
            create: (_) => BillingProvider(),
          ),
          ChangeNotifierProvider<AppSettingsProvider>(
            create: (_) => _FakeAppSettingsProvider(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: BillingActionButtons(
              onSaveOrder: () {},
              onCreateOrderAndPrint: () {},
              onConfirmOrder: () {},
              onSaveAndPrint: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Save Order'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Confirm & Print'), findsOneWidget);
    expect(find.text('Save & Print'), findsNothing);
  });
}
