import 'package:dropdown_search/dropdown_search.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';
import 'package:pos_machine/features/reports/domain/customer_report.dart';
import 'package:pos_machine/features/reports/presentation/pages/customer_transactions_report_page.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/transaction_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../test_support/app_translations.dart';
import '../../../../test_support/export_capture.dart';
import '../../support/report_fixtures.dart';

typedef _Call = ({int page, String? customer, String? from, bool update});

class _FakeInvoices extends InvoiceProvider {
  final calls = <_Call>[];
  Future<dynamic> Function(int page)? handler;

  @override
  Future<dynamic> listAllTransaction(
      {String? type,
      required String accessToken,
      String? customerId,
      String? customerName,
      String? transactionType,
      String? dateFrom,
      String? dateTo,
      int? page,
      bool updateState = true}) async {
    calls.add((
      page: page ?? 1,
      customer: customerId,
      from: dateFrom,
      update: updateState
    ));
    return handler == null
        ? customerReportResponse(page ?? 1, [customerGroup(page ?? 1)])
        : handler!(page ?? 1);
  }
}

class _FakeCustomers extends CustomerProvider {
  @override
  List<CustomerListModelData>? get allCustomers => [
        CustomerListModelData(id: 42, name: 'Customer'),
        CustomerListModelData(id: 99, name: 'Profile customer')
      ];

  @override
  Future<void> fetchCustomers(
      {required String accessToken,
      String? customerName,
      bool listAll = true}) async {}
}

class _ReportRouteObserver extends NavigatorObserver {
  final popped = <Route<dynamic>>[];

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popped.add(route);
    super.didPop(route, previousRoute);
  }
}

