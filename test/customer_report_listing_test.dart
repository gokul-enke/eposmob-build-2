import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/components/export_share_button.dart';
import 'package:pos_machine/core/ui/list_page/filter_panel.dart';
import 'package:pos_machine/core/ui/list_page/list_page_scaffold.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/transaction_provider.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/services/customer_report_snapshot.dart';
import 'package:pos_machine/screens/reports/customer_transactions_reports/customer_tranctions_reports .dart';

Map<String, dynamic> group(Object id, [String name = 'Customer']) => {
      'customer_id': id,
      'customer_name': name,
      'total_debit': '12.125',
      'total_credit': 2,
      'balance': '-10.125',
      'transaction_count': '3'
    };
Map<String, dynamic> response(int page, List<Map<String, dynamic>> rows,
        {int last = 1, int? total}) =>
    {
      'status': 'success',
      'data': {
        'data': rows,
        'current_page': page,
        'last_page': last,
        'per_page': 20,
        if (total != null) 'total': total
      }
    };

class FakeInvoice extends InvoiceProvider {
  final calls =
      <({int page, String? customer, String? from, String? to, bool update})>[];
  Future<dynamic> Function(int)? handler;
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
      to: dateTo,
      update: updateState
    ));
    return handler == null
        ? response(page ?? 1, [group(page ?? 1)])
        : handler!(page ?? 1);
  }
}

class FakeCustomers extends CustomerProvider {
  @override
  Future<void> fetchCustomers(
      {required String accessToken,
      String? customerName,
      bool listAll = true}) async {}
}

