import 'package:pos_machine/features/purchase_returns/data/purchase_return_api.dart';
import 'package:pos_machine/features/purchase_returns/data/purchase_return_repository.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/screens/purchase/purchase_orders.dart';
import 'package:pos_machine/features/purchase_returns/presentation/pages/purchase_return_list_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePurchaseProvider extends PurchaseProvider {
  _FakePurchaseProvider()
      : super(
            purchaseReturnRepository: PurchaseReturnRepository(
                api: PurchaseReturnApi(
                    httpGet: (url, {headers}) async => http.Response(
                        '{"status":"success","data":{"current_page":1,"last_page":1,"data":[]}}',
                        200))));

  @override
  Future<void> listAllStores(String accessToken, String? storeName) async {}

  @override
  Future<void> listAllSuppliers(
    String accessToken,
    String? supplierName,
  ) async {}

  @override
  Future<void> listPurchaseOrders({
    required String accessToken,
    String? storeId,
    String? supplierId,
    String? dateFrom,
    String? dateTo,
    int? page,
  }) async {}

  @override
  Future<void> listPurchaseReturns({
    required String accessToken,
    int? page,
    String? supplierId,
    String? dateFrom,
    String? dateTo,
  }) async {}
}

class _AllowedRoleProvider extends RoleProvider {
  @override
  bool currentUserHasPermissionSync(String permission) => true;
}

class _FakeAppSettingsProvider extends AppSettingsProvider {
  @override
  Future<void> fetchAppSettings() async {}
}

class _TestTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': {
          'pagination.previous': 'Previous',
          'pagination.page': 'Page',
          'pagination.of': 'of',
          'pagination.next': 'Next',
          'purchase_order.summary': 'Summary',
          'purchase_order.total_price': 'Total Price',
          'purchase_order.create_purchase_order_btn': 'Create Purchase Order',
          'purchase_return.create_btn': 'Create Purchase Return',
        },
      };
}

void main() {
  setUpAll(() {
    Get.testMode = true;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'api_key': 'test-api-key'});
  });

  tearDown(() {
    Get.reset();
  });

  Widget wrapScreen(Widget screen) {
    final auth = AuthModel()..login('test-token', 1);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthModel>.value(value: auth),
        ChangeNotifierProvider<PurchaseProvider>(
          create: (_) => _FakePurchaseProvider(),
        ),
        ChangeNotifierProvider<AppSettingsProvider>(
          create: (_) => _FakeAppSettingsProvider(),
        ),
        ChangeNotifierProvider<RoleProvider>(
          create: (_) => _AllowedRoleProvider(),
        ),
      ],
      child: GetMaterialApp(
        translations: _TestTranslations(),
        locale: const Locale('en', 'US'),
        home: Scaffold(body: screen),
      ),
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapScreen(screen));
    await tester.pump();
  }

  Future<void> verifyDesktopCollapse(
    WidgetTester tester, {
    required Widget screen,
    required Key toggleKey,
    required Key panelKey,
    required Key actionKey,
  }) async {
    await pumpScreen(tester, screen, size: const Size(1200, 900));

    expect(find.byKey(toggleKey), findsOneWidget);
    expect(find.byKey(panelKey), findsOneWidget);
    expect(find.byKey(actionKey), findsOneWidget);

    await tester.tap(find.byKey(toggleKey));
    await tester.pump();

    expect(find.byKey(panelKey), findsNothing);
    expect(find.byKey(toggleKey), findsOneWidget);
    expect(find.byKey(actionKey), findsOneWidget);
  }

  Future<void> verifyMobileStartsCollapsed(
    WidgetTester tester, {
    required Widget screen,
    required Key toggleKey,
    required Key panelKey,
  }) async {
    await pumpScreen(tester, screen, size: const Size(390, 800));

    expect(find.byKey(toggleKey), findsOneWidget);
    expect(find.byKey(panelKey), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(toggleKey),
        matching: find.byIcon(Icons.filter_alt_outlined),
      ),
      findsOneWidget,
    );
  }

  Future<Object?> verifyMobileExpansion(
    WidgetTester tester, {
    required Widget screen,
    required Key toggleKey,
    required Key panelKey,
  }) async {
    await pumpScreen(tester, screen, size: const Size(390, 650));

    await tester.tap(find.byKey(toggleKey));
    await tester.pump();

    expect(find.byKey(panelKey), findsOneWidget);
    return tester.takeException();
  }

  testWidgets('Purchase Order collapses its real desktop filter panel',
      (tester) async {
    await verifyDesktopCollapse(
      tester,
      screen: const AddPurchaseOrderScreen(),
      toggleKey: const ValueKey('purchase-order-filter-toggle'),
      panelKey: const ValueKey('purchase-order-filters'),
      actionKey: const ValueKey('purchase-order-create-action'),
    );
  });

  testWidgets('Purchase Order starts with mobile filters collapsed',
      (tester) async {
    await verifyMobileStartsCollapsed(
      tester,
      screen: const AddPurchaseOrderScreen(),
      toggleKey: const ValueKey('purchase-order-filter-toggle'),
      panelKey: const ValueKey('purchase-order-filters'),
    );
  });

  testWidgets('Purchase Return collapses its real desktop filter panel',
      (tester) async {
    await verifyDesktopCollapse(
      tester,
      screen: const PurchaseReturnListPage(),
      toggleKey: const ValueKey('purchase-return-filter-toggle'),
      panelKey: const ValueKey('purchase-return-filters'),
      actionKey: const ValueKey('purchase-return-create-action'),
    );
  });

  testWidgets('Purchase Return starts with mobile filters collapsed',
      (tester) async {
    await verifyMobileStartsCollapsed(
      tester,
      screen: const PurchaseReturnListPage(),
      toggleKey: const ValueKey('purchase-return-filter-toggle'),
      panelKey: const ValueKey('purchase-return-filters'),
    );
  });

  testWidgets('purchase filters expand without overflow on a short phone',
      (tester) async {
    final failures = <String>[];
    final orderException = await verifyMobileExpansion(
      tester,
      screen: const AddPurchaseOrderScreen(),
      toggleKey: const ValueKey('purchase-order-filter-toggle'),
      panelKey: const ValueKey('purchase-order-filters'),
    );
    if (orderException != null) {
      failures.add('Purchase Order: $orderException');
    }

    final returnException = await verifyMobileExpansion(
      tester,
      screen: const PurchaseReturnListPage(),
      toggleKey: const ValueKey('purchase-return-filter-toggle'),
      panelKey: const ValueKey('purchase-return-filters'),
    );
    if (returnException != null) {
      failures.add('Purchase Return: $returnException');
    }

    expect(failures, isEmpty);
  });
}
