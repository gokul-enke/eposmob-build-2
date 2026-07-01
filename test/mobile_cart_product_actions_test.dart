import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/cart/cart_item_card.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAppSettingsProvider extends AppSettingsProvider {
  _FakeAppSettingsProvider(this.settings);

  final AppSettings settings;

  @override
  Future<void> fetchAppSettings() async {}

  @override
  AppSettings? get appSettings => settings;
}

class _FakeRoleProvider extends RoleProvider {
  _FakeRoleProvider({required this.canViewProductDetails});

  final bool canViewProductDetails;

  @override
  bool currentUserHasPermissionSync(String permission) {
    if (permission == 'billing.product.view') {
      return canViewProductDetails;
    }
    return false;
  }
}

AppSettings _buildAppSettings({required bool showCustomerLastBuyedPriceList}) {
  return AppSettings(
    barcodeSales: false,
    customerCarePhone: '',
    customerCareEmail: '',
    printTitle: '',
    showCustomerLastBuyedPriceList: showCustomerLastBuyedPriceList,
    askDeliveryDate: false,
    priceRoundOff: false,
    discountAndCoupon: false,
    autoAssignDefaultCustomer: false,
    autoAssignDefaultCustomerPhone: '',
    currency: 'SAR',
    zatcaPhase1Enabled: false,
    zatcaPhase2Enabled: false,
    showTaxPos: false,
    showMrpPos: false,
    showTaxRatePos: false,
    showConfirmOrderButton: true,
    enableKOTPrint: false,
    defaultDeliveryMethod: '',
    defaultPaymentMethod: '',
    posPrintDoubleBill: false,
    skipCustomerSelection: false,
    hideDefaultPhone: false,
    freeDeliveryEnabled: false,
    freeDeliveryMinimumAmount: '',
    itemCodeEnabled: false,
    companyB2BEnabled: false,
    enableSendToKitchenButton: false,
    enableKotBillButton: false,
    kotBillAutoMarkServed: false,
    kotBillAllowedForDineIn: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;
  const cartController = BillingMobileCartController();
  const settingsController = BillingMobileSettingsController();

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_mobile_cart_actions_');
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
    SharedPreferences.setMockInitialValues({'general_stock_enabled': false});
    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
  });

  tearDownAll(() async {
    try {
      await Hive.close().timeout(const Duration(seconds: 5));
    } catch (_) {}
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  GetProduct buildProduct() {
    return GetProduct(
      productId: 1,
      productName: 'Rice',
      unit: 'PCS',
      price: ProductPrice(price: '10'),
      mrp: '120',
      taxes: [ProductTax(rate: '5')],
    );
  }

  group('BillingMobileSettingsController.shouldShowPurchaseHistoryAction', () {
    test('shows when setting enabled and non-default customer selected', () {
      expect(
        settingsController.shouldShowPurchaseHistoryAction(
          appSettings: _buildAppSettings(showCustomerLastBuyedPriceList: true),
          hasSelectedCustomer: true,
          isDefaultCustomer: false,
        ),
        isTrue,
      );
    });

    test('hides when setting disabled', () {
      expect(
        settingsController.shouldShowPurchaseHistoryAction(
          appSettings: _buildAppSettings(showCustomerLastBuyedPriceList: false),
          hasSelectedCustomer: true,
          isDefaultCustomer: false,
        ),
        isFalse,
      );
    });

    test('hides for default customer even when setting enabled', () {
      expect(
        settingsController.shouldShowPurchaseHistoryAction(
          appSettings: _buildAppSettings(showCustomerLastBuyedPriceList: true),
          hasSelectedCustomer: true,
          isDefaultCustomer: true,
        ),
        isFalse,
      );
    });

    test('hides when no customer selected', () {
      expect(
        settingsController.shouldShowPurchaseHistoryAction(
          appSettings: _buildAppSettings(showCustomerLastBuyedPriceList: true),
          hasSelectedCustomer: false,
          isDefaultCustomer: false,
        ),
        isFalse,
      );
    });
  });

  group('RoleProvider billing.product.view gate', () {
    test('grants product details when permission is present', () {
      final provider = _FakeRoleProvider(canViewProductDetails: true);
      expect(provider.currentUserHasPermissionSync('billing.product.view'),
          isTrue);
    });

    test('denies product details when permission is absent', () {
      final provider = _FakeRoleProvider(canViewProductDetails: false);
      expect(provider.currentUserHasPermissionSync('billing.product.view'),
          isFalse);
    });
  });

  group('CartItemCard smoke', () {
    testWidgets('renders product details action when role permission granted',
        (tester) async {
      late LocalProductProvider provider;
      await tester.runAsync(() async {
        provider = LocalProductProvider();
        provider.setStockEnabled(false);
        provider.initializeProducts([buildProduct()]);
        provider.addToCart(
          product: buildProduct(),
          quantity: 1,
          price: 10,
          mrp: 12,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocalProductProvider>.value(value: provider),
            ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) => _FakeAppSettingsProvider(
                _buildAppSettings(showCustomerLastBuyedPriceList: false),
              ),
            ),
            ChangeNotifierProvider<RoleProvider>(
              create: (_) =>
                  _FakeRoleProvider(canViewProductDetails: true),
            ),
            ChangeNotifierProvider<CustomerSelectionProvider>(
              create: (_) => CustomerSelectionProvider(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CartItemCard(
                item: provider.cartItems.single,
                controller: cartController,
                onDecrease: () {},
                onIncrease: () {},
                onRemove: () {},
                onSaleUnitChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('cart_product_details_action')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('cart_purchase_history_action')),
          findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
