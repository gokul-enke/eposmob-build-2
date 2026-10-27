import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';
import 'package:pos_machine/features/reports/data/discount_sale_report_api.dart';
import 'package:pos_machine/features/reports/presentation/pages/discount_sale_report_page.dart';
import 'package:pos_machine/features/reports/presentation/widgets/non_stock_report/non_stock_report_picker.dart';
import 'package:pos_machine/models/executive.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/models/sales_executive.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import '../../../../test_support/app_translations.dart';
import '../../../../test_support/export_capture.dart';
import '../../../../test_support/header_actions.dart';

class _Session extends TenantSession {
  const _Session();
  @override
  Future<String?> apiKey() async => 'tenant';
  @override
  Future<int?> activeStoreId() async => 2;
}

/// Fake backend in the reports API shape (`data.data`, `data.summary`,
/// `data.pagination`), paging through [all]. Like the real API it refuses
/// more than 100 rows per page.
class _Backend {
  final requests = <Uri>[];
  bool fail = false;
  List<Map<String, dynamic>> all = [];
  Map<String, num> summary = const {};

  Future<http.Response> get(Uri uri, {Map<String, String>? headers}) async {
    requests.add(uri);
    if (uri.path.contains('sales-executive')) {
      return http.Response(
          jsonEncode({
            'status': 'success',
            'data': [
              {'id': 4, 'name': 'salesexecutiv2'}
            ]
          }),
          200);
    }
    if (fail) return http.Response('down', 500);
    final page = int.parse(uri.queryParameters['page']!);
    final per = int.parse(uri.queryParameters['per_page']!);
    if (per > 100) {
      return http.Response(
          jsonEncode({'status': 'failed', 'message': 'per_page max 100'}), 422);
    }
    final start = (page - 1) * per;
    return http.Response(
        jsonEncode({
          'status': 'success',
          'message': 'Report',
          'data': {
            'data': all.skip(start).take(per).toList(),
            'summary': summary,
            'filters': {'from': '2026-10-01', 'to': '2026-10-31'},
            'pagination': {
              'current_page': page,
              'last_page': all.isEmpty ? 1 : (all.length + per - 1) ~/ per,
              'per_page': per,
              'total': all.length,
              'next_page_url': null,
            }
          }
        }),
        200);
  }

  List<Uri> get reportRequests =>
      requests.where((u) => !u.path.contains('sales-executive')).toList();
  List<Uri> get executiveRequests =>
      requests.where((u) => u.path.contains('sales-executive')).toList();
}

class _Settings extends AppSettingsProvider {
  @override
  Future<void> fetchAppSettings() async {}
}

class _Roles extends RoleProvider {
  _Roles([this.role = 'manager']);
  final String role;
  bool allowed = true;
  @override
  String? get currentUserRole => role;
  @override
  bool currentUserHasPermissionSync(String permission) => allowed;
}

class _Stores extends StoreSessionProvider {
  @override
  List<Store> get availableStores => [
        Store(storeId: 5, storeName: 'Main Store'),
        Store(storeId: 6, storeName: ' '),
      ];
  Store? active = Store(storeId: 5, storeName: 'Main Store');
  @override
  Store? get activeStore => active;
  void switchTo(Store store) {
    active = store;
    notifyListeners();
  }
}

