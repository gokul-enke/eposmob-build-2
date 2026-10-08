import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/executive.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/report_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/features/reports/domain/models/non_stock_report.dart';
import 'package:pos_machine/features/reports/domain/non_stock_report_query.dart';
import 'package:pos_machine/features/reports/presentation/pages/non_stock_report_page.dart';
import 'package:pos_machine/features/reports/presentation/widgets/non_stock_report/non_stock_report_picker.dart';
import '../../../../test_support/app_translations.dart';
import '../../../../test_support/export_capture.dart';
import '../../../../test_support/hive_test_teardown.dart';
import '../../support/non_stock_fixtures.dart';

class _Reports extends ReportsProvider {
  final calls = <NonStockCall>[];
  bool fail = false;
  @override
  Future<NonStockReportScope> nonStockReportScope(String token) async =>
      nonStockScope;
  @override
  Future<GetNonStockReportResponse> fetchNonStockReportSnapshot(
      {required String accessToken,
      String? store,
      String? category,
      String? product,
      String? barcode,
      int? page}) async {
    calls.add((
      query: NonStockReportQuery(
          store: store,
          category: category,
          product: product,
          barcode: barcode ?? ''),
      page: page ?? 1
    ));
    if (fail) {
      throw StateError('outage');
    }
    return nonStockPage(page ?? 1, last: 2, total: 2, rows: [
      nonStockRow(page ?? 1, status: page == 2 ? 'Out of Stock' : 'Low Stock')
    ]);
  }
}

class _Products extends LocalProductProvider {
  @override
  List<GetProduct> get products =>
      [GetProduct(productId: 999, productName: 'Catalog product')];
}

class _Categories extends CategoryProvider {
  @override
  List<Category>? get category => [Category(categoryName: 'Category')];
}

