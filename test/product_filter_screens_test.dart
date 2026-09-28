import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/providers/stock_provider.dart';
import 'package:pos_machine/screens/product/add_product.dart';
import 'package:pos_machine/screens/product/product_barcode.dart';
import 'package:pos_machine/screens/product/stock.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support/hive_test_teardown.dart';

class _FakeAppSettingsProvider extends AppSettingsProvider {
  @override
  Future<void> fetchAppSettings() async {}
}

class _FakeCategoryProvider extends CategoryProvider {
  @override
  bool get isCategoriesLoaded => true;

  @override
  Future<void> ensureCategoriesLoaded() async {}
}

class _FakeStockProvider extends StockProvider {
  @override
  Future<void> loadAllStocks(String accessToken) async {}
}

class _FakePurchaseProvider extends PurchaseProvider {
  @override
  Future<void> listAllStores(String accessToken, String? storeName) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    Get.testMode = true;
    hiveDir = await Directory.systemTemp.createTemp('product_filter_screens_');
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
      'api_key': 'test-api-key',
      'general_stock_enabled': true,
    });
    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
  });

  tearDown(() async {
    Get.reset();
    await awaitPendingHiveBoxWrites();
  });
  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

  Widget wrapScreen(
    Widget screen, {
    LocalProductProvider? localProductProvider,
    double? contentWidth,
  }) {
    final auth = AuthModel()..login('test-token', 1);
    final content = contentWidth == null
        ? screen
        : Align(
            alignment: AlignmentDirectional.topStart,
            child: SizedBox(width: contentWidth, child: screen),
          );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthModel>.value(value: auth),
        ChangeNotifierProvider<AppSettingsProvider>(
          create: (_) => _FakeAppSettingsProvider(),
        ),
        ChangeNotifierProvider<CategoryProvider>(
          create: (_) => _FakeCategoryProvider(),
        ),
        ChangeNotifierProvider<LocalProductProvider>.value(
          value: localProductProvider ?? LocalProductProvider(),
        ),
        ChangeNotifierProvider<StockProvider>(
          create: (_) => _FakeStockProvider(),
        ),
        ChangeNotifierProvider<PurchaseProvider>(
          create: (_) => _FakePurchaseProvider(),
        ),
        ChangeNotifierProvider<RoleProvider>(create: (_) => RoleProvider()),
      ],
      child: GetMaterialApp(home: Scaffold(body: content)),
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    required Size size,
    LocalProductProvider? localProductProvider,
    double? contentWidth,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapScreen(
        screen,
        localProductProvider: localProductProvider,
        contentWidth: contentWidth,
      ),
    );
    await tester.pump();
  }

  Future<void> verifyDesktopCollapse(
    WidgetTester tester, {
    required Widget screen,
    required Key toggleKey,
    required Key panelKey,
  }) async {
    await pumpScreen(tester, screen, size: const Size(1200, 900));

    expect(find.byKey(toggleKey), findsOneWidget);
    expect(find.byKey(panelKey), findsOneWidget);

    await tester.tap(find.byKey(toggleKey));
    await tester.pump();

    expect(find.byKey(panelKey), findsNothing);
    expect(find.byKey(toggleKey), findsOneWidget);
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

  testWidgets('Product List collapses its real desktop filter panel',
      (tester) async {
    await verifyDesktopCollapse(
      tester,
      screen: const AddProductScreen(),
      toggleKey: const ValueKey('product-filter-toggle'),
      panelKey: const ValueKey('product-desktop-filters'),
    );
  });

  testWidgets('Product List starts with mobile filters collapsed',
      (tester) async {
    await verifyMobileStartsCollapsed(
      tester,
      screen: const AddProductScreen(),
      toggleKey: const ValueKey('product-filter-toggle'),
      panelKey: const ValueKey('product-mobile-filters'),
    );
  });

  testWidgets('Product Stock collapses its real desktop filter panel',
      (tester) async {
    await verifyDesktopCollapse(
      tester,
      screen: const AddStockScreen(),
      toggleKey: const ValueKey('stock-filter-toggle'),
      panelKey: const ValueKey('stock-desktop-filters'),
    );
  });

  testWidgets('Product Stock starts with mobile filters collapsed',
      (tester) async {
    await verifyMobileStartsCollapsed(
      tester,
      screen: const AddStockScreen(),
      toggleKey: const ValueKey('stock-filter-toggle'),
      panelKey: const ValueKey('stock-mobile-filters'),
    );
  });

  testWidgets('Product Barcode collapses its real desktop filter panel',
      (tester) async {
    await verifyDesktopCollapse(
      tester,
      screen: const ProductBarcodeScreen(),
      toggleKey: const ValueKey('product-barcode-filter-toggle'),
      panelKey: const ValueKey('product-barcode-desktop-filters'),
    );
  });

  testWidgets('Product Barcode starts with mobile filters collapsed',
      (tester) async {
    await verifyMobileStartsCollapsed(
      tester,
      screen: const ProductBarcodeScreen(),
      toggleKey: const ValueKey('product-barcode-filter-toggle'),
      panelKey: const ValueKey('product-barcode-mobile-filters'),
    );
  });

  testWidgets('Product Barcode selected actions do not overflow on tablet',
      (tester) async {
    final productProvider = LocalProductProvider()
      ..initializeProducts([
        GetProduct(
          productId: 1,
          productName: 'Test Product',
          barcode: 'TEST-001',
        ),
      ]);

    await pumpScreen(
      tester,
      const ProductBarcodeScreen(),
      size: const Size(650, 800),
      contentWidth: 500,
      localProductProvider: productProvider,
    );
    await tester.pump();

    expect(find.byType(Checkbox), findsWidgets);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