/// The logged-in sales executive: user 4, or 7 after a switch.
class _Executives extends SalesExecutiveProvider {
  static const _names = {4: 'salesexecutiv2', 7: 'Second Exec'};
  @override
  SalesExecutive? getCurrentUser(BuildContext context) {
    final id = Provider.of<AuthModel>(context, listen: false).userId;
    return SalesExecutive(
      id: id ?? 0,
      name: _names[id] ?? '',
      email: 'se@example.test',
      phone: '',
      phoneVerified: 0,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
  }
}

class _Customers extends CustomerProvider {
  bool down = false;
  Completer<void>? gate;
  int fetches = 0;
  @override
  Future<List<CustomerListModelData>> fetchAllCustomersSnapshot(
      {required String accessToken}) async {
    fetches++;
    final wait = gate;
    if (wait != null) await wait.future;
    if (down) throw StateError('down');
    return [CustomerListModelData(id: 7, name: 'Test Default')];
  }
}

/// A row of `/api/v1/discount-sales-report`, as the demo returned it.
Map<String, dynamic> _discount(int id) => {
      'order_id': id,
      'order_date': '2026-10-12',
      'order_number': 'ORD-00$id',
      'executive_id': 1060,
      'executive_name': 'SALESMEDINA',
      'customer_id': 2693,
      'customer_name': 'Ayswariya',
      'discount_type': 'Cart items level',
      'item_discount': 2,
      'discount': 0,
      'total_discount': 2,
      'store_id': 70,
      'store_name': 'MEDINA FUNZCART',
    };

const _unavailable = 'Could not load the report. Showing the last loaded data.';
const _optionsUnavailable = 'Some filter options could not be loaded.';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    Get.testMode = true;
  });
  setUp(() => SharedPreferences.setMockInitialValues({'api_key': 'tenant'}));
  tearDown(Get.reset);

  Future<(_Backend, CapturingExport, _Roles)> mount(WidgetTester tester,
      {Size size = const Size(1440, 900),
      String role = 'manager',
      _Customers? customers,
      bool settle = true}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final backend = _Backend()
      ..all = [_discount(11)]
      ..summary = {
        'orders': 1,
        'item_discount': 2,
        'discount': 0,
        'total_discount': 2
      };
    final capture = CapturingExport(), roles = _Roles(role);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(
              create: (_) => AuthModel()
                ..login('token', role == 'sales_executive' ? 4 : 1)),
          ChangeNotifierProvider<SalesExecutiveProvider>(
              create: (_) => _Executives()),
          ChangeNotifierProvider<RoleProvider>.value(value: roles),
          ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) => _Settings()),
          ChangeNotifierProvider<StoreSessionProvider>(
              create: (_) => _Stores()),
          ChangeNotifierProvider<CustomerProvider>(
              create: (_) => customers ?? _Customers()),
        ],
        child: GetMaterialApp(
            translations: EnglishTranslations(),
            locale: const Locale('en'),
            home: Scaffold(
                body: DiscountSaleReportPage(
                    export: capture,
                    api: DiscountSaleReportApi(
                        endpoint: () =>
                            'https://x.test/api/v1/discount-sales-report',
                        get: backend.get,
                        session: const _Session()))))));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
    return (backend, capture, roles);
  }

  Finder pickerOf(String label) => find
      .byWidgetPredicate((w) => w is NonStockReportPicker && w.label == label);

  NonStockReportPicker single(WidgetTester tester, String label) =>
      tester.widget<NonStockReportPicker>(pickerOf(label));

  Finder pickerField(String label) =>
      find.descendant(of: pickerOf(label), matching: find.byType(TextField));

  testWidgets('a report covered by another screen reloads only when shown',
      (tester) async {
    final (backend, _, _) = await mount(tester, role: 'sales_executive');
    final context = tester.element(find.byType(DiscountSaleReportPage));
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Store selection'))));
    await tester.pumpAndSettle();
    final before = backend.reportRequests.length;

    Provider.of<AuthModel>(context, listen: false).login('token-7', 7);
    await tester.pumpAndSettle();
    expect(backend.reportRequests, hasLength(before),
        reason: 'nobody sees it: no background reload');

    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(backend.reportRequests.last.queryParameters['executive_id'], '7');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a user or store switch while open re-locks the report',
      (tester) async {
    final (backend, _, _) = await mount(tester, role: 'sales_executive');
    final context = tester.element(find.byType(DiscountSaleReportPage));
    String shown(String label) => tester
        .widget<TextField>(find.descendant(
            of: find.byWidgetPredicate(
                (w) => w is NonStockReportPicker && w.label == label),
            matching: find.byType(TextField)))
        .controller!
        .text;

    // Another sales executive switches in on this device.
    Provider.of<AuthModel>(context, listen: false).login('token-7', 7);
    await tester.pumpAndSettle();
    expect(backend.reportRequests.last.queryParameters, {
      'sales_date_range': 'month',
      'executive_id': '7',
      'store_id': '5',
      'page': '1',
      'per_page': '25'
    });
    expect(shown('Executive'), 'Second Exec');

    // The store changes underneath the open report.
    (Provider.of<StoreSessionProvider>(context, listen: false) as _Stores)
        .switchTo(Store(storeId: 6, storeName: 'Branch'));
    await tester.pumpAndSettle();
    expect(backend.reportRequests.last.queryParameters, {
      'sales_date_range': 'month',
      'executive_id': '7',
      'store_id': '6',
      'page': '1',
      'per_page': '25'
    });
    expect(shown('Store'), 'Branch');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a sales executive sees only their own sales in their store',
      (tester) async {
    final (backend, _, _) = await mount(tester, role: 'sales_executive');
    expect(backend.reportRequests.first.queryParameters, {
      'sales_date_range': 'month',
      'executive_id': '4',
      'store_id': '5',
      'page': '1',
      'per_page': '25'
    });
    for (final (label, id, name) in [
      ('Executive', '4', 'salesexecutiv2'),
      ('Store', '5', 'Main Store'),
    ]) {
      final picker = tester.widget<NonStockReportPicker>(find.byWidgetPredicate(
          (w) => w is NonStockReportPicker && w.label == label));
      expect((picker.value, picker.enabled), (id, false), reason: label);
      final field = find.descendant(
          of: find.byWidget(picker), matching: find.byType(TextField));
      expect(tester.widget<TextField>(field).controller!.text, name);
      expect(tester.widget<TextField>(field).enabled, isFalse);
    }
    // Their own name is known: the executives list is not even loaded.
    expect(backend.requests.where((u) => u.path.contains('sales-executive')),
        isEmpty);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(backend.reportRequests.last.queryParameters, {
      'sales_date_range': 'month',
      'executive_id': '4',
      'store_id': '5',
      'page': '1',
      'per_page': '25'
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('web columns, pickers and the filter keys of the API',
      (tester) async {
    final (backend, _, _) = await mount(tester);
    for (final column in [
      'SL#',
      'Date',
      'Order Number',
      'Executive',
      'Customer',
      'Discount Type',
      'Cart Items Discount',
      'Overall Order Discount',
      'Discount Amount',
      'Store'
    ]) {
      expect(find.text(column), findsWidgets, reason: column);
    }
    expect(find.text('Offline Receipt No.'), findsNothing);
    expect(find.text('2026 Oct 12'), findsOneWidget);
    expect(find.text('Cart items level'), findsOneWidget);
    expect(find.text('MEDINA FUNZCART'), findsOneWidget);
    expect(find.text('1 orders · Discount INR 2.00'), findsOneWidget);
    final first = backend.reportRequests.single;
    expect(first.path, '/api/v1/discount-sales-report');
    expect(first.queryParameters,
        {'sales_date_range': 'month', 'page': '1', 'per_page': '25'});

    // Single-choice pickers fed by the app's directories; executives seen in
    // rows join the list.
    expect(single(tester, 'Executive').options,
        {'4': 'salesexecutiv2', '1060': 'SALESMEDINA'});
    expect(single(tester, 'Customer').options, {'7': 'Test Default'});
    expect(single(tester, 'Store').options, {'5': 'Main Store'});
    expect(single(tester, 'Store').allLabel, 'All');

    // Pick through the menu: the id goes to the API, the name stays shown.
    await tester.tap(pickerField('Executive'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'SALESMEDINA'));
    await tester.pumpAndSettle();
    expect(backend.reportRequests.last.queryParameters['executive_id'], '1060');
    expect(tester.widget<TextField>(pickerField('Executive')).controller!.text,
        'SALESMEDINA');

    await tester.tap(pickerField('Store'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Main Store'));
    await tester.pumpAndSettle();
    expect(backend.reportRequests.last.queryParameters['store_id'], '5');

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Order / Offline Receipt Number'),
        '4749');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(backend.reportRequests.last.queryParameters['order_number'], '4749');

    await tester.tap(find.text('All').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overall order level').last);
    await tester.pumpAndSettle();
    expect(
        backend.reportRequests.last.queryParameters['discount_type'], 'order');

    await tester.tap(find.text('This Month'));
    await tester.pumpAndSettle();
    for (final option in ['Today', 'This Week', 'Custom']) {
      expect(find.text(option), findsWidgets, reason: option);
    }
    expect(find.text('Last 3 Months'), findsNothing);
    expect(find.text('Last Month'), findsNothing);
    await tester.tap(find.text('This Week').last);
    await tester.pumpAndSettle();
    expect(backend.reportRequests.last.queryParameters, {
      'sales_date_range': 'week',
      'executive_id': '1060',
      'store_id': '5',
      'order_number': '4749',
      'discount_type': 'order',
      'page': '1',
      'per_page': '25',
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('export: the web columns, numbers as numbers, applied filters',
      (tester) async {
    final (backend, capture, _) = await mount(tester);
    await useTempExportDirectory(tester, 'discount-sale-report-');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Order / Offline Receipt Number'),
        '4749');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DiscountSaleReportPage.exportKey));
    await tester.pumpAndSettle();
    expect(capture.runs, 1);
    final file = (await tester.runAsync(capture.createFile!))!;
    final sheet =
        Excel.decodeBytes(await tester.runAsync(file.readAsBytes) as List<int>)
            .tables['Discount Sale Report']!;
    expect(sheet.maxRows, 2);
    expect([
      for (final c in sheet.rows[0]) c?.value.toString()
    ], [
      'SL#',
      'Date',
      'Order Number',
      'Executive',
      'Customer',
      'Discount Type',
      'Cart Items Discount',
      'Overall Order Discount',
      'Discount Amount',
      'Store',
      'Applied Filters'
    ]);
    final row = sheet.rows[1];
    expect(row[1]!.value.toString(), '2026-10-12');
    expect(row[2]!.value.toString(), 'ORD-0011');
    expect(row[3]!.value.toString(), 'SALESMEDINA');
    expect(row[5]!.value.toString(), 'Cart items level');
    expect(row[6]!.value, anyOf(isA<IntCellValue>(), isA<DoubleCellValue>()));
    expect(row[8]!.value.toString(), anyOf('2', '2.0'));
    expect(row[9]!.value.toString(), 'MEDINA FUNZCART');
    expect(row[10]!.value.toString(),
        'Date Range: This Month; Order / Offline Receipt Number: 4749');
    final exported = backend.reportRequests.last.queryParameters;
    expect(exported['per_page'], '100');
    expect(exported['order_number'], '4749');
    await tester.runAsync(() => File(file.path).delete());
  });

  testWidgets('a failed load shows Retry and disables Export', (tester) async {
    final (backend, capture, _) = await mount(tester);
    backend.fail = true;
    await tester.tap(find.byKey(DiscountSaleReportPage.refreshKey));
    await tester.pumpAndSettle();
    expect(find.text(_unavailable), findsOneWidget);
    expect(find.text('ORD-0011'), findsOneWidget, reason: 'rows are kept');
    await tester.tap(find.byKey(DiscountSaleReportPage.exportKey),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(capture.runs, 0, reason: 'Export is disabled');
    backend.fail = false;
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.text(_unavailable), findsNothing);
    await tester.tap(find.byKey(DiscountSaleReportPage.exportKey));
    await tester.pumpAndSettle();
    expect(capture.runs, 1);
  });

  testWidgets('Export needs the permission', (tester) async {
    final (_, capture, roles) = await mount(tester);
    roles.allowed = false;
    roles.notifyListeners();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DiscountSaleReportPage.exportKey),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(capture.runs, 0);
  });

  testWidgets('Custom without both dates: an error without Retry',
      (tester) async {
    final (backend, capture, _) = await mount(tester);
    expect(find.text('From Date'), findsNothing);
    await tester.tap(find.text('This Month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();
    expect(find.text('From Date'), findsOneWidget);
    expect(find.text('To Date'), findsOneWidget);
    final params = backend.reportRequests.last.queryParameters;
    expect(params['sales_date_range'], 'custom');
    expect(params['from'], matches(RegExp(r'^\d{4}-\d{2}-01$')));
    expect(params['to'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));

    final before = backend.reportRequests.length;
    await tester.tap(find.byTooltip('Clear date').last);
    await tester.pumpAndSettle();
    expect(backend.reportRequests, hasLength(before));
    expect(find.text('Pick both From Date and To Date.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsNothing);
    await tester.tap(find.byKey(DiscountSaleReportPage.exportKey),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(capture.runs, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reset clears the type, the number and the pickers',
      (tester) async {
    final (backend, _, _) = await mount(tester);
    await tester.tap(pickerField('Executive'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'salesexecutiv2'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Order / Offline Receipt Number'),
        'ORD');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cart items level').last);
    await tester.pumpAndSettle();
    expect(backend.reportRequests.last.queryParameters, {
      'sales_date_range': 'month',
      'executive_id': '4',
      'order_number': 'ORD',
      'discount_type': 'items',
      'page': '1',
      'per_page': '25',
    });
    final before = backend.reportRequests.length;

    await tester.tap(find.text('Reset'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(backend.reportRequests, hasLength(before + 1));
    expect(backend.reportRequests.last.queryParameters,
        {'sales_date_range': 'month', 'page': '1', 'per_page': '25'});
    expect(single(tester, 'Executive').value, isNull);
    expect(tester.widget<TextField>(pickerField('Executive')).controller!.text,
        'All');
    expect(
        tester
            .widget<TextField>(find.descendant(
                of: find.widgetWithText(
                    TextFormField, 'Order / Offline Receipt Number'),
                matching: find.byType(TextField)))
            .controller!
            .text,
        isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a picker shows a spinner and stays closed while it loads',
      (tester) async {
    final customers = _Customers()..gate = Completer();
    await mount(tester, customers: customers, settle: false);
    expect(single(tester, 'Customer').loading, isTrue);
    expect(single(tester, 'Store').loading, isFalse,
        reason: 'each list is ready on its own');
    await tester.tap(pickerField('Customer'));
    await tester.pump();
    expect(find.byType(MenuItemButton), findsNothing);
    customers.gate!.complete();
    await tester.pumpAndSettle();
    expect(single(tester, 'Customer').loading, isFalse);
    expect(single(tester, 'Customer').options, {'7': 'Test Default'});
  });

  testWidgets('a list that failed shows Retry, which reloads only it',
      (tester) async {
    final customers = _Customers()..down = true;
    final (backend, _, _) = await mount(tester, customers: customers);
    expect(find.text(_optionsUnavailable), findsOneWidget);
    expect(single(tester, 'Customer').options, isEmpty);
    expect(single(tester, 'Store').options, {'5': 'Main Store'});
    expect(find.text('ORD-0011'), findsOneWidget, reason: 'the report loads');
    final executiveLoads = backend.executiveRequests.length;
    customers.down = false;
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.text(_optionsUnavailable), findsNothing);
    expect(single(tester, 'Customer').options, {'7': 'Test Default'});
    expect(customers.fetches, 2);
    expect(backend.executiveRequests, hasLength(executiveLoads));
  });

  testWidgets('phones start with the filters hidden, behind a collapsed tile',
      (tester) async {
    await mount(tester, size: const Size(375, 900));
    expect(find.textContaining('ORD-0011'), findsOneWidget);
    expect(find.text('INR 2.00'), findsWidgets);
    expect(find.text('Tap to show filters'), findsNothing);
    await tapFilterToggle(tester, key: DiscountSaleReportPage.filterToggleKey);
    await tester.pumpAndSettle();
    expect(find.text('Tap to show filters'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [375.0, 768.0]) {
    testWidgets('renders at $width', (tester) async {
      await mount(tester, size: Size(width, 900));
      // Phones show cards; a tablet may fit the table.
      expect(find.textContaining('ORD-0011'), findsOneWidget);
      expect(find.text('INR 2.00'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
