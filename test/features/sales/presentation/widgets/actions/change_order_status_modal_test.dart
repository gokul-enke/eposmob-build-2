import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/presentation/widgets/actions/change_order_status_modal.dart';

import 'order_payment_method_fakes.dart';

void main() {
  testWidgets('cancelling loads the refund methods and sends the picked id',
      (tester) async {
    final methods = FakePaymentMethods(loaded: false);
    String? status;
    String? refundMethod;
    double? refunded;
    await openOrderModal(
      tester,
      methods,
      ChangeOrderStatusModal(
        currentStatus: 'new',
        orderTotal: '215.000',
        onConfirm: ({
          required newStatus,
          refundAmount,
          paymentMethod,
          deliveryChargeRefundable,
          deliveryLogistics,
        }) {
          status = newStatus;
          refundMethod = paymentMethod;
          refunded = refundAmount;
        },
      ),
    );

    // Not fetched until the refund method is asked for.
    expect(methods.fetches, 0);
    await pickOption(tester, 0, 'Cancelled');
    expect(methods.fetches, 1);
    expect(dropdownValue(tester, 1), isNull);

    await pickOption(tester, 1, 'CASH');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(status, 'cancelled');
    expect(refundMethod, '7974');
    expect(refunded, 0);
  });

  testWidgets('a cancellation still needs a refund method', (tester) async {
    var confirmed = false;
    await openOrderModal(
      tester,
      FakePaymentMethods(),
      ChangeOrderStatusModal(
        currentStatus: 'cancelled',
        orderTotal: '215.000',
        onConfirm: ({
          required newStatus,
          refundAmount,
          paymentMethod,
          deliveryChargeRefundable,
          deliveryLogistics,
        }) =>
            confirmed = true,
      ),
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(confirmed, isFalse);
    expect(find.text('sales.select_refund_payment_method'.tr), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
