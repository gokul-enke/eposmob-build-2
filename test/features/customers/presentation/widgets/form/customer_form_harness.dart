/// Provider setup shared by the customer form widget tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/customers/data/customer_payloads.dart';
import 'package:pos_machine/features/customers/data/customer_repository.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/location_provider.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:provider/provider.dart';

AppSettings minimalAppSettings({
  bool companyB2BEnabled = false,
  bool zatcaPhase1Enabled = false,
}) {
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
    zatcaPhase1Enabled: zatcaPhase1Enabled,
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

class FakeAppSettingsProvider extends AppSettingsProvider {
  FakeAppSettingsProvider(this._settings);

  final AppSettings _settings;

  @override
  Future<void> fetchAppSettings() async {}

  @override
  AppSettings? get appSettings => _settings;
}

class FakeLocationProvider extends LocationProvider {
  @override
  Future<void> listAllStates(String accessToken) async {}
}

class FakeSharedPreferenceProvider extends SharedPreferenceProvider {
  @override
  Future<String?> getCountryName() async => 'India';

  @override
  Future<int?> getActiveStoreId() async => null;
}

/// Records create / update calls instead of sending them.
class RecordingCustomerRepository extends CustomerRepository {
  CustomerFields? createdFields;
  String? createdStoreId;
  CustomerFields? updatedFields;
  int? updatedId;

  @override
  Future<CustomerListResult> list(
          String accessToken, CustomerQuery query) async =>
      const CustomerListFailed('offline');

  @override
  Future<dynamic> create(
    String accessToken,
    CustomerFields fields, {
    required String storeId,
  }) async {
    createdFields = fields;
    createdStoreId = storeId;
    return {'status': 'success', 'message': 'Customer created'};
  }

  @override
  Future<dynamic> update(
    String accessToken,
    int customerId,
    CustomerFields fields, {
    int? storeId,
  }) async {
    updatedId = customerId;
    updatedFields = fields;
    return {'status': 'success', 'message': 'Customer updated'};
  }
}

/// Wraps [child] in the providers the customer form reads.
Widget wrapCustomerForm(
  Widget child, {
  bool companyB2BEnabled = false,
  bool zatcaPhase1Enabled = false,
  CustomerRepository? repository,
}) {
  final auth = AuthModel()..login('test-token', 1);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthModel>.value(value: auth),
      ChangeNotifierProvider<AppSettingsProvider>(
        create: (_) => FakeAppSettingsProvider(
          minimalAppSettings(
            companyB2BEnabled: companyB2BEnabled,
            zatcaPhase1Enabled: zatcaPhase1Enabled,
          ),
        ),
      ),
      ChangeNotifierProvider<LocationProvider>(
        create: (_) => FakeLocationProvider(),
      ),
      ChangeNotifierProvider<PurchaseProvider>(
        create: (_) => PurchaseProvider(),
      ),
      ChangeNotifierProvider<SharedPreferenceProvider>(
        create: (_) => FakeSharedPreferenceProvider(),
      ),
      ChangeNotifierProvider<StoreSessionProvider>(
        create: (_) => StoreSessionProvider(),
      ),
      ChangeNotifierProvider<CustomerProvider>(
        create: (_) => CustomerProvider(
          repository: repository ?? RecordingCustomerRepository(),
        ),
      ),
    ],
    child: GetMaterialApp(
      locale: const Locale('en'),
      home: child,
    ),
  );
}

/// Call inside a test. Collects "RenderFlex overflowed" errors; other errors are reported.
List<FlutterErrorDetails> captureOverflowErrors() {
  final overflows = <FlutterErrorDetails>[];
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
      overflows.add(details);
    } else {
      original?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = original);
  return overflows;
}
