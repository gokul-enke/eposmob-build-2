import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/suppliers/domain/models/supplier.dart';
import 'package:pos_machine/features/suppliers/presentation/widgets/profile/orders/supplier_purchase_card.dart';
import 'package:pos_machine/features/suppliers/presentation/widgets/profile/orders/supplier_purchase_details_dialog.dart';
import 'package:pos_machine/features/suppliers/presentation/widgets/profile/supplier_orders_tab.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:provider/provider.dart';

import 'supplier_profile_test_helpers.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required Supplier supplier,
  bool allowed = true,
}) async {
  useSurfaceSize(tester, size);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<RoleProvider>(
          create: (_) => FakeRoleProvider(allowed: allowed),
        ),
        ChangeNotifierProvider<AppSettingsProvider>(
          create: (_) => FakeAppSettingsProvider(testAppSettings()),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SupplierOrdersTab(supplier: supplier),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('without permission shows the permission message',
      (tester) async {
    await _pump(
      tester,
      size: const Size(1280, 800),
      supplier: testSupplier(purchases: [testPurchase(1)]),
      allowed: false,
    );

    expect(
      find.text('Purchase permission is required to view orders.'),
      findsOneWidget,
    );
    expect(find.text('PO-1'), findsNothing);
  });

  testWidgets('empty supplier shows the empty state', (tester) async {
    await _pump(tester, size: const Size(1280, 800), supplier: testSupplier());

    expect(find.text('Purchase Orders (0)'), findsOneWidget);
    expect(find.text('No Purchase Orders Found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop: table, pagination and details dialog', (tester) async {
    final supplier = testSupplier(
      purchases: [for (var i = 1; i <= 21; i++) testPurchase(i)],
    );
    await _pump(tester, size: const Size(1280, 800), supplier: supplier);

    expect(find.text('Purchase Orders (21)'), findsOneWidget);
    expect(find.byType(AppDataTable<SupplierPurchase>), findsOneWidget);
    expect(find.text('Page 1 of 2'), findsOneWidget);
    expect(find.text('INR 100.00'), findsOneWidget);

    await tester.tap(find.text('PO-1'));
    await tester.pumpAndSettle();

    expect(find.byType(SupplierPurchaseDetails), findsOneWidget);
    expect(find.text('Widget 1 (x2)'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Tax'), findsOneWidget);
    expect(find.text('INR 5.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile: cards without overflow', (tester) async {
    final supplier = testSupplier(
      purchases: [testPurchase(1), testPurchase(2, status: 'n')],
    );
    await _pump(tester, size: const Size(375, 812), supplier: supplier);

    expect(find.byType(SupplierPurchaseCard), findsNWidgets(2));
    expect(find.text('Pending'), findsOneWidget);
    expect(find.byType(AppPaginationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
