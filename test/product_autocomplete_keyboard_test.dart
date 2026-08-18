import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/general_settings_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/widgets/product_autocomplete_list.dart';
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

class _TestGeneralSettingsProvider extends GeneralSettingsProvider {
  @override
  Future<void> fetchGeneralSettings() async {}
}

GetProduct _product(int id, String name) => GetProduct(
      productId: id,
      productName: name,
      sellable: true,
      price: ProductPrice(price: '10'),
      mrp: '10',
      unit: 'PCS',
      stock: const <Stock>[],
      taxes: const <ProductTax>[],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_autocomplete_keys_');
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

  testWidgets('Arrow Down then Enter adds only the highlighted product once',
      (tester) async {
    final products = <GetProduct>[
      _product(1, 'Auto Racing Car'),
      _product(2, 'aaa'),
      _product(3, 'Abu Jabal'),
    ];
    final localProducts = LocalProductProvider();
    for (final product in products) {
      localProducts.addProduct(product);
    }
    final selectedProductIds = <int?>[];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSettingsProvider>(
            create: (_) => _TestAppSettingsProvider(),
          ),
          ChangeNotifierProvider<CustomerSelectionProvider>(
            create: (_) => CustomerSelectionProvider(),
          ),
          ChangeNotifierProvider<GeneralSettingsProvider>(
            create: (_) => _TestGeneralSettingsProvider(),
          ),
          ChangeNotifierProvider<KeyboardProvider>(
            create: (_) => KeyboardProvider(),
          ),
          ChangeNotifierProvider<LocalProductProvider>.value(
            value: localProducts,
          ),
          ChangeNotifierProvider<MasterDataProvider>(
            create: (_) => MasterDataProvider(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: ProductAutocomplete(
                size: const Size(600, 400),
                productList: products,
                onSelected: (product, _) {
                  selectedProductIds.add(product.productId);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'a');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    // Desktop sends a raw Enter event and the focused text input submits it.
    // Reproduce both halves so a second raw-key selection path is caught.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(selectedProductIds, [2]);
    expect(localProducts.cartItems, hasLength(1));
    expect(localProducts.cartItems.single.product.productId, 2);
    expect(localProducts.cartItems.single.quantity, 1);

    // Let the add-to-cart success snackbar timer finish before test teardown.
    await tester.pump(const Duration(seconds: 3));
  });
}
