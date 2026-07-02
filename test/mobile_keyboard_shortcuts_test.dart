import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/features/billing/controllers/billing_mobile_controller.dart';
import 'package:pos_machine/providers/billing_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('BillingMobileController.resolveShortcutAction', () {
    test('maps F1-F2 and F6-F9 to desktop-aligned cart/order actions', () {
      expect(
        BillingMobileController.resolveShortcutAction(
          key: LogicalKeyboardKey.f1,
          controlPressed: false,
          barcodeSalesEnabled: true,
        ),
        MobileBillingShortcutAction.clearCart,
      );
      expect(
        BillingMobileController.resolveShortcutAction(
          key: LogicalKeyboardKey.f2,
          controlPressed: false,
          barcodeSalesEnabled: true,
        ),
        MobileBillingShortcutAction.confirmOrder,
      );
      expect(
        BillingMobileController.resolveShortcutAction(
          key: LogicalKeyboardKey.f6,
          controlPressed: false,
          barcodeSalesEnabled: true,
        ),
        MobileBillingShortcutAction.createOrderAndPrint,
      );
      expect(
        BillingMobileController.resolveShortcutAction(
          key: LogicalKeyboardKey.f7,
          controlPressed: false,
          barcodeSalesEnabled: true,
        ),
        MobileBillingShortcutAction.newOrder,
      );
      expect(
        BillingMobileController.resolveShortcutAction(
          key: LogicalKeyboardKey.f8,
          controlPressed: false,
          barcodeSalesEnabled: true,
        ),
        MobileBillingShortcutAction.saveOrder,
      );
      expect(
        BillingMobileController.resolveShortcutAction(
          key: LogicalKeyboardKey.f9,
          controlPressed: false,
          barcodeSalesEnabled: true,
        ),
        MobileBillingShortcutAction.saveOrderAndPrint,
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

    test('ignores desktop-only checkout-step and sidebar keys', () {
      for (final key in [
        LogicalKeyboardKey.f3,
        LogicalKeyboardKey.f4,
        LogicalKeyboardKey.f5,
        LogicalKeyboardKey.f10,
        LogicalKeyboardKey.f12,
      ]) {
        expect(
          BillingMobileController.resolveShortcutAction(
            key: key,
            controlPressed: false,
            barcodeSalesEnabled: true,
          ),
          isNull,
          reason: '${key.debugName} has no mobile equivalent',
        );
      }
    });
  });

  group('BillingProvider keyboard shortcut registration', () {
    test('registerDefaultKeyboardShortcuts dispatches all billing callbacks', () {
      final bp = BillingProvider();
      var cleared = false;
      var saved = false;
      var printed = false;
      var confirmed = false;
      var newOrder = false;
      var savedAndPrinted = false;

      bp.registerDefaultKeyboardShortcuts(
        onClearCart: () => cleared = true,
        onSaveOrder: () => saved = true,
        onCreateOrderAndPrint: () => printed = true,
        onConfirmOrder: () => confirmed = true,
        onNewOrder: () => newOrder = true,
        onSaveOrderAndPrint: () => savedAndPrinted = true,
      );

      bp.executeKeyboardShortcut('clearCart');
      bp.executeKeyboardShortcut('saveOrder');
      bp.executeKeyboardShortcut('createOrderAndPrint');
      bp.executeKeyboardShortcut('confirmOrder');
      bp.executeKeyboardShortcut('newOrder');
      bp.executeKeyboardShortcut('saveOrderAndPrint');

      expect(cleared, isTrue);
      expect(saved, isTrue);
      expect(printed, isTrue);
      expect(confirmed, isTrue);
      expect(newOrder, isTrue);
      expect(savedAndPrinted, isTrue);
    });
  });
}