class Labels extends Translations {
  @override
  Map<String, Map<String, String>> get keys {
    final keys = <String, String>{};
    void flatten(Map<String, dynamic> m, String prefix) {
      for (final entry in m.entries) {
        final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
        if (entry.value is Map<String, dynamic>) {
          flatten(entry.value, key);
        } else {
          keys[key] = entry.value.toString();
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
    SharedPreferences.setMockInitialValues({'api_key': 'test'});
  });
  tearDown(() => Get.reset());
  Future<FakeInvoice> mount(WidgetTester tester,
      {Size size = const Size(1440, 900),
      FakeInvoice? invoice,
      FakeCustomers? customers}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = invoice ?? FakeInvoice();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthModel()..login('test', 1)),
          ChangeNotifierProvider<CustomerProvider>.value(
              value: customers ?? FakeCustomers()),
          ChangeNotifierProvider<InvoiceProvider>.value(value: provider),
          ChangeNotifierProvider(create: (_) => TransactionProvider())
        ],
        child: GetMaterialApp(
            translations: Labels(),
            locale: const Locale('en'),
            home: const Scaffold(body: CustomerTransactionsReportScreen()))));
    await tester.pumpAndSettle();
    return provider;
  }

  ListPageScaffold<CustomerReportRow> screen(WidgetTester t) =>
      t.widget(find.byType(ListPageScaffold<CustomerReportRow>));

  test('counts accept integer strings; money preserves precision', () {
    final row =
        CustomerReportPage.parse(response(1, [group('42')]), 1).rows.single;
    expect(row.id, '42');
    expect(row.count, 3);
    expect(row.debit, 12.125);
  });
  test('same names with distinct IDs remain distinct', () {
    expect(
        CustomerReportPage.parse(response(1, [group(1), group(2)]), 1)
            .rows
            .length,
        2);
  });
  for (final bad in ['NaN', 'Infinity', 'invalid', null]) {
    test('reject invalid money $bad', () {
      final row = group(1)..['total_debit'] = bad;
      expect(() => CustomerReportPage.parse(response(1, [row]), 1),
          throwsFormatException);
    });
  }
  test('reject wrong page and duplicate normalized IDs', () {
    expect(() => CustomerReportPage.parse(response(1, [group(1)]), 2),
        throwsFormatException);
    expect(
        () => CustomerReportPage.parse(response(1, [group(1), group('1')]), 1),
        throwsFormatException);
  });
  test('complete export visits every page', () async {
    final calls = <int>[];
    final result = await fetchCustomerReportSnapshot((p) async {
      calls.add(p);
      return response(p, [group(p)], last: 3, total: 3);
    });
    expect(calls, [1, 2, 3]);
    expect(result.length, 3);
  });
  test('reject overlapping export pages with matching totals', () async {
    await expectLater(
        fetchCustomerReportSnapshot((p) async =>
            response(p, [group(p == 1 ? 1 : '1')], last: 2, total: 2)),
        throwsFormatException);
  });
  test('failed later page does not return partial export', () async {
    await expectLater(fetchCustomerReportSnapshot((p) async {
      if (p == 2) throw StateError('network');
      return response(p, [group(p)], last: 2, total: 2);
    }), throwsStateError);
  });
  test('reject changed totals and missing final records', () async {
    await expectLater(
        fetchCustomerReportSnapshot((p) async =>
            response(p, [group(p)], last: 2, total: p == 1 ? 2 : 3)),
        throwsFormatException);
    await expectLater(
        fetchCustomerReportSnapshot(
            (p) async => response(p, [group(p)], last: 2, total: 3)),
        throwsFormatException);
  });
  test('legacy flat ledger export aggregates across pages', () async {
    final rows = await fetchCustomerReportSnapshot((p) async => response(
        p,
        [
          {
            'id': p,
            'customer_id': 1,
            'customer_name': 'Same',
            'date': '2026-10-01',
            'amount': '5',
            'balance': '12',
            'type': p == 1 ? 'debit' : 'credit'
          }
        ],
        last: 2,
        total: 2));
    expect(rows.single.debit, 5);
    expect(rows.single.credit, 5);
    expect(rows.single.count, 2);
  });
  for (final size in [
    const Size(1440, 900),
    const Size(1000, 700),
    const Size(600, 900),
    const Size(390, 650),
    const Size(375, 300)
  ]) {
    testWidgets('responsive shared layout $size', (t) async {
      final provider = await mount(t, size: size);
      expect(screen(t).items.length, 1);
      expect(provider.calls.single.update, false);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('pagination forwards page and failed reload retains rows',
      (t) async {
    final provider = FakeInvoice()
      ..handler = (p) async => response(p, [group(p, 'Page $p')], last: 2);
    await mount(t, invoice: provider);
    screen(t).onPageChanged(2);
    await t.pumpAndSettle();
    expect(provider.calls.last.page, 2);
    expect(screen(t).items.single.name, 'Page 2');
    provider.handler = (_) async => throw StateError('failure');
    await screen(t).onRefresh();
    await t.pumpAndSettle();
    expect(screen(t).items.single.name, 'Page 2');
    expect(t.widget<ExportShareButton>(find.byType(ExportShareButton)).enabled,
        false);
  });
  testWidgets(
      'Reset clears dates and customer then requests unfiltered first page',
      (t) async {
    final customers = FakeCustomers()..setSelectedCustomerId('42');
    final provider = await mount(t, customers: customers);
    for (final key in ['customer-report-from', 'customer-report-to']) {
      t.widget<TextFormField>(find.byKey(ValueKey(key))).controller!.text =
          '2026-10-01 00:00:00';
    }
    await screen(t).onRefresh();
    await t.pumpAndSettle();
    expect(provider.calls.last.customer, '42');
    expect(provider.calls.last.from, isNotNull);
    t.widget<FilterPanel>(find.byType(FilterPanel)).onReset();
    await t.pumpAndSettle();
    expect(provider.calls.last.customer, isNull);
    expect(provider.calls.last.from, isNull);
    expect(provider.calls.last.to, isNull);
    expect(provider.calls.last.page, 1);
  });
  testWidgets('late stale response cannot replace newer filters', (t) async {
    final provider = await mount(t);
    final pending = Completer<dynamic>();
    provider.handler = (_) => pending.future;
    final old = screen(t).onRefresh();
    await t.pump();
    provider.handler = (_) async => response(1, [group(2, 'Newest')]);
    await screen(t).onRefresh();
    await t.pumpAndSettle();
    pending.complete(response(1, [group(1, 'Stale')]));
    await old;
    await t.pumpAndSettle();
    expect(screen(t).items.single.name, 'Newest');
  });

  testWidgets('Retry retries the failed next page', (t) async {
    final provider = FakeInvoice()
      ..handler = (p) async => response(p, [group(p)], last: 2);
    await mount(t, invoice: provider);
    provider.handler = (_) async => throw StateError('network');
    screen(t).onPageChanged(2);
    await t.pumpAndSettle();
    expect(screen(t).currentPage, 1);
    provider.handler = (p) async => response(p, [group(p)], last: 2);
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    expect(provider.calls.last.page, 2);
    expect(screen(t).currentPage, 2);
  });

  testWidgets('View selects customer ID even when names match', (t) async {
    final customers = FakeCustomers();
    final provider = FakeInvoice()
      ..handler = (_) async => response(1, [group(41), group(42)]);
    await mount(t, invoice: provider, customers: customers);
    await t.tap(find.text('View').last);
    await t.pumpAndSettle();
    expect(customers.selectedCustomerId, '42');
    expect(Get.find<SideBarController>().index.value, 66);
  });

  testWidgets(
      'workbook exports all pages with captured filters and numeric amounts',
      (t) async {
    final customers = FakeCustomers()..setSelectedCustomerId('42');
    final provider = FakeInvoice()
      ..handler = (p) async => response(p, [group(p)], last: 2, total: 2);
    await mount(t, invoice: provider, customers: customers);
    t
        .widget<TextFormField>(
            find.byKey(const ValueKey('customer-report-from')))
        .controller!
        .text = '2026-09-01 00:00:00';
    await screen(t).onRefresh();
    await t.pumpAndSettle();
    final visible = screen(t).items;
    final dir = (await t.runAsync(
        () => Directory.systemTemp.createTemp('customer-report-test-')))!;
    addTearDown(() => dir.delete(recursive: true));
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => dir.path);
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), null));
    final button = t.widget<ExportShareButton>(find.byType(ExportShareButton));
    final file = (await t.runAsync(button.createFile))!;
    final workbook = Excel.decodeBytes(file.readAsBytesSync());
    final sheet = workbook.tables.values.single;
    expect(sheet.maxRows, 3);
    expect(sheet.rows[1][0]!.value, isA<TextCellValue>());
    expect(sheet.rows[1][2]!.value, const DoubleCellValue(12.125));
    expect(provider.calls.map((c) => c.page).toList(), [1, 1, 1, 2]);
    expect(provider.calls.every((c) => !c.update), true);
    expect(provider.calls.last.customer, '42');
    expect(provider.calls.last.from, '2026-09-01 00:00:00');
    expect(screen(t).items, same(visible));
  });

  test('real snapshot API forwards page and filters without notifications',
      () async {
    SharedPreferences.setMockInitialValues(
        {'api_key': 'test', 'active_store_id': 7});
    final provider = InvoiceProvider();
    var notifications = 0;
    provider.addListener(() => notifications++);
    await http.runWithClient(() async {
      final result = await provider.listAllTransaction(
          accessToken: 'token',
          customerId: '42',
          dateFrom: '2026-09-01 00:00:00',
          page: 2,
          updateState: false);
      expect(result['status'], 'success');
    },
        () => MockClient((request) async {
              expect(request.url.queryParameters['page'], '2');
              expect(request.url.queryParameters['customer_id'], '42');
              expect(request.url.queryParameters['date_from'],
                  '2026-09-01 00:00:00');
              expect(request.url.queryParameters['store_id'], '7');
              expect(request.headers['X-Tenant'], 'test');
              return http.Response(
                  jsonEncode(response(2, [group(42)], last: 2)), 200);
            }));
    expect(notifications, 0);
    expect(provider.transactionListDetails, isNull);
  });

  test('HTTP failure throws rather than returning an empty report', () async {
    await http.runWithClient(() async {
      await expectLater(
          InvoiceProvider()
              .listAllTransaction(accessToken: 'test', updateState: false),
          throwsA(isA<HttpException>()));
    },
        () => MockClient(
            (_) async => http.Response('{"status":"success"}', 500)));
  });

  test('report action and export translations exist in all languages', () {
    for (final locale in ['en', 'ar', 'ml']) {
      final json = jsonDecode(
          File('lib/resources/i18n/$locale.json').readAsStringSync());
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
        expect(json['customer_transaction_report'][key], isA<String>());
      }
    }
  });
}
