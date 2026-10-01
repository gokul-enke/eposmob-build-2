import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool loadFixtures = false;
  int requests = 0;
  String? lastSupplierName;
  String? lastSupplierEmail;
  String? lastSupplierPhone;
  String? lastFilterBalance;

  @override
  Future<List<Supplier>?> fetchSuppliers({
    required String accessToken,
    String? supplierName,
  }) async {
    if (!loadFixtures) return <Supplier>[];
    return http.runWithClient(
        () => super.fetchSuppliers(
            accessToken: accessToken, supplierName: supplierName),
        () => MockClient((_) async {
              requests++;
              return http.Response(
                  jsonEncode({
                    'status': 'success',
                    'data': [
                      for (int id = 1; id <= 28; id++)
                        {
                          'id': id,
                          'name': id == 26 ? 'Other' : 'Acme',
                          'email':
                              id == 27 ? 'other@test.com' : 'acme@test.com',
                          'phone': id == 28 ? '99999' : '00123',
                          'current_balance': 10
                        }
                    ]
                  }),
                  200);
            }));
  }

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
          'suppliers.title': 'Suppliers',
          'suppliers.name': 'Name',
          'suppliers.email': 'Email',
          'suppliers.phone': 'Phone',
          'suppliers.balance': 'Balance',
          'suppliers.all': 'All',
          'suppliers.positive': 'Positive (+ve)',
          'suppliers.negative': 'Negative (-ve)',
          'suppliers.zero': 'Zero (0)',
          'supplier_list.subtitle':
              'Manage supplier details, contacts and balances.',
          'supplier_list.find': 'Find suppliers',
          'supplier_list.find_hint': 'Results update as you type.',
          'supplier_list.count_on_page': '@count suppliers on this page',
          'list.refresh': 'Refresh',
          'list.reset': 'Reset',
          'list.view': 'View',
          'pagination.page_of': 'Page @current of @total',
          'pagination.previous_page': 'Previous page',
          'pagination.next_page': 'Next page',
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
    // show() completes only after the refresh animation runs, and frames
    // advance only when the test pumps, so awaiting it here would deadlock.
    final refreshDone = refresh.show();
    await tester.pumpAndSettle();
    await refreshDone;

    expect(supplierProvider.lastSupplierName, 'Acme');
    expect(supplierProvider.lastSupplierEmail, 'accounts@acme.test');
    expect(supplierProvider.lastSupplierPhone, '555');
    expect(supplierProvider.lastFilterBalance, 'Positive (+ve)');
  });
  testWidgets('hiding filters preserves pending search', (tester) async {
    final provider = _FakeSupplierProvider();
    await pumpSupplierList(tester,
        size: const Size(1440, 900),
        supplierProvider: provider,
        authenticated: true);
    await tester.enterText(find.byType(TextField).first, 'Acme');
    await tester.tap(find.byKey(const ValueKey('supplier-list-filter-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(provider.lastSupplierName, 'Acme');
  });
  testWidgets('expanded filters fit short mobile viewport', (tester) async {
    await pumpSupplierList(tester, size: const Size(375, 300));
    await tester.tap(find.byKey(const ValueKey('supplier-list-filter-toggle')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'export flushes pending supplier filters for Excel and table without API calls',
      (tester) async {
    SharedPreferences.setMockInitialValues({'api_key': 'test'});
    final provider = _FakeSupplierProvider()..loadFixtures = true;
    await pumpSupplierList(tester,
        size: const Size(1440, 900),
        supplierProvider: provider,
        authenticated: true);
    await tester.pumpAndSettle();
    expect(provider.filteredSuppliers.length, 28);
    provider.goToPage(2);
    await tester.enterText(find.byType(TextField).at(0), 'Acme');
    await tester.enterText(find.byType(TextField).at(1), 'acme@test');
    await tester.enterText(find.byType(TextField).at(2), '00123');
    await tester.pump(const Duration(milliseconds: 100));
    expect(provider.filteredSuppliers.length, 28);
    final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('supplier-export-test-')))!;
    addTearDown(() => dir.delete(recursive: true));
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final export =
        tester.widget<ExportShareButton>(find.byType(ExportShareButton));
    final file = await tester.runAsync(export.createFile);
    final rows =
        Excel.decodeBytes(file!.readAsBytesSync()).tables.values.single.rows;
    expect(rows.length, 26);
    expect(provider.filteredSuppliers.length, 25);
    expect(provider.supplierList!.length, 5);
    expect(provider.currentPage, 2);
    expect(
        rows.skip(1).every((row) =>
            row[1]!.value == TextCellValue('Acme') &&
            row[2]!.value == TextCellValue('acme@test.com') &&
            row[3]!.value == TextCellValue('00123')),
        isTrue);
    expect(provider.requests, 1);
    await tester.pump(const Duration(milliseconds: 400));
    expect(provider.currentPage, 2);
    expect(provider.requests, 1);
    expect(tester.takeException(), isNull);
  });
}
