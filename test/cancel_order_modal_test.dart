import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/screens/sales/widgets/cancel_order_modal.dart';
import 'package:provider/provider.dart';

class _PaymentMethodsProvider extends MasterDataProvider {
  @override
  List<MasterDataValue> get paymentMethods => [
        MasterDataValue(id: 1, value: 'CASH', description: 'Cash'),
      ];
}

void main() {
  setUp(() {
    Get.addTranslations({
      'en_US': {
        'cancel_order_modal.title': 'Cancel Order',
        'cancel_order_modal.original_total': 'Original total: @amount',
      },
    });
  });
  tearDown(Get.clearTranslations);

  testWidgets('rounded full refund is displayed and accepted', (tester) async {
    String? submittedAmount;
    await tester.pumpWidget(
      ChangeNotifierProvider<MasterDataProvider>(
        create: (_) => _PaymentMethodsProvider(),
        child: GetMaterialApp(
          locale: const Locale('en', 'US'),
          home: Scaffold(
            body: CancelOrderModal(
              initialRefundAmount: '4.1899999999999995',
              onConfirm: (_, amount, __) => submittedAmount = amount,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '4.190');
    expect(find.text('Original total: 4.190'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CASH').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(submittedAmount, '4.1899999999999995');
  });

  for (final original in ['4.1896', '4.1904']) {
    testWidgets('display rounding preserves original refund $original',
        (tester) async {
      String? submittedAmount;
      await tester.pumpWidget(
        ChangeNotifierProvider<MasterDataProvider>(
          create: (_) => _PaymentMethodsProvider(),
          child: GetMaterialApp(
            locale: const Locale('en', 'US'),
            home: Scaffold(
              body: CancelOrderModal(
                initialRefundAmount: original,
                onConfirm: (_, amount, __) => submittedAmount = amount,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '4.190');
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CASH').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(submittedAmount, original);
    });
  }

  testWidgets('edited refund cannot exceed the unrounded total', (tester) async {
    String? submittedAmount;
    await tester.pumpWidget(
      ChangeNotifierProvider<MasterDataProvider>(
        create: (_) => _PaymentMethodsProvider(),
        child: GetMaterialApp(
          locale: const Locale('en', 'US'),
          home: Scaffold(
            body: CancelOrderModal(
              initialRefundAmount: '4.1896',
              onConfirm: (_, amount, __) => submittedAmount = amount,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CASH').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4.191');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(submittedAmount, isNull);
    expect(find.byType(CancelOrderModal), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '4.189');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(submittedAmount, '4.189');
  });

  testWidgets('restoring displayed full total preserves original refund',
      (tester) async {
    String? submittedAmount;
    await tester.pumpWidget(
      ChangeNotifierProvider<MasterDataProvider>(
        create: (_) => _PaymentMethodsProvider(),
        child: GetMaterialApp(
          locale: const Locale('en', 'US'),
          home: Scaffold(
            body: CancelOrderModal(
              initialRefundAmount: '4.1899999999999995',
              onConfirm: (_, amount, __) => submittedAmount = amount,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CASH').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4.000');
    await tester.enterText(find.byType(TextField), '4.190');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(submittedAmount, '4.1899999999999995');
  });

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
