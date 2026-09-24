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

    test('defaults to FALSE when the setting is absent', () {
      final settings = AppSettings.fromJson(_settingsJson([
        {'code': 'BARCODE_SALES', 'value': '', 'status': 'true'},
      ]));
      // Fail closed: variants stay off unless the tenant explicitly enables
      // the PRODUCT_VARIANT_ENABLED setting.
      expect(settings.productVariantEnabled, isFalse);
    });

    test('default constructor value is FALSE', () {
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
      expect(settings.productVariantEnabled, isFalse);
    });
  });

  group('ALLOW_OVERSELL settings gate', () {
    test('defaults to TRUE when the setting is absent', () {
      final settings = AppSettings.fromJson(_settingsJson(const []));
      expect(settings.allowOverselling, isTrue);
    });

    test('parses explicit false as strict stock enforcement', () {
      final settings = AppSettings.fromJson(_settingsJson(const [
        {'code': 'ALLOW_OVERSELL', 'value': '', 'status': 'false'},
      ]));
      expect(settings.allowOverselling, isFalse);
    });

    test('serializes the setting for cached/debug representations', () {
      final settings = AppSettings.fromJson(_settingsJson(const []));
      final entries = settings.toJson()['data'] as List<dynamic>;
      final entry = entries.cast<Map<String, dynamic>>().firstWhere(
            (item) => item['code'] == 'ALLOW_OVERSELL',
          );
      expect(entry['status'], 'true');
    });
  });

  group('MULTI_SALE_UNIT_ENABLED settings gate', () {
    test('defaults to TRUE when the setting is absent', () {
      final settings = AppSettings.fromJson(_settingsJson(const []));
      expect(settings.multiSaleUnitEnabled, isTrue);
    });

    test('parses string, boolean, and numeric enabled statuses', () {
      for (final status in <dynamic>['true', true, 1]) {
        final settings = AppSettings.fromJson(_settingsJson([
          {
            'code': 'MULTI_SALE_UNIT_ENABLED',
            'value': '',
            'status': status,
          },
        ]));
        expect(settings.multiSaleUnitEnabled, isTrue, reason: '$status');
      }
    });

    test('parses an explicit disabled status', () {
      final settings = AppSettings.fromJson(_settingsJson(const [
        {
          'code': 'MULTI_SALE_UNIT_ENABLED',
          'value': '',
          'status': 'false',
        },
      ]));
      expect(settings.multiSaleUnitEnabled, isFalse);
    });

    test('serializes the setting for cached/debug representations', () {
      final settings = AppSettings.fromJson(_settingsJson(const []));
      final entries = settings.toJson()['data'] as List<dynamic>;
      final entry = entries.cast<Map<String, dynamic>>().firstWhere(
            (item) => item['code'] == 'MULTI_SALE_UNIT_ENABLED',
          );
      expect(entry['status'], 'true');
    });
  });
}
