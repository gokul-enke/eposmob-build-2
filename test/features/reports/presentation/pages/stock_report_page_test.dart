import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/reports/domain/models/stock_report.dart';
import 'package:pos_machine/features/reports/domain/models/stock_report_pagination.dart';
import 'package:pos_machine/features/reports/presentation/pages/stock_report_page.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/executive.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/report_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../test_support/app_translations.dart';
import '../../../../test_support/export_capture.dart';
import '../../../../test_support/header_actions.dart';
import '../../../../test_support/hive_test_teardown.dart';

class _Reports extends ReportsProvider {
  final calls = <Map<String, Object?>>[];
  bool fail = false;
  @override
  Future<GetStockReportResponse> fetchStockReportSnapshot(
      {required String accessToken,
      String? product,
      String? sortBy,
      String? sortDirection,
      int? storeId,
      int? categoryId,
      String? stockLevel,
      String? expiringWithin,
      String? snapshotDate,
      String? from,
      String? until,
      int? page,
      int? perPage}) async {
    calls.add({
      'product': product,
      'store': storeId,
      'category': categoryId,
      'level': stockLevel,
      'expiry': expiringWithin,
      'snapshot': snapshotDate,
      'from': from,
      'until': until,
      'page': page,
      'perPage': perPage
    });
    if (fail) throw StateError('offline');
    return GetStockReportResponse(
        status: 'success',
        message: '',
        data: [
          StockReportData(
              id: page ?? 1,
              name: 'Crayons camel small',
              categoryName: 'Toys',
              barcode: '0012345',
              totalQuantity: '61.5',
              retailPrice: '8.123',
              mrp: '9.0',
              purchasePrice: '6.75',
              stockValue: '415.125',
              retailValue: '499.5645',
              unit: 'PCS',
              expiryDate: '2027-12-31')
        ],
        summary: StockReportSummary(
            totalUnits: '2881095.66',
            totalStockValue: '133842609.66',
            totalRetailValue: '285061258.79'),
        pagination: StockReportPagination(
            currentPage: page ?? 1, lastPage: 2, perPage: 1, total: 2));
  }
}

class _Roles extends RoleProvider {
  bool allowed = true;
  @override
  bool currentUserHasPermissionSync(String permission) => allowed;
  void revoke() {
    allowed = false;
    notifyListeners();
  }
}

class _Stores extends StoreSessionProvider {
  @override
  List<Store> get availableStores =>
      [Store(storeId: 3, storeName: 'Main Store')];
}

class _Categories extends CategoryProvider {
  @override
  List<Category>? get category =>
      [Category(categoryId: 4, categoryName: 'Toys')];
}

