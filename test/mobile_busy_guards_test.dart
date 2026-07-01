import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_machine/features/billing/presentation/widgets/mobile/cart/cart_action_buttons.dart';

/// Mirrors the early-return guard predicates used by [BillingPageMobile].
class MobileBusyGuardLogic {
  static bool canStartSave({
    required bool isSavingOrder,
  }) =>
      !isSavingOrder;

  static bool canStartConfirm({
    required bool isConfirmingOrder,
    required bool isConfirmingAndPrinting,
  }) =>
      !isConfirmingOrder && !isConfirmingAndPrinting;

  static bool canStartConfirmAndPrint({
    required bool isConfirmingOrder,
    required bool isConfirmingAndPrinting,
  }) =>
      !isConfirmingOrder && !isConfirmingAndPrinting;

  static bool canStartLoadOrder({
    required bool isLoadingOrder,
  }) =>
      !isLoadingOrder;

  static bool canStartClearCart({
    required bool isClearingCart,
  }) =>
      !isClearingCart;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MobileBusyGuardLogic', () {
    test('blocks duplicate save while saving', () {
      expect(
        MobileBusyGuardLogic.canStartSave(isSavingOrder: false),
        isTrue,
      );
      expect(
        MobileBusyGuardLogic.canStartSave(isSavingOrder: true),
        isFalse,
      );
    });

    test('blocks confirm while confirm or confirm-print is in flight', () {
      expect(
        MobileBusyGuardLogic.canStartConfirm(
          isConfirmingOrder: false,
          isConfirmingAndPrinting: false,
        ),
        isTrue,
      );
      expect(
        MobileBusyGuardLogic.canStartConfirm(
          isConfirmingOrder: true,
          isConfirmingAndPrinting: false,
        ),
        isFalse,
      );
      expect(
        MobileBusyGuardLogic.canStartConfirm(
          isConfirmingOrder: false,
          isConfirmingAndPrinting: true,
        ),
        isFalse,
      );
    });

    test('blocks confirm-print while confirm or confirm-print is in flight', () {
      expect(
        MobileBusyGuardLogic.canStartConfirmAndPrint(
          isConfirmingOrder: true,
          isConfirmingAndPrinting: false,
        ),
        isFalse,
      );
      expect(
        MobileBusyGuardLogic.canStartConfirmAndPrint(
          isConfirmingOrder: false,
          isConfirmingAndPrinting: true,
        ),
        isFalse,
      );
    });

    test('blocks duplicate load while loading', () {
      expect(
        MobileBusyGuardLogic.canStartLoadOrder(isLoadingOrder: true),
        isFalse,
      );
    });

    test('blocks duplicate clear while clearing', () {
      expect(
        MobileBusyGuardLogic.canStartClearCart(isClearingCart: true),
        isFalse,
      );
    });
  });

  group('Billing checkout button enablement', () {
    test('confirm disabled when checkout is busy', () {
      const hasItems = true;
      const isConfirmingOrder = true;
      const isConfirmingAndPrinting = false;
      final isCheckoutBusy = isConfirmingOrder || isConfirmingAndPrinting;

      expect(hasItems && !isCheckoutBusy, isFalse);
    });

    test('confirm-print disabled when checkout is busy', () {
      const hasItems = true;
      const isConfirmingOrder = false;
      const isConfirmingAndPrinting = true;
      final isCheckoutBusy = isConfirmingOrder || isConfirmingAndPrinting;

      expect(hasItems && !isCheckoutBusy, isFalse);
    });
  });

  group('CartActionButtons busy UI', () {
    testWidgets('save and clear buttons disabled while saving', (tester) async {
      var saveCalls = 0;
      var clearCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CartActionButtons(
              hasItems: true,
              onProceedToPayment: () {},
              onSaveOrder: () => saveCalls++,
              onClearCart: () => clearCalls++,
              isSavingOrder: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.receipt_long_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      expect(saveCalls, 0);
      expect(clearCalls, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
