/// Mobile product autocomplete must search [sellableProducts] only (desktop parity).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/market_home_widget.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/widgets/product_autocomplete_list_mobile.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support/hive_test_teardown.dart';

class _TestAppSettingsProvider extends AppSettingsProvider {
  @override
  AppSettings? get appSettings => AppSettings.fromJson({
        'data': [
          {'code': 'ITEM_CODE_ENABLED', 'status': 'false', 'value': 'false'},
        ],
      });

  @override
  Future<void> fetchAppSettings() async {}
}

GetProduct _namedProduct({
  required int id,
  required String name,
  bool sellable = true,
}) {
  return GetProduct(
    productId: id,
    productName: name,
    sellable: sellable,
    price: ProductPrice(price: '10'),
    unit: 'PCS',
    stock: const <Stock>[],
    taxes: const <ProductTax>[],
  );
}

Widget _wrap({
  required List<GetProduct> sellableList,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppSettingsProvider>(
        create: (_) => _TestAppSettingsProvider(),
      ),
      ChangeNotifierProvider<CustomerSelectionProvider>(
        create: (_) => CustomerSelectionProvider(),
      ),
      ChangeNotifierProvider<KeyboardProvider>(
        create: (_) => KeyboardProvider(),
      ),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_autocomplete_sellable_');
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

  group('MobileProductAutocomplete sellable parity', () {
    test('LocalProductProvider.sellableProducts excludes non-sellable catalog rows',
        () {
      final provider = LocalProductProvider();
      provider.addProduct(_namedProduct(id: 1, name: 'Retail Item'));
      provider.addProduct(
        _namedProduct(id: 2, name: 'Wholesale Only', sellable: false),
      );

      expect(provider.products, hasLength(2));
      expect(provider.sellableProducts.map((p) => p.productId), [1]);
      expect(
        provider.sellableProducts.any((p) => p.productName == 'Wholesale Only'),
        isFalse,
      );
    });

    testWidgets('suggestions come only from productList (sellable), not all products',
        (tester) async {
      final sellable = _namedProduct(id: 1, name: 'Sellable Tea');
      final nonSellable =
          _namedProduct(id: 2, name: 'Hidden Wholesale', sellable: false);

      await tester.pumpWidget(
        _wrap(
          sellableList: [sellable],
          child: SizedBox(
            width: 400,
            height: 200,
            child: MobileProductAutocomplete(
              size: const Size(400, 200),
              productList: [sellable],
              onSelected: (_, __) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hidden');
      await tester.pump();

      expect(find.text('Hidden Wholesale'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Sellable');
      await tester.pump();

      expect(find.text('Sellable Tea'), findsOneWidget);

      // Guard: non-sellable product exists in fixture but is excluded from list.
      expect(nonSellable.sellable, isFalse);
    });

    testWidgets('prefix matches rank before contains matches', (tester) async {
      final products = [
        _namedProduct(id: 1, name: 'Sweet Tea'),
        _namedProduct(id: 2, name: 'Tea Premium'),
        _namedProduct(id: 3, name: 'Teapot'),
      ];

      await tester.pumpWidget(
        _wrap(
          sellableList: products,
          child: SizedBox(
            width: 400,
            height: 400,
            child: MobileProductAutocomplete(
              size: const Size(400, 400),
              productList: products,
              onSelected: (_, __) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Tea');
      await tester.pump();

      final optionFinder = find.byType(ListTile);
      expect(optionFinder, findsNWidgets(3));
      expect(
        tester.widget<ListTile>(optionFinder.at(0)).title,
        isA<Text>().having((t) => t.data, 'data', 'Tea Premium'),
      );
      expect(
        tester.widget<ListTile>(optionFinder.at(1)).title,
        isA<Text>().having((t) => t.data, 'data', 'Teapot'),
      );
      expect(
        tester.widget<ListTile>(optionFinder.at(2)).title,
        isA<Text>().having((t) => t.data, 'data', 'Sweet Tea'),
      );
    });
  });

  group('filterMarketHomeProducts item-code grid search', () {
    const controller = BillingMobileMarketController();

    test('matches item code when itemCodeEnabled is true', () {
      final products = [
        GetProduct(
          productId: 1,
          productName: 'Mystery Box',
          itemCode: 'SKU-42',
          price: ProductPrice(price: '10'),
        ),
        GetProduct(
          productId: 2,
          productName: 'Other Item',
          itemCode: 'SKU-99',
          price: ProductPrice(price: '10'),
        ),
      ];

      final result = filterMarketHomeProducts(
        controller: controller,
        products: products,
        query: 'sku-42',
        selectedCategory: BillingMobileMarketController.allProductsCategory,
        itemCodeEnabled: true,
      );

      expect(result.map((p) => p.productId), [1]);
    });

    test('ignores item code when itemCodeEnabled is false', () {
      final products = [
        GetProduct(
          productId: 1,
          productName: 'Mystery Box',
          itemCode: 'SKU-42',
          price: ProductPrice(price: '10'),
        ),
      ];

      final result = filterMarketHomeProducts(
        controller: controller,
        products: products,
        query: 'sku-42',
        selectedCategory: BillingMobileMarketController.allProductsCategory,
        itemCodeEnabled: false,
      );

      expect(result, isEmpty);
    });
  });
}
