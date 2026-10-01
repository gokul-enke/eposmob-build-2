import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/suppliers/presentation/pages/supplier_profile_page.dart';
import 'package:pos_machine/features/suppliers/presentation/state/supplier_profile_tab.dart';
import 'package:pos_machine/features/suppliers/presentation/state/supplier_provider.dart';
import 'package:pos_machine/features/suppliers/presentation/widgets/profile/supplier_address_tab.dart';
import 'package:pos_machine/features/suppliers/presentation/widgets/profile/supplier_info_tab.dart';
import 'package:pos_machine/features/suppliers/presentation/widgets/profile/supplier_orders_tab.dart';
import 'package:pos_machine/features/suppliers/presentation/widgets/profile/supplier_transactions_tab.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:provider/provider.dart';

import '../widgets/profile/supplier_profile_test_helpers.dart';

void main() {
  Future<SupplierProvider> pump(
    WidgetTester tester, {
    required Size size,
    bool select = true,
  }) async {
    useSurfaceSize(tester, size);
    final suppliers = SupplierProvider();
    if (select) {
      suppliers.selectSupplier(
        testSupplier(
          transactions: [testTransaction(1)],
          purchases: [testPurchase(1)],
        ),
      );
    }
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SupplierProvider>.value(value: suppliers),
          ChangeNotifierProvider<RoleProvider>(
            create: (_) => FakeRoleProvider(),
          ),
          ChangeNotifierProvider<AppSettingsProvider>(
            create: (_) => FakeAppSettingsProvider(testAppSettings()),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SupplierProfilePage())),
      ),
    );
    await tester.pump();
    return suppliers;
  }

  SupplierProfileTab selectedTab(WidgetTester tester) => tester
      .widget<DetailPageScaffold<SupplierProfileTab>>(
        find.byType(DetailPageScaffold<SupplierProfileTab>),
      )
      .selectedTab;

  Future<void> tapTab(WidgetTester tester, String label) async {
    final tab = find.text(label).first;
    await tester.ensureVisible(tab);
    await tester.pumpAndSettle();
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  testWidgets('without a selected supplier shows a message', (tester) async {
    await pump(tester, size: const Size(1280, 800), select: false);

    expect(find.text('No supplier selected.'), findsOneWidget);
    expect(find.byType(DetailPageScaffold<SupplierProfileTab>), findsNothing);
  });

  testWidgets('picks up a supplier selected later', (tester) async {
    final suppliers =
        await pump(tester, size: const Size(1280, 800), select: false);

    suppliers.selectSupplier(testSupplier(name: 'Ravi Stores'));
    await tester.pump();

    expect(find.byType(SupplierInfoTab), findsOneWidget);
    expect(find.text('Ravi Stores'), findsWidgets);
  });

  for (final (label, size) in [
    ('mobile', const Size(375, 812)),
    ('desktop', const Size(1280, 800)),
  ]) {
    final mobile = size.width < DetailLayoutBreakpoints.mobileBelow;
    final addressLabel = mobile ? 'Address' : 'Supplier Address';

    testWidgets('$label: header, summary and all tabs in order',
        (tester) async {
      await pump(tester, size: size);

      expect(find.text('Supplier Profile'), findsOneWidget);
      expect(find.text('All Suppliers'), findsOneWidget);
      expect(find.text('ID: 7'), findsWidgets);
      expect(selectedTab(tester), SupplierProfileTab.info);

      final tabs = tester
          .widget<DetailPageScaffold<SupplierProfileTab>>(
            find.byType(DetailPageScaffold<SupplierProfileTab>),
          )
          .tabs;
      expect(tabs.map((t) => t.id), SupplierProfileTab.values);
      expect(tabs.last.label, addressLabel);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$label: tabs switch the content without overflow',
        (tester) async {
      await pump(tester, size: size);

      await tapTab(tester, 'Transactions');
      expect(selectedTab(tester), SupplierProfileTab.transactions);
      expect(find.byType(SupplierTransactionsTab), findsOneWidget);
      expect(find.text('REF-1'), findsOneWidget);

      await tapTab(tester, 'All Orders');
      expect(selectedTab(tester), SupplierProfileTab.orders);
      expect(find.byType(SupplierOrdersTab), findsOneWidget);
      expect(find.text('Purchase Orders (1)'), findsOneWidget);

      await tapTab(tester, addressLabel);
      expect(selectedTab(tester), SupplierProfileTab.address);
      expect(find.byType(SupplierAddressTab), findsOneWidget);

      await tapTab(tester, 'Information');
      expect(selectedTab(tester), SupplierProfileTab.info);
      expect(find.byType(SupplierInfoTab), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$label: the View Orders quick action opens the orders tab',
        (tester) async {
      await pump(tester, size: size);

      final orders = find.text('View Orders');
      await tester.ensureVisible(orders);
      await tester.pumpAndSettle();
      await tester.tap(orders);
      await tester.pumpAndSettle();

      expect(selectedTab(tester), SupplierProfileTab.orders);
      expect(find.byType(SupplierOrdersTab), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