void main() {
  late CapturingExport capture;

  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({'api_key': 'test'});
    capture = CapturingExport();
  });
  tearDown(Get.reset);

  Future<_FakeInvoices> mount(WidgetTester tester,
      {Size size = const Size(1440, 900),
      _FakeInvoices? invoices,
      _FakeCustomers? customers,
      NavigatorObserver? observer}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = invoices ?? _FakeInvoices();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthModel()..login('test', 1)),
          ChangeNotifierProvider<CustomerProvider>.value(
              value: customers ?? _FakeCustomers()),
          ChangeNotifierProvider<InvoiceProvider>.value(value: provider),
          ChangeNotifierProvider(create: (_) => TransactionProvider())
        ],
        child: GetMaterialApp(
            navigatorObservers: [if (observer != null) observer],
            translations: EnglishTranslations(),
            locale: const Locale('en'),
            home: Scaffold(
                body: CustomerTransactionsReportPage(export: capture)))));
    await tester.pumpAndSettle();
    return provider;
  }

  ListPageScaffold<CustomerReportRow> scaffold(WidgetTester tester) =>
      tester.widget(find.byType(ListPageScaffold<CustomerReportRow>));

  DropdownSearch<CustomerListModelData> picker(WidgetTester tester) =>
      tester.widget(find.byType(DropdownSearch<CustomerListModelData>));

  /// Picks customer [id] in the report's own customer filter.
  Future<void> choose(WidgetTester tester, int id) async {
    picker(tester).onChanged!(CustomerListModelData(id: id, name: 'Customer'));
    await tester.pumpAndSettle();
  }

  for (final width in [375.0, 768.0, 1280.0]) {
    testWidgets(
        'real customer popup search/select/clear/Reset at $width keeps report route',
        (tester) async {
      final routes = _ReportRouteObserver();
      final customers = _FakeCustomers()..setSelectedCustomerId('42');
      final invoices = await mount(tester,
          size: Size(width, 900), customers: customers, observer: routes);
      if (width < 700) {
        tester
            .widget<PageHeader>(find.byType(PageHeader))
            .actions
            .first
            .onPressed!();
        await tester.pumpAndSettle();
      }
      expect(find.text('Select Date'), findsNWidgets(2));
      final field = find.byType(DropdownSearch<CustomerListModelData>);
      final originalState =
          tester.state<DropdownSearchState<CustomerListModelData>>(field);
      Future<void> selectProfile({bool search = false}) async {
        await tester.tap(field);
        await tester.pumpAndSettle();
        final option = find.text('Profile customer').last;
        final material = tester
            .widgetList<Material>(
                find.ancestor(of: option, matching: find.byType(Material)))
            .firstWhere((widget) => widget.type == MaterialType.card);
        expect(material.color, AppColors.surface);
        expect(material.surfaceTintColor, AppColors.surface);
        expect(tester.widget<Text>(option).style!.fontSize,
            AppTextStyles.input.fontSize);
        if (search) {
          await tester.enterText(find.byType(TextField).last, 'Profile');
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
        }
        await tester.tap(find
            .ancestor(
                of: find.text('Profile customer').last,
                matching: find.byType(InkResponse))
            .first);
        await tester.pumpAndSettle();
        expect(find.byType(CustomerTransactionsReportPage), findsOneWidget);
        expect(routes.popped.every((route) => route is PopupRoute), isTrue);
        expect(tester.state<DropdownSearchState<CustomerListModelData>>(field),
            same(originalState));
        expect(originalState.getSelectedItem!.id, 99);
        expect(invoices.calls.last.customer, '99');
        expect(customers.selectedCustomerId, '42');
      }

      await selectProfile(search: true);
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(
          tester.widget<Text>(find.text('Profile customer').last).style!.color,
          AppColors.primary);
      expect(
          tester
              .widget<Ink>(find
                  .ancestor(
                      of: find.text('Profile customer').last,
                      matching: find.byType(Ink))
                  .first)
              .decoration,
          isA<BoxDecoration>().having(
              (value) => value.color, 'selected colour', AppColors.softBlue));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester
          .tap(find.descendant(of: field, matching: find.byIcon(Icons.clear)));
      await tester.pumpAndSettle();
      expect(originalState.getSelectedItem, isNull);
      expect(invoices.calls.last.customer, isNull);
      await selectProfile();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(originalState.getSelectedItem, isNull);
      expect(invoices.calls.last.customer, isNull);
      expect(find.text('All Customers'), findsOneWidget);
      expect(find.text('Select Date'), findsNWidgets(2));
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(routes.popped, hasLength(4));
      expect(routes.popped.every((route) => route is PopupRoute), isTrue);
      expect(find.byType(CustomerTransactionsReportPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  for (final size in const [
    Size(1440, 900),
    Size(1000, 700),
    Size(600, 900),
    Size(390, 650),
    Size(375, 300)
  ]) {
    testWidgets('lays out on the shared kit at $size', (tester) async {
      final invoices = await mount(tester, size: size);
      expect(scaffold(tester).items, hasLength(1));
      // The report must not replace the shared transactions list.
      expect(invoices.calls.single.update, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pagination loads the requested page', (tester) async {
    final invoices = _FakeInvoices()
      ..handler = (p) async =>
          customerReportResponse(p, [customerGroup(p, 'Page $p')], last: 2);
    await mount(tester, invoices: invoices);
    scaffold(tester).pagination!.onPageChanged(2);
    await tester.pumpAndSettle();
    expect(invoices.calls.last.page, 2);
    expect(scaffold(tester).items.single.name, 'Page 2');
  });

  testWidgets('a failed load shows Retry, which reloads that page',
      (tester) async {
    final invoices = _FakeInvoices()
      ..handler =
          (p) async => customerReportResponse(p, [customerGroup(p)], last: 2);
    await mount(tester, invoices: invoices);
    invoices.handler = (_) async => throw StateError('network');
    scaffold(tester).pagination!.onPageChanged(2);
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Could not load the report. Previous results remain visible.'),
        findsOneWidget);
    final exportButton = tester.widget<AppSquareIconButton>(
        find.byKey(CustomerTransactionsReportPage.exportKey));
    expect(exportButton.onPressed, isNull);

    invoices.handler =
        (p) async => customerReportResponse(p, [customerGroup(p)], last: 2);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(invoices.calls.last.page, 2);
    expect(scaffold(tester).pagination!.currentPage, 2);
  });

  testWidgets('View selects the customer by ID even when names match',
      (tester) async {
    final customers = _FakeCustomers();
    final invoices = _FakeInvoices()
      ..handler = (_) async =>
          customerReportResponse(1, [customerGroup(41), customerGroup(42)]);
    await mount(tester, invoices: invoices, customers: customers);
    await tester.tap(find.text('View').last);
    await tester.pumpAndSettle();
    expect(customers.selectedCustomerId, '42');
    expect(Get.find<SideBarController>().index.value,
        SideBarController.customerTransactionDetailsScreenIndex);
  });

  testWidgets('a customer selected in profiles never filters the report',
      (tester) async {
    final customers = _FakeCustomers()
      ..selectCustomer(CustomerListModelData(id: 99, name: 'Profile customer'));
    final invoices = _FakeInvoices()
      ..handler =
          (p) async => customerReportResponse(p, [customerGroup(p)], last: 2);
    await mount(tester, customers: customers, invoices: invoices);
    expect(invoices.calls.single.customer, isNull);
    expect(picker(tester).selectedItems, isEmpty);
    expect(customers.selectedCustomerId, '99');

    customers
        .selectCustomer(CustomerListModelData(id: 42, name: 'Other profile'));
    await tester.pumpAndSettle();
    scaffold(tester).pagination!.onPageChanged(2);
    await tester.pumpAndSettle();
    await scaffold(tester).onRefresh!();
    await tester.pumpAndSettle();
    expect(invoices.calls.every((c) => c.customer == null), isTrue);
  });

  testWidgets(
      'the report keeps its own customer and Reset leaves the profile one',
      (tester) async {
    final customers = _FakeCustomers()
      ..selectCustomer(CustomerListModelData(id: 99, name: 'Profile customer'));
    final invoices = await mount(tester, customers: customers);
    await choose(tester, 42);
    expect(invoices.calls.last.customer, '42');
    expect(customers.selectedCustomerId, '99');

    customers.setSelectedCustomerId('7');
    await tester.pumpAndSettle();
    await scaffold(tester).onRefresh!();
    await tester.pumpAndSettle();
    expect(invoices.calls.last.customer, '42');

    final from = tester
        .widget<FilterPanel>(
            find.byKey(CustomerTransactionsReportPage.filtersKey))
        .fields
        .whereType<DateTimeFilterField>()
        .first;
    from.onChanged(DateTime(2026, 9, 1, 10, 30));
    await tester.pumpAndSettle();
    expect(find.text('2026-09-01 10:30'), findsOneWidget);
    expect(
        tester
            .widget<InputDecorator>(find.descendant(
                of: find.byKey(CustomerTransactionsReportPage.fromKey),
                matching: find.byType(InputDecorator)))
            .isEmpty,
        isFalse);
    expect(invoices.calls.last.from, '2026-09-01 10:30:00');

    await tester.tap(find.descendant(
        of: find.byKey(CustomerTransactionsReportPage.filtersKey),
        matching: find.text('Reset')));
    await tester.pumpAndSettle();
    expect(invoices.calls.last.customer, isNull);
    expect(invoices.calls.last.page, 1);
    expect(customers.selectedCustomerId, '7');
    expect(find.text('2026-09-01 10:30'), findsNothing);
    expect(find.text('Select Date'), findsNWidgets(2));
    expect(
        tester
            .widget<InputDecorator>(find.descendant(
                of: find.byKey(CustomerTransactionsReportPage.fromKey),
                matching: find.byType(InputDecorator)))
            .isEmpty,
        isTrue);
  });

  testWidgets('coming back from View opens an unfiltered report',
      (tester) async {
    final customers = _FakeCustomers();
    final invoices = _FakeInvoices()
      ..handler = (_) async => customerReportResponse(1, [customerGroup(42)]);
    await mount(tester, customers: customers, invoices: invoices);
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(customers.selectedCustomerId, '42');

    await tester.pumpWidget(const SizedBox());
    await mount(tester, customers: customers, invoices: invoices);
    expect(invoices.calls.last.customer, isNull);
  });

  testWidgets('the workbook has every page with the filters and numbers',
      (tester) async {
    final invoices = _FakeInvoices()
      ..handler = (p) async =>
          customerReportResponse(p, [customerGroup(p)], last: 2, total: 2);
    await mount(tester, invoices: invoices);
    await choose(tester, 42);
    final visible = scaffold(tester).items;

    await tester.tap(find.byKey(CustomerTransactionsReportPage.exportKey));
    await tester.pump();
    await useTempExportDirectory(tester, 'customer-report-test-');
    final file = (await tester.runAsync(capture.createFile!))!;
    final sheet =
        Excel.decodeBytes(file.readAsBytesSync()).tables.values.single;
    expect(sheet.maxRows, 3);
    expect(sheet.rows[1][0]!.value, isA<TextCellValue>());
    expect(sheet.rows[1][2]!.value, const DoubleCellValue(12.125));
    expect(invoices.calls.map((c) => c.page).toList(), [1, 1, 1, 2]);
    expect(invoices.calls.every((c) => !c.update), isTrue);
    expect(invoices.calls.last.customer, '42');
    expect(scaffold(tester).items, same(visible));
  });

  test('report labels exist in every language', () {
    for (final lang in ['en', 'ar', 'ml']) {
      final section = translationSection(lang, 'customer_transaction_report');
      for (final key in [
        'subtitle',
        'find',
        'filter_hint',
        'load_error',
        'retry',
        'customer_load_error',
        'export_tooltip',
        'export_error',
        'export_fetching',
        'count',
        'customer_id'
      ]) {
        expect(section[key], isA<String>(), reason: '$lang.$key');
      }
    }
  });
}
