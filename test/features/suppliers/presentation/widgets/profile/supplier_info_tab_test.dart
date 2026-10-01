import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/suppliers/domain/models/supplier.dart';
import 'package:pos_machine/features/suppliers/presentation/widgets/profile/supplier_address_tab.dart';
import 'package:pos_machine/features/suppliers/presentation/widgets/profile/supplier_info_tab.dart';

import 'supplier_profile_test_helpers.dart';

void main() {
  late List<String> calls;

  Future<void> pump(
    WidgetTester tester,
    Supplier supplier, {
    Size size = const Size(1280, 800),
  }) async {
    useSurfaceSize(tester, size);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupplierInfoTab(
            supplier: supplier,
            onEdit: () => calls.add('edit'),
            onViewOrders: () => calls.add('orders'),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() => calls = []);

  testWidgets('shows contact, account, address and KYC fields', (tester) async {
    await pump(tester, testSupplier());

    expect(find.text('Acme Traders'), findsOneWidget);
    expect(find.text('ID: 7'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('acme@example.com'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('TAX-1'), findsOneWidget);
    expect(find.text('-250.50'), findsOneWidget);
    expect(find.text('To Pay'), findsOneWidget);
    expect(find.text('Payable'), findsOneWidget);
    expect(find.text('Hardware'), findsOneWidget);
    expect(find.text('12 Market Road'), findsOneWidget);
    // Blank alt phone and no KYC entries.
    expect(find.text('Not provided'), findsNWidgets(2));
    expect(find.text('KYC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lists KYC entries by key', (tester) async {
    await pump(
      tester,
      testSupplier(
        kyc: const [
          SupplierKyc(key: 'CR Number', value: 'CR-55'),
          SupplierKyc(key: 'VAT', value: ''),
        ],
      ),
    );

    expect(find.text('CR Number'), findsOneWidget);
    expect(find.text('CR-55'), findsOneWidget);
    expect(find.text('VAT'), findsOneWidget);
    expect(find.text('Not provided'), findsNWidgets(2));
  });

  testWidgets('blank name falls back to the placeholder', (tester) async {
    await pump(tester, testSupplier(name: '', email: ''));

    expect(find.text('Supplier Name'), findsOneWidget);
    expect(find.text('Not provided'), findsNWidgets(3));
  });

  for (final size in const [Size(375, 812), Size(1280, 800)]) {
    testWidgets('quick actions call back at ${size.width}', (tester) async {
      await pump(tester, testSupplier(), size: size);

      for (final label in ['Edit Supplier', 'View Orders']) {
        final action = find.text(label);
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        await tester.tap(action);
      }

      expect(calls, ['edit', 'orders']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('address tab shows address, phone and email', (tester) async {
    useSurfaceSize(tester, const Size(375, 812));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SupplierAddressTab(supplier: testSupplier())),
      ),
    );

    expect(find.text('Address Information'), findsOneWidget);
    expect(find.text('Supplier: Acme Traders'), findsOneWidget);
    expect(find.text('Business'), findsOneWidget);
    expect(find.text('Address Details'), findsOneWidget);
    expect(find.text('12 Market Road'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('acme@example.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
