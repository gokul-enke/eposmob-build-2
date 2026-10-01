import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/components/export_share_button.dart';
import 'package:pos_machine/components/filter_toggle_button.dart';
import 'package:pos_machine/core/ui/list_page/list_page_scaffold.dart';
import 'package:pos_machine/models/list_receipt.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/screens/transactions/receipt_list.dart';

class _Translations extends Translations {
  @override
  Map<String, Map<String, String>> get keys {
    final flat = <String, String>{};
    void flatten(Map<String, dynamic> data, String prefix) {
      for (final e in data.entries) {
        final key = prefix.isEmpty ? e.key : '$prefix.${e.key}';
        if (e.value is Map<String, dynamic>) {
          flatten(e.value, key);
        } else {
          flat[key] = '${e.value}';
        }
      }
    }

    flatten(
        jsonDecode(File('lib/resources/i18n/en.json').readAsStringSync()), '');
    return {'en': flat};
  }
}

Map<String, dynamic> row(int id, {bool matches = true}) => {
      'id': id,
      'receipt_number': '000$id',
      'amount': '12.125',
      'receipt_status': matches ? 'paid' : 'pending',
      'payment_reference': matches ? 'REF-001' : 'OTHER',
      'payment_method': matches ? 'Cash' : 'Card',
      'customer': {
        'user': {
          'name': matches ? 'Test Customer' : 'Other',
          'phone': matches ? '0012345' : '9',
          'email': matches ? 'test@example.com' : 'other@example.com'
        }
      },
      'created_at': '2026-10-01T12:00:00',
      'updated_at': '2026-10-01T12:00:00',
      'receipt_payments': [
        {
          'id': id,
          'invoice_id': id,
          'paid_amount': '12.125',
          'payment_method': 'Cash',
          'payment_date': '2026-10-01'
        }
      ],
    };
Map<String, dynamic> response(int page) => {
      'status': 'success',
      'message': 'ok',
      'data': {
        'current_page': page,
        'last_page': 2,
        'total': 4,
        'links': [],
        'per_page': 100,
        'data': [row(page * 2 - 1), row(page * 2, matches: false)]
      }
    };

class _Settings extends AppSettingsProvider {
  @override
  AppSettings get appSettings => AppSettings.fromJson({
        'data': [
          {'code': 'CURRENCY', 'status': true, 'value': 'SAR'}
        ]
      });
}

class _Provider extends InvoiceProvider {
  int page = 1;
  Map<String, Object?>? lastFilters, exported;
  @override
  bool get isLoading => false;
  @override
  List<Receipt> get getListReceipt => [Receipt.fromJson(row(page))];
  @override
  int get receiptCurrentPage => page;
  @override
  int get receiptTotalPages => 2;
  @override
  int get receiptItemsPerPage => 20;
  @override
  Future<void> loadAllReceipts(String token) async {}
  @override
  List<String> getReceiptStatusOptions() => ['All Status', 'paid', 'pending'];
  @override
  List<String> getPaymentMethodOptions() =>
      ['All Payment Methods', 'Cash', 'Card'];
  @override
  void goToReceiptPage(int value) {
    page = value;
    notifyListeners();
  }

  @override
  void resetReceiptFilters() {
    lastFilters = null;
    page = 1;
    notifyListeners();
  }

  @override
  void applyReceiptFilters(
      {String? name,
      String? receiptNumber,
      String? paymentReference,
      String? receiptStatus,
      String? paymentMethod,
      String? phone,
      String? email,
      String? dateFrom,
      String? dateTo,
      int page = 1}) {
    lastFilters = {
      'name': name,
      'number': receiptNumber,
      'reference': paymentReference,
      'status': receiptStatus,
      'method': paymentMethod,
      'phone': phone,
      'email': email,
      'from': dateFrom,
      'to': dateTo
    };
    this.page = page;
    notifyListeners();
  }

