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
import 'package:pos_machine/models/customer_voucher.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_voucher_provider.dart';
import 'package:pos_machine/screens/transactions/customer_voucher_list.dart';

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

Map<String, Object?> voucher(int id) => {
      'id': id,
      'voucher_number': '000$id',
      'voucher_date': '2026-10-01',
      'due_date': '2026-11-01',
      'amount': '126.125',
      'type': 'sales_return',
      'status': id <= 25 ? 'paid' : 'pending',
      'payment_method': 'cash',
      'customer': {
        'user': {
          'name': id <= 25 ? 'Test Customer' : 'Other Customer',
          'phone': '0012345'
        }
      },
      'items': []
    };

class FakeProvider extends CustomerVoucherProvider {
  int requests = 0;
  bool fail = false;
  @override
  Future<void> listAllCustomerVouchers({required String accessToken}) =>
      http.runWithClient(
          () => super.listAllCustomerVouchers(accessToken: accessToken),
          () => MockClient((request) async {
                requests++;
                return fail
                    ? http.Response('failed', 500)
                    : http.Response(
                        jsonEncode({
                          'status': true,
                          'message': 'ok',
                          'data': [for (int i = 1; i <= 30; i++) voucher(i)]
                        }),
                        200);
              }));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues(
        {'api_key': 'test', 'active_store_id': 7});
  });
  tearDown(() => Get.reset());
  test(
      'filtered export covers cached pages and preserves leading zero references',
      () async {
    final p = FakeProvider();
    await p.listAllCustomerVouchers(accessToken: 'test');
    p.applyFiltersLocally(
        filterCustomerName: 'Test',
        filterType: 'sales_return',
        filterStatus: 'paid',
        page: 2);
    expect(p.voucherListDetails!.length, 5);
    expect(
        p
            .filterForExport(
                customerName: 'Test', type: 'sales_return', status: 'paid')
            .length,
        25);
    expect(
        p.filterForExport(voucherNumber: '0001').first.voucherNumber, '0001');
    expect(p.requests, 1);
    expect(p.getTypeOptions(), contains('sales_return'));
  });
  test('failed refresh retains rows and releases loading', () async {
    final p = FakeProvider();
    await p.listAllCustomerVouchers(accessToken: 'test');
    p.fail = true;
    await p.listAllCustomerVouchers(accessToken: 'test');
    expect(p.voucherListDetails!.length, 20);
    expect(p.loadError, isNotNull);
    expect(p.isLoading, isFalse);
  });
  test('missing tenant releases loading and exposes failure', () async {
    SharedPreferences.setMockInitialValues({});
    final p = FakeProvider();
    await p.listAllCustomerVouchers(accessToken: 'test');
    expect(p.requests, 0);
    expect(p.loadError, isNotNull);
    expect(p.isLoading, isFalse);
  });
  test('failed or malformed success payload is not an empty success', () async {
    for (final data in [
      {'status': false, 'data': []},
      {'status': true, 'data': null}
    ]) {
      final p = CustomerVoucherProvider();
      await http.runWithClient(
          () => p.listAllCustomerVouchers(accessToken: 'test'),
          () => MockClient((_) async => http.Response(jsonEncode(data), 200)));
      expect(p.loadError, isA<FormatException>());
      expect(p.isLoading, isFalse);
    }
  });
  test('older refresh cannot overwrite latest rows or loading state', () async {
    final p = CustomerVoucherProvider();
    final first = Completer<http.Response>();
    final started = Completer<void>();
    int calls = 0;
    await http.runWithClient(() async {
      final older = p.listAllCustomerVouchers(accessToken: 'test');
      await started.future;
      await p.listAllCustomerVouchers(accessToken: 'test');
      first.complete(http.Response(
          jsonEncode({
            'status': true,
            'data': [voucher(1)]
          }),
          200));
      await older;
      expect(p.allVouchers!.single.id, 2);
      expect(p.isLoading, isFalse);
    },
        () => MockClient((r) {
              calls++;
              expect(r.headers['X-Tenant'], 'test');
              expect(r.url.queryParameters['store_id'], '7');
              if (calls == 1) {
                started.complete();
                return first.future;
              }
              return Future.value(http.Response(
                  jsonEncode({
                    'status': true,
                    'data': [voucher(2)]
                  }),
                  200));
            }));
  });
  Future<FakeProvider> mount(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final p = FakeProvider();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthModel>(
              create: (_) => AuthModel()..login('test', 1)),
          ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) => AppSettingsProvider()),
          ChangeNotifierProvider<CustomerVoucherProvider>.value(value: p)
        ],
        child: GetMaterialApp(
            translations: _Translations(),
            locale: const Locale('en'),
            home: const Scaffold(body: CustomerVoucherListScreen()))));
    await tester.pumpAndSettle();
    return p;
  }

  for (final size in [
    const Size(1340, 900),
    const Size(800, 900),
    const Size(390, 800),
    const Size(375, 300)
  ]) {
    testWidgets(
        'table/cards retain all actions without pixel overflow at $size',
        (tester) async {
      await mount(tester, size);
      expect(find.byType(ExportShareButton), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsWidgets);
      expect(find.byIcon(Icons.print_outlined), findsWidgets);
      expect(find.byIcon(Icons.more_vert), findsWidgets);
      final layout = tester.widget<ListPageScaffold<CustomerVoucher>>(
          find.byType(ListPageScaffold<CustomerVoucher>));
      expect(layout.tableScrollController, isNotNull);
      if (size.width < 700) {
        await tester.tap(find.byType(FilterToggleButton));
        await tester.pumpAndSettle();
      }
      expect(find.byType(TextField), findsNWidgets(4));
      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'export applies pending text and writes numeric amounts without another request',
      (tester) async {
    final p = await mount(tester, const Size(1440, 900));
    await tester.enterText(find.byType(TextField).first, 'Test');
    await tester.pump(const Duration(milliseconds: 100));
    final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('customer-voucher-test-')))!;
    addTearDown(() => dir.delete(recursive: true));
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final button =
        tester.widget<ExportShareButton>(find.byType(ExportShareButton));
    final file = await tester.runAsync(button.createFile);
    final rows =
        Excel.decodeBytes(file!.readAsBytesSync()).tables.values.single.rows;
    expect(rows.length, 26);
    expect(rows[1][0]!.value, TextCellValue('0001'));
    expect(rows[1][6]!.value, const DoubleCellValue(126.125));
    expect(p.requests, 1);
    expect(p.totalPages, 2);
    p.goToPage(2);
    expect(p.voucherListDetails!.length, 5);
    expect(
        p.voucherListDetails!
            .every((v) => v.customer.user.name == 'Test Customer'),
        isTrue);
    await tester.pump(const Duration(milliseconds: 400));
    expect(p.requests, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('More retains Share and failure disables export', (tester) async {
    final p = await mount(tester, const Size(1440, 900));
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text('Share'), findsOneWidget);
    Navigator.of(tester.element(find.text('Share'))).pop();
    await tester.pumpAndSettle();
    p.fail = true;
    await p.listAllCustomerVouchers(accessToken: 'test');
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ExportShareButton>(find.byType(ExportShareButton))
            .enabled,
        isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'failed date filtering marks stale rows and Retry restores export',
      (tester) async {
    final p = await mount(tester, const Size(1440, 900));
    p.fail = true;
    p.applyFilters(dateFrom: '2026-10-01 00:00:00');
    await tester.pumpAndSettle();
    expect(p.loadError, isNotNull);
    expect(p.voucherListDetails!.length, 20);
    expect(find.textContaining('Showing previously loaded records'),
        findsOneWidget);
    expect(
        tester
            .widget<ExportShareButton>(find.byType(ExportShareButton))
            .enabled,
        isFalse);
    p.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Showing previously loaded records'), findsNothing);
    expect(
        tester
            .widget<ExportShareButton>(find.byType(ExportShareButton))
            .enabled,
        isTrue);
    expect(find.byTooltip('Copy voucher number'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  test('local filters use cached rows, date changes request fresh rows',
      () async {
    final p = FakeProvider();
    await p.listAllCustomerVouchers(accessToken: 'test');
    p.applyFilters(customerName: 'Test', status: 'paid', type: 'sales_return');
    expect(p.requests, 1);
    expect(p.totalPages, 2);
    p.goToPage(2);
    expect(p.voucherListDetails!.length, 5);
    p.applyFilters(customerName: 'Other', dateFrom: '2026-10-01 00:00:00');
    await Future<void>.delayed(Duration.zero);
    expect(p.requests, 2);
    expect(p.voucherListDetails!.length, 5);
  });
}
