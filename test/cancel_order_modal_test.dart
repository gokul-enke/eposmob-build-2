import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/screens/sales/widgets/cancel_order_modal.dart';

void main() {
  testWidgets('unpaid COD cancellation does not request refund details',
      (tester) async {
    String? paymentMethod;
    String? refundAmount;
    bool? deliveryChargeRefundable;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: CancelOrderModal(
            isUnpaidCod: true,
            initialRefundAmount: '180.00',
            onConfirm: (method, amount, deliveryRefundable) {
              paymentMethod = method;
              refundAmount = amount;
              deliveryChargeRefundable = deliveryRefundable;
            },
          ),
        ),
      ),
    );

    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(Switch), findsNothing);
    final description = tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data == 'cancel_order_modal.unpaid_cod_description' ||
                widget.data?.contains('Cash on Delivery') == true),
      ),
    );
    expect(description.softWrap, isTrue);
    expect(description.style?.overflow, TextOverflow.visible);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(paymentMethod, isNull);
    expect(refundAmount, isNull);
    expect(deliveryChargeRefundable, isNull);
  });
}
