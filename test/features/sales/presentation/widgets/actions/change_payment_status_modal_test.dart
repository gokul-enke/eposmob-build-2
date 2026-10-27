import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/presentation/widgets/actions/change_payment_status_modal.dart';
import 'package:pos_machine/models/payment_method.dart';
import 'package:pos_machine/models/payment_method_registry.dart';

import 'order_payment_method_fakes.dart';

void main() {
  testWidgets('the order\'s own method is picked and its id is sent',
      (tester) async {
    final sent = <Object?>[];
    await openOrderModal(
      tester,
      FakePaymentMethods(),
      ChangePaymentStatusModal(
        currentPaymentStatus: 'pending',
        grandTotal: '215.000',
        paymentMethodCode: 'cash',
        onConfirm: (status, amount, method) =>
            sent.addAll([status, amount, method]),
      ),
    );

    expect(dropdownValue(tester, 1), '7974');
    await pickOption(tester, 0, 'Paid');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(sent, ['paid', 215.0, '7974']);
  });

  // The server fails any update sent without a method, Failed included, so
  // an order with no payment yet (nothing to preselect) must pick one.
  for (final status in ['Paid', 'Failed', 'Pending']) {
    testWidgets('$status cannot be saved without a payment method',
        (tester) async {
      final sent = <Object?>[];
      await openOrderModal(
        tester,
        FakePaymentMethods(),
        ChangePaymentStatusModal(
          currentPaymentStatus: 'pending',
          grandTotal: '215.000',
          onConfirm: (status, amount, method) =>
              sent.addAll([status, amount, method]),
        ),
      );

      expect(dropdownValue(tester, 1), isNull);
      if (status != 'Pending') await pickOption(tester, 0, status);
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(sent, isEmpty);
      expect(find.text('sales.select_payment_method'.tr), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await pickOption(tester, 1, 'CARD');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(sent,
          [status.toLowerCase(), status == 'Failed' ? null : 215.0, '7973']);
    });
  }

  // Failed records no money; the server rejects an amount sent with it.
  testWidgets('Failed hides the amount and sends none', (tester) async {
    final sent = <Object?>[];
    await openOrderModal(
      tester,
      FakePaymentMethods(),
      ChangePaymentStatusModal(
        currentPaymentStatus: 'pending',
        grandTotal: '247.000',
        paymentMethodCode: 'CASH',
        onConfirm: (status, amount, method) =>
            sent.addAll([status, amount, method]),
      ),
    );

    // A cleared amount must not block Failed, whose amount is hidden.
    await tester.enterText(find.byType(TextField), '');
    await pickOption(tester, 0, 'Failed');
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('sales.valid_amount_minimum_zero'.tr), findsNothing);
    expect(sent, ['failed', null, '7974']);
  });

  // The server rejects Paid without the full amount; 0 is caught in the form.
  testWidgets('Paid cannot be saved with amount 0; Pending can',
      (tester) async {
    final sent = <Object?>[];
    await openOrderModal(
      tester,
      FakePaymentMethods(),
      ChangePaymentStatusModal(
        currentPaymentStatus: 'pending',
        grandTotal: '247.000',
        paymentMethodCode: 'CASH',
        onConfirm: (status, amount, method) =>
            sent.addAll([status, amount, method]),
      ),
    );

    await pickOption(tester, 0, 'Paid');
    await tester.enterText(find.byType(TextField), '0.000');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(sent, isEmpty);
    expect(find.text('sales.paid_amount_above_zero'.tr), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await pickOption(tester, 0, 'Pending');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(sent, ['pending', 0.0, '7974']);
  });

  testWidgets('an order holding the method id gets that method picked',
      (tester) async {
    await openOrderModal(
      tester,
      FakePaymentMethods(),
      ChangePaymentStatusModal(
        currentPaymentStatus: 'pending',
        grandTotal: '215.000',
        paymentMethodCode: '7973',
        onConfirm: (_, __, ___) {},
      ),
    );

    expect(dropdownValue(tester, 1), '7973');
  });

  testWidgets('an order holding a translated label gets that method picked',
      (tester) async {
    // e.g. saved while the app ran in Arabic.
    PaymentMethodRegistry.update([
      PaymentMethod.fromJson({
        'id': '7974',
        'value': 'CASH',
        'description': 'Cash',
        'translations': {'ar': 'نقدي'},
      }),
    ]);
    addTearDown(PaymentMethodRegistry.clear);
    await openOrderModal(
      tester,
      FakePaymentMethods(),
      ChangePaymentStatusModal(
        currentPaymentStatus: 'pending',
        grandTotal: '215.000',
        paymentMethodCode: 'نقدي',
        onConfirm: (_, __, ___) {},
      ),
    );

    expect(dropdownValue(tester, 1), '7974');
  });

  testWidgets('methods not loaded yet are fetched, then the order\'s picked',
      (tester) async {
    final methods = FakePaymentMethods(loaded: false);
    await openOrderModal(
      tester,
      methods,
      ChangePaymentStatusModal(
        currentPaymentStatus: 'pending',
        grandTotal: '215.000',
        paymentMethodCode: 'CARD',
        onConfirm: (_, __, ___) {},
      ),
    );

    expect(methods.fetches, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(dropdownValue(tester, 1), '7973');
  });
}
