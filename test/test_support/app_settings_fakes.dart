import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';

AppSettings testAppSettings({
  String currency = 'INR',
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
    currency: currency,
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
    companyB2BEnabled: false,
    enableSendToKitchenButton: false,
    enableKotBillButton: false,
    kotBillAutoMarkServed: false,
    kotBillAllowedForDineIn: false,
    pineLabPayment: false,
  );
}

/// [AppSettingsProvider] that never hits the network.
class FakeAppSettingsProvider extends AppSettingsProvider {
  FakeAppSettingsProvider([AppSettings? settings])
      : _settings = settings ?? testAppSettings();

  final AppSettings _settings;

  @override
  Future<void> fetchAppSettings() async {}

  @override
  AppSettings? get appSettings => _settings;
}

/// Sets the test surface to [size] for the rest of the test.
void useSurfaceSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
