import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/features/reports/presentation/widgets/product_sales/product_sales_filters.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';
import 'package:pos_machine/features/reports/domain/models/product_sales_report.dart';
import 'package:pos_machine/features/reports/domain/product_sales_query.dart';
import 'package:pos_machine/features/reports/presentation/pages/product_sales_report_page.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/report_provider.dart';
import '../../../../test_support/app_translations.dart';
import '../../../../test_support/export_capture.dart';
import '../../../../test_support/header_actions.dart';
import '../../support/product_sales_fixtures.dart';

class FakeReports extends ReportsProvider {
  final calls = <({
    int page,
    int size,
    String? category,
    String? product,
    String? customer,
    String? from,
    String? to,
    bool update
  })>[];
  bool fail = false;
  @override
  Future<GetProductSalesReportResponse> fetchProductSalesReport(
      {required String accessToken,
      String? categoryId,
      String? productId,
      String? customerId,
      String? startDate,
      String? endDate,
      int page = 1,
      int perPage = 25,
      bool updateState = true}) async {
    calls.add((
      page: page,
      size: perPage,
      category: categoryId,
      product: productId,
      customer: customerId,
      from: startDate,
      to: endDate,
      update: updateState
    ));
    if (fail) throw StateError('network');
    return productReport(page, perPage: perPage);
  }
}

class FakeCategories extends CategoryProvider {
  @override
  List<Category>? get category =>
      [Category(categoryId: 88, categoryName: 'Juice')];
  @override
  Future<void> listAllCategory(
      {String? filterName,
      String? filterParent,
      int? page,
      bool sellableOnly = true,
      bool scopeToActiveStore = true,
      bool force = false}) async {}
}

class FakeProducts extends GridSelectionProvider {
  Completer<List<GetProduct>>? pending;
  int directoryCalls = 0;
  @override
  Future<void> listAllProducts(
      {int? categoryId,
      String? filterName,
      String? filterCategory,
      String? filterBarcode,
      String? filterPrice,
      String? filterCreatedBy,
      String? filterProperties,
      String? filterStore,
      String? filterSupplier,
      int page = 1}) async {}
  @override
  Future<void> listAllProductsAPI({int? categoryId, String? barCode}) async {}
  @override
  Future<List<GetProduct>> listAllProductsForReportFilter() async {
    directoryCalls++;
    if (pending != null) return pending!.future;
    return [
      GetProduct(productId: 9, productName: 'Apple Juice', categoryId: 88),
      GetProduct(productId: 10, productName: 'Other Product', categoryId: 99)
    ];
  }
}

class FakeCustomers extends CustomerProvider {
  bool fail = false;
  int calls = 0;
  @override
  Future<List<CustomerListModelData>> fetchAllCustomersSnapshot(
      {required String accessToken}) async {
    calls++;
    if (fail) throw StateError('directory');
    return [CustomerListModelData(id: 7, name: 'Test Customer')];
  }
}

Widget app(FakeReports reports, CapturingExport capture,
        {FakeCustomers? customers,
        FakeProducts? products,
        GlobalKey? captureKey}) =>
    MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthModel()),
          ChangeNotifierProvider<ReportsProvider>.value(value: reports),
          ChangeNotifierProvider<CategoryProvider>(
              create: (_) => FakeCategories()),
          ChangeNotifierProvider<GridSelectionProvider>(
              create: (_) => products ?? FakeProducts()),
          ChangeNotifierProvider<CustomerProvider>(
              create: (_) => customers ?? FakeCustomers())
        ],
        child: GetMaterialApp(
            translations: EnglishTranslations(),
            locale: const Locale('en'),
            home: Scaffold(
                body: RepaintBoundary(
                    key: captureKey,
                    child:
                        ProductSalesReportPage(exportController: capture)))));
