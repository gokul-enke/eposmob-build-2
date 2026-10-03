import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/core/ui/ui.dart';
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
  Future<void> fetchCustomers(
      {required String accessToken,
      String? customerName,
      bool listAll = true}) async {}
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
      _FakeCustomers? customers}) async {
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
            translations: EnglishTranslations(),
            locale: const Locale('en'),
            home: Scaffold(
                body: CustomerTransactionsReportPage(export: capture)))));
    await tester.pumpAndSettle();
    return provider;
  }

  ListPageScaffold<CustomerReportRow> scaffold(WidgetTester tester) =>
      tester.widget(find.byType(ListPageScaffold<CustomerReportRow>));

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

  testWidgets('Reset clears the selected customer and reloads page 1',
      (tester) async {
    final customers = _FakeCustomers()..setSelectedCustomerId('42');
    final invoices = await mount(tester, customers: customers);
    expect(invoices.calls.last.customer, '42');

    await tester.tap(find.descendant(
        of: find.byKey(CustomerTransactionsReportPage.filtersKey),
        matching: find.text('Reset')));
    await tester.pumpAndSettle();
    expect(customers.selectedCustomerId, isNull);
    expect(invoices.calls.last.customer, isNull);
    expect(invoices.calls.last.page, 1);
  });

  testWidgets('the workbook has every page with the filters and numbers',
      (tester) async {
    final customers = _FakeCustomers()..setSelectedCustomerId('42');
    final invoices = _FakeInvoices()
      ..handler = (p) async =>
          customerReportResponse(p, [customerGroup(p)], last: 2, total: 2);
    await mount(tester, invoices: invoices, customers: customers);
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
    expect(invoices.calls.map((c) => c.page).toList(), [1, 1, 2]);
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
