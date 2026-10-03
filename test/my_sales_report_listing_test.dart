import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/components/export_share_button.dart';
import 'package:pos_machine/components/filter_toggle_button.dart';
import 'package:pos_machine/core/ui/list_page/list_page_scaffold.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/models/sales_executive_report.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:pos_machine/screens/reports/sales_executive_report/sales_executive_report.dart';

Map<String, dynamic> row(String name) => {
      'name': name,
      'phone': '0012345',
      'order_count': 2,
      'total_sales': '12.125',
      'online_sales': '2.125',
      'cash_sales': 5,
      'credit_sales': 5,
      'collected_sales': '4.125',
      'payment_breakdown': {'UPI': 1.125, 'CARD': 1},
      'total_payment_received': 8.25,
      'total_collected_on_sale': 4.125,
      'credit_collected_prev': 4.125
    };
Map<String, dynamic> report([List<Map<String, dynamic>>? rows]) => {
      'status': 'success',
      'data': rows ?? [row('My Executive')]
    };

class FakeProvider extends SalesExecutiveProvider {
  final calls = <({String? from, String? to, bool updateState})>[];
  Future<dynamic> Function(String?, String?)? handler;
  @override
  Future<dynamic> getSalesExecutiveReport(
      {required BuildContext context,
      String? fromDate,
      String? toDate,
      bool updateState = true}) async {
    calls.add((from: fromDate, to: toDate, updateState: updateState));
    return handler == null ? report() : await handler!(fromDate, toDate);
  }
}

