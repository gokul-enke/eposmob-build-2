import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/suppliers/domain/models/supplier.dart';
import 'package:pos_machine/features/suppliers/presentation/widgets/profile/supplier_transactions_tab.dart';
import 'package:pos_machine/features/suppliers/presentation/widgets/profile/transactions/supplier_transaction_card.dart';
import 'package:pos_machine/features/suppliers/presentation/widgets/profile/transactions/supplier_transaction_details_dialog.dart';
import 'package:pos_machine/features/suppliers/presentation/widgets/profile/transactions/supplier_transaction_report_launcher.dart';

import 'supplier_profile_test_helpers.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required Supplier supplier,
}) async {
  useSurfaceSize(tester, size);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SupplierTransactionsTab(supplier: supplier),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(AppToast.dismiss);

  testWidgets('empty supplier shows the no-data message', (tester) async {
    await _pump(tester, size: const Size(1280, 800), supplier: testSupplier());

    expect(find.text('Transactions (0)'), findsOneWidget);
    expect(find.text('No Transactions Found'), findsOneWidget);
    expect(
      find.text('Transaction data is not available for this supplier.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('printing without transactions shows an error', (tester) async {
    await _pump(tester, size: const Size(1280, 800), supplier: testSupplier());

    await tester.tap(find.byTooltip('Print transactions'));
    await tester.pump();

    expect(find.text('No transactions available to print'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('desktop: table with pagination and a details dialog',
      (tester) async {
    final supplier = testSupplier(
      transactions: [for (var i = 1; i <= 25; i++) testTransaction(i)],
    );
    await _pump(tester, size: const Size(1280, 800), supplier: supplier);

    expect(find.text('Transactions (25)'), findsOneWidget);
    expect(find.byType(AppDataTable<SupplierTransaction>), findsOneWidget);
    expect(find.byType(AppPaginationBar), findsOneWidget);
    expect(find.text('Page 1 of 2'), findsOneWidget);
    expect(find.text('REF-1'), findsOneWidget);

    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('Page 2 of 2'), findsOneWidget);
    expect(find.text('REF-21'), findsOneWidget);

    await tester.tap(find.text('REF-21'));
    await tester.pumpAndSettle();
    expect(find.byType(SupplierTransactionDetails), findsOneWidget);
    expect(find.text('Invoice'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile: cards without overflow', (tester) async {
    final supplier = testSupplier(
      transactions: [
        testTransaction(1),
        testTransaction(2, type: 'Debit'),
      ],
    );
    await _pump(tester, size: const Size(375, 812), supplier: supplier);

    expect(find.byType(SupplierTransactionCard), findsNWidgets(2));
    expect(find.byType(AppPaginationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter panel toggles and filters by reference', (tester) async {
    final supplier = testSupplier(
      transactions: [
        testTransaction(1, reference: 'INV-1'),
        testTransaction(2, reference: 'VCH-2'),
      ],
    );
    await _pump(tester, size: const Size(1280, 800), supplier: supplier);

    await tester.tap(find.byTooltip('Filter transactions'));
    await tester.pumpAndSettle();
    expect(find.text('Apply Filters'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'vch');
    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    expect(find.text('Transactions (1)'), findsOneWidget);
    expect(find.text('VCH-2'), findsOneWidget);
    expect(find.text('INV-1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('report data sums amounts and spans the dates', () {
    final data = SupplierTransactionReportData.build([
      testTransaction(1, date: '2026-03-04'),
      testTransaction(2, date: '2026-01-02'),
      testTransaction(3, date: ''),
    ]);

    expect(data.formattedTotal, '60.00');
    expect(data.fromDate, '2026-01-02');
    expect(data.toDate, '2026-03-04');
    expect(data.transactions, hasLength(3));
  });
}