DropdownMenu<ProductSalesOption> picker(WidgetTester tester, String name) =>
    tester.widget(find.descendant(
        of: find.byKey(ValueKey('product-sales-$name-picker')),
        matching: find.byType(DropdownMenu<ProductSalesOption>)));
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(
        {'api_key': 'tenant', 'active_store_id': 1});
  });
  tearDown(Get.reset);
  testWidgets('options Retry waits for the pending directory batch',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final customers = FakeCustomers()..fail = true;
    final products = FakeProducts()..pending = Completer<List<GetProduct>>();
    await tester.pumpWidget(app(FakeReports(), CapturingExport(),
        customers: customers, products: products));
    await tester.pumpAndSettle();
    final retry = find.widgetWithText(TextButton, 'Retry');
    expect(tester.widget<TextButton>(retry).onPressed, isNull);
    expect(find.byKey(const ValueKey('product-sales-report-summary')),
        findsOneWidget);
    await tester.tap(retry, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(products.directoryCalls, 1);
    expect(customers.calls, 1);
    products.pending!.complete([]);
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(retry).onPressed, isNotNull);
    customers.fail = false;
    products.pending = null;
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(products.directoryCalls, 2);
    expect(customers.calls, 2);
    expect(retry, findsNothing);
    expect(picker(tester, 'customer').dropdownMenuEntries.length, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets('Reset clears unselected search text in every directory picker',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final reports = FakeReports();
    await tester.pumpWidget(app(reports, CapturingExport()));
    await tester.pumpAndSettle();
    Finder field(String name) => find.descendant(
        of: find.byKey(ValueKey('product-sales-$name-picker')),
        matching: find.byType(TextField));
    final queries = {'category': 'Jui', 'product': 'Apple', 'customer': 'Test'};
    for (final entry in queries.entries) {
      await tester.tap(field(entry.key));
      await tester.enterText(field(entry.key), entry.value);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }
    for (var reset = 0; reset < 2; reset++) {
      await tester.tap(find.text('Reset').first);
      await tester.pumpAndSettle();
      for (final name in queries.keys) {
        expect(tester.widget<TextField>(field(name)).controller!.text, isEmpty);
      }
      expect(reports.calls.last.category, isNull);
      expect(reports.calls.last.product, isNull);
      expect(reports.calls.last.customer, isNull);
      expect(reports.calls.last.page, 1);
      expect(picker(tester, 'product').dropdownMenuEntries.length, 3);
      expect(find.byType(ProductSalesReportPage), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'date picker bounds, invalid range and Reset preserve date-only API values',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final reports = FakeReports();
    await tester.pumpWidget(app(reports, CapturingExport()));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('product-sales-report-from-filter')));
    await tester.pumpAndSettle();
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime(2026, 9, 2));
    await tester.pumpAndSettle();
    expect(reports.calls.last.from, '2026-09-02');
    expect(find.byType(CalendarDatePicker), findsNothing);
    final filters =
        tester.widget<ProductSalesFilters>(find.byType(ProductSalesFilters));
    final count = reports.calls.length;
    filters.onDate(DateTime(2026, 9, 1), false);
    await tester.pumpAndSettle();
    expect(reports.calls.length, count);
    expect(find.text('From date cannot be after To date.'), findsWidgets);
    expect(
        tester.widget<PageHeader>(find.byType(PageHeader)).actions[1].onPressed,
        isNull);
    await tester.tap(find.text('Reset').first);
    await tester.pumpAndSettle();
    expect(reports.calls.last.from, '');
    expect(reports.calls.last.to, '');
    expect(reports.calls.last.page, 1);
    expect(find.text('Select Date'), findsNWidgets(2));
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets('individual All choice clears a filter and resets paging',
      (tester) async {
    final reports = FakeReports();
    await tester.pumpWidget(app(reports, CapturingExport()));
    await tester.pumpAndSettle();
    picker(tester, 'customer').onSelected!(customerOption);
    await tester.pumpAndSettle();
    var list = tester.widget<ListPageScaffold<ProductSalesReportEntry>>(
        find.byType(ListPageScaffold<ProductSalesReportEntry>));
    list.pagination!.onPageChanged(2);
    await tester.pumpAndSettle();
    expect(reports.calls.last.page, 2);
    picker(tester, 'customer').onSelected!(
        picker(tester, 'customer').dropdownMenuEntries.first.value);
    await tester.pumpAndSettle();
    expect(reports.calls.last.customer, isNull);
    expect(reports.calls.last.page, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final (width, expanded) in [(375.0, false), (1280.0, true)]) {
    testWidgets('first frame at $width already has its filter state',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(FakeReports(), CapturingExport()));
      // Only the first frame: no post-frame callback has run yet.
      expect(find.byType(FilterPanel), expanded ? findsOneWidget : findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(FilterPanel), expanded ? findsOneWidget : findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final width in [375.0, 768.0, 1280.0]) {
    testWidgets('shared report layout and filters at $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final reports = FakeReports(), capture = CapturingExport();
      final boundaryKey = GlobalKey();
      final fontDirectory =
          Platform.environment['PRODUCT_SALES_FONT_DIRECTORY'];
      if (Platform.environment['PRODUCT_SALES_CAPTURE'] != null &&
          fontDirectory != null) {
        await tester.runAsync(() async {
          for (final font in ['Roboto', 'MaterialIcons']) {
            final path = font == 'Roboto'
                ? '$fontDirectory/Roboto-Regular.ttf'
                : '$fontDirectory/MaterialIcons-Regular.otf';
            final loader = FontLoader(font)
              ..addFont(Future.value(
                  ByteData.sublistView(await File(path).readAsBytes())));
            await loader.load();
          }
        });
      }
      await tester.pumpWidget(app(reports, capture, captureKey: boundaryKey));
      await tester.pumpAndSettle();
      expect(find.byType(ListPageScaffold<ProductSalesReportEntry>),
          findsOneWidget);
      expect(find.text('SAR 76.88'), findsOneWidget);
      expect(find.text('7.500'), findsOneWidget);
      final summaryIcons = tester.widgetList<AppIconTile>(find.descendant(
          of: find.byKey(const ValueKey('product-sales-report-summary')),
          matching: find.byType(AppIconTile)));
      expect(summaryIcons.length, 2);
      expect(
          summaryIcons.every((icon) =>
              icon.iconSize == AppSizes.metricIcon &&
              icon.foreground == AppColors.primary),
          isTrue);
      if (width < 700) {
        expect(find.byType(FilterPanel), findsNothing);
        expect(find.byType(AppListCard), findsWidgets);
        await tapFilterToggle(tester);
      }
      expect(picker(tester, 'product').dropdownMenuEntries.length, 3);
      picker(tester, 'category').onSelected!(categoryOption);
      await tester.pumpAndSettle();
      expect(reports.calls.last.category, '88');
      expect(picker(tester, 'product').dropdownMenuEntries.length, 2);
      picker(tester, 'product').onSelected!(productOption);
      await tester.pumpAndSettle();
      picker(tester, 'customer').onSelected!(customerOption);
      await tester.pumpAndSettle();
      expect(reports.calls.last.product, '9');
      expect(reports.calls.last.customer, '7');
      await tester.tap(find.text('Reset').first);
      await tester.pumpAndSettle();
      expect(reports.calls.last.category, isNull);
      expect(reports.calls.last.product, isNull);
      expect(reports.calls.last.customer, isNull);
      expect(find.text('Select Date'), findsNWidgets(2));
      expect(picker(tester, 'product').dropdownMenuEntries.length, 3);
      expect(reports.calls.every((r) => !r.update), isTrue);
      // Optional fixture captures, stored outside the repository.
      final directory = Platform.environment['PRODUCT_SALES_CAPTURE'];
      if (directory != null) {
        if (width < 700) {
          await tapFilterToggle(tester);
          await tester.pumpAndSettle();
        }
        final boundary = boundaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
        final image = (await tester.runAsync(() => boundary.toImage()))!;
        final bytes = await tester
            .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
        await tester.runAsync(() async {
          await Directory(directory).create(recursive: true);
          await File('$directory/after-${width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        });
        image.dispose();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'actual searchable menu selection dismissal and Reset keep the report mounted',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final reports = FakeReports();
    await tester.pumpWidget(app(reports, CapturingExport()));
    await tester.pumpAndSettle();
    final field = find.descendant(
        of: find.byKey(const ValueKey('product-sales-category-picker')),
        matching: find.byType(TextField));
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, 'Jui');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Juice').last);
    await tester.pumpAndSettle();
    expect(reports.calls.last.category, '88');
    expect(find.byType(ProductSalesReportPage), findsOneWidget);
    await tester.tap(find.text('Reset').first);
    await tester.pumpAndSettle();
    expect(reports.calls.last.category, isNull);
    expect(find.byType(ProductSalesReportPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'failed reload clears old totals, disables shared Export and Retry recovers',
      (tester) async {
    final reports = FakeReports();
    await tester.pumpWidget(app(reports, CapturingExport()));
    await tester.pumpAndSettle();
    reports.fail = true;
    final list = tester.widget<ListPageScaffold<ProductSalesReportEntry>>(
        find.byType(ListPageScaffold<ProductSalesReportEntry>));
    await list.onRefresh!();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('product-sales-report-error')),
        findsOneWidget);
    expect(find.byType(AppMetricStrip), findsNothing);
    expect(
        tester.widget<PageHeader>(find.byType(PageHeader)).actions[1].onPressed,
        isNull);
    reports.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('product-sales-report-error')), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'filter-only outage keeps sales and Export usable with independent Retry',
      (tester) async {
    final customers = FakeCustomers()..fail = true;
    final reports = FakeReports();
    await tester
        .pumpWidget(app(reports, CapturingExport(), customers: customers));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('product-sales-filter-options-error')),
        findsOneWidget);
    expect(
        tester.widget<PageHeader>(find.byType(PageHeader)).actions[1].onPressed,
        isNotNull);
    customers.fail = false;
    final requests = reports.calls.length;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(customers.calls, 2);
    expect(reports.calls.length, requests);
    expect(find.byKey(const ValueKey('product-sales-filter-options-error')),
        findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'shared Export captures all matching pages as numeric workbook cells',
      (tester) async {
    final reports = FakeReports(), capture = CapturingExport();
    await useTempExportDirectory(tester, 'product-sales-export');
    await tester.pumpWidget(app(reports, capture));
    await tester.pumpAndSettle();
    tester.widget<PageHeader>(find.byType(PageHeader)).actions[1].onPressed!();
    await tester.pumpAndSettle();
    final file = await tester.runAsync(capture.createFile!);
    final bytes = await tester.runAsync(() => file!.readAsBytes());
    final sheet = Excel.decodeBytes(bytes!).tables['Product Sales']!;
    expect(sheet.rows.length, 4);
    expect(sheet.rows[1][2]!.value, const DoubleCellValue(10.25));
    expect(sheet.rows[1][3]!.value, const DoubleCellValue(25.625));
    expect(sheet.rows[1][4]!.value, const DoubleCellValue(2.5));
    expect(reports.calls.where((v) => v.size == 250).map((v) => v.page),
        [1, 2, 3]);
    expect(reports.productSalesReport, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
