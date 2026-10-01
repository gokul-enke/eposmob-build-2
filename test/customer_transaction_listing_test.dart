import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/export_share_button.dart';
import 'package:pos_machine/core/ui/list_page/list_page_scaffold.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/screens/transactions/transaction_list.dart';
import 'package:pos_machine/services/customer_ledger_snapshot.dart';
import 'package:pos_machine/models/list_transaction.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> row(Object? id,
        {String name = 'Test Customer', String reference = '0001'}) =>
    {
      'id': id,
      'customer_id': 1,
      'customer_name': name,
      'date': '2026-10-01',
      'amount': '10.125',
      'currency': 'SAR',
      'reference_id': reference,
      'type': 'Credit',
      'status': 'SUCC',
      'payment_method': 'Cash'
    };
Map<String, dynamic> page(int p, List<Map<String, dynamic>> rows,
        {int last = 1, int? total}) =>
    {
      'status': 'success',
      'data': {
        'current_page': p,
        'last_page': last,
        if (total != null) 'total': total,
        'data': rows
      }
    };

class FakeProvider extends InvoiceProvider {
  final queries = <Map<String, dynamic>>[];
  Future<dynamic> Function(Map<String, dynamic>)? handler;
  @override
  Future<dynamic> listCustomerTransactions(
      {required String accessToken,
      String? customerId,
      String? dateFrom,
      String? dateTo,
      String? transactionType,
      String? type,
      int? perPage,
      int? page,
      bool updateState = true}) async {
    final q = <String, dynamic>{
      'customer_id': customerId,
      'date': dateFrom,
      'type': type,
      'page': page,
      'per_page': perPage,
      'updateState': updateState
    };
    queries.add(q);
    return handler == null
        ? {
            'status': 'success',
            'data': {
              'current_page': page,
              'last_page': 1,
              'total': 1,
              'data': [row(1)]
            }
          }
        : await handler!(q);
  }
}

