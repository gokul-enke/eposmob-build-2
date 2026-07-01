import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/features/billing/controllers/billing_mobile_controller.dart';
import 'package:pos_machine/providers/billing_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('BillingMobileController.resolveShortcutAction', () {
    test('maps F6-F9 to cart/order actions', () {
      expect(
        BillingMobileController.resolveShortcutAction(
          key: LogicalKeyboardKey.f6,
          controlPressed: false,
          barcodeSalesEnabled: true,
        ),
        MobileBillingShortcutAction.clearCart,
      );
      expect(
        BillingMobileController.resolveShortcutAction(
          key: LogicalKeyboardKey.f7,
          controlPressed: false,
          barcodeSalesEnabled: true,
        ),
        MobileBillingShortcutAction.saveOrder,
      );
      expect(
        BillingMobileController.resolveShortcutAction(
          key: LogicalKeyboardKey.f8,
          controlPressed: false,
          barcodeSalesEnabled: true,
        ),
        MobileBillingShortcutAction.createOrderAndPrint,
      );
      expect(
        BillingMobileController.resolveShortcutAction(
          key: LogicalKeyboardKey.f9,
          controlPressed: false,
          barcodeSalesEnabled: true,
        ),
        MobileBillingShortcutAction.confirmOrder,
      );
    });

    test('Esc restores product-entry focus', () {
      expect(
        BillingMobileController.resolveShortcutAction(
          key: LogicalKeyboardKey.escape,
          controlPressed: false,
          barcodeSalesEnabled: false,
        ),
        MobileBillingShortcutAction.restoreFocus,
      );
    });

    test('Ctrl+A focuses barcode only when barcodeSales is enabled', () {
      expect(
        BillingMobileController.resolveShortcutAction(
          key: LogicalKeyboardKey.keyA,
          controlPressed: true,
          barcodeSalesEnabled: true,
        ),
        MobileBillingShortcutAction.focusBarcode,
      );
      expect(
        BillingMobileController.resolveShortcutAction(
          key: LogicalKeyboardKey.keyA,
          controlPressed: true,
          barcodeSalesEnabled: false,
        ),
        isNull,
      );
      expect(
        BillingMobileController.resolveShortcutAction(
          key: LogicalKeyboardKey.keyA,
          controlPressed: false,
          barcodeSalesEnabled: true,
        ),
        isNull,
      );
    });

    test('ignores unsupported keys', () {
      expect(
        BillingMobileController.resolveShortcutAction(
          key: LogicalKeyboardKey.f12,
          controlPressed: false,
          barcodeSalesEnabled: true,
        ),
        isNull,
      );
    });
  });

  group('BillingProvider keyboard shortcut registration', () {
    test('registerDefaultKeyboardShortcuts dispatches F6-F9 callbacks', () {
      final bp = BillingProvider();
      var cleared = false;
      var saved = false;
      var printed = false;
      var confirmed = false;

      bp.registerDefaultKeyboardShortcuts(
        onClearCart: () => cleared = true,
        onSaveOrder: () => saved = true,
        onCreateOrderAndPrint: () => printed = true,
        onConfirmOrder: () => confirmed = true,
      );

      bp.executeKeyboardShortcut('clearCart');
      bp.executeKeyboardShortcut('saveOrder');
      bp.executeKeyboardShortcut('createOrderAndPrint');
      bp.executeKeyboardShortcut('confirmOrder');

      expect(cleared, isTrue);
      expect(saved, isTrue);
      expect(printed, isTrue);
      expect(confirmed, isTrue);
    });
  });
}
