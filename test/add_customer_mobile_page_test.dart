/// Widget tests for [AddCustomerMobilePage] — verifies full field parity layout
/// at phone width without RenderFlex overflow.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/add_customer_mobile_page.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/location_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/providers/store_session_provider.dart';

AppSettings _minimalAppSettings({bool companyB2BEnabled = false}) {
  return AppSettings(
    barcodeSales: false,
    customerCarePhone: '',
    customerCareEmail: '',
    printTitle: '',
    showCustomerLastBuyedPriceList: false,
    askDeliveryDate: false,
    priceRoundOff: false,
    discountAndCoupon: false,
    autoAssignDefaultCustomer: false,
    autoAssignDefaultCustomerPhone: '',
    currency: 'INR',
    workingTime: '',
    zatcaPhase1Enabled: false,
    zatcaPhase2Enabled: false,
    showTaxPos: false,
    showMrpPos: false,
    showTaxRatePos: false,
    showConfirmOrderButton: false,
    enableKOTPrint: false,
    defaultDeliveryMethod: '',
    defaultPaymentMethod: '',
    posPrintDoubleBill: false,
    skipCustomerSelection: false,
    hideDefaultPhone: false,
    freeDeliveryEnabled: false,
    freeDeliveryMinimumAmount: '0',
    itemCodeEnabled: false,
    companyB2BEnabled: companyB2BEnabled,
    enableSendToKitchenButton: false,
    enableKotBillButton: false,
    kotBillAutoMarkServed: false,
    kotBillAllowedForDineIn: false,
    pineLabPayment: false,
  );
}

class _FakeAppSettingsProvider extends AppSettingsProvider {
  _FakeAppSettingsProvider(this._settings);

  final AppSettings _settings;

  @override
  Future<void> fetchAppSettings() async {}

  @override
  AppSettings? get appSettings => _settings;
}

class _FakeLocationProvider extends LocationProvider {
  @override
  Future<void> listAllStates(String accessToken) async {}
}

class _FakeSharedPreferenceProvider extends SharedPreferenceProvider {
  @override
  Future<String?> getCountryName() async => 'India';

  @override
  Future<int?> getActiveStoreId() async => null;
}

class _FakePurchaseProvider extends PurchaseProvider {}

Widget _wrap(Widget child, {bool companyB2BEnabled = false}) {
  final auth = AuthModel()..login('test-token', 1);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthModel>.value(value: auth),
      ChangeNotifierProvider<AppSettingsProvider>(
        create: (_) =>
            _FakeAppSettingsProvider(_minimalAppSettings(companyB2BEnabled: companyB2BEnabled)),
      ),
      ChangeNotifierProvider<LocationProvider>(
        create: (_) => _FakeLocationProvider(),
      ),
      ChangeNotifierProvider<PurchaseProvider>(
        create: (_) => _FakePurchaseProvider(),
      ),
      ChangeNotifierProvider<SharedPreferenceProvider>(
        create: (_) => _FakeSharedPreferenceProvider(),
      ),
      ChangeNotifierProvider<StoreSessionProvider>(
        create: (_) => StoreSessionProvider(),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final overflowErrors = <FlutterErrorDetails>[];
  FlutterExceptionHandler? originalOnError;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    overflowErrors.clear();
    originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        overflowErrors.add(details);
      } else {
        FlutterError.presentError(details);
      }
    };
  });

  tearDown(() {
    FlutterError.onError = originalOnError;
  });

  group('AddCustomerMobilePage', () {
    testWidgets('renders all standard fields at 360dp without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(const AddCustomerMobilePage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add New Customer'), findsOneWidget);
      expect(find.textContaining('First Name'), findsOneWidget);
      expect(find.textContaining('Last Name'), findsOneWidget);
      expect(find.textContaining('Email Address'), findsOneWidget);
      expect(find.textContaining('Phone Number'), findsOneWidget);
      expect(find.textContaining('Building / Apartment'), findsOneWidget);
      expect(find.textContaining('Country'), findsOneWidget);
      expect(find.textContaining('States / Provinces'), findsOneWidget);
      expect(find.textContaining('District / City'), findsOneWidget);
      expect(find.textContaining('Pincode'), findsOneWidget);
      expect(find.textContaining('Gender'), findsOneWidget);
      expect(find.textContaining('Date of Birth'), findsOneWidget);
      expect(find.textContaining('Alternate Phone'), findsOneWidget);
      expect(find.textContaining('Balance'), findsOneWidget);
      expect(find.textContaining('Payment Type'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      expect(overflowErrors, isEmpty,
          reason: 'form must not overflow at 360dp width');
    });

    testWidgets('scrolls on 360x800 viewport without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(const AddCustomerMobilePage()),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.drag(scrollable, const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(overflowErrors, isEmpty,
          reason: 'scrolled form must not overflow at 360x800');
    });

    testWidgets('shows B2B fields when companyB2BEnabled', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(
          const AddCustomerMobilePage(),
          companyB2BEnabled: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Customer Type'), findsOneWidget);
      expect(find.textContaining('CR Number'), findsOneWidget);
      expect(find.textContaining('VAT Number'), findsOneWidget);
      expect(find.text('B2C'), findsOneWidget);
      expect(find.text('B2B'), findsOneWidget);

      expect(overflowErrors, isEmpty,
          reason: 'B2B section must not overflow at 360dp width');
    });
  });
}
