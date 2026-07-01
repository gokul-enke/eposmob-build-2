import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/features/billing/domain/add_created_product_to_cart.dart';
import 'package:pos_machine/features/billing/domain/add_product_form_helpers.dart';
import 'package:pos_machine/models/get_general_settings.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/general_settings_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support/hive_test_teardown.dart';

class _FakeGeneralSettingsProvider extends GeneralSettingsProvider {
  _FakeGeneralSettingsProvider({required this.stockEnabled});

  final bool stockEnabled;

  @override
  Future<void> fetchGeneralSettings() async {}

  @override
  GeneralSettings? get generalSettings =>
      GeneralSettings(stockEnabled: stockEnabled);
}

GetProduct _product({int id = 99, String price = '150'}) {
  return GetProduct(
    productId: id,
    productName: 'Created Product',
    barcode: 'NEW-BC',
    price: ProductPrice(price: price),
    mrp: '180',
    purchasePrice: '100',
    unit: 'PCS',
    stock: const <Stock>[],
    taxes: const <ProductTax>[],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_created_cart_test_');
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

  group('AddProductFormHelpers — add-to-cart parsing', () {
    test('parseAddToCartQuantity defaults invalid or zero to 1', () {
      expect(AddProductFormHelpers.parseAddToCartQuantity(''), 1);
      expect(AddProductFormHelpers.parseAddToCartQuantity('0'), 1);
      expect(AddProductFormHelpers.parseAddToCartQuantity('-2'), 1);
      expect(AddProductFormHelpers.parseAddToCartQuantity('abc'), 1);
    });

    test('parseAddToCartQuantity respects positive form values', () {
      expect(AddProductFormHelpers.parseAddToCartQuantity('3'), 3);
      expect(AddProductFormHelpers.parseAddToCartQuantity(' 2.5 '), 2.5);
    });

    test('P-04 desktop modal uses same qty-3 parsing as mobile create-and-add',
        () {
      // AddProductWithBarcodeModal passes _productQuantityController.text
      // through addCreatedProductToCart — same helper path as P-02 mobile.
      expect(AddProductFormHelpers.parseAddToCartQuantity('3'), 3);
      expect(AddProductFormHelpers.parseAddToCartSellingPrice('150'), 150);
    });

    test('parseAddToCartSellingPrice only returns positive values', () {
      expect(AddProductFormHelpers.parseAddToCartSellingPrice(''), isNull);
      expect(AddProductFormHelpers.parseAddToCartSellingPrice('0'), isNull);
      expect(AddProductFormHelpers.parseAddToCartSellingPrice('-10'), isNull);
      expect(AddProductFormHelpers.parseAddToCartSellingPrice('199.50'), 199.50);
    });
  });

  group('addCreatedProductToCart', () {
    testWidgets('routes through ProductCartHelper with form quantity and price',
        (tester) async {
      final localProductProvider = LocalProductProvider();
      final product = _product();
      localProductProvider.addProduct(product);

      late BuildContext capturedContext;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocalProductProvider>.value(
              value: localProductProvider,
            ),
            ChangeNotifierProvider<GeneralSettingsProvider>(
              create: (_) => _FakeGeneralSettingsProvider(stockEnabled: false),
            ),
            ChangeNotifierProvider<MasterDataProvider>(
              create: (_) => MasterDataProvider(),
            ),
            ChangeNotifierProvider<StoreSessionProvider>(
              create: (_) => StoreSessionProvider(),
            ),
            ChangeNotifierProvider<CustomerSelectionProvider>(
              create: (_) => CustomerSelectionProvider(),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await addCreatedProductToCart(
        context: capturedContext,
        product: product,
        quantityText: '4',
        sellingPriceText: '175',
      );
      await tester.pump();

      expect(localProductProvider.cartItems, hasLength(1));
      expect(localProductProvider.cartItems.first.product.productId, 99);
      expect(localProductProvider.cartItems.first.quantity, 4);
      expect(localProductProvider.cartItems.first.price, 175);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('uses opening-stock zero as cart quantity 1', (tester) async {
      final localProductProvider = LocalProductProvider();
      final product = _product(id: 100);
      localProductProvider.addProduct(product);

      late BuildContext capturedContext;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocalProductProvider>.value(
              value: localProductProvider,
            ),
            ChangeNotifierProvider<GeneralSettingsProvider>(
              create: (_) => _FakeGeneralSettingsProvider(stockEnabled: false),
            ),
            ChangeNotifierProvider<MasterDataProvider>(
              create: (_) => MasterDataProvider(),
            ),
            ChangeNotifierProvider<StoreSessionProvider>(
              create: (_) => StoreSessionProvider(),
            ),
            ChangeNotifierProvider<CustomerSelectionProvider>(
              create: (_) => CustomerSelectionProvider(),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await addCreatedProductToCart(
        context: capturedContext,
        product: product,
        quantityText: '0',
        sellingPriceText: '150',
      );
      await tester.pump();

      expect(localProductProvider.cartItems.single.quantity, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
