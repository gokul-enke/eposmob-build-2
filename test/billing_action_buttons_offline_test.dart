library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/resources/localization_service.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing_tab.dart';
import 'package:pos_machine/features/billing/presentation/widgets/payment_summary.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/billing_action_buttons.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

class _OfflineBillingProvider extends BillingProvider {
  @override
  bool get hasInternet => false;
}

class _CartWithItems extends LocalProductProvider {
  @override
  List<LocalCartItem> get cartItems =>
      [LocalCartItem(product: GetProduct(productId: 1))];
}

// Isolate footer sizing at enlarged text scales from the existing fixed-width
// payment-summary rows. Normal-scale tests below render the real totals.
class _UnpricedCart extends LocalProductProvider {
  _UnpricedCart() {
    priceSummary = null;
  }

  @override
  double get cartTotal => 0;
}

class _FakeAppSettingsProvider extends AppSettingsProvider {
  final bool showWhatsapp;
  _FakeAppSettingsProvider({this.showWhatsapp = false});

  @override
  AppSettings get appSettings => AppSettings.fromJson({
        'data': [
          {'code': 'SHOW_CONFIRM_WHATSAPP_BUTTON', 'status': showWhatsapp},
        ],
      });

  @override
  Future<void> fetchAppSettings() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalizationService.init();
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.addTranslations(LocalizationService.translations);
    Get.locale = const Locale('en');
  });

  for (final action in ['confirm', 'print', 'whatsapp']) {
    testWidgets('only $action shows loading and all submissions are blocked',
        (tester) async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<LocalProductProvider>(
              create: (_) => _CartWithItems()),
          ChangeNotifierProvider<AppSettingsProvider>(
            create: (_) => _FakeAppSettingsProvider(showWhatsapp: true),
          ),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: BillingActionButtons(
          onSaveOrder: () {},
          onCreateOrderAndPrint: () {},
          onConfirmOrder: () {},
          onConfirmAndWhatsapp: () {},
          isConfirmingOrder: action == 'confirm',
          isConfirmingAndPrinting: action == 'print',
          isConfirmingAndWhatsapp: action == 'whatsapp',
        ))),
      ));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final label = action == 'confirm'
          ? 'Confirm'
          : action == 'print'
              ? 'Confirm & Print'
              : 'Confirm & Whatsapp';
      final activeButton = find.ancestor(
          of: find.text(label), matching: find.byType(ElevatedButton));
      expect(
          find.descendant(
              of: activeButton,
              matching: find.byType(CircularProgressIndicator)),
          findsOneWidget);
      for (final button
          in tester.widgetList<ElevatedButton>(find.byType(ElevatedButton))) {
        expect(button.onPressed, isNull);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final enabled in [false, true]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('mobile summary clears footer enabled=$enabled scale=$scale',
          (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<LocalProductProvider>(
                create: (_) =>
                    scale == 1.0 ? LocalProductProvider() : _UnpricedCart()),
            ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) => _FakeAppSettingsProvider(showWhatsapp: enabled),
            ),
            ChangeNotifierProvider<BillingProvider>(
                create: (_) => BillingProvider()),
            ChangeNotifierProvider<CustomerSelectionProvider>(
                create: (_) => CustomerSelectionProvider()),
            ChangeNotifierProvider<DeliveryMethodsProvider>(
                create: (_) => DeliveryMethodsProvider()),
          ],
          child: GetMaterialApp(
            translationsKeys: LocalizationService.translations,
            locale: const Locale('en', 'US'),
            home: MediaQuery(
              data: MediaQueryData(
                  size: const Size(360, 800),
                  padding: const EdgeInsets.only(bottom: 24),
                  textScaler: TextScaler.linear(scale)),
              child: MobileBillingTab(
                autocompletePhoneKey: GlobalKey(),
                onConfirmOrder: () {},
                onSaveOrder: () {},
                onCreateOrderAndPrint: () {},
                onConfirmAndWhatsapp: () {},
              ),
            ),
          ),
        ));
        await tester.pump();
        final scroll = find.byType(SingleChildScrollView);
        await tester.drag(scroll, const Offset(0, -1500));
        await tester.pumpAndSettle();
        final footerTop =
            tester.getTopLeft(find.byType(BillingActionButtons)).dy;
        expect(tester.getBottomLeft(scroll).dy, lessThanOrEqualTo(footerTop));
        expect(tester.getBottomLeft(find.byType(PaymentSummary)).dy,
            lessThan(footerTop));
        expect(tester.getBottomLeft(find.byType(BillingActionButtons)).dy,
            lessThanOrEqualTo(776));
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final busy in [false, true]) {
    testWidgets('WhatsApp callback respects checkout busy=$busy',
        (tester) async {
      var whatsappCalls = 0;
      var confirmCalls = 0;
      var printCalls = 0;
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<LocalProductProvider>(
              create: (_) => _CartWithItems()),
          ChangeNotifierProvider<AppSettingsProvider>(
            create: (_) => _FakeAppSettingsProvider(showWhatsapp: true),
          ),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: BillingActionButtons(
          onSaveOrder: () {},
          onCreateOrderAndPrint: () => printCalls++,
          onConfirmOrder: () => confirmCalls++,
          onConfirmAndWhatsapp: () => whatsappCalls++,
          isConfirmingAndPrinting: busy,
        ))),
      ));
      await tester.pump();
      final label = find.text('Confirm & Whatsapp');
      expect(label, findsOneWidget);
      await tester.tap(label);
      await tester.pump();
      expect(whatsappCalls, busy ? 0 : 1);
      expect(confirmCalls, 0);
      expect(printCalls, 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final enabled in [false, true]) {
    for (final quotation in [false, true]) {
      testWidgets('WhatsApp visibility enabled=$enabled quotation=$quotation',
          (tester) async {
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<LocalProductProvider>(
              create: (_) => LocalProductProvider(),
            ),
            ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) => _FakeAppSettingsProvider(showWhatsapp: enabled),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BillingActionButtons(
                isQuotationMode: quotation,
                onSaveOrder: () {},
                onCreateOrderAndPrint: () {},
                onConfirmOrder: () {},
                onConfirmAndWhatsapp: () {},
              ),
            ),
          ),
        ));
        await tester.pump();
        final label = find.text('Confirm & Whatsapp');
        expect(label, enabled && !quotation ? findsOneWidget : findsNothing);
        if (enabled && !quotation) {
          final button = tester.widget<ElevatedButton>(
            find.ancestor(of: label, matching: find.byType(ElevatedButton)),
          );
          expect(
              button.onPressed, isNull); // Empty cart uses the existing gate.
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('offline shows the same confirm actions as online',
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
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    // Offline sales are confirmed offline-first; the old never-synced
    // Save & Print is gone.
    expect(find.text('Save Order'), findsOneWidget);
    expect(find.text('Save & Print'), findsNothing);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Confirm & Print'), findsOneWidget);
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
