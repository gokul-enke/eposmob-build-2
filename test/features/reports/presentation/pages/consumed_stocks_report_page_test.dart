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
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/report_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/features/reports/domain/models/consumed_stocks_report.dart';
import 'package:pos_machine/features/reports/domain/consumed_stocks_report_query.dart';
import 'package:pos_machine/features/reports/presentation/pages/consumed_stocks_report_page.dart';
import 'package:pos_machine/features/reports/presentation/widgets/consumed_stocks_report/consumed_stocks_report_picker.dart';
import 'package:pos_machine/features/reports/presentation/widgets/consumed_stocks_report/consumed_stocks_report_filters.dart';
import '../../../../test_support/app_translations.dart';
import '../../../../test_support/export_capture.dart';
import '../../../../test_support/hive_test_teardown.dart';
import '../../support/consumed_stocks_fixtures.dart';

class _Reports extends ReportsProvider {
  final calls = <ConsumedCall>[];
  bool fail = false;
  @override
  Future<ConsumedStocksReportScope> consumedStocksReportScope(
          String token) async =>
      consumedScope;
  @override
  Future<GetConsumedStocksReportResponse> fetchConsumedStocksReportSnapshot(
      {required String accessToken,
      String? productId,
      String? storeId,
      String? from,
      String? until,
      int? page}) async {
    calls.add((
      query: ConsumedStocksReportQuery(
          productId: productId,
          storeId: storeId,
          from: from == null ? null : DateTime.parse(from),
          until: until == null ? null : DateTime.parse(until)),
      page: page ?? 1
    ));
    if (fail) throw StateError('outage');
    return consumedPage(page ?? 1, last: 2, total: 2, rows: [
      consumedRow(page ?? 1,
          quantity: page == 2 ? '3.125000' : '1.000000',
          remaining: page == 2 ? 74.25 : 0)
    ]);
  }
}

