import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/providers/billing_provider.dart';

void main() {
  const controller = BillingMobileConnectivityController();

  group('BillingMobileConnectivityController', () {
    test('canSaveOrderOffline is always true', () {
      expect(controller.canSaveOrderOffline(), isTrue);
    });

    test('canConfirmOnline follows BillingProvider.hasInternet', () async {
      SharedPreferences.setMockInitialValues({});
      final bp = BillingProvider();

      expect(bp.hasInternet, isTrue);
      expect(controller.canConfirmOnline(bp), isTrue);
      expect(controller.shouldBlockOnlineCheckout(bp), isFalse);

      await bp.setManualOfflineMode(true);

      expect(bp.hasInternet, isFalse);
      expect(controller.canConfirmOnline(bp), isFalse);
      expect(controller.shouldBlockOnlineCheckout(bp), isTrue);

      await bp.setManualOfflineMode(false);

      expect(bp.hasInternet, isTrue);
      expect(controller.canConfirmOnline(bp), isTrue);
    });

    test('offline messages guide user to save locally', () {
      expect(
        BillingMobileConnectivityController.offlineConfirmMessage,
        contains('Save the order locally'),
      );
      expect(
        BillingMobileConnectivityController.offlineConfirmPrintMessage,
        contains('Save the order locally'),
      );
    });
  });

  group('BillingProvider.hasInternet', () {
    test('manual offline mode disables hasInternet', () async {
      SharedPreferences.setMockInitialValues({});
      final bp = BillingProvider();

      expect(bp.isManualOfflineMode, isFalse);
      expect(bp.hasInternet, isTrue);

      await bp.setManualOfflineMode(true);

      expect(bp.isManualOfflineMode, isTrue);
      expect(bp.hasInternet, isFalse);
    });
  });
}