  @override
  Future<List<Receipt>> fetchReceiptsForExport(
      {required String accessToken,
      String? name,
      String? receiptNumber,
      String? paymentReference,
      String? email,
      String? paymentMethod,
      String? phone,
      String? fromDate,
      String? toDate,
      String? status,
      void Function(int, int)? onProgress,
      http.Client? client,
      Duration requestTimeout = const Duration(seconds: 30)}) async {
    exported = {
      'name': name,
      'number': receiptNumber,
      'reference': paymentReference,
      'status': status,
      'method': paymentMethod,
      'phone': phone,
      'email': email,
      'from': fromDate,
      'to': toDate
    };
    return [
      Receipt.fromJson(row(1)..remove('payment_method')),
      Receipt.fromJson(row(3)..remove('payment_method'))
    ];
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues(
        {'api_key': 'tenant', 'active_store_id': 7});
  });
  tearDown(() => Get.reset());
  test(
      'export visits every page, uses all local filters and date query, preserves provider state',
      () async {
    final p = InvoiceProvider();
    int notifications = 0;
    p.addListener(() => notifications++);
    final calls = <http.Request>[];
    final client = MockClient((req) async {
      calls.add(req);
      return http.Response(
          jsonEncode(response(int.parse(req.url.queryParameters['page']!))),
          200);
    });
    final rows = await p.fetchReceiptsForExport(
        accessToken: 'token',
        name: 'test',
        receiptNumber: '000',
        paymentReference: 'ref',
        status: 'PAID',
        paymentMethod: 'cash',
        phone: '001',
        email: '@example.com',
        fromDate: '01/10/2026',
        toDate: '2026-10-31 23:59:00',
        client: client);
    expect(rows.map((r) => r.id), [1, 3]);
    expect(calls.length, 2);
    expect(notifications, 0);
    expect(p.getListReceipt, isNull);
    expect(p.invoiceListDetails, isNull);
    for (final req in calls) {
      expect(req.headers['X-Tenant'], 'tenant');
      expect(req.url.queryParameters, containsPair('store_id', '7'));
      expect(req.url.queryParameters, containsPair('date_from', '2026-10-01'));
      expect(req.url.queryParameters,
          containsPair('date_to', '2026-10-31 23:59:00'));
    }
  });
  for (final fault in [
    'http',
    'failed',
    'empty',
    'duplicate',
    'count',
    'metadata'
  ]) {
    test('export rejects $fault rather than partial receipts', () async {
      final client = MockClient((req) async {
        final page = int.parse(req.url.queryParameters['page']!);
        final data = response(page);
        if (page == 2) {
          if (fault == 'http') return http.Response('fail', 500);
          if (fault == 'failed') data['status'] = 'failed';
          if (fault == 'empty') data['data']['data'] = [];
          if (fault == 'duplicate') data['data']['data'] = [row(1), row(4)];
          if (fault == 'count') data['data']['total'] = 5;
          if (fault == 'metadata') data['data']['current_page'] = 1;
        }
        return http.Response(jsonEncode(data), 200);
      });
      await expectLater(
          InvoiceProvider()
              .fetchReceiptsForExport(accessToken: 'token', client: client),
          throwsA(anyOf(isA<FormatException>(), isA<HttpException>())));
    });
  }
  test(
      'nested payment rows supply dropdown methods and mixed receipts match either method',
      () async {
    final mixed = row(1)..remove('payment_method');
    mixed['receipt_payments'] = [
      {'id': 1, 'payment_method': ' Cash ', 'paid_amount': '5'},
      {'id': 2, 'payment_method': 'Card', 'paid_amount': '7.125'},
      {'id': 3, 'payment_method': 'cash', 'paid_amount': '0'},
    ];
    final receipt = Receipt.fromJson(mixed);
    expect(receipt.paymentMethod, isEmpty);
    expect(receipt.paymentMethods, ['Cash', 'Card']);
    final p = InvoiceProvider();
    final data = {
      'status': 'success',
      'message': 'ok',
      'data': {
        'current_page': 1,
        'last_page': 1,
        'total': 1,
        'per_page': 100,
        'links': [],
        'data': [mixed],
      }
    };
    final client =
        MockClient((_) async => http.Response(jsonEncode(data), 200));
    await p.listAllReceipts(
        accessToken: 'token', loadAll: true, client: client);
    expect(
        p.getPaymentMethodOptions(), ['All Payment Methods', 'Card', 'Cash']);
    p.applyReceiptFiltersLocally(filterPaymentMethod: 'CARD');
    expect(p.getListReceipt!.single.id, 1);
    expect(
        (await p.fetchReceiptsForExport(
                accessToken: 'token', paymentMethod: 'cash', client: client))
            .single
            .id,
        1);
    expect(
        await p.fetchReceiptsForExport(
            accessToken: 'token', paymentMethod: 'Cheque', client: client),
        isEmpty);
  });

  test('legacy method string and arrays stay supported and deduplicate', () {
    final legacy = row(1)..['receipt_payments'] = [];
    expect(Receipt.fromJson(legacy).paymentMethods, ['Cash']);
    legacy['payment_method'] = ['Cash', 'Card', 'cash'];
    expect(Receipt.fromJson(legacy).paymentMethods, ['Cash', 'Card']);
  });

  test('receipt export times out', () async {
    final pending = Completer<http.Response>();
    await expectLater(
        InvoiceProvider().fetchReceiptsForExport(
            accessToken: 'token',
            client: MockClient((_) => pending.future),
            requestTimeout: const Duration(milliseconds: 20)),
        throwsA(isA<TimeoutException>()));
    pending.complete(http.Response(jsonEncode(response(1)), 200));
  });
  test('complete list loads beyond 1000 and discovers methods on later pages',
      () async {
    final p = InvoiceProvider();
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      final page = int.parse(request.url.queryParameters['page']!);
      final data = List.generate(page == 1 ? 1000 : 5, (i) {
        final r = row(page == 1 ? i + 1 : i + 1001);
        if (page == 2) {
          r['payment_method'] = 'Bank transfer';
          r['receipt_payments'] = [];
        }
        return r;
      });
      return http.Response(
          jsonEncode({
            'status': 'success',
            'message': 'ok',
            'data': {
              'current_page': page,
              'last_page': 2,
              'total': 1005,
              'per_page': 1000,
              'links': [],
              'data': data
            }
          }),
          200);
    });
    final result = await p.listAllReceipts(
        accessToken: 'token',
        loadAll: true,
        client: client,
        dateFrom: '2026-10-01',
        dateTo: '2026-10-31');
    expect(result['status'], 'success');
    expect(requests.map((r) => r.url.queryParameters['page']), ['1', '2']);
    for (final request in requests) {
      expect(request.url.queryParameters['per_page'], '1000');
      expect(request.url.queryParameters['date_from'], '2026-10-01');
      expect(request.url.queryParameters['store_id'], '7');
    }
    expect(p.receiptTotalPages, 51);
    expect(p.getPaymentMethodOptions(), contains('Bank transfer'));
    p.goToReceiptPage(51);
    expect(p.getListReceipt!.map((r) => r.id), [1001, 1002, 1003, 1004, 1005]);
    expect(p.invoiceListDetails, isNull);
    expect(p.isLoading, isFalse);
  });

  Future<void> waitForReceiptLoad(
      InvoiceProvider provider, VoidCallback action) async {
    final done = Completer<void>();
    void listener() {
      if (!provider.isLoading && !done.isCompleted) done.complete();
    }

    provider.addListener(listener);
    try {
      action();
      await done.future.timeout(const Duration(seconds: 5));
    } finally {
      provider.removeListener(listener);
    }
  }

  for (final resetResult in ['complete', 'empty', 'later-page-failure']) {
    test('receipt Reset reloads full cache after date filtering: $resetResult',
        () async {
      final provider = InvoiceProvider();
      final requests = <http.Request>[];
      var resetting = false;
      final client = MockClient((request) async {
        requests.add(request);
        final query = request.url.queryParameters;
        final current = int.parse(query['page']!);
        final dateFiltered = query.containsKey('date_from');
        if (resetting && resetResult == 'later-page-failure' && current == 2) {
          return http.Response('failed', 500);
        }
        final total = dateFiltered
            ? 2
            : resetting && resetResult == 'empty'
                ? 0
                : 40;
        return http.Response(
            jsonEncode({
              'status': 'success',
              'message': 'ok',
              'data': {
                'current_page': current,
                'last_page': total <= 2 ? 1 : 2,
                'total': total,
                'per_page': 20,
                'links': [],
                'data': total == 0
                    ? []
                    : List.generate(
                        dateFiltered ? 2 : 20,
                        (i) =>
                            row((current - 1) * 20 + i + 1, matches: i.isEven)),
              }
            }),
            200);
      });
      await http.runWithClient(() async {
        await provider.listAllReceipts(accessToken: 'token', loadAll: true);
        provider.goToReceiptPage(2);
        await waitForReceiptLoad(
            provider,
            () => provider.applyReceiptFilters(
                name: 'test',
                receiptStatus: 'paid',
                paymentMethod: 'Cash',
                dateFrom: '2026-10-01',
                dateTo: '2026-10-31'));
        expect(provider.allReceipts!.length, 2);
        expect(provider.getListReceipt!.length, 1);
        final resetStart = requests.length;
        resetting = true;
        await waitForReceiptLoad(provider, provider.resetReceiptFilters);
        final resetRequests = requests.skip(resetStart).toList();
        expect(resetRequests.first.url.queryParameters['per_page'], '1000');
        for (final request in resetRequests) {
          expect(request.url.queryParameters.containsKey('date_from'), isFalse);
          expect(request.url.queryParameters.containsKey('date_to'), isFalse);
          expect(request.url.queryParameters['store_id'], '7');
        }
        expect(provider.isLoading, isFalse);
        expect(provider.receiptCurrentPage, 1);
        if (resetResult == 'complete') {
          expect(resetRequests.map((r) => r.url.queryParameters['page']),
              ['1', '2']);
          expect(provider.allReceipts!.length, 40);
          expect(provider.getListReceipt!.length, 20);
          expect(
              provider.getListReceipt!.any((r) => r.receiptStatus == 'pending'),
              isTrue);
          expect(provider.receiptTotalPages, 2);
          provider.goToReceiptPage(2);
          expect(provider.getListReceipt!.first.id, 21);
          expect(provider.getListReceipt!.last.id, 40);
        } else if (resetResult == 'empty') {
          expect(provider.allReceipts, isEmpty);
          expect(provider.getListReceipt, isEmpty);
          expect(provider.receiptTotalPages, 1);
        } else {
          expect(provider.allReceipts!.map((r) => r.id), [1, 2]);
        }
      }, () => client);
    });
  }

  test('later page failure keeps the previous complete receipt list', () async {
    final p = InvoiceProvider();
    Map<String, dynamic> single(int id) => {
          'status': 'success',
          'data': {
            'current_page': 1,
            'last_page': 1,
            'total': 1,
            'links': [],
            'data': [row(id)]
          }
        };
    await p.listAllReceipts(
        accessToken: 'token',
        loadAll: true,
        client: MockClient(
            (_) async => http.Response(jsonEncode(single(99)), 200)));
    final result = await p.listAllReceipts(
        accessToken: 'token',
        loadAll: true,
        client: MockClient((r) async => r.url.queryParameters['page'] == '1'
            ? http.Response(jsonEncode(response(1)), 200)
            : http.Response('failed', 500)));
    expect(result['status'], 'error');
    expect(p.getListReceipt!.single.id, 99);
    expect(p.isLoading, isFalse);
  });

  test('older receipt refresh cannot overwrite a newer completed list',
      () async {
    final p = InvoiceProvider();
    final started = Completer<void>();
    final delayed = Completer<http.Response>();
    Map<String, dynamic> single(int id) => {
          'status': 'success',
          'data': {
            'current_page': 1,
            'last_page': 1,
            'total': 1,
            'links': [],
            'data': [row(id)]
          }
        };
    final older = p.listAllReceipts(
        accessToken: 'token',
        loadAll: true,
        client: MockClient((_) {
          started.complete();
          return delayed.future;
        }));
    await started.future;
    await p.listAllReceipts(
        accessToken: 'token',
        loadAll: true,
        client:
            MockClient((_) async => http.Response(jsonEncode(single(9)), 200)));
    delayed.complete(http.Response(jsonEncode(single(1)), 200));
    await older;
    expect(p.getListReceipt!.single.id, 9);
    expect(p.isLoading, isFalse);
  });

  test('receipt pagination retains every active local filter', () async {
    final p = InvoiceProvider();
    p.applyReceiptFilters(
        name: 'test',
        receiptNumber: '000',
        paymentReference: 'ref',
        receiptStatus: 'paid',
        paymentMethod: 'cash',
        phone: '001',
        email: 'test@');
    final data = {
      'status': 'success',
      'message': 'ok',
      'data': {
        'current_page': 1,
        'last_page': 1,
        'total': 50,
        'per_page': 1000,
        'links': [],
        'data': List.generate(50, (i) => row(i + 1, matches: i % 2 == 0))
      }
    };
    await p.listAllReceipts(
        accessToken: 'token',
        loadAll: true,
        client: MockClient((_) async => http.Response(jsonEncode(data), 200)));
    expect(p.getListReceipt!.length, 20);
    p.goToReceiptPage(2);
    expect(p.getListReceipt!.length, 5);
    expect(
        p.getListReceipt!.every(
            (r) => r.receiptStatus == 'paid' && r.paymentMethod == 'Cash'),
        isTrue);
  });
  Future<_Provider> mount(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final p = _Provider();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthModel>(
              create: (_) => AuthModel()..login('test', 1)),
          ChangeNotifierProvider<InvoiceProvider>.value(value: p),
          ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) => _Settings())
        ],
        child: GetMaterialApp(
            translations: _Translations(),
            locale: const Locale('en'),
            home: const Scaffold(body: ReceiptListScreen()))));
    await tester.pumpAndSettle();
    return p;
  }

  for (final size in [
    const Size(1440, 900),
    const Size(800, 900),
    const Size(390, 800),
    const Size(375, 300)
  ]) {
    testWidgets('receipt layout fits $size and keeps filters/actions',
        (tester) async {
      await mount(tester, size);
      expect(find.byType(ExportShareButton), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'View'), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
      expect(find.byTooltip('Copy'), findsNWidgets(2));
      if (size.width < 700) {
        await tester.tap(find.byType(FilterToggleButton));
        await tester.pumpAndSettle();
      }
      expect(find.byType(TextField), findsNWidgets(7));
      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'pagination applies pending search instead of dropping typed filters',
      (tester) async {
    final p = await mount(tester, const Size(1440, 900));
    await tester.enterText(find.byType(TextField).first, 'new-filter');
    tester
        .widget<ListPageScaffold<Receipt>>(
            find.byType(ListPageScaffold<Receipt>))
        .onPageChanged(2);
    await tester.pumpAndSettle();
    expect(p.lastFilters!['number'], 'new-filter');
    expect(p.page, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'receipt export uses pending controls and creates numeric workbook; View keeps details',
      (tester) async {
    final p = await mount(tester, const Size(1440, 900));
    await tester.enterText(find.byType(TextField).at(0), '000');
    await tester.enterText(find.byType(TextField).at(1), 'REF');
    final dir = await tester.runAsync(
        () => Directory.systemTemp.createTemp('receipt-export-test-'));
    addTearDown(() => dir!.deleteSync(recursive: true));
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir!.path);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final action =
        tester.widget<ExportShareButton>(find.byType(ExportShareButton));
    final file = await tester.runAsync(action.createFile);
    await tester.pumpAndSettle();
    expect(p.exported!['number'], '000');
    expect(p.exported!['reference'], 'REF');
    expect(p.lastFilters!['number'], '000');
    final rows =
        Excel.decodeBytes(file!.readAsBytesSync()).tables.values.single.rows;
    expect(rows.length, 3);
    expect(rows[1][0]!.value, TextCellValue('0001'));
    expect(rows[1][4]!.value, const DoubleCellValue(12.125));
    expect(rows[1][9]!.value, TextCellValue('Cash'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'View'));
    await tester.pumpAndSettle();
    expect(find.text('receipt.receipt_details_title'.tr), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
