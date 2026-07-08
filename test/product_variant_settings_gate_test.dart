import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/get_app_settings.dart';

Map<String, dynamic> _settingsJson(List<Map<String, dynamic>> entries) => {
      'data': entries,
    };

void main() {
  group('PRODUCT_VARIANT_ENABLED settings gate', () {
    test('parses status "1" as enabled', () {
      final settings = AppSettings.fromJson(_settingsJson([
        {'code': 'PRODUCT_VARIANT_ENABLED', 'value': '', 'status': '1'},
      ]));
      expect(settings.productVariantEnabled, isTrue);
    });

    test('parses status "true" as enabled', () {
      final settings = AppSettings.fromJson(_settingsJson([
        {'code': 'PRODUCT_VARIANT_ENABLED', 'value': '', 'status': 'true'},
      ]));
      expect(settings.productVariantEnabled, isTrue);
    });

    test('parses status "0" as disabled', () {
      final settings = AppSettings.fromJson(_settingsJson([
        {'code': 'PRODUCT_VARIANT_ENABLED', 'value': '', 'status': '0'},
      ]));
      expect(settings.productVariantEnabled, isFalse);
    });

    test('parses status "false" as disabled', () {
      final settings = AppSettings.fromJson(_settingsJson([
        {'code': 'PRODUCT_VARIANT_ENABLED', 'value': '', 'status': 'false'},
      ]));
      expect(settings.productVariantEnabled, isFalse);
    });

    test('defaults to TRUE when the setting is absent', () {
      final settings = AppSettings.fromJson(_settingsJson([
        {'code': 'BARCODE_SALES', 'value': '', 'status': 'true'},
      ]));
      // Absent setting must NOT silently disable existing variant behavior.
      expect(settings.productVariantEnabled, isTrue);
    });

    test('default constructor value is TRUE', () {
      final settings = AppSettings(
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
        currency: '',
        workingTime: '',
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
        enableSendToKitchenButton: true,
        enableKotBillButton: false,
        kotBillAutoMarkServed: false,
        kotBillAllowedForDineIn: false,
      );
      expect(settings.productVariantEnabled, isTrue);
    });
  });
}
