import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';
import 'package:pos_machine/features/reports/presentation/widgets/customer_report/details/customer_report_details_filters.dart';
import 'package:pos_machine/features/reports/presentation/widgets/customer_report/details/customer_report_details_results.dart';
import 'package:pos_machine/models/list_transaction.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/transaction_provider.dart';
import 'package:pos_machine/screens/reports/customer_transactions_reports/customer_transaction_details_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../test_support/app_translations.dart';
import '../../../../test_support/export_capture.dart';

class DetailsInvoices extends InvoiceProvider {
  Future<dynamic> Function()? respond;
  Future<dynamic> Function(int? page, bool update)? respondPage;
  final calls =
      <({String? id, String? name, String? type, int? page, bool update})>[];

  @override
  Future<dynamic> listAllTransaction({
    String? type,
    required String accessToken,
    String? customerId,
    String? customerName,
    String? transactionType,
    String? dateFrom,
    String? dateTo,
    int? page,
    bool updateState = true,
  }) async {
    calls.add((
      id: customerId,
      name: customerName,
      type: type,
      page: page,
      update: updateState
    ));
    return respondPage != null
        ? respondPage!(page, updateState)
        : respond == null
            ? response()
            : respond!();
  }
}

Map<String, dynamic> transaction(int id, String kind, String type, String date,
        {String status = 'SUCC'}) =>
    {
      'id': id,
      'order_number': 'ROW-$id',
      'transaction_type': kind,
      'type': type,
      'date': date,
      'amount': id == 1 ? 10.25 : 2,
      'balance': 8.25,
      'reference': 'REF-$id',
      'status': status,
    };

Map<String, dynamic> response() => {
      'status': 'success',
      'data': {
        'data': [
          {
            'customer_id': 99,
            'customer_name': 'Twin',
            'transactions': [transaction(99, 'Invoice', 'debit', '2026-10-11')],
          },
          {
            'customer_id': 42,
            'customer_name': 'Twin',
            'transactions': [
              transaction(1, 'Receipt', 'credit', '2026-10-12'),
              transaction(2, 'Invoice', 'debit', '2026-10-13'),
              transaction(3, 'Voucher', 'credit', '2026-10-14', status: 'FAIL'),
            ],
          },
        ],
      },
    };

