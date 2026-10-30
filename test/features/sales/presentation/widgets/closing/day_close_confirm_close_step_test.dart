import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close_summary.dart';
import 'package:pos_machine/features/sales/presentation/state/day_close_form_controller.dart';
import 'package:pos_machine/features/sales/presentation/state/day_close_form_ports.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/features/sales/presentation/widgets/closing/day_close_form/day_close_confirm_close_step_content.dart';
import 'package:pos_machine/features/sales/presentation/widgets/closing/day_close_form/day_close_form_inputs.dart';
import 'package:pos_machine/helpers/payment_method_display.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';

void main() {
  // The manager asked for the day's online payments next to the cash
  // summary when confirming the close, as the Day Close step shows them.
  Future<void> pumpStep(WidgetTester tester, DailySalesCloseSummary? summary) {
    final controller = DayCloseFormController(
        ports: DayCloseFormPorts(
            master: MasterDataProvider(),
            auth: AuthModel(),
            settings: AppSettingsProvider(),
            store: StoreSessionProvider(),
            sales: SalesProvider()),
        onCompleted: (_) {},
        onError: (_) {})
      ..summary = summary;
    addTearDown(controller.dispose);
    return tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DayCloseConfirmCloseStepContent('SAR',
                inputs: DayCloseFormInputs(
                    controller: controller,
                    currency: 'SAR',
                    onClose: () {})))));
  }

  Finder row(String label) =>
      find.ancestor(of: find.text(label.tr), matching: find.byType(Row));

  testWidgets('shows online sales under the cash summary', (tester) async {
    await pumpStep(
        tester,
        DailySalesCloseSummary(
            cashSales: '258.00', onlineSales: '949.00', openingCashInHand: 0));

    expect(find.text('daily_sales_close.cash_summary'.tr), findsOneWidget);
    // Real English text, so a missing translation key fails the test.
    expect(find.text('Online Summary'), findsOneWidget);
    expect(find.text('Online Sales'), findsOneWidget);
    expect(
        find.descendant(
            of: row('daily_sales_close.online_sales'),
            matching: find.text('SAR 949.00')),
        findsOneWidget);
    // The cash rows are unchanged.
    expect(
        find.descendant(
            of: row('daily_sales_close.today_cash_collection'),
            matching: find.text('SAR 258.00')),
        findsOneWidget);
    expect(
        tester.getTopLeft(find.text('daily_sales_close.online_summary'.tr)).dy,
        greaterThan(tester
            .getTopLeft(find.text('daily_sales_close.today_cash_collection'.tr))
            .dy));
  });

  // The manager's layout: Online payment 1000, then UPI 500, Online 500.
  testWidgets('lists each online method under the online total',
      (tester) async {
    await pumpStep(
        tester,
        DailySalesCloseSummary.fromJson({
          'cash_sales': '258.00',
          'online_sales': '1,000.00',
          'credit_amount': '50.00',
          'payment_method_breakdown': {
            'CASH': '258.00',
            'UPI': '500.00',
            'ONLINE': 500,
            'COD': '0.00',
            'CREDIT': '50.00',
          },
        }));

    expect(
        find.descendant(
            of: row('daily_sales_close.online_sales'),
            // Thousands grouped, as in the Day Close step.
            matching: find.text('SAR 1,000.00')),
        findsOneWidget);
    // Shown by name, never as the raw code (e.g. ONLINE).
    for (final name in ['UPI', 'Online']) {
      expect(
          find.descendant(
              of: find.ancestor(
                  of: find.text(name), matching: find.byType(Row)),
              matching: find.text('SAR 500.00')),
          findsOneWidget,
          reason: name);
    }
    expect(find.text('ONLINE'), findsNothing);
    // Cash, credit and zero amounts are not online methods here.
    for (final code in ['CASH', 'CREDIT', 'COD']) {
      expect(find.text(PaymentMethodDisplay.labelFor(code)), findsNothing,
          reason: code);
    }
    // In order, under the total.
    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('UPI'), greaterThan(top('Online Sales')));
    expect(top('Online'), greaterThan(top('UPI')));
  });

  testWidgets('no summary yet shows zero online sales', (tester) async {
    await pumpStep(tester, null);
    expect(
        find.descendant(
            of: row('daily_sales_close.online_sales'),
            matching: find.text('SAR 0.00')),
        findsOneWidget);
  });
}
