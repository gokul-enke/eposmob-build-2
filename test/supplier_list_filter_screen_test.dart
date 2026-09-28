import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/filter_toggle_button.dart';
import 'package:pos_machine/models/supplier.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/supplier_provider.dart';
import 'package:pos_machine/screens/suppliers/supplier_list.dart';
import 'package:provider/provider.dart';

class _FakeSupplierProvider extends SupplierProvider {
  @override
  Future<List<Supplier>?> fetchSuppliers({
    required String accessToken,
    String? supplierName,
  }) async =>
      <Supplier>[];
}

class _TestTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': {
          'suppliers.list': 'Supplier List',
          'suppliers.add': 'Add Supplier',
          'supplier_list_mobile.title': 'Supplier List',
          'supplier_list_mobile.btn_add_new': 'Add New',
          'supplier_list_mobile.show_filters': 'Show Filters',
          'supplier_list_mobile.hide_filters': 'Hide Filters',
        },
      };
}

void main() {
  setUpAll(() => Get.testMode = true);
  tearDown(() => Get.reset());

  Future<void> pumpSupplierList(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthModel()),
          ChangeNotifierProvider<SupplierProvider>(
            create: (_) => _FakeSupplierProvider(),
          ),
        ],
        child: GetMaterialApp(
          translations: _TestTranslations(),
          locale: const Locale('en', 'US'),
          home: const Scaffold(body: SupplierListScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('Supplier List collapses desktop filters and preserves input',
      (tester) async {
    await pumpSupplierList(tester, size: const Size(1440, 900));

    final toggle = find.byKey(
      const ValueKey('supplier-list-filter-toggle'),
    );
    final filters = find.byKey(
      const ValueKey('supplier-list-desktop-filters'),
    );

    expect(toggle, findsOneWidget);
    expect(filters, findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Acme');
    await tester.pump();
    expect(
      find.descendant(
        of: toggle,
        matching: find.byType(PositionedDirectional),
      ),
      findsOneWidget,
    );

    await tester.tap(toggle);
    await tester.pump();
    expect(filters, findsNothing);
    expect(find.text('Add Supplier'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pump();
    expect(filters, findsOneWidget);
    expect(find.text('Acme'), findsOneWidget);
  });

  testWidgets('Supplier List toggles its mobile filter panel', (tester) async {
    await pumpSupplierList(tester, size: const Size(390, 650));

    final toggle = find.byType(FilterToggleButton);
    final filters = find.byKey(
      const ValueKey('supplier-list-mobile-filters'),
    );

    expect(toggle, findsOneWidget);
    expect(filters, findsNothing);

    await tester.tap(toggle);
    await tester.pump();
    expect(filters, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(toggle);
    await tester.pump();
    expect(filters, findsNothing);
    expect(find.text('Add New'), findsOneWidget);
  });
}