class DetailsTranslations extends EnglishTranslations {
  @override
  Map<String, Map<String, String>> get keys {
    final translations = super.keys;
    void flatten(Map<String, dynamic> values, String prefix,
        Map<String, String> output) {
      for (final entry in values.entries) {
        final key = '$prefix.${entry.key}';
        if (entry.value is Map<String, dynamic>) {
          flatten(entry.value as Map<String, dynamic>, key, output);
        } else {
          output[key] = entry.value.toString();
        }
      }
    }

    for (final lang in ['ar', 'ml']) {
      final output = <String, String>{};
      for (final section in [
        'customer_transaction_report',
        'transaction_status_labels',
        'list',
        'general',
      ]) {
        flatten(translationSection(lang, section), section, output);
      }
      translations[lang] = output;
    }
    return translations;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config =
        jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    final flutter = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['name'] == 'flutter');
    final fontRoot = configFile.uri
        .resolve('${flutter['rootUri']}/')
        .resolve('../../bin/cache/artifacts/material_fonts/');
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(File.fromUri(fontRoot.resolve(entry.value))
            .readAsBytes()
            .then(ByteData.sublistView));
      await loader.load();
    }
    final arabic = FontLoader('NotoSansArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    await arabic.load();
  });
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({'api_key': 'fixture'});
  });
  tearDown(Get.reset);

  Future<DetailsInvoices> mount(
    WidgetTester tester, {
    DetailsInvoices? invoices,
    String? selectedId = '42',
    String selectedName = 'Twin',
    Size size = const Size(1440, 900),
    String locale = 'en',
    bool settle = true,
    double? contentWidth,
    double textScale = 1,
    ExportController? export,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = invoices ?? DetailsInvoices();
    final customers = CustomerProvider()..setSelectedCustomerId(selectedId);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthModel()..login('fixture', 1)),
        ChangeNotifierProvider<CustomerProvider>.value(value: customers),
        ChangeNotifierProvider<InvoiceProvider>.value(value: provider),
        ChangeNotifierProvider(
            create: (_) =>
                TransactionProvider()..setCustomerName(selectedName)),
      ],
      child: GetMaterialApp(
        theme: ThemeData(fontFamilyFallback: const ['NotoSansArabic']),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!),
        translations: DetailsTranslations(),
        locale: Locale(locale),
        fallbackLocale: const Locale('en'),
        home: Scaffold(
            body: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                    width: contentWidth,
                    child: RepaintBoundary(
                        key: const ValueKey('details-capture'),
                        child:
                            SimpleTransactionDetailsScreen(export: export))))),
      ),
    ));
    addTearDown(customers.dispose);
    addTearDown(provider.dispose);
    if (settle) await tester.pumpAndSettle();
    return provider;
  }

  dynamic state(WidgetTester tester) =>
      tester.state(find.byType(SimpleTransactionDetailsScreen));
  List<ListTransaction> rows(WidgetTester tester) =>
      List<ListTransaction>.from(state(tester).filteredTransactions);

  Future<void> choose(WidgetTester tester, int index, String value) async {
    final fields = tester
        .widgetList<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>))
        .toList();
    fields[index].onChanged!(value);
    await tester.pumpAndSettle();
  }

  HeaderAction exportAction(WidgetTester tester) =>
      tester.widget<PageHeader>(find.byType(PageHeader)).actions.firstWhere(
          (action) => action.key == SimpleTransactionDetailsScreen.exportKey);

  Map<String, dynamic> paginatedResponse() {
    final value = response();
    value['data'] = {
      ...Map<String, dynamic>.from(value['data'] as Map),
      'current_page': 1,
      'last_page': 1,
      'per_page': 20,
      'total': 2,
    };
    return value;
  }

  testWidgets(
      'shared export builds every matching page as numeric Excel cells without changing display',
      (tester) async {
    final capture = CapturingExport();
    addTearDown(capture.dispose);
    final provider = DetailsInvoices()
      ..respondPage = (page, update) async {
        if (update) return response();
        Map<String, dynamic> flat(int id,
                {int customer = 42, String kind = 'Receipt'}) =>
            {
              ...transaction(id, kind, 'credit', '2026-10-12'),
              'customer_id': customer,
              'customer_name': 'Twin'
            };
        return {
          'status': 'success',
          'data': {
            'data': page == 1
                ? [flat(1), flat(99, customer: 99)]
                : [flat(4), flat(2, kind: 'Invoice')],
            'current_page': page,
            'last_page': 2,
            'per_page': 20,
            'total': 4,
          }
        };
      };
    await mount(tester, invoices: provider, export: capture);
    await choose(tester, 0, 'Receipt');
    await choose(tester, 1, 'SUCC');
    await choose(tester, 2, 'Credit');
    final dateFields = tester
        .widgetList<CustomerReportDetailsDateField>(
            find.byType(CustomerReportDetailsDateField))
        .toList();
    dateFields[0].onChanged(DateTime(2026, 10, 12));
    dateFields[1].onChanged(DateTime(2026, 10, 12));
    await tester.pumpAndSettle();
    final visible = state(tester).filteredTransactions;
    final providerVisible = provider.transactionListDetails;
    await tester.tap(find.byKey(SimpleTransactionDetailsScreen.exportKey));
    await tester.pump();
    expect(capture.runs, 1);
    await useTempExportDirectory(tester, 'customer-report-details-');
    final file = (await tester.runAsync(capture.createFile!))!;
    final sheet =
        Excel.decodeBytes(file.readAsBytesSync()).tables.values.single;
    expect(sheet.maxRows, 3);
    expect(sheet.rows[1][0]?.value, const IntCellValue(42));
    expect(sheet.rows[1][1]?.value.toString(), 'Twin');
    expect(sheet.rows[1][3]?.value.toString(), 'ROW-1');
    expect(sheet.rows[2][3]?.value.toString(), 'ROW-4');
    expect(sheet.rows[1][5]?.value, const DoubleCellValue(10.25));
    expect(sheet.rows[1][9]?.value.toString(), '2026-10-12');
    expect(sheet.rows[1][10]?.value.toString(), '2026-10-12');
    expect(provider.calls.skip(1).map((c) => c.page), [1, 2]);
    expect(
        provider.calls
            .skip(1)
            .every((c) => !c.update && c.id == '42' && c.name == null),
        true);
    expect(identical(state(tester).filteredTransactions, visible), true);
    expect(identical(provider.transactionListDetails, providerVisible), true);
  });

  testWidgets(
      'Reset keeps selected customer metadata for export and phone menu exposes Export',
      (tester) async {
    final capture = CapturingExport();
    addTearDown(capture.dispose);
    final provider = DetailsInvoices()
      ..respondPage =
          (_, update) async => update ? response() : paginatedResponse();
    await mount(tester, invoices: provider, export: capture);
    await choose(tester, 0, 'Receipt');
    tester.widget<FilterPanel>(find.byType(FilterPanel)).onReset();
    await tester.pumpAndSettle();
    exportAction(tester).onPressed!();
    await useTempExportDirectory(tester, 'customer-details-reset-');
    final file = (await tester.runAsync(capture.createFile!))!;
    final sheet =
        Excel.decodeBytes(file.readAsBytesSync()).tables.values.single;
    expect(sheet.maxRows, 4);
    expect(sheet.rows.skip(1).every((r) => r[1]?.value.toString() == 'Twin'),
        true);
    await tester.pumpWidget(const SizedBox());
    await mount(tester, export: capture, size: const Size(390, 844));
    await tester.tap(find.byKey(PageHeader.moreActionsKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(capture.runs, 2);
  });

  testWidgets(
      'Export disabled for empty, loading and failed refresh; retry restores it',
      (tester) async {
    final provider = await mount(tester);
    expect(exportAction(tester).onPressed, isNotNull);
    await choose(tester, 1, 'INIT');
    expect(exportAction(tester).onPressed, isNull);
    await choose(tester, 1, '');
    final pending = Completer<dynamic>();
    provider.respond = () => pending.future;
    final load = state(tester).loadInitData() as Future<void>;
    await tester.pump();
    expect(exportAction(tester).onPressed, isNull);
    pending.complete({'status': 'failed'});
    await load;
    await tester.pumpAndSettle();
    expect(rows(tester).length, 3);
    expect(exportAction(tester).onPressed, isNull);
    provider.respond = null;
    await state(tester).loadInitData();
    await tester.pumpAndSettle();
    expect(exportAction(tester).onPressed, isNotNull);
  });

  for (final change in [
    'filter',
    'refresh',
    'customer',
    'store',
    'tenant',
    'token',
    'dispose'
  ]) {
    testWidgets(
        'pending export cancels safely after $change and blocks repeated clicks',
        (tester) async {
      final pending = Completer<dynamic>();
      var deliveries = 0;
      final export = ExportController(
          deliver: (context, file,
                  {required mimeType, shareText, shareOrigin, onStage}) async =>
              deliveries++);
      addTearDown(export.dispose);
      final provider = DetailsInvoices()
        ..respondPage =
            (_, update) async => update ? response() : pending.future;
      await mount(tester, invoices: provider, export: export);
      final screenContext =
          tester.element(find.byType(SimpleTransactionDetailsScreen));
      await tester.tap(find.byKey(SimpleTransactionDetailsScreen.exportKey));
      await tester.pump();
      expect(export.busy, true);
      expect(exportAction(tester).onPressed, isNull);
      switch (change) {
        case 'filter':
          tester
              .widgetList<DropdownButtonFormField<String>>(
                  find.byType(DropdownButtonFormField<String>))
              .first
              .onChanged!('Invoice');
        case 'refresh':
          await state(tester).loadInitData();
        case 'customer':
          screenContext.read<CustomerProvider>().setSelectedCustomerId('99');
        case 'store':
          await (await SharedPreferences.getInstance())
              .setInt('active_store_id', 32);
        case 'tenant':
          await (await SharedPreferences.getInstance())
              .setString('api_key', 'changed');
        case 'token':
          screenContext.read<AuthModel>().login('changed', 2);
        case 'dispose':
          await tester.pumpWidget(const SizedBox());
      }
      pending.complete(paginatedResponse());
      await tester.pumpAndSettle();
      expect(deliveries, 0);
      expect(export.busy, false);
      expect(tester.takeException(), isNull);
      expect(provider.calls.where((c) => !c.update).length, 1);
    });
  }

  testWidgets(
      'incomplete export shows shared error without Save As or changing rows',
      (tester) async {
    var deliveries = 0;
    final export = ExportController(
        deliver: (context, file,
                {required mimeType, shareText, shareOrigin, onStage}) async =>
            deliveries++);
    addTearDown(export.dispose);
    final provider = DetailsInvoices()
      ..respondPage =
          (_, update) async => update ? response() : {'status': 'failed'};
    await mount(tester, invoices: provider, export: export);
    await tester.tap(find.byKey(SimpleTransactionDetailsScreen.exportKey));
    await tester.pumpAndSettle();
    expect(deliveries, 0);
    expect(export.busy, false);
    expect(rows(tester).map((row) => row.id), [1, 2, 3]);
    expect(find.text('Could not export the complete report. Please try again.'),
        findsOneWidget);
  });

  testWidgets(
      'shared controller delivers the completed workbook and releases busy state',
      (tester) async {
    File? delivered;
    String? deliveredMime;
    final export = ExportController(deliver: (context, file,
        {required mimeType, shareText, shareOrigin, onStage}) async {
      deliveredMime = mimeType;
      onStage?.call('Waiting for Save As');
      delivered = file;
    });
    addTearDown(export.dispose);
    final provider = DetailsInvoices()
      ..respondPage =
          (_, update) async => update ? response() : paginatedResponse();
    await mount(tester, invoices: provider, export: export);
    await useTempExportDirectory(tester, 'customer-details-delivery-');
    await tester.tap(find.byKey(SimpleTransactionDetailsScreen.exportKey));
    await tester.pump();
    // Let real isolate/file IO run, then drain plugin replies in fake async.
    for (var attempt = 0; delivered == null && attempt < 200; attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
    expect(delivered, isNotNull, reason: 'Export stage: ${export.stage}');
    final file = delivered!;
    await tester.pumpAndSettle();
    expect(deliveredMime, FileExportService.xlsxMimeType);
    expect(
        Excel.decodeBytes(file.readAsBytesSync()).tables.values.single.maxRows,
        4);
    expect(export.busy, false);
    expect(export.stage, isNull);
    expect(exportAction(tester).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'excessive pagination releases Export and a corrected retry succeeds',
      (tester) async {
    var deliveries = 0;
    final export = ExportController(deliver: (context, file,
        {required mimeType, shareText, shareOrigin, onStage}) async {
      expect(
          Excel.decodeBytes(file.readAsBytesSync())
              .tables
              .values
              .single
              .maxRows,
          4);
      deliveries++;
    });
    addTearDown(export.dispose);
    final provider = DetailsInvoices()
      ..respondPage = (page, update) async {
        if (update) return response();
        if (page != 1) throw StateError('Unexpected extra page request.');
        final value = paginatedResponse();
        (value['data'] as Map)['last_page'] = 1001;
        return value;
      };
    await mount(tester, invoices: provider, export: export);
    await tester.tap(find.byKey(SimpleTransactionDetailsScreen.exportKey));
    await tester.pumpAndSettle();
    expect(
        provider.calls.where((call) => !call.update).map((call) => call.page),
        [1]);
    expect(deliveries, 0);
    expect(export.busy, isFalse);
    expect(export.stage, isNull);
    expect(rows(tester).map((row) => row.id), [1, 2, 3]);
    expect(exportAction(tester).onPressed, isNotNull);
    expect(find.text('Could not export the complete report. Please try again.'),
        findsOneWidget);
    provider.respondPage =
        (_, update) async => update ? response() : paginatedResponse();
    await useTempExportDirectory(tester, 'customer-details-page-limit-');
    await tester.tap(find.byKey(SimpleTransactionDetailsScreen.exportKey));
    await tester.pump();
    for (var attempt = 0; deliveries == 0 && attempt < 200; attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(deliveries, 1);
    expect(export.busy, isFalse);
    expect(export.stage, isNull);
    expect(rows(tester).map((row) => row.id), [1, 2, 3]);
    expect(exportAction(tester).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'selected ID keeps same-name customers separate and retains request contract',
      (tester) async {
    final provider = await mount(tester);
    expect(provider.calls.single,
        (id: '42', name: null, type: null, page: null, update: true));
    expect(rows(tester).map((t) => t.id), [1, 2, 3]);
    expect(rows(tester).first.amount, '10.25');
    expect(rows(tester).first.balance, '8.25');
    expect(rows(tester).first.referenceId, 'REF-1');
    expect(rows(tester).every((t) => t.customerId == 42), true);
    expect(find.text('ROW-99'), findsNothing);
  });

  testWidgets('missing selection ID retains case-insensitive name fallback',
      (tester) async {
    final provider =
        await mount(tester, selectedId: null, selectedName: 'tWiN');
    expect(provider.calls.single.name, 'tWiN');
    expect(rows(tester).single.id, 99);
  });

  testWidgets(
      'combined dropdowns, inclusive date range, Reset and reload preserve behavior',
      (tester) async {
    final provider = await mount(tester);
    await choose(tester, 0, 'Receipt');
    await choose(tester, 1, 'SUCC');
    await choose(tester, 2, 'Credit');
    expect(rows(tester).map((t) => t.id), [1]);
    final dates = tester
        .widgetList<CustomerReportDetailsDateField>(
            find.byType(CustomerReportDetailsDateField))
        .toList();
    dates[0].onChanged(DateTime(2026, 10, 12));
    dates[1].onChanged(DateTime(2026, 10, 12));
    await tester.pumpAndSettle();
    expect(rows(tester).map((t) => t.id), [1]);
    await state(tester).loadInitData();
    await tester.pumpAndSettle();
    expect(rows(tester).map((t) => t.id), [1]);
    expect(provider.calls.length, 2);
    await tester.tap(find.text('customer_transaction_report.reset'.tr));
    await tester.pumpAndSettle();
    expect(rows(tester).map((t) => t.id), [1, 2, 3]);
    expect(state(tester).searchCustomer, '');
    expect(
        tester
            .widget<CustomerReportDetailsDateField>(
                find.byKey(SimpleTransactionDetailsScreen.fromKey))
            .value,
        isNull);
    expect(
        tester
            .widget<CustomerReportDetailsDateField>(
                find.byKey(SimpleTransactionDetailsScreen.toKey))
            .value,
        isNull);
    expect(
        tester
            .widgetList<DropdownButtonFormField<String>>(
                find.byType(DropdownButtonFormField<String>))
            .every((field) => field.initialValue == ''),
        true);
    expect(provider.calls.length, 2);
    await state(tester).loadInitData();
    await tester.pumpAndSettle();
    expect(provider.calls.last.id, '42');
    expect(rows(tester).map((t) => t.id), [1, 2, 3]);
  });

  testWidgets(
      'failed refresh and recovery retain previous rows and release loading',
      (tester) async {
    final provider = await mount(tester);
    provider.respond = () async => {'status': 'failed', 'message': 'fixture'};
    await state(tester).loadInitData();
    await tester.pumpAndSettle();
    expect(rows(tester).length, 3);
    expect(state(tester).initLoading, false);
    provider.respond = () async => throw const FormatException('fixture');
    await state(tester).loadInitData();
    await tester.pumpAndSettle();
    expect(rows(tester).length, 3);
    expect(state(tester).initLoading, false);
    provider.respond = () async => response();
    await state(tester).loadInitData();
    await tester.pumpAndSettle();
    expect(rows(tester).length, 3);
  });

  testWidgets('empty selection, back route and disposal during a pending load',
      (tester) async {
    await mount(tester, selectedId: '777');
    expect(rows(tester), isEmpty);
    await tester.tap(find.byKey(SimpleTransactionDetailsScreen.backKey));
    expect(Get.find<SideBarController>().index.value,
        SideBarController.customerTransactionsReportScreenIndex);
    final pending = Completer<dynamic>();
    final provider = DetailsInvoices()..respond = () => pending.future;
    // Dispose a settled screen before mounting a new one with an outstanding request.
    await tester.pumpWidget(const SizedBox());
    await mount(tester, invoices: provider, settle: false);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete(response());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(Get.find<SideBarController>().index.value, isNot(66));
  });

  testWidgets(
      'All selection, filter visibility and refresh retain applied rows',
      (tester) async {
    final provider = await mount(tester);
    await choose(tester, 0, 'Receipt');
    await tester
        .tap(find.byKey(SimpleTransactionDetailsScreen.filterToggleKey));
    await tester.pumpAndSettle();
    expect(rows(tester).map((t) => t.id), [1]);
    expect(find.byKey(SimpleTransactionDetailsScreen.filtersKey), findsNothing);
    await tester.tap(find.byKey(SimpleTransactionDetailsScreen.refreshKey));
    await tester.pumpAndSettle();
    expect(provider.calls.length, 2);
    expect(rows(tester).map((t) => t.id), [1]);
    await tester
        .tap(find.byKey(SimpleTransactionDetailsScreen.filterToggleKey));
    await tester.pumpAndSettle();
    final field = find.byType(DropdownButtonFormField<String>).first;
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text('customer_transaction_report.all'.tr).last);
    await tester.pumpAndSettle();
    expect(rows(tester).map((t) => t.id), [1, 2, 3]);
    expect(provider.calls.length, 2);
    expect(find.byKey(SimpleTransactionDetailsScreen.printKey), findsOneWidget);
  });

  testWidgets(
      'date-only calendar selection and cancel preserve inclusive bounds',
      (tester) async {
    await mount(tester);
    final from = find.byKey(SimpleTransactionDetailsScreen.fromKey);
    // Seed a month to make actual calendar selection deterministic.
    tester
        .widget<CustomerReportDetailsDateField>(from)
        .onChanged(DateTime(2026, 10, 11));
    await tester.pumpAndSettle();
    await tester.tap(from);
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    final calendar =
        tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
    expect(calendar.firstDate, DateTime(2000));
    expect(calendar.lastDate, DateTime(2101));
    await tester.tap(find.descendant(
        of: find.byType(CalendarDatePicker), matching: find.text('13')));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(rows(tester).map((t) => t.id), [2, 3]);
    expect(tester.widget<CustomerReportDetailsDateField>(from).value,
        DateTime(2026, 10, 13));
    await tester.tap(from);
    await tester.pumpAndSettle();
    await tester.tap(find.text('general.cancel'.tr));
    await tester.pumpAndSettle();
    expect(rows(tester).map((t) => t.id), [2, 3]);
  });

  testWidgets('empty results use shared state and Reset restores visible rows',
      (tester) async {
    await mount(tester);
    await choose(tester, 0, 'Invoice');
    await choose(tester, 1, 'FAIL');
    expect(find.byType(AppEmptyState), findsOneWidget);
    await tester.tap(find.text('customer_transaction_report.reset'.tr));
    await tester.pumpAndSettle();
    expect(rows(tester).map((t) => t.id), [1, 2, 3]);
    expect(find.byType(AppEmptyState), findsNothing);
  });

  testWidgets(
      'narrow desktop panel and long source values stay readable without overflow',
      (tester) async {
    final payload = response();
    final tx =
        payload['data']['data'][1]['transactions'][0] as Map<String, dynamic>;
    tx['order_number'] =
        'A very long order number with several repeated segments 1234567890';
    tx['status'] = 'A custom backend status with a long description';
    tx['transaction_type'] = 'A long custom transaction type from the backend';
    tx['amount'] = '1234567890.123456';
    final provider = DetailsInvoices()..respond = () async => payload;
    await mount(tester, invoices: provider, contentWidth: 650, textScale: 1.3);
    expect(find.byType(CustomerReportDetailsCard), findsWidgets);
    expect(find.text('1234567890.123456'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('customer_transaction_report.reset'.tr));
    await tester.pumpAndSettle();
    expect(rows(tester).length, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'pending reload shows shared loading and restores the filtered table',
      (tester) async {
    final provider = await mount(tester);
    await choose(tester, 0, 'Receipt');
    final pending = Completer<dynamic>();
    provider.respond = () => pending.future;
    await tester.tap(find.byKey(SimpleTransactionDetailsScreen.refreshKey));
    await tester.pump();
    expect(find.byType(AppLoadingView), findsOneWidget);
    pending.complete(response());
    await tester.pumpAndSettle();
    expect(find.byType(AppLoadingView), findsNothing);
    expect(rows(tester).map((t) => t.id), [1]);
  });

  for (final (label, size, locale) in [
    ('desktop', const Size(1440, 900), 'en'),
    ('phone', const Size(375, 812), 'en'),
    ('tablet', const Size(768, 900), 'en'),
    ('short', const Size(1280, 500), 'en'),
    ('arabic', const Size(1440, 900), 'ar'),
    ('malayalam-phone', const Size(375, 812), 'ml'),
  ]) {
    testWidgets('shared $label layout and controls remain usable',
        (tester) async {
      await mount(tester, size: size, locale: locale);
      expect(find.byType(ListPageScaffold<ListTransaction>), findsOneWidget);
      expect(find.byType(PageHeader), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (size.width < PageHeader.collapseActionsBelow) {
        await tester.tap(find.byKey(PageHeader.moreActionsKey));
        await tester.pumpAndSettle();
        await tester.tap(find.text('list.filters'.tr).last);
        await tester.pumpAndSettle();
      }
      expect(find.byType(FilterPanel), findsOneWidget);
      expect(tester.takeException(), isNull);
      await choose(tester, 0, 'Receipt');
      expect(rows(tester).map((t) => t.id), [1]);
      final reset = find.text('customer_transaction_report.reset'.tr);
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(rows(tester).map((t) => t.id), [1, 2, 3]);
      expect(tester.takeException(), isNull);
      if (Platform.environment['CUSTOMER_REPORT_DETAILS_CAPTURE'] != 'shared') {
        return;
      }
      final directory = Directory(
          '${Platform.environment['LOCALAPPDATA']}/Temp/customer-report-details-shared')
        ..createSync(recursive: true);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('details-capture')));
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
        image.dispose();
        return bytes;
      });
      File('${directory.path}/$label.png').writeAsBytesSync(bytes!);
    });
  }
}
