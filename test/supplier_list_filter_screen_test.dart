import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/export_share_button.dart';
import 'package:pos_machine/components/filter_toggle_button.dart';
import 'package:pos_machine/models/supplier.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/supplier_provider.dart';
import 'package:pos_machine/screens/suppliers/supplier_list.dart';
import 'package:provider/provider.dart';

class _FakeSupplierProvider extends SupplierProvider {
  String? lastSupplierName;
  String? lastSupplierEmail;
  String? lastSupplierPhone;
  String? lastFilterBalance;

  @override
  Future<List<Supplier>?> fetchSuppliers({
    required String accessToken,
    String? supplierName,
  }) async =>
      <Supplier>[];

  @override
  void applyFiltersLocally({
    String? supplierName,
    String? supplierEmail,
    String? supplierPhone,
    String? filterBalance,
    int page = 1,
  }) {
    lastSupplierName = supplierName;
    lastSupplierEmail = supplierEmail;
    lastSupplierPhone = supplierPhone;
    lastFilterBalance = filterBalance;
    super.applyFiltersLocally(
      supplierName: supplierName,
      supplierEmail: supplierEmail,
      supplierPhone: supplierPhone,
      filterBalance: filterBalance,
      page: page,
    );
  }
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
          'supplier_list.export': 'Export',
          'supplier_list.exporting': 'Exporting...',
          'supplier_list.export_tooltip': 'Export and share suppliers',
          'supplier_list.export_failed': 'Could not export suppliers',
          'supplier_list.share_text': 'Supplier list exported from CloudPOS',
        },
      };
}

void main() {
  setUpAll(() => Get.testMode = true);
  tearDown(() => Get.reset());

  Future<void> pumpSupplierList(
    WidgetTester tester, {
    required Size size,
    _FakeSupplierProvider? supplierProvider,
    bool authenticated = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authModel = AuthModel();
    if (authenticated) authModel.login('test-token', 1);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authModel),
          ChangeNotifierProvider<SupplierProvider>(
            create: (_) => supplierProvider ?? _FakeSupplierProvider(),
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
    expect(find.byType(ExportShareButton), findsOneWidget);

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
    expect(find.byType(ExportShareButton), findsOneWidget);

    await tester.tap(toggle);
    await tester.pump();
    expect(filters, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(toggle);
    await tester.pump();
    expect(filters, findsNothing);
    expect(find.text('Add New'), findsOneWidget);
  });

  testWidgets('Supplier List export action fits a narrow mobile header',
      (tester) async {
    await pumpSupplierList(tester, size: const Size(320, 568));

    expect(find.byKey(const ValueKey('supplier-list-export')), findsOneWidget);
    expect(find.byType(FilterToggleButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh reapplies every visible supplier filter',
      (tester) async {
    final supplierProvider = _FakeSupplierProvider();
    await pumpSupplierList(
      tester,
      size: const Size(1440, 900),
      supplierProvider: supplierProvider,
      authenticated: true,
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Acme');
    await tester.enterText(fields.at(1), 'accounts@acme.test');
    await tester.enterText(fields.at(2), '555');
    await tester.pump();

    final balanceDropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    balanceDropdown.onChanged!('Positive (+ve)');
    await tester.pump();

    supplierProvider.lastSupplierName = null;
    supplierProvider.lastSupplierEmail = null;
    supplierProvider.lastSupplierPhone = null;
    supplierProvider.lastFilterBalance = null;

    final refresh = tester.state<RefreshIndicatorState>(
      find.byType(RefreshIndicator),
    );
    await refresh.show();
    await tester.pumpAndSettle();

    expect(supplierProvider.lastSupplierName, 'Acme');
    expect(supplierProvider.lastSupplierEmail, 'accounts@acme.test');
    expect(supplierProvider.lastSupplierPhone, '555');
    expect(supplierProvider.lastFilterBalance, 'Positive (+ve)');
  });
}
