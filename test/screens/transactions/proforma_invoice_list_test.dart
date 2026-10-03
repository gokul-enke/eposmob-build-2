import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/quotations_provider.dart';
import 'package:pos_machine/screens/transactions/proforma_invoice_list.dart';
import 'package:pos_machine/screens/transactions/widgets/common_details_dialog.dart';

class _Translations extends Translations {
  @override
  Map<String, Map<String, String>> get keys {
    final flat = <String, String>{};
    void flatten(Map<String, dynamic> data, String prefix) {
      for (final entry in data.entries) {
        final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
        if (entry.value is Map<String, dynamic>) {
          flatten(entry.value, key);
        } else {
          flat[key] = entry.value.toString();
        }
      }
    }

    flatten(
        jsonDecode(File('lib/resources/i18n/en.json').readAsStringSync()), '');
    return {'en': flat};
  }
}

Map<String, dynamic> row(int id, {String? name}) => {
      'id': id,
      'invoice_number': '000$id',
      'amount': '126.125',
      'invoice_date': '2026-10-01',
      'due_date': '2026-11-01',
      'status': 'pending',
      'customer': {'name': name ?? 'Customer $id'},
      'quotation': {'quotation_number': '000Q$id'},
      'items': []
    };
Map<String, dynamic> page(int number,
        {int last = 2, List<Map<String, dynamic>>? rows}) =>
    {
      'status': 'success',
      'data': {
        'current_page': number,
        'last_page': last,
        'data': rows ?? [row(number)]
      }
    };

/// Records the file factory the screen hands to the export instead of
/// creating and delivering the file, so tests can run it directly.
class _CapturingExport extends ExportController {
  Future<File> Function()? createFile;

  @override
  Future<bool> run(BuildContext context,
      {required Future<File> Function() createFile,
      String mimeType = FileExportService.xlsxMimeType,
      String? shareText,
      Rect? shareOrigin}) async {
    this.createFile = createFile;
    return true;
  }
}

class FakeProvider extends QuotationsProvider {
  final queries = <Map<String, String>>[];
  Future<Map<String, dynamic>> Function(Map<String, String>)? handler;
  int details = 0;
  @override
  Future<Map<String, dynamic>> fetchProformaInvoices(
      {required String accessToken, Map<String, String>? filters}) async {
    final query = Map<String, String>.of(filters ?? {});
    queries.add(query);
    if (handler != null) return handler!(query);
    final number = int.parse(query['page']!);
    return page(number, rows: [row(number, name: query['customer_search'])]);
  }

  @override
  Future<Map<String, dynamic>> fetchProformaInvoiceDetails(
      {required String accessToken, required dynamic invoiceId}) async {
    details++;
    return {'data': row(invoiceId as int)};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());
  late _CapturingExport capture;

