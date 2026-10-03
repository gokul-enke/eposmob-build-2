import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/customers/presentation/widgets/profile/customer_loyalty_tab.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:provider/provider.dart';

import 'profile_test_helpers.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    CustomerListModelData customer, {
    Size size = const Size(900, 900),
  }) async {
    useSurfaceSize(tester, size);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppSettingsProvider>(
        create: (_) =>
            FakeAppSettingsProvider(testAppSettings(currency: 'SAR')),
        child: MaterialApp(
          home: Scaffold(body: CustomerLoyaltyTab(customer: customer)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the card and points details', (tester) async {
    await pump(tester, testCustomer());

    expect(find.text('EPOS Loyalty'), findsOneWidget);
    expect(find.text('Gold'), findsOneWidget);
    expect(find.text('Asha Menon'), findsOneWidget);
    expect(find.text('LC-0042'), findsOneWidget);
    expect(find.text('320'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('SAR0.25'), findsOneWidget);
    expect(find.text('2026-01-01'), findsOneWidget);
    expect(find.text('--'), findsOneWidget); // valid until
  });

  testWidgets('falls back for missing card data', (tester) async {
    await pump(tester, CustomerListModelData(id: 1));

    expect(find.text('customer_loyalty.tier_default'.tr), findsOneWidget);
    expect(find.text('Customer Name'), findsOneWidget);
    expect(find.text('Not available'), findsOneWidget);
    expect(find.text('SAR0.00'), findsOneWidget);
  });

  testWidgets('fits a phone without overflow', (tester) async {
    await pump(tester, testCustomer(), size: const Size(343, 520));
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