class _Products extends LocalProductProvider {
  @override
  List<GetProduct> get products =>
      [GetProduct(productId: 12, productName: 'Catalog product')];
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
    hiveDir = await Directory.systemTemp.createTemp('consumed-stocks-page-');
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
  setUp(() => SharedPreferences.setMockInitialValues({
        'api_key': 'tenant',
        'stores': '[{"store_id":9,"store_name":"Store"}]'
      }));
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
          ChangeNotifierProvider<LocalProductProvider>(
              create: (_) => _Products()),
        ],
        child: GetMaterialApp(
            translations: EnglishTranslations(),
            locale: const Locale('en'),
            home: Scaffold(body: ConsumedStocksReportPage(export: capture)))));
    await tester.pumpAndSettle();
    return (reports, capture, roles);
  }

  ConsumedStocksReportPicker picker(WidgetTester tester, int i) =>
      tester.widget(find.byType(ConsumedStocksReportPicker).at(i));
  ConsumedStocksDateField date(WidgetTester tester, int i) =>
      tester.widget(find.byType(ConsumedStocksDateField).at(i));
  testWidgets(
      'login-cached store appears and its ID reaches the report request',
      (tester) async {
    final reports = (await mount(tester)).$1;
    await tester.tap(find.byType(TextField).at(1));
    await tester.pumpAndSettle();
    final storeOption = find.descendant(
        of: find.byType(MenuItemButton), matching: find.text('Store'));
    expect(storeOption, findsOneWidget);
    await tester.tap(storeOption);
    await tester.pumpAndSettle();
    expect(reports.calls.last.query.storeId, '9');
    expect(picker(tester, 1).value, '9');
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(reports.calls.last.query.storeId, isNull);
    expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        'All Stores');
  });
  testWidgets('shared listing preserves raw quantities, dates, IDs and Reset',
      (tester) async {
    final reports = (await mount(tester)).$1;
    expect(find.text('1.000000'), findsOneWidget);
    expect(find.text('2026-05-25 04:54:14'), findsOneWidget);
    expect(find.text('Select From Date'), findsOneWidget);
    expect(find.text('Select Until Date'), findsOneWidget);
    picker(tester, 0).onChanged('12');
    await tester.pumpAndSettle();
    picker(tester, 1).onChanged('9');
    await tester.pumpAndSettle();
    date(tester, 0).onChanged(DateTime(2026, 5, 1));
    await tester.pumpAndSettle();
    date(tester, 1).onChanged(DateTime(2026, 5, 31));
    await tester.pumpAndSettle();
    expect(reports.calls.last.query.productId, '12');
    expect(reports.calls.last.query.storeId, '9');
    expect(reports.calls.last.query.apiFrom, '2026-05-01');
    expect(reports.calls.last.query.apiUntil, '2026-05-31');
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(reports.calls.last.query.isEmpty, true);
    expect(date(tester, 0).value, isNull);
    expect(date(tester, 1).value, isNull);
    expect(picker(tester, 0).value, isNull);
    expect(picker(tester, 1).value, isNull);
    expect(find.text('Select From Date'), findsOneWidget);
    expect(find.text('Select Until Date'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'searching dropdown only searches cached options; Reset clears typed search',
      (tester) async {
    final reports = (await mount(tester)).$1;
    final productField = find.descendant(
        of: find.byType(ConsumedStocksReportPicker).first,
        matching: find.byType(TextField));
    await tester.enterText(productField, 'unknown');
    await tester.pumpAndSettle();
    expect(reports.calls.length, 1);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(productField).controller!.text,
        'All Products');
  });
  testWidgets(
      'date picker dismisses on selection and clear/reset updates visible value',
      (tester) async {
    await mount(tester);
    await tester.tap(find.byKey(const ValueKey('consumed-from')));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    final calendar =
        tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
    calendar.onDateChanged(DateTime(DateTime.now().year, 5, 1));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(date(tester, 0).value, DateTime(DateTime.now().year, 5, 1));
    await tester.tap(find.byTooltip('Clear date'));
    await tester.pumpAndSettle();
    expect(date(tester, 0).value, isNull);
    expect(find.text('Select From Date'), findsOneWidget);
  });
  testWidgets('inverted dates show validation without requesting the endpoint',
      (tester) async {
    final reports = (await mount(tester)).$1;
    date(tester, 0).onChanged(DateTime(2026, 5, 31));
    await tester.pumpAndSettle();
    final count = reports.calls.length;
    date(tester, 1).onChanged(DateTime(2026, 5, 1));
    await tester.pumpAndSettle();
    expect(reports.calls.length, count);
    expect(find.text('From Date must be on or before Until Date.'),
        findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(reports.calls.last.query.isEmpty, true);
  });
  testWidgets(
      'page 2 export saves all matching withdrawal records and keeps visible page',
      (tester) async {
    await useTempExportDirectory(tester, 'consumed-stock-export-');
    final (reports, capture, _) = await mount(tester);
    picker(tester, 0).onChanged('12');
    await tester.pumpAndSettle();
    date(tester, 0).onChanged(DateTime(2026, 5, 1));
    await tester.pumpAndSettle();
    final scaffold = tester.widget<ListPageScaffold<ConsumedStockData>>(
        find.byType(ListPageScaffold<ConsumedStockData>));
    scaffold.pagination!.onPageChanged(2);
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byKey(ConsumedStocksReportPage.exportKey));
    await tester.pumpAndSettle();
    final output = await tester.runAsync(capture.createFile!);
    final sheet =
        Excel.decodeBytes(output!.readAsBytesSync()).tables['Consumed Stocks']!;
    expect(sheet.rows.length, 3);
    expect(sheet.rows[1][3]!.value, isA<IntCellValue>());
    expect(sheet.rows[2][3]!.value, const DoubleCellValue(3.125));
    expect(sheet.rows[2][4]!.value, const DoubleCellValue(74.25));
    expect(sheet.rows[1][4]!.value, isA<IntCellValue>());
    expect(sheet.rows[2][1]!.value.toString(), 'Banana');
    expect(reports.calls.last.query.productId, '12');
    expect(reports.calls.last.query.apiFrom, '2026-05-01');
    expect(find.text('Page 2 of 2'), findsOneWidget);
    expect(reports.consumedStocksReport, isNull);
  });
  testWidgets(
      'refresh failure retains rows and correct retry; permission revocation disables export',
      (tester) async {
    final (reports, _, roles) = await mount(tester);
    reports.fail = true;
    await tester.tap(find.byKey(ConsumedStocksReportPage.refreshKey));
    await tester.pumpAndSettle();
    expect(find.text('Banana'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    reports.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    roles.revoke();
    await tester.pumpAndSettle();
    expect(
        tester.widget<PageHeader>(find.byType(PageHeader)).actions[1].onPressed,
        isNull);
  });
  for (final size in [
    const Size(375, 800),
    const Size(768, 900),
    const Size(1280, 900)
  ]) {
    testWidgets('populated listing and filters fit ${size.width}',
        (tester) async {
      await mount(tester, size: size);
      expect(find.textContaining('Banana'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (size.width < 700) {
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();
      }
      expect(find.byType(ConsumedStocksReportPicker), findsNWidgets(2));
      expect(find.byType(ConsumedStocksDateField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }
  test('new strings exist in all supported locales', () {
    final en = translationSection('en', 'consumed_stocks_report');
    for (final lang in ['ar', 'ml']) {
      final values = translationSection(lang, 'consumed_stocks_report');
      for (final key in en.keys) {
        expect(values[key], isNotEmpty, reason: '$lang.$key');
      }
    }
  });
}