  Future<FakeProvider> mount(WidgetTester tester, Size size,
      {FakeProvider? provider}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final p = provider ?? FakeProvider();
    capture = _CapturingExport();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthModel>(
              create: (_) => AuthModel()..login('test', 1)),
          ChangeNotifierProvider<QuotationsProvider>.value(value: p)
        ],
        child: GetMaterialApp(
            translations: _Translations(),
            locale: const Locale('en'),
            home: Scaffold(body: ProformaInvoiceListScreen(export: capture)))));
    await tester.pumpAndSettle();
    return p;
  }

  AppSquareIconButton exportButton(WidgetTester tester) =>
      tester.widget<AppSquareIconButton>(
          find.byKey(ProformaInvoiceListScreen.exportKey));

  /// Presses the header Export action and returns the file factory it
  /// handed to the export controller.
  Future<Future<File> Function()> createFileOf(WidgetTester tester) async {
    expect(exportButton(tester).onPressed, isNotNull);
    exportButton(tester).onPressed!();
    await tester.pump();
    return capture.createFile!;
  }

  Future<File?> export(WidgetTester tester) async {
    final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('proforma-export-test-')))!;
    addTearDown(() => directory.delete(recursive: true));
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    return tester.runAsync(await createFileOf(tester));
  }

  Future<void> expectRejectedExport(WidgetTester tester) async {
    final createFile = await createFileOf(tester);
    await tester.runAsync(
        () => expectLater(createFile(), throwsA(isA<FormatException>())));
  }

  for (final size in [
    const Size(1440, 900),
    const Size(800, 900),
    const Size(390, 800),
    const Size(375, 300)
  ]) {
    testWidgets('shared proforma layout and actions fit $size', (tester) async {
      await mount(tester, size);
      expect(find.byIcon(Icons.visibility_outlined), findsWidgets);
      if (size.width < 700) {
        // Phones fold Filters/Export/Refresh into the header "more" menu and
        // start with the filters hidden.
        await tester.tap(find.byKey(PageHeader.moreActionsKey));
        await tester.pumpAndSettle();
        expect(
            find.text('Export all matching proforma invoices'), findsOneWidget);
        await tester.tap(find.text('Show Filters'));
        await tester.pumpAndSettle();
      } else {
        expect(find.byKey(ProformaInvoiceListScreen.exportKey), findsOneWidget);
        expect(find.byKey(ProformaInvoiceListScreen.filterToggleKey),
            findsOneWidget);
      }
      expect(find.byKey(ProformaInvoiceListScreen.filtersKey), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'export flushes pending filters, fetches every page and keeps typed references',
      (tester) async {
    final p = await mount(tester, const Size(1440, 900));
    await tester.enterText(find.byType(TextField).at(0), '000');
    await tester.enterText(find.byType(TextField).at(1), 'Acme');
    await tester.pump(const Duration(milliseconds: 100));
    final file = await export(tester);
    final rows =
        Excel.decodeBytes(file!.readAsBytesSync()).tables.values.single.rows;
    expect(rows.length, 3);
    expect(rows[1][0]!.value, TextCellValue('0001'));
    expect(rows[1][2]!.value, TextCellValue('000Q1'));
    expect(rows[1][5]!.value, const DoubleCellValue(126.125));
    final exportQueries =
        p.queries.where((q) => q['per_page'] == '1000').toList();
    expect(exportQueries.map((q) => q['page']), ['1', '2']);
    expect(
        exportQueries.every((q) =>
            q['invoice_number'] == '000' && q['customer_search'] == 'Acme'),
        isTrue);
    await tester.pumpAndSettle();
    final layout = tester.widget<ListPageScaffold<Map<String, dynamic>>>(
        find.byType(ListPageScaffold<Map<String, dynamic>>));
    expect(layout.items.single['customer']['name'], 'Acme');
    expect(layout.pagination!.currentPage, 1);
    expect(layout.pagination!.totalPages, 2);
    expect(p.queries.length, 4);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'export preserves visible page and pagination when filters are unchanged',
      (tester) async {
    final p = await mount(tester, const Size(1440, 900));
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    await export(tester);
    await tester.pumpAndSettle();
    final layout = tester.widget<ListPageScaffold<Map<String, dynamic>>>(
        find.byType(ListPageScaffold<Map<String, dynamic>>));
    expect(layout.pagination!.currentPage, 2);
    expect(layout.items.single['id'], 2);
    expect(p.queries.length, 4);
    expect(tester.takeException(), isNull);
  });
  for (final mode in [
    'failure',
    'wrong_page',
    'missing_data',
    'changed_last',
    'empty_middle',
    'empty_final'
  ]) {
    testWidgets(
        'export rejects $mode on a later page without creating partial workbook',
        (tester) async {
      final p = await mount(tester, const Size(1440, 900));
      p.handler = (q) async {
        if (q['page'] == '1') return page(1);
        switch (mode) {
          case 'failure':
            throw StateError('failed');
          case 'wrong_page':
            return page(1);
          case 'missing_data':
            return {
              'data': {'current_page': 2, 'last_page': 2}
            };
          case 'changed_last':
            return page(2, last: 3);
          case 'empty_final':
            return page(2, rows: []);
          default:
            return page(2, last: 3, rows: []);
        }
      };
      final createFile = await createFileOf(tester);
      await tester
          .runAsync(() => expectLater(createFile(), throwsA(anything)));
      final layout = tester.widget<ListPageScaffold<Map<String, dynamic>>>(
          find.byType(ListPageScaffold<Map<String, dynamic>>));
      expect(layout.items.single['id'], 1);
      expect(layout.pagination!.currentPage, 1);
    });
  }
  for (final samePage in [true, false]) {
    testWidgets(
        'export rejects duplicate IDs with stable counts: samePage=$samePage',
        (tester) async {
      final p = await mount(tester, const Size(1440, 900));
      p.handler = (q) async {
        final number = int.parse(q['page']!);
        final result = page(number,
            last: samePage ? 1 : 2,
            rows: samePage ? [row(1), row(1)] : [row(1)]);
        (result['data'] as Map)['total'] = 2;
        return result;
      };
      await expectRejectedExport(tester);
      final layout = tester.widget<ListPageScaffold<Map<String, dynamic>>>(
          find.byType(ListPageScaffold<Map<String, dynamic>>));
      expect(layout.items.single['id'], 1);
      expect(layout.pagination!.currentPage, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('export normalizes numeric string IDs when checking duplicates',
      (tester) async {
    final p = await mount(tester, const Size(1440, 900));
    p.handler = (q) async => page(int.parse(q['page']!), rows: [
          {...row(1), 'id': q['page'] == '1' ? 1 : '1'},
        ]);
    await expectRejectedExport(tester);
  });
  for (final invalidId in [null, 0, -1, 'invalid']) {
    testWidgets('export rejects rows without a valid ID: $invalidId',
        (tester) async {
      final p = await mount(tester, const Size(1440, 900));
      p.handler = (_) async => page(1, last: 1, rows: [
            {...row(1), 'id': invalidId}
          ]);
      await expectRejectedExport(tester);
    });
  }
  testWidgets('export accepts distinct numeric string IDs', (tester) async {
    final p = await mount(tester, const Size(1440, 900));
    p.handler = (q) async => page(int.parse(q['page']!), rows: [
          {...row(int.parse(q['page']!)), 'id': q['page']},
        ]);
    final file = await export(tester);
    final rows =
        Excel.decodeBytes(file!.readAsBytesSync()).tables.values.single.rows;
    expect(rows.length, 3);
    expect(rows[1][0]!.value, TextCellValue('0001'));
    expect(rows[2][0]!.value, TextCellValue('0002'));
  });

  testWidgets('older filter response cannot overwrite new response',
      (tester) async {
    final p = await mount(tester, const Size(1440, 900));
    final old = Completer<Map<String, dynamic>>();
    p.handler = (q) async => q['customer_search'] == 'Old'
        ? await old.future
        : page(1, last: 1, rows: [row(2, name: q['customer_search'])]);
    await tester.enterText(find.byType(TextField).at(1), 'Old');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).at(1), 'New');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    old.complete(page(1, rows: [row(1, name: 'Old')]));
    await tester.pumpAndSettle();
    final layout = tester.widget<ListPageScaffold<Map<String, dynamic>>>(
        find.byType(ListPageScaffold<Map<String, dynamic>>));
    expect(layout.items.single['customer']['name'], 'New');
    expect(layout.isLoading, isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'failed filtering retains rows, disables export and Retry recovers',
      (tester) async {
    final p = await mount(tester, const Size(1440, 900));
    p.handler = (_) async => throw StateError('failed');
    await tester.enterText(find.byType(TextField).at(1), 'Acme');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.textContaining('Previously loaded rows'), findsOneWidget);
    expect(exportButton(tester).onPressed, isNull);
    p.handler = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(exportButton(tester).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('View keeps existing detail API and dialog', (tester) async {
    final p = await mount(tester, const Size(1440, 900));
    await tester.tap(find.byIcon(Icons.visibility_outlined).first);
    await tester.pumpAndSettle();
    expect(p.details, 1);
    expect(find.byType(CommonDetailsDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('selected status is sent on every export page', (tester) async {
    final p = await mount(tester, const Size(1440, 900));
    tester
        .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>))
        .onChanged!('pending');
    await tester.pumpAndSettle();
    await export(tester);
    final queries = p.queries.where((q) => q['per_page'] == '1000').toList();
    expect(queries.length, 2);
    expect(queries.every((q) => q['status'] == 'pending'), isTrue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('integer and decimal JSON amounts export as numeric cells',
      (tester) async {
    final p = await mount(tester, const Size(1440, 900));
    p.handler = (q) async => page(int.parse(q['page']!), rows: [
          {
            ...row(int.parse(q['page']!)),
            'amount': q['page'] == '1' ? 126.125 : 42
          }
        ]);
    final file = await export(tester);
    final rows =
        Excel.decodeBytes(file!.readAsBytesSync()).tables.values.single.rows;
    expect(rows[1][5]!.value, const DoubleCellValue(126.125));
    expect(rows[2][5]!.value, const IntCellValue(42));
  });
  for (final mode in [
    'matching',
    'mismatch',
    'changed',
    'missing_later',
    'invalid',
    'empty_first_with_total'
  ]) {
    testWidgets('export validates optional API total: $mode', (tester) async {
      final p = await mount(tester, const Size(1440, 900));
      p.handler = (q) async {
        final number = int.parse(q['page']!);
        final response =
            page(number, rows: mode == 'empty_first_with_total' ? [] : null);
        final data = response['data'] as Map<String, dynamic>;
        if (mode == 'missing_later' && number > 1) return response;
        data['total'] = mode == 'invalid'
            ? 'bad'
            : mode == 'mismatch'
                ? 3
                : mode == 'changed' && number > 1
                    ? 3
                    : 2;
        return response;
      };
      if (mode == 'matching') {
        final file = await export(tester);
        expect(
            Excel.decodeBytes(file!.readAsBytesSync())
                .tables
                .values
                .single
                .rows
                .length,
            3);
      } else {
        final createFile = await createFileOf(tester);
        await tester.runAsync(() =>
            expectLater(createFile(), throwsA(isA<FormatException>())));
      }
    });
  }
}