class Settings extends AppSettingsProvider {
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

class Labels extends Translations {
  @override
  Map<String, Map<String, String>> get keys {
    final keys = <String, String>{};
    void flatten(Map<String, dynamic> map, String prefix) {
      for (final e in map.entries) {
        final key = prefix.isEmpty ? e.key : '$prefix.${e.key}';
        if (e.value is Map<String, dynamic>) {
          flatten(e.value, key);
        } else {
          keys[key] = e.value.toString();
        }
      }
    }

    flatten(
        jsonDecode(File('lib/resources/i18n/en.json').readAsStringSync()), '');
    return {'en': keys};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues(
        {'api_key': 'test', 'active_store_id': 7});
  });
  tearDown(() => Get.reset());
  Future<FakeProvider> mount(WidgetTester tester,
      {Size size = const Size(1440, 900), FakeProvider? provider}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final p = provider ?? FakeProvider();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthModel()..login('test', 1)),
          ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) => Settings()),
          ChangeNotifierProvider<SalesExecutiveProvider>.value(value: p)
        ],
        child: GetMaterialApp(
            translations: Labels(),
            locale: const Locale('en'),
            home: const Scaffold(body: SalesExecutiveReportScreen()))));
    await tester.pumpAndSettle();
    return p;
  }

  TextEditingController date(WidgetTester tester, bool from) => tester
      .widget<TextFormField>(find.byKey(
          ValueKey(from ? 'my-sales-from-date' : 'my-sales-to-date'),
          skipOffstage: false))
      .controller!;
  Future<File> export(WidgetTester tester) async {
    final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('my-sales-export-test-')))!;
    addTearDown(() => dir.delete(recursive: true));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => dir.path);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null));
    return (await tester.runAsync(tester
        .widget<ExportShareButton>(find.byType(ExportShareButton))
        .createFile))!;
  }

  ListPageScaffold<SalesExecutiveReportData> scaffold(WidgetTester tester) =>
      tester.widget(find.byType(ListPageScaffold<SalesExecutiveReportData>));

  for (final size in [
    const Size(1440, 900),
    const Size(1000, 700),
    const Size(600, 900),
    const Size(390, 650),
    const Size(375, 300),
    const Size(1000, 480)
  ]) {
    testWidgets('shared responsive UI at $size', (tester) async {
      await mount(tester, size: size);
      expect(find.byType(ExportShareButton), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(FilterToggleButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'export includes all report rows without another API request and preserves numeric values',
      (tester) async {
    final p = FakeProvider()
      ..handler = (_, __) async =>
          report([for (var i = 0; i < 21; i++) row('Executive $i')]);
    await mount(tester, provider: p);
    scaffold(tester).onPageChanged(2);
    await tester.pumpAndSettle();
    final file = await export(tester);
    final values =
        Excel.decodeBytes(file.readAsBytesSync()).tables.values.first.rows;
    expect(p.calls.length, 1);
    expect(p.calls.single.updateState, false);
    expect(values.length, 22);
    expect(values[1][1]!.value, TextCellValue('0012345'));
    expect(values[1][2]!.value, const IntCellValue(2));
    expect(values[1][3]!.value, const DoubleCellValue(12.125));
    expect(values[1][8]!.value, const DoubleCellValue(1.125));
    expect(values[1][13]!.value, TextCellValue('SAR'));
    expect(values[1][14]!.value.toString(), isNotEmpty);
    expect(scaffold(tester).currentPage, 2);
  });
  testWidgets('date filters and Reset return to Today', (tester) async {
    final p = await mount(tester);
    date(tester, true).text = '2026-09-01 10:30:00';
    date(tester, false).text = '2026-09-30 22:00:00';
    await scaffold(tester).onRefresh();
    await tester.pumpAndSettle();
    expect(p.calls.last.from, '2026-09-01 10:30:00');
    expect(p.calls.last.to, '2026-09-30 22:00:00');
    final file = await export(tester);
    final values =
        Excel.decodeBytes(file.readAsBytesSync()).tables.values.first.rows;
    expect(values[1][14]!.value, TextCellValue('2026-09-01 10:30:00'));
    expect(values[1][15]!.value, TextCellValue('2026-09-30 22:00:00'));
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(p.calls.last.from, isNull);
    expect(p.calls.last.to, isNull);
  });
  testWidgets('invalid date range issues no request and disables export',
      (tester) async {
    final p = await mount(tester);
    date(tester, true).text = '2026-10-02 00:00:00';
    date(tester, false).text = '2026-10-01 00:00:00';
    await scaffold(tester).onRefresh();
    await tester.pumpAndSettle();
    expect(p.calls.length, 1);
    expect(find.text('From Date cannot be after To Date.'), findsOneWidget);
    expect(
        tester
            .widget<ExportShareButton>(find.byType(ExportShareButton))
            .enabled,
        false);
    expect(scaffold(tester).items.single.name, 'My Executive');
  });
  testWidgets('failed request retains report and Retry recovers',
      (tester) async {
    final p = await mount(tester);
    p.handler =
        (_, __) async => {'status': 'failed', 'message': 'server error'};
    await scaffold(tester).onRefresh();
    await tester.pumpAndSettle();
    expect(scaffold(tester).items.single.name, 'My Executive');
    expect(
        tester
            .widget<ExportShareButton>(find.byType(ExportShareButton))
            .enabled,
        false);
    p.handler = (_, __) async => report([row('Recovered')]);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(scaffold(tester).items.single.name, 'Recovered');
  });
  testWidgets('older request cannot replace newer date result', (tester) async {
    final p = await mount(tester);
    final older = Completer<dynamic>();
    p.handler =
        (from, _) async => from == null ? older.future : report([row('Newer')]);
    final old = scaffold(tester).onRefresh();
    await tester.pump();
    date(tester, true).text = '2026-09-01 00:00:00';
    await scaffold(tester).onRefresh();
    await tester.pumpAndSettle();
    older.complete(report([row('Stale')]));
    await old;
    await tester.pumpAndSettle();
    expect(scaffold(tester).items.single.name, 'Newer');
  });
  testWidgets('empty success clears rows and disables export', (tester) async {
    final p = await mount(tester);
    p.handler = (_, __) async => report([]);
    await scaffold(tester).onRefresh();
    await tester.pumpAndSettle();
    expect(scaffold(tester).items, isEmpty);
    expect(find.text('No report data found'), findsOneWidget);
    expect(
        tester
            .widget<ExportShareButton>(find.byType(ExportShareButton))
            .enabled,
        false);
  });
  testWidgets('phone details dialog has no overflow', (tester) async {
    await mount(tester, size: const Size(390, 650));
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(find.text('Sales Executive Details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'real snapshot request preserves shared state, date contract and saved store',
      (tester) async {
    final p = SalesExecutiveProvider();
    var notifications = 0;
    p.addListener(() => notifications++);
    late BuildContext reportContext;
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthModel()..login('test', 1))
        ],
        child: MaterialApp(home: Builder(builder: (context) {
          reportContext = context;
          return const SizedBox();
        }))));
    final requests = <http.Request>[];
    await tester.runAsync(() => http.runWithClient(() async {
          await p.getSalesExecutiveReport(
              context: reportContext, updateState: false);
          await p.getSalesExecutiveReport(
              context: reportContext,
              fromDate: '2026-09-01 10:00:00',
              updateState: false);
        },
            () => MockClient((request) async {
                  requests.add(request);
                  return http.Response(jsonEncode(report()), 200);
                })));
    expect(requests.length, 2);
    expect(requests[0].url.queryParameters['dateFilter'], 'today');
    expect(requests[1].url.queryParameters['dateFilter'], 'custom');
    expect(requests[1].url.queryParameters['dateFrom'], '2026-09-01 10:00:00');
    expect(requests[0].url.queryParameters['store_id'], '7');
    expect(requests[0].headers['X-Tenant'], 'test');
    expect(p.salesExecutiveReportList, isEmpty);
    expect(notifications, 0);
  });
  for (final invalid in [
    null,
    {},
    {'status': 'success', 'data': {}},
    {'status': 'failed', 'data': []},
    report([row('Bad')..['total_sales'] = 'NaN']),
    report([row('Bad')..['cash_sales'] = 'bad']),
    report([row('Bad')..['order_count'] = -1]),
    report([
      row('Bad')..['payment_breakdown'] = {'CARD': 'Infinity'}
    ])
  ]) {
    test('invalid report $invalid rejected', () {
      expect(() => parseMySalesReport(invalid), throwsFormatException);
    });
  }
  test('legacy camelCase and empty payment breakdown remain supported', () {
    final rows = parseMySalesReport(report([
      {
        'name': 'Legacy',
        'orderCount': '2',
        'totalSales': 5.125,
        'payment_breakdown': []
      }
    ]));
    expect(rows.single.orderCount, 2);
    expect(rows.single.totalSalesAmount, 5.125);
  });
  test('report translations exist in each language', () {
    for (final lang in ['en', 'ar', 'ml']) {
      final section =
          jsonDecode(File('lib/resources/i18n/$lang.json').readAsStringSync())[
              'sales_executive_report'];
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
        expect(section[key], isA<String>());
      }
    }
  });
  testWidgets('cancelled time picker leaves filters and report unchanged',
      (tester) async {
    final p = await mount(tester);
    await tester.tap(find.byKey(const ValueKey('my-sales-from-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(p.calls.length, 1);
    expect(date(tester, true).text, '');
  });
  testWidgets('date and time selection reloads the selected range',
      (tester) async {
    final p = await mount(tester);
    await tester.tap(find.byKey(const ValueKey('my-sales-from-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(p.calls.length, 2);
    expect(p.calls.last.from,
        matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:00$')));
    expect(p.calls.last.to, isNull);
  });
  testWidgets('HTTP failure cannot be accepted as a successful report',
      (tester) async {
    final p = SalesExecutiveProvider();
    late BuildContext reportContext;
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthModel()..login('test', 1))
        ],
        child: MaterialApp(home: Builder(builder: (context) {
          reportContext = context;
          return const SizedBox();
        }))));
    final result = await tester.runAsync(() => http.runWithClient(
        () => p.getSalesExecutiveReport(
            context: reportContext, updateState: false),
        () =>
            MockClient((_) async => http.Response(jsonEncode(report()), 500))));
    expect(result['status'], 'error');
    expect(() => parseMySalesReport(result), throwsFormatException);
    expect(p.reportError, isNull);
  });
  testWidgets('currency updates without refetching the report', (tester) async {
    final p = await mount(tester);
    final screenContext =
        tester.element(find.byType(SalesExecutiveReportScreen));
    final settings = screenContext.read<AppSettingsProvider>() as Settings;
    settings.currency = 'USD';
    settings.notifyListeners();
    await tester.pumpAndSettle();
    final file = await export(tester);
    final values =
        Excel.decodeBytes(file.readAsBytesSync()).tables.values.first.rows;
    expect(values[1][13]!.value, TextCellValue('USD'));
    expect(p.calls.length, 1);
  });
}
