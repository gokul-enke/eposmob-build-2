import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/mobile_product_details_sheet.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/language_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/product_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRoleProvider extends RoleProvider {
  @override
  bool currentUserHasPermissionSync(String permission) {
    return permission == 'billing.product.edit';
  }
}

class _FakeLanguageProvider extends LanguageProvider {
  @override
  Future<void> fetchLanguages({required String accessToken}) async {}
}

class _FakeCategoryProvider extends CategoryProvider {
  @override
  Future<void> ensureCategoriesLoaded() async {}
}

class _FakePurchaseProvider extends PurchaseProvider {
  @override
  Map<String, String>? get getUnitList => const {'1': 'Each'};

  @override
  Map<String, String>? get getMasterDataValues => const {'1': 'Rack A'};

  @override
  Future<void> listAllUnits(String accessToken) async {}

  @override
  Future<void> listMasterDataValues(String accessToken, String code) async {}
}

class _FakeAppSettingsProvider extends AppSettingsProvider {
  @override
  Future<void> fetchAppSettings() async {}
}

Widget _wrapWithProviders(Widget child) {
  final auth = AuthModel()..login('test-token', 1);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthModel>.value(value: auth),
      ChangeNotifierProvider<RoleProvider>(create: (_) => _FakeRoleProvider()),
      ChangeNotifierProvider<CategoryProvider>(
        create: (_) => _FakeCategoryProvider(),
      ),
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => _FakeLanguageProvider(),
      ),
      ChangeNotifierProvider<PurchaseProvider>(
        create: (_) => _FakePurchaseProvider(),
      ),
      ChangeNotifierProvider<LocalProductProvider>(
        create: (_) => LocalProductProvider(),
      ),
      ChangeNotifierProvider<AppSettingsProvider>(
        create: (_) => _FakeAppSettingsProvider(),
      ),
      ChangeNotifierProvider<ProductProvider>(
        create: (_) => ProductProvider(),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir =
        await Directory.systemTemp.createTemp('epos_mobile_product_details_');
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
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  testWidgets('Edit tab sticky footer lays out without infinite width errors',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));

    final product = GetProduct(
      productId: 1,
      productName: 'Test Product',
      productSlug: 'test-product',
      barcode: '123456',
    );

    await tester.pumpWidget(
      _wrapWithProviders(
        Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showMobileProductDetailsSheet(
                      context: context,
                      product: product,
                      useBillingProductPermissions: true,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('View'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}
