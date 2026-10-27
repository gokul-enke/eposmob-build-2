import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/features/sales/presentation/commands/detail/change_detail_payment_status.dart';
import 'package:pos_machine/features/sales/presentation/commands/sales_order_payment.dart';
import 'package:pos_machine/features/sales/presentation/sharing/sales_page_services.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_order_detail_controller.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/features/sales/presentation/widgets/actions/change_payment_status_modal.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:provider/provider.dart';

import '../widgets/actions/order_payment_method_fakes.dart';

/// Opens Update Payment Status the way the screens do: from the list's
/// More actions sheet, or from the order details button.
Future<void> _open(WidgetTester tester, String paymentStatus,
    {required bool fromList}) async {
  final order = ListOrderModelData(
      id: 7026,
      grantTotal: '247.000',
      paymentStatus: paymentStatus,
      paymentMethods: ['CASH']);
  final details = SalesOrderDetailController(fetch: () async => {})
    ..data = OrderDetailsModelData.fromJson({
      'orders_id': 7026,
      'payment_status': paymentStatus,
      'payment_details': {
        'payment_method': ['CASH']
      },
    });
  addTearDown(details.dispose);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthModel()),
      ChangeNotifierProvider(create: (_) => SalesProvider()),
      ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
      ChangeNotifierProvider(create: (_) => StoreSessionProvider()),
      ChangeNotifierProvider<MasterDataProvider>(
          create: (_) => FakePaymentMethods()),
    ],
    child: GetMaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => fromList
                ? showModalBottomSheet<void>(
                    context: context,
                    builder: (sheet) => TextButton(
                      onPressed: () => paymentSalesOrder(
                          context,
                          sheet,
                          SalesPageServices.capture(context),
                          order,
                          () async {}),
                      child: const Text('update payment'),
                    ),
                  )
                : changeDetailPaymentStatus(
                    context, details, SalesPageServices.capture(context)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  if (fromList) {
    await tester.tap(find.text('update payment'));
    await tester.pumpAndSettle();
  }
}

void main() {
  for (final fromList in [true, false]) {
    final from = fromList ? 'list' : 'details';

    // A paid order takes no more payment updates (the server rejects them),
    // so the app says "already paid" without opening the form.
    testWidgets('$from: a paid order says already paid, no form',
        (tester) async {
      await _open(tester, ' PAID ', fromList: fromList);

      expect(find.byType(ChangePaymentStatusModal), findsNothing);
      expect(find.text('sales.payment_already_paid'.tr), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('$from: a pending order opens the form', (tester) async {
      await _open(tester, 'pending', fromList: fromList);

      expect(find.byType(ChangePaymentStatusModal), findsOneWidget);
      expect(find.text('sales.payment_already_paid'.tr), findsNothing);
    });
  }
}
