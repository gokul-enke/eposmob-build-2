import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/customers/presentation/widgets/profile/customer_info_tab.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:provider/provider.dart';

import 'profile_test_helpers.dart';

void main() {
  late List<String> calls;

  Future<void> pump(
    WidgetTester tester,
    CustomerListModelData customer, {
    bool zatca = false,
    Size size = const Size(1280, 800),
  }) async {
    useSurfaceSize(tester, size);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppSettingsProvider>(
        key: UniqueKey(),
        create: (_) => FakeAppSettingsProvider(
          testAppSettings(zatcaPhase1Enabled: zatca),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: CustomerInfoTab(
              customer: customer,
              onEdit: () => calls.add('edit'),
              onViewOrders: () => calls.add('orders'),
              onMessage: () => calls.add('message'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() => calls = []);

  testWidgets('shows name, contact, balance, payment and type', (tester) async {
    await pump(tester, testCustomer());

    expect(find.text('Asha Menon'), findsOneWidget);
    expect(find.text('asha@example.com'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('-125.50'), findsOneWidget);
    expect(find.text('B2B'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('To Pay'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(find.text('9/3/2025'), findsOneWidget);
    // Alt phone is missing.
    expect(find.text('Not provided'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick actions fire their callbacks', (tester) async {
    await pump(tester, testCustomer());

    for (final label in ['Edit Customer', 'View Orders', 'Message']) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
    }
    expect(calls, ['edit', 'orders', 'message']);
  });

  testWidgets('KYC shows only with ZATCA phase 1', (tester) async {
    final customer = testCustomer(
      kyc: [Kyc(key: 'National ID', value: 'X123', expiryDate: '2030-01-01')],
    );

    await pump(tester, customer);
    expect(find.text('KYC Information'), findsNothing);

    await pump(tester, customer, zatca: true);
    expect(find.text('KYC Information'), findsOneWidget);
    expect(find.text('X123'), findsOneWidget);
    expect(find.text('Expires: 2030-01-01'), findsOneWidget);
  });

  testWidgets('recent transactions show the newest three and a remainder',
      (tester) async {
    final transactions = [
      for (var i = 1; i <= 5; i++)
        CustomerTransaction(
          transactionType: 'Payment $i',
          type: i.isEven ? 'Credit' : 'Debit',
          amount: '$i.00',
          referenceId: 'R$i',
        ),
    ];
    await pump(tester, testCustomer(transactions: transactions));
    await tester.ensureVisible(find.text('Payment 3'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'customer_profile.view_transactions_count'.trParams({'count': '5'}),
      ),
      findsOneWidget,
    );
    expect(find.text('Payment 5'), findsOneWidget);
    expect(find.text('Payment 4'), findsOneWidget);
    expect(find.text('Payment 2'), findsNothing);
    expect(find.text('+4.00 INR'), findsOneWidget);
    expect(find.text('-5.00 INR'), findsOneWidget);
    expect(
      find.text(
        'customer_profile.view_more_transactions_count'
            .trParams({'count': '2'}),
      ),
      findsOneWidget,
    );
  });

  testWidgets('fits a phone without overflow', (tester) async {
    await pump(
      tester,
      testCustomer(name: 'A very long customer name that keeps going on'),
      size: const Size(343, 520),
    );
    await tester.scrollUntilVisible(find.text('Message'), 200);
    expect(tester.takeException(), isNull);
  });
}
