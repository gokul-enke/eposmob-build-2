import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/mobile_product_details_sheet.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/language_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/product_provider.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_provider.dart';
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
  _FakeCategoryProvider() {
    categoryList = [Category(categoryId: 5, categoryName: 'Snacks')];
  }

  @override
  Future<void> ensureCategoriesLoaded() async {}
}

/// Answers the SKU generator without the network; skips startup loads.
class _FakeGridSelectionProvider extends GridSelectionProvider {
  int skuRequests = 0;

  @override
  Future<void> listAllProducts(
      {int? categoryId,
      String? filterName,
      String? filterCategory,
      String? filterBarcode,
      String? filterPrice,
      String? filterCreatedBy,
      String? filterProperties,
      String? filterStore,
      String? filterSupplier,
      int page = 1}) async {}

  @override
  Future<void> listAllProductsAPI({int? categoryId, String? barCode}) async {}

  @override
  Future<String?> generateSku({required String accessToken}) async {
    skuRequests++;
    return '4227';
  }
}

/// Records what a save sends and answers like the server, echoing the SKU.
class _FakeProductProvider extends ProductProvider {
  final List<String?> sentSkus = [];

  @override
  Future<Map<String, dynamic>> editProduct({
    required int productId,
    required String name,
    required String slug,
    required String barcode,
    required String unit,
    String? unitId,
    double? price,
    double? mrp,
    double? purchasePrice,
    int? categoryId,
    int? rackNumber,
    List<Map<String, dynamic>>? productNames,
    List<Map<String, dynamic>>? variants,
    List<Map<String, dynamic>>? saleUnits,
    String? minMarginPercentage,
    String? minMarginPrice,
    String? sku,
    required String accessToken,
  }) async {
    sentSkus.add(sku);
    return {
      'message': 'Product updated',
      'data': {
        'product_id': productId,
        'product_name': name,
        'product_slug': slug,
        'barcode': barcode,
        'category_id': categoryId,
        if (sku != null) 'sku': sku.isEmpty ? null : sku,
      },
    };
  }
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

Widget _wrapWithProviders(
  Widget child, {
  GridSelectionProvider? grid,
  ProductProvider? productProvider,
  LocalProductProvider? localProducts,
}) {
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
        create: (_) => localProducts ?? LocalProductProvider(),
      ),
      ChangeNotifierProvider<AppSettingsProvider>(
        create: (_) => _FakeAppSettingsProvider(),
      ),
      ChangeNotifierProvider<ProductProvider>(
        create: (_) => productProvider ?? ProductProvider(),
      ),
      ChangeNotifierProvider<GridSelectionProvider>(
        create: (_) => grid ?? _FakeGridSelectionProvider(),
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

  group('SKU', () {
    final generateSku =
        find.byKey(const ValueKey('mobile-product-details-generate-sku'));
    Finder skuField() => find.byWidgetPredicate((widget) =>
        widget is TextField &&
        widget.decoration?.labelText == 'product_detail.sku'.tr);

    GetProduct productWithSku(String? sku) => GetProduct(
          productId: 1,
          productName: 'Test Product',
          productSlug: 'test-product',
          barcode: '123456',
          categoryId: 5,
          unit: 'Each',
          sku: sku,
        );

    Future<void> openEditTab(
      WidgetTester tester,
      GetProduct product, {
      GridSelectionProvider? grid,
      ProductProvider? productProvider,
      LocalProductProvider? localProducts,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        _wrapWithProviders(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showMobileProductDetailsSheet(
                    context: context,
                    product: product,
                    useBillingProductPermissions: true,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
          grid: grid,
          productProvider: productProvider,
          localProducts: localProducts,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(skuField(), 200,
          scrollable: find
              .descendant(
                  of: find.byType(Form), matching: find.byType(Scrollable))
              .first);
      await tester.pumpAndSettle();
    }

    String skuText(WidgetTester tester) =>
        tester.widget<TextField>(skuField()).controller!.text;

    testWidgets('View tab shows the SKU', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        _wrapWithProviders(
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showMobileProductDetailsSheet(
                  context: context,
                  product: productWithSku('SKU-7'),
                  useBillingProductPermissions: true,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('SKU-7'), 200,
          scrollable: find.byType(Scrollable).last);

      expect(find.text('SKU-7'), findsOneWidget);
    });

    testWidgets('a set SKU is prefilled and offers no generate button',
        (tester) async {
      await openEditTab(tester, productWithSku('SKU-7'));

      expect(skuText(tester), 'SKU-7');
      expect(generateSku, findsNothing);
    });

    testWidgets('generate fills an empty SKU and then hides the button',
        (tester) async {
      final grid = _FakeGridSelectionProvider();
      await openEditTab(tester, productWithSku(null), grid: grid);

      expect(generateSku, findsOneWidget);
      await tester.tap(generateSku);
      await tester.pumpAndSettle();

      expect(grid.skuRequests, 1);
      expect(skuText(tester), '4227');
      expect(generateSku, findsNothing);
    });

    testWidgets('save sends a changed SKU and keeps it in the local catalog',
        (tester) async {
      final productProvider = _FakeProductProvider();
      final localProducts = LocalProductProvider();
      await openEditTab(tester, productWithSku('SKU-7'),
          productProvider: productProvider, localProducts: localProducts);

      await tester.enterText(skuField(), ' SKU-8 ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(productProvider.sentSkus, ['SKU-8']);
      final saved =
          localProducts.products.firstWhere((p) => p.productId == 1);
      expect(saved.sku, 'SKU-8');
    });

    testWidgets('save leaves an unchanged SKU out of the request',
        (tester) async {
      final productProvider = _FakeProductProvider();
      final localProducts = LocalProductProvider();
      await openEditTab(tester, productWithSku('SKU-7'),
          productProvider: productProvider, localProducts: localProducts);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(productProvider.sentSkus, [null]);
      final saved =
          localProducts.products.firstWhere((p) => p.productId == 1);
      expect(saved.sku, 'SKU-7');
    });
  });
}