class Labels extends Translations {
  @override
  Map<String, Map<String, String>> get keys {
    final keys = <String, String>{};
    void flatten(Map<String, dynamic> values, String prefix) {
      for (final e in values.entries) {
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
        {'api_key': 'test', 'active_store_id': 3});
  });
  tearDown(() => Get.reset());
  Future<FakeProvider> mount(WidgetTester tester,
      {FakeProvider? provider, Size size = const Size(1440, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final p = provider ?? FakeProvider();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthModel()..login('test', 1)),
          ChangeNotifierProvider<InvoiceProvider>.value(value: p),
          ChangeNotifierProvider(create: (_) => MasterDataProvider())
        ],
        child: GetMaterialApp(
            translations: Labels(),
            locale: const Locale('en'),
            home: const Scaffold(body: CustomerTransactionListScreen()))));
    await tester.pumpAndSettle();
    return p;
  }

  Finder field(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label);
  Future<File> export(WidgetTester tester) async {
    final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('customer-ledger-test-')))!;
    addTearDown(() => directory.delete(recursive: true));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => directory.path);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null));
    return (await tester.runAsync(tester
        .widget<ExportShareButton>(find.byType(ExportShareButton))
        .createFile))!;
  }

  test('isolated provider request retains shared ledger state and store scope',
      () async {
    final p = InvoiceProvider();
    final previous = p.transactionListDetails;
    var notifications = 0;
    p.addListener(() => notifications++);
    await http.runWithClient(() async {
      await p.listCustomerTransactions(
          accessToken: 'test',
          customerId: '8',
          type: 'debit',
          page: 2,
          perPage: 1000,
          updateState: false);
    },
        () => MockClient((request) async {
              expect(
                  request.url.queryParameters, containsPair('store_id', '3'));
              expect(request.url.queryParameters,
                  containsPair('customer_id', '8'));
              expect(request.headers['X-Tenant'], 'test');
              return http.Response(jsonEncode(page(2, [row(2)], last: 2)), 200);
            }));
    expect(p.transactionListDetails, same(previous));
    expect(notifications, 0);
  });
  test(
      'numeric string IDs and amounts normalize; repeated references are valid',
      () async {
    final rows = await fetchCustomerLedgerSnapshot((p) async =>
        page(p, [row('$p')..['amount'] = 10.125], last: 2, total: 2));
    expect(rows.map((r) => r.id), [1, 2]);
    expect(rows.first.amount, '10.125');
  });
  for (final invalid in [null, 0, -1, 'bad']) {
    test('invalid identifier $invalid rejected', () {
      expect(() => CustomerLedgerPage.parse(page(1, [row(invalid)]), 1),
          throwsFormatException);
    });
  }
  for (final amount in [null, 'NaN', 'Infinity', 'bad']) {
    test('invalid amount $amount rejected', () {
      expect(
          () => CustomerLedgerPage.parse(
              page(1, [row(1)..['amount'] = amount]), 1),
          throwsFormatException);
    });
  }
  test('duplicates within a page rejected', () {
    expect(() => CustomerLedgerPage.parse(page(1, [row(1), row('1')]), 1),
        throwsFormatException);
  });
  test('overlap across pages rejected despite stable count', () async {
    await expectLater(
        fetchCustomerLedgerSnapshot(
            (p) async => page(p, [row(1)], last: 2, total: 2)),
        throwsFormatException);
  });
  test('changed totals rejected', () async {
    await expectLater(
        fetchCustomerLedgerSnapshot(
            (p) async => page(p, [row(p)], last: 2, total: p + 1)),
        throwsFormatException);
  });
  test('missing later page rejected', () async {
    await expectLater(
        fetchCustomerLedgerSnapshot(
            (p) async => page(p, p == 1 ? [row(1)] : [], last: 2)),
        throwsFormatException);
  });
  test('incomplete totals rejected', () async {
    await expectLater(
        fetchCustomerLedgerSnapshot((p) async => page(p, [row(p)], total: 3)),
        throwsFormatException);
  });
  test('failed response is not an empty success', () {
    expect(() => CustomerLedgerPage.parse({'status': 'failed', 'data': []}, 1),
        throwsFormatException);
  });

  for (final size in [
    const Size(1440, 900),
    const Size(1000, 700),
    const Size(600, 900),
    const Size(390, 650),
    const Size(900, 480)
  ]) {
    testWidgets('responsive layout at $size', (tester) async {
      await mount(tester, size: size);
      expect(find.byType(ExportShareButton), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.text('Success'), findsWidgets);
    });
  }
  testWidgets(
      'pending reference filters all pages and exports numeric money and text references',
      (tester) async {
    final p = FakeProvider()
      ..handler = (q) async => page(q['page'],
          [row(q['page'], reference: q['page'] == 1 ? '0001' : '0002')],
          last: 2, total: 2);
    await mount(tester, provider: p);
    await tester.enterText(field('Reference ID'), '0002');
    final file = await export(tester);
    await tester.pumpAndSettle();
    final excel = Excel.decodeBytes(file.readAsBytesSync());
    final values = excel.tables.values.first.rows;
    expect(values.length, 2);
    expect(values[1][4]!.value, const DoubleCellValue(10.125));
    expect(values[1][6]!.value, TextCellValue('0002'));
    expect(find.text('0002'), findsWidgets);
    expect(p.queries.every((q) => q['updateState'] == false), isTrue);
    expect(p.queries.where((q) => q['per_page'] == 1000).length, 2);
  });
  testWidgets('Reset after date filter clears server query and typed edits',
      (tester) async {
    final p = await mount(tester);
    await tester.tap(find.byKey(const ValueKey('customer-transactions-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(p.queries.last['date'], isNotNull);
    await tester.enterText(field('Amount'), '10');
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(p.queries.last['date'], isNull);
    expect(tester.widget<TextField>(field('Amount')).controller!.text, '');
    expect(p.queries.last['per_page'], 20);
  });
  testWidgets('failed refresh retains rows and disables export; retry recovers',
      (tester) async {
    final p = await mount(tester);
    p.handler = (_) async => throw StateError('failed');
    final scaffold = tester.widget<ListPageScaffold>(
        find.byType(ListPageScaffold<ListTransaction>));
    await scaffold.onRefresh();
    await tester.pumpAndSettle();
    expect(find.text('Test Customer'), findsOneWidget);
    expect(
        tester
            .widget<ExportShareButton>(find.byType(ExportShareButton))
            .enabled,
        false);
    p.handler = (q) async => page(1, [row(2, name: 'Recovered')]);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Recovered'), findsOneWidget);
  });
  testWidgets('export preserves current server page', (tester) async {
    final p = FakeProvider()
      ..handler =
          (q) async => page(q['page'], [row(q['page'])], last: 2, total: 2);
    await mount(tester, provider: p);
    tester
        .widget<ListPageScaffold>(
            find.byType(ListPageScaffold<ListTransaction>))
        .onPageChanged(2);
    await tester.pumpAndSettle();
    await export(tester);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ListPageScaffold>(
                find.byType(ListPageScaffold<ListTransaction>))
            .currentPage,
        2);
  });
  testWidgets('late response cannot replace a newer filter', (tester) async {
    final p = await mount(tester);
    final old = Completer<dynamic>();
    p.handler = (q) async =>
        q['type'] == 'credit' ? old.future : page(1, [row(2, name: 'Newer')]);
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>));
    dropdown.onChanged!('Credit');
    await tester.pump();
    tester
        .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>))
        .onChanged!('Debit');
    await tester.pumpAndSettle();
    old.complete(page(1, [row(3, name: 'Stale')]));
    await tester.pumpAndSettle();
    expect(find.text('Newer'), findsOneWidget);
    expect(find.text('Stale'), findsNothing);
  });
  for (final invalidDate in ['bad', '2026-02-31', '2026-13-01']) {
    test('invalid date $invalidDate rejected', () {
      expect(
          () => CustomerLedgerPage.parse(
              page(1, [row(1)..['date'] = invalidDate]), 1),
          throwsFormatException);
    });
  }
  testWidgets('clearing a global local filter restores server pagination',
      (tester) async {
    final p = FakeProvider()
      ..handler = (q) async => page(q['page'],
          [row(q['page'], reference: q['page'] == 1 ? '0001' : '0002')],
          last: 2, total: 2);
    await mount(tester, provider: p);
    await tester.enterText(field('Reference ID'), '0002');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.text('0002'), findsWidgets);
    await tester.enterText(field('Reference ID'), '');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(p.queries.last['per_page'], 20);
    expect(
        tester
            .widget<ListPageScaffold<ListTransaction>>(
                find.byType(ListPageScaffold<ListTransaction>))
            .totalPages,
        2);
  });
  testWidgets(
      'failed later export page retains the visible rows and pagination',
      (tester) async {
    final p = FakeProvider()
      ..handler = (q) async => q['per_page'] == 1000 && q['page'] == 2
          ? throw StateError('late failure')
          : page(q['page'], [row(q['page'])], last: 2, total: 2);
    await mount(tester, provider: p);
    final button =
        tester.widget<ExportShareButton>(find.byType(ExportShareButton));
    await tester
        .runAsync(() => expectLater(button.createFile(), throwsStateError));
    await tester.pumpAndSettle();
    final screen = tester.widget<ListPageScaffold<ListTransaction>>(
        find.byType(ListPageScaffold<ListTransaction>));
    expect(screen.currentPage, 1);
    expect(screen.items.single.id, 1);
    expect(screen.isLoading, false);
  });
  testWidgets(
      'overlapping export rows are rejected without removing visible rows',
      (tester) async {
    final p = FakeProvider()
      ..handler = (q) async => page(q['page'], [row(1)], last: 2, total: 2);
    await mount(tester, provider: p);
    await tester.runAsync(() => expectLater(
        tester
            .widget<ExportShareButton>(find.byType(ExportShareButton))
            .createFile(),
        throwsFormatException));
    await tester.pumpAndSettle();
    expect(find.text('Test Customer'), findsOneWidget);
  });
  testWidgets('view details and copy confirmation remain available',
      (tester) async {
    await mount(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = call.arguments['text'];
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.byIcon(Icons.copy_outlined));
    await tester.pump();
    expect(copied, '0001');
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('SAR 10.125'), findsWidgets);
  });
  test('new labels exist in all supported translations', () {
    for (final locale in ['en', 'ar', 'ml']) {
      final section = jsonDecode(File('lib/resources/i18n/$locale.json')
          .readAsStringSync())['party_accounts'];
      for (final key in [
        'subtitle',
        'find',
        'filter_hint',
        'load_error',
        'retry',
        'select_date',
        'export_tooltip',
        'export_error',
        'export_fetching',
        'currency',
        'transaction_id',
        'page_count'
      ]) {
        expect(section[key], isA<String>(), reason: '$locale:$key');
        expect((section[key] as String).trim(), isNotEmpty);
      }
    }
  });
}
