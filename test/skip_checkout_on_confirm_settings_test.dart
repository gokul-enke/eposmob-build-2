import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';

import 'test_support/app_settings_fakes.dart';

void main() {
  test('plain confirm keeps checkout when settings are missing or not loaded',
      () {
    final provider = _UnloadedAppSettingsProvider();
    addTearDown(provider.dispose);

    expect(testAppSettings().skipCheckoutOnConfirm, isFalse);
    expect(AppSettings.fromJson({'data': []}).skipCheckoutOnConfirm, isFalse);
    expect(provider.skipCheckoutOnConfirm, isFalse);
  });

  for (final status in [true, 'true', '1', 1, false, 'false', '0', 0, null]) {
    test('parses and round-trips plain confirm status $status', () {
      final settings = AppSettings.fromJson({
        'data': [
          {'code': 'SKIP_CHECKOUT_ON_CONFIRM', 'status': status, 'value': ''},
        ],
      });
      final enabled = [true, 'true', '1', 1].contains(status);
      final provider = FakeAppSettingsProvider(settings);
      addTearDown(provider.dispose);

      expect(settings.skipCheckoutOnConfirm, enabled);
      expect(provider.skipCheckoutOnConfirm, enabled);
      expect(AppSettings.fromJson(settings.toJson()).skipCheckoutOnConfirm,
          enabled);
    });
  }

  for (final confirm in [false, true]) {
    for (final print in [false, true]) {
      test('confirm=$confirm and print=$print are independent', () {
        final settings = AppSettings.fromJson({
          'data': [
            {'code': 'SKIP_CHECKOUT_ON_CONFIRM', 'status': confirm},
            {'code': 'SKIP_CHECKOUT_ON_CONFIRM_AND_PRINT', 'status': print},
          ],
        });
        final restored = AppSettings.fromJson(settings.toJson());

        expect(restored.skipCheckoutOnConfirm, confirm);
        expect(restored.skipCheckoutOnConfirmAndPrint, print);
      });
    }
  }
}

class _UnloadedAppSettingsProvider extends AppSettingsProvider {
  @override
  Future<void> fetchAppSettings() async {}
}