class _Products extends LocalProductProvider {
  _Products({int catalogSize = 1})
      : catalog = [
          GetProduct(productId: 5, productName: 'Crayons camel small'),
          for (var i = 1; i < catalogSize; i++)
            GetProduct(
                productId: i + 5,
                productName: 'Catalog product ${i.toString().padLeft(5, '0')}'),
        ];
  final List<GetProduct> catalog;
  @override
  List<GetProduct> get products => catalog;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDir;
  late _Reports reports;
  late _Roles roles;
  late CapturingExport capture;
  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('stock-report-hive-');
    Hive.init(hiveDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HiveStringValueAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(HiveLocalCartItemAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(HiveSavedOrderAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(HiveProductAdapter());
    }
    await Hive.openBox<HiveProduct>('products');
    await Hive.openBox<HiveLocalCartItem>('cart_items');
    await Hive.openBox<HiveSavedOrder>('saved_orders');
    await Hive.openBox<HiveSavedOrder>('confirmed_orders');
  });
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues(
        {'api_key': 'test', 'active_store_id': 3});
    reports = _Reports();
    roles = _Roles();
    capture = CapturingExport();
  });
  tearDown(() async {
    Get.reset();
    reports.dispose();
    roles.dispose();
    capture.dispose();
    await awaitPendingHiveBoxWrites();
  });
  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));
  Future<void> mount(WidgetTester tester,
      {Size size = const Size(1280, 900), int catalogSize = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthModel()..login('token', 1)),
          ChangeNotifierProvider<ReportsProvider>.value(value: reports),
          ChangeNotifierProvider<RoleProvider>.value(value: roles),
          ChangeNotifierProvider<StoreSessionProvider>(
              create: (_) => _Stores()),
          ChangeNotifierProvider<CategoryProvider>(
              create: (_) => _Categories()),
          ChangeNotifierProvider<LocalProductProvider>(
              create: (_) => _Products(catalogSize: catalogSize)),
        ],
        child: GetMaterialApp(
            translations: EnglishTranslations(),
            locale: const Locale('en'),
            home: Scaffold(body: StockReportPage(export: capture)))));
    await tester.pumpAndSettle();
  }

  ListPageScaffold<StockReportData> page(WidgetTester tester) =>
      tester.widget(find.byType(ListPageScaffold<StockReportData>));
  Finder picker(String key) => find.descendant(
      of: find.byKey(ValueKey((key, 0))), matching: find.byType(TextField));
  Future<void> select(WidgetTester tester, String key, String label) async {
    await tester.ensureVisible(picker(key));
    await tester.tap(picker(key));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('large catalog opens lazily, searches all products and resets',
      (tester) async {
    await mount(tester, catalogSize: 10000);
    for (var attempt = 0; attempt < 3; attempt++) {
      await tester.tap(picker('stock-product'));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton).evaluate().length, lessThan(25));
      expect(reports.calls, hasLength(1));
      expect(find.byType(PageHeader), findsOneWidget);
      await tester.tap(find.text('Find stock'));
      await tester.pumpAndSettle();
      await tester.tap(picker('stock-category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find stock'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.enterText(picker('stock-product'), '09999');
    await tester.pumpAndSettle();
    expect(reports.calls, hasLength(1));
    await tester
        .tap(find.widgetWithText(MenuItemButton, 'Catalog product 09999'));
    await tester.pumpAndSettle();
    expect(
        reports.calls.last, containsPair('product', 'Catalog product 09999'));
    await select(tester, 'stock-product', 'All Products');
    expect(reports.calls.last['product'], isNull);
    await tester.enterText(picker('stock-product'), 'unselected');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset').first);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.descendant(
                of: find.byKey(const ValueKey(('stock-product', 1))),
                matching: find.byType(TextField)))
            .controller!
            .text,
        'All Products');
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(1280, 900),
    const Size(768, 900),
    const Size(375, 812),
    const Size(375, 300)
  ]) {
    testWidgets('populated shared layout has no overflow at $size',
        (tester) async {
      await mount(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(page(tester).items.single.name, 'Crayons camel small');
      await tapFilterToggle(tester, key: StockReportPage.filterToggleKey);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'native menu remains above visible page and Reset clears unselected search',
      (tester) async {
    await mount(tester);
    for (final key in ['stock-store', 'stock-category', 'stock-product']) {
      await tester.enterText(picker(key), 'unselected search');
      await tester.pumpAndSettle();
      expect(find.byType(PageHeader), findsOneWidget);
      expect(find.byType(StockReportPage), findsOneWidget);
      expect(reports.calls, hasLength(1));
      await tester.tap(find.text('Reset').first);
      await tester.pumpAndSettle();
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.any((f) => f.controller?.text == 'unselected search'),
          isFalse);
      // Reset uses a new revision for the next iteration.
      if (key != 'stock-product') {
        await tester.pumpWidget(const SizedBox());
        await mount(tester);
        reports.calls.clear();
        reports.calls.add({});
      }
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'selections preserve product names, reset paging and survive menu reopen',
      (tester) async {
    await mount(tester);
    page(tester).pagination!.onPageChanged(2);
    await tester.pumpAndSettle();
    await select(tester, 'stock-store', 'Main Store');
    await select(tester, 'stock-category', 'Toys');
    await select(tester, 'stock-product', 'Crayons camel small');
    expect(reports.calls.last, containsPair('page', 1));
    expect(reports.calls.last, containsPair('store', 3));
    expect(reports.calls.last, containsPair('category', 4));
    expect(reports.calls.last, containsPair('product', 'Crayons camel small'));
    await select(tester, 'stock-product', 'All Products');
    expect(reports.calls.last['product'], isNull);
    expect(find.byType(PageHeader), findsOneWidget);
    await tester.tap(find.text('Reset').first);
    await tester.pumpAndSettle();
    expect(reports.calls.last['store'], isNull);
    expect(reports.calls.last['category'], isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'filtered workbook contains all pages and authorized costs as numbers',
      (tester) async {
    await mount(tester);
    await select(tester, 'stock-store', 'Main Store');
    await select(tester, 'stock-category', 'Toys');
    await select(tester, 'stock-product', 'Crayons camel small');
    await select(tester, 'stock-level', 'Below Reorder');
    await select(tester, 'stock-expiry', '3 Months');
    final start = reports.calls.length;
    await tester.tap(find.byKey(StockReportPage.exportKey));
    await tester.pump();
    await useTempExportDirectory(tester, 'stock-export-filtered-');
    final file = (await tester.runAsync(capture.createFile!))!;
    final values =
        Excel.decodeBytes(file.readAsBytesSync()).tables['Stock Report']!.rows;
    expect(values, hasLength(3));
    expect(values.first.map((c) => c?.value.toString()),
        contains('Purchase\nPrice'));
    expect(values[1][7]!.value, const DoubleCellValue(6.75));
    expect(values[1][10]!.value, const DoubleCellValue(415.125));
    for (final request in reports.calls.skip(start)) {
      expect(request, containsPair('store', 3));
      expect(request, containsPair('category', 4));
      expect(request, containsPair('product', 'Crayons camel small'));
      expect(request, containsPair('level', 'below_reorder'));
      expect(request, containsPair('expiry', 'three_months'));
      expect(request, containsPair('perPage', 250));
    }
    expect(reports.calls.skip(start).map((c) => c['page']), [1, 2]);
  });
  testWidgets('date fields show placeholders, select one date, clear and reset',
      (tester) async {
    await mount(tester);
    expect(find.text('Select Date'), findsNWidgets(2));
    for (final field in ['snapshot', 'from', 'until']) {
      await tester.ensureVisible(find.byKey(ValueKey('stock-date-$field')));
      await tester.tap(find.byKey(ValueKey('stock-date-$field')));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      await tester.tap(find.text('6').last);
      await tester.pumpAndSettle();
      expect(reports.calls.last[field], matches(RegExp(r'^\d{4}-\d{2}-06$')));
      await tester.tap(find.byKey(ValueKey('stock-clear-$field')));
      await tester.pumpAndSettle();
      expect(reports.calls.last[field], isNull);
    }
    await tester.tap(find.text('Reset').first);
    await tester.pumpAndSettle();
    expect(find.text('Select Date'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
  testWidgets('retry preserves rows and starts failed filter on page one',
      (tester) async {
    await mount(tester);
    page(tester).pagination!.onPageChanged(2);
    await tester.pumpAndSettle();
    reports.fail = true;
    await select(tester, 'stock-store', 'Main Store');
    expect(page(tester).pagination!.currentPage, 2);
    expect(page(tester).items, hasLength(1));
    expect(find.text('Retry'), findsOneWidget);
    reports.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(reports.calls.last['page'], 1);
    expect(page(tester).pagination!.currentPage, 1);
  });
  testWidgets(
      'permission revocation removes costs from table, totals and export',
      (tester) async {
    await mount(tester);
    expect(
        page(tester).columns.map((c) => c.label), contains('Purchase\nPrice'));
    roles.revoke();
    await tester.pumpAndSettle();
    expect(page(tester).columns.map((c) => c.label),
        isNot(contains('Purchase\nPrice')));
    expect(find.text('Total Stock Value (Cost)'), findsNothing);
    await tester.tap(find.byKey(StockReportPage.exportKey));
    await tester.pump();
    await useTempExportDirectory(tester, 'stock-export-');
    final file = (await tester.runAsync(capture.createFile!))!;
    final rows =
        Excel.decodeBytes(file.readAsBytesSync()).tables['Stock Report']!.rows;
    final headers = rows.first.map((c) => c?.value.toString()).toList();
    expect(headers, isNot(contains('Purchase\nPrice')));
    expect(headers, isNot(contains('Stock\nValue')));
    expect(rows, hasLength(3));
    expect(rows[1][4]!.value, TextCellValue('0012345'));
    expect(rows[1][5]!.value, const DoubleCellValue(8.123));
    expect(reports.calls.skip(1).map((c) => c['page']), [1, 2]);
  });
  testWidgets('mobile cards also remove purchase prices after revocation',
      (tester) async {
    await mount(tester, size: const Size(375, 812));
    expect(find.text('Purchase\nPrice'), findsOneWidget);
    roles.revoke();
    await tester.pumpAndSettle();
    expect(find.text('Purchase\nPrice'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
