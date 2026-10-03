import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/reports/presentation/pages/my_sales_report_page.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/models/sales_executive_report.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../test_support/app_translations.dart';
import '../../../../test_support/export_capture.dart';
import '../../../../test_support/header_actions.dart';
import '../../support/report_fixtures.dart';

class _FakeSales extends SalesExecutiveProvider {
  final calls = <({String? from, String? to, bool updateState})>[];
  Future<dynamic> Function(String?, String?)? handler;

  @override
  Future<dynamic> getSalesExecutiveReport(
      {required BuildContext context,
      String? fromDate,
      String? toDate,
      bool updateState = true}) async {
    calls.add((from: fromDate, to: toDate, updateState: updateState));
    return handler == null ? salesReport() : await handler!(fromDate, toDate);
  }
}

class _Settings extends AppSettingsProvider {
  String currency = 'SAR';
  @override
  Future<void> fetchAppSettings() async {}
  @override
  AppSettings? get appSettings => AppSettings.fromJson({
        'data': [
          {'code': 'CURRENCY', 'status': true, 'value': currency}
        ]
      });
}

void main() {
  late CapturingExport capture;

  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues(
        {'api_key': 'test', 'active_store_id': 7});
    capture = CapturingExport();
  });
  tearDown(Get.reset);

  Future<_FakeSales> mount(WidgetTester tester,
      {Size size = const Size(1440, 900), _FakeSales? sales}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = sales ?? _FakeSales();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthModel()..login('test', 1)),
          ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) => _Settings()),
          ChangeNotifierProvider<SalesExecutiveProvider>.value(value: provider)
        ],
        child: GetMaterialApp(
            translations: EnglishTranslations(),
            locale: const Locale('en'),
            home: Scaffold(body: MySalesReportPage(export: capture)))));
    await tester.pumpAndSettle();
    return provider;
  }

  ListPageScaffold<SalesExecutiveReportData> scaffold(WidgetTester tester) =>
      tester.widget(find.byType(ListPageScaffold<SalesExecutiveReportData>));

  Future<List<List<Data?>>> exportRows(WidgetTester tester) async {
    await tester.tap(find.byKey(MySalesReportPage.exportKey));
    await tester.pump();
    await useTempExportDirectory(tester, 'my-sales-export-test-');
    final file = (await tester.runAsync(capture.createFile!))!;
    return Excel.decodeBytes(file.readAsBytesSync()).tables.values.first.rows;
  }

  for (final size in const [
    Size(1440, 900),
    Size(1000, 700),
    Size(600, 900),
    Size(390, 650),
    Size(375, 300),
    Size(1000, 480)
  ]) {
    testWidgets('lays out on the shared kit at $size', (tester) async {
      await mount(tester, size: size);
      expect(tester.takeException(), isNull);
      await tapFilterToggle(tester, key: MySalesReportPage.filterToggleKey);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'the export has every loaded row, no new request, and numeric values',
      (tester) async {
    final sales = _FakeSales()
      ..handler = (_, __) async =>
          salesReport([for (var i = 0; i < 21; i++) salesRow('Executive $i')]);
    await mount(tester, sales: sales);
    scaffold(tester).pagination!.onPageChanged(2);
    await tester.pumpAndSettle();

    final values = await exportRows(tester);
    expect(sales.calls, hasLength(1));
    expect(sales.calls.single.updateState, isFalse);
    expect(values.length, 22);
    expect(values[1][1]!.value, TextCellValue('0012345'));
    expect(values[1][2]!.value, const IntCellValue(2));
    expect(values[1][3]!.value, const DoubleCellValue(12.125));
    expect(values[1][8]!.value, const DoubleCellValue(1.125));
    expect(values[1][13]!.value, TextCellValue('SAR'));
    expect(values[1][14]!.value.toString(), isNotEmpty);
    expect(scaffold(tester).pagination!.currentPage, 2);
  });

  testWidgets('an empty result shows the empty state and blocks the export',
      (tester) async {
    final sales = _FakeSales()..handler = (_, __) async => salesReport([]);
    await mount(tester, sales: sales);
    expect(find.text('No report data found'), findsOneWidget);
    expect(
        tester
            .widget<AppSquareIconButton>(
                find.byKey(MySalesReportPage.exportKey))
            .onPressed,
        isNull);
  });

  testWidgets('a failed request shows Retry, which recovers', (tester) async {
    final sales = await mount(tester);
    sales.handler = (_, __) async => {'status': 'failed'};
    await scaffold(tester).onRefresh!();
    await tester.pumpAndSettle();
    expect(scaffold(tester).items.single.name, 'My Executive');

    sales.handler = (_, __) async => salesReport([salesRow('Recovered')]);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(scaffold(tester).items.single.name, 'Recovered');
  });

  testWidgets('the details dialog fits a phone', (tester) async {
    await mount(tester, size: const Size(390, 650));
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(find.text('Sales Executive Details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a cancelled time picker leaves the filters unchanged',
      (tester) async {
    final sales = await mount(tester);
    await tester.tap(find.byKey(MySalesReportPage.fromKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(sales.calls, hasLength(1));
  });

  testWidgets('picking a date and time reloads that range, and Reset clears it',
      (tester) async {
    final sales = await mount(tester);
    await tester.tap(find.byKey(MySalesReportPage.fromKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(sales.calls, hasLength(2));
    expect(sales.calls.last.from,
        matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:00$')));
    expect(sales.calls.last.to, isNull);

    final values = await exportRows(tester);
    expect(values[1][14]!.value, TextCellValue(sales.calls.last.from!));
    expect(values[1][15]!.value, TextCellValue(''));

    await tester.tap(find.descendant(
        of: find.byKey(MySalesReportPage.filtersKey),
        matching: find.text('Reset')));
    await tester.pumpAndSettle();
    expect(sales.calls.last.from, isNull);
    expect(sales.calls.last.to, isNull);
  });

  testWidgets('a currency change updates without refetching', (tester) async {
    final sales = await mount(tester);
    final settings = tester
        .element(find.byType(MySalesReportPage))
        .read<AppSettingsProvider>() as _Settings;
    settings.currency = 'USD';
    settings.notifyListeners();
    await tester.pumpAndSettle();
    final values = await exportRows(tester);
    expect(values[1][13]!.value, TextCellValue('USD'));
    expect(sales.calls, hasLength(1));
  });

  test('report labels exist in every language', () {
    for (final lang in ['en', 'ar', 'ml']) {
      final section = translationSection(lang, 'sales_executive_report');
      for (final key in [
        'subtitle',
        'find',
        'filter_hint',
        'load_error',
        'export_tooltip',
        'export_error',
        'currency',
        'page_count'
      ]) {
        expect(section[key], isA<String>(), reason: '$lang.$key');
      }
    }
  });
}