class _Stores extends StoreSessionProvider {
  @override
  List<Store> get availableStores => [Store(storeName: 'Store')];
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

void main() {
  late Directory hiveDir;
  setUpAll(() async {
    Get.testMode = true;
    hiveDir = await Directory.systemTemp.createTemp('non-stock-page-');
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
  setUp(() => SharedPreferences.setMockInitialValues({'api_key': 'tenant'}));
  tearDown(() async {
    Get.reset();
    await awaitPendingHiveBoxWrites();
  });
  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));
  Future<(_Reports, CapturingExport, _Roles)> mount(WidgetTester tester,
      {Size size = const Size(1440, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final reports = _Reports(), capture = CapturingExport(), roles = _Roles();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthModel()..login('test', 1)),
          ChangeNotifierProvider<ReportsProvider>.value(value: reports),
          ChangeNotifierProvider<RoleProvider>.value(value: roles),
          ChangeNotifierProvider<CategoryProvider>(
              create: (_) => _Categories()),
          ChangeNotifierProvider<LocalProductProvider>(
              create: (_) => _Products()),
          ChangeNotifierProvider<StoreSessionProvider>(
              create: (_) => _Stores()),
        ],
        child: GetMaterialApp(
            translations: EnglishTranslations(),
            locale: const Locale('en'),
            home: Scaffold(body: NonStockReportPage(export: capture)))));
    await tester.pumpAndSettle();
    return (reports, capture, roles);
  }

  NonStockReportPicker picker(WidgetTester tester, int index) =>
      tester.widget(find.byType(NonStockReportPicker).at(index));
  testWidgets(
      'shared listing retains status, decimals, independent name filters and reset',
      (tester) async {
    final reports = (await mount(tester)).$1;
    for (var i = 0; i < 3; i++) {
      final field = find.descendant(
          of: find.byType(NonStockReportPicker).at(i),
          matching: find.byType(TextField));
      expect(tester.widget<TextField>(field).decoration!.labelText,
          ['Store', 'Category', 'Product'][i]);
    }
    expect(
        tester
            .widget<TextField>(find.descendant(
                of: find.byType(TextFormField),
                matching: find.byType(TextField)))
            .decoration!
            .labelText,
        'Barcode');
    expect(find.text('0.125'), findsOneWidget);
    expect(find.text('Low Stock'), findsOneWidget);
    expect(tester.widget<AppBadge>(find.byType(AppBadge)).tone,
        AppBadgeTone.warning);
    picker(tester, 0).onChanged('Store');
    await tester.pumpAndSettle();
    picker(tester, 2).onChanged('Catalog product');
    await tester.pumpAndSettle();
    picker(tester, 1).onChanged('Category');
    await tester.pumpAndSettle();
    expect(reports.calls.last.query.product, 'Catalog product');
    expect(reports.calls.last.query.store, 'Store');
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(reports.calls.last.query.isEmpty, isTrue);
    expect(picker(tester, 2).value, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'typing picker search never reloads and Reset clears unselected search',
      (tester) async {
    final reports = (await mount(tester)).$1;
    final productField = find.descendant(
        of: find.byType(NonStockReportPicker).at(2),
        matching: find.byType(TextField));
    await tester.enterText(productField, 'unknown');
    await tester.pumpAndSettle();
    expect(reports.calls.length, 1);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(productField).controller!.text,
        'All products');
    expect(reports.calls.last.query.isEmpty, isTrue);
  });
  testWidgets(
      'barcode Enter, page 2 and export keep visible rows and text barcodes',
      (tester) async {
    await useTempExportDirectory(tester, 'non-stock-export');
    final (reports, capture, _) = await mount(tester);
    final barcode = find.byType(TextFormField);
    await tester.enterText(barcode, '001');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(reports.calls.last.query.barcode, '001');
    final list = tester.widget<ListPageScaffold<NonStockReportData>>(
        find.byType(ListPageScaffold<NonStockReportData>));
    list.pagination!.onPageChanged(2);
    await tester.pumpAndSettle();
    expect(find.text('Out of Stock'), findsOneWidget);
    await tester.tap(find.byKey(NonStockReportPage.exportKey));
    await tester.pumpAndSettle();
    expect(capture.runs, 1);
    final output = await tester.runAsync(capture.createFile!);
    final workbook = Excel.decodeBytes(output!.readAsBytesSync()),
        sheet = workbook.tables['Non-Stock Report']!;
    expect(sheet.rows.length, 3);
    expect(sheet.rows[1][4]!.value, isA<TextCellValue>());
    expect(sheet.rows[1][5]!.value, isA<DoubleCellValue>());
    expect(reports.calls.map((c) => c.query.barcode), contains('001'));
    expect(find.text('Page 2 of 2'), findsOneWidget);
    expect(reports.nonStockReport, isNull);
  });
  testWidgets(
      'refresh failure retains rows and retry, permissions disable export',
      (tester) async {
    final (reports, _, roles) = await mount(tester);
    reports.fail = true;
    await tester.tap(find.byKey(NonStockReportPage.refreshKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('Product 1'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    reports.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    roles.revoke();
    await tester.pumpAndSettle();
    final header = tester.widget<PageHeader>(find.byType(PageHeader));
    expect(header.actions[1].onPressed, isNull);
  });
  for (final size in [
    const Size(375, 800),
    const Size(768, 900),
    const Size(1280, 900)
  ]) {
    testWidgets('populated responsive listing and filters at ${size.width}',
        (tester) async {
      await mount(tester, size: size);
      expect(find.textContaining('Product 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (size.width < 700) {
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();
      }
      expect(find.byType(NonStockReportPicker), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  }
  test('new strings exist in every supported locale', () {
    final english = translationSection('en', 'non_stock_report');
    for (final locale in ['ar', 'ml']) {
      final keys = translationSection(locale, 'non_stock_report');
      for (final key in english.keys) {
        expect(keys[key], isNotEmpty, reason: '$locale.$key');
      }
    }
  });
}
