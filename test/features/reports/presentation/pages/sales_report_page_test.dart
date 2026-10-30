import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';
import 'package:pos_machine/features/reports/data/sales_report_api.dart';
import 'package:pos_machine/features/reports/presentation/pages/sales_report_page.dart';
import 'package:pos_machine/features/reports/presentation/widgets/non_stock_report/non_stock_report_picker.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/delivery_method.dart';
import 'package:pos_machine/models/executive.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/models/payment_method.dart';
import 'package:pos_machine/models/payment_method_registry.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/models/sales_executive.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import '../../../../test_support/app_translations.dart';
import '../../../../test_support/export_capture.dart';
import '../../../../test_support/header_actions.dart';
import '../../../../test_support/hive_test_teardown.dart';

class _Session extends TenantSession {
  const _Session();
  @override
  Future<String?> apiKey() async => 'tenant';
  @override
  Future<int?> activeStoreId() async => 2;
}

/// Fake backend in the sales-report API shape (`data.data`, `data.summary`,
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
  List<Store> get availableStores =>
      [Store(storeId: 5, storeName: 'Main Store')];
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

class _Categories extends CategoryProvider {
  @override
  List<Category>? get category =>
      [Category(categoryId: 88, categoryName: 'Juice')];
  @override
  Future<void> listAllCategory(
      {String? filterName,
      String? filterParent,
      int? page,
      bool sellableOnly = true,
      bool scopeToActiveStore = true,
      bool force = false}) async {}
}

class _Customers extends CustomerProvider {
  _Customers([this.snapshot]);
  final Future<List<CustomerListModelData>>? snapshot;
  @override
  Future<List<CustomerListModelData>> fetchAllCustomersSnapshot(
          {required String accessToken}) =>
      snapshot ??
      Future.value([CustomerListModelData(id: 7, name: 'Test Default')]);
}

class _Delivery extends DeliveryMethodsProvider {
  _Delivery({List<DeliveryMethod>? methods, this.fetched = true})
      : methods = methods ??
            [
              DeliveryMethod(
                  id: '11', name: 'Store Takeaway', code: 'STORE_TAKEAWAY')
            ];
  List<DeliveryMethod> methods;
  bool fetched;
  @override
  bool get hasMethods => methods.isNotEmpty;
  @override
  bool get loadedForStore => fetched;
  @override
  List<DeliveryMethod> get deliveryMethods => methods;
  @override
  Future<void> fetchDeliveryMethods({bool forceRefresh = false}) async {}
}

/// Fills the payment registry the way the real provider does.
class _MasterData extends MasterDataProvider {
  _MasterData({this.payments = _payments});
  final List<PaymentMethod> payments;
  int fetches = 0;
  @override
  Future<List<MasterDataValue>?> fetchPaymentMethods(
      {bool forceRefresh = false}) async {
    fetches++;
    PaymentMethodRegistry.update(payments);
    return null;
  }
}

const _payments = [
  PaymentMethod(id: '1', code: 'CARD', label: 'Card'),
  PaymentMethod(id: '2', code: 'CASH', label: 'Cash'),
];

/// The server's product list (the slow fallback).
class _Products extends GridSelectionProvider {
  int serverLoads = 0;
  @override
  Future<void> listAllProducts(
      {int? categoryId,
      String? filterName,
      String? filterCategory,
      String? filterBarcode,
      String? filterPrice,
      String? filterCreatedBy,
      String? filterProperties,
      String? filterStore,
      String? filterSupplier,
      int page = 1}) async {}
  @override
  Future<void> listAllProductsAPI({int? categoryId, String? barCode}) async {}
  @override
  Future<List<GetProduct>> listAllProductsForReportFilter() async {
    serverLoads++;
    return [GetProduct(productId: 9, productName: 'Apple Juice')];
  }
}

/// The product catalog kept on the device for billing.
class _Catalog extends LocalProductProvider {
  _Catalog(this.items);
  final List<GetProduct> items;
  @override
  List<GetProduct> get products => items;
}

/// A row of `/api/v1/sales-report`.
Map<String, dynamic> _sale(int id) => {
      'order_id': id,
      'order_number': 'ORD-00$id',
      'order_date': '2026-10-15',
      'order_value': 21.0,
      'store_id': 5,
      'store_name': 'Main Store',
      'customer_id': 7,
      'customer_name': 'Test Default',
      'payment_methods': ['CARD'],
      'delivery_method_id': 11,
      'delivery_method': 'Store Takeaway',
      'sales_executive_id': 4,
      'sales_executive': 'salesexecutiv2',
      'items_quantity': 1,
    };

const _unavailable = 'Could not load the report. Showing the last loaded data.';
const _optionsUnavailable = 'Some filter options could not be loaded.';

void main() {
  late Directory hiveDir;
  setUpAll(() async {
    await initializeDateFormatting('en');
    Get.testMode = true;
    PaymentMethodRegistry.update(_payments);
    // LocalProductProvider reads its catalog from Hive.
    hiveDir = await Directory.systemTemp.createTemp('sales-report-page-');
    Hive.init(hiveDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HiveStringValueAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(HiveLocalCartItemAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(HiveSavedOrderAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(HiveProductAdapter());
    }
    await Hive.openBox<HiveProduct>('products');
    await Hive.openBox<HiveLocalCartItem>('cart_items');
    await Hive.openBox<HiveSavedOrder>('saved_orders');
    await Hive.openBox<HiveSavedOrder>('confirmed_orders');
  });
  tearDownAll(() async {
    PaymentMethodRegistry.clear();
    await closeHiveAndDeleteTestDir(hiveDir);
  });
  setUp(() => SharedPreferences.setMockInitialValues({'api_key': 'tenant'}));
  tearDown(() async {
    Get.reset();
    await awaitPendingHiveBoxWrites();
  });

  /// The Sales Report with 30 orders: two pages of 25 on screen, one page of
  /// 100 for the export.
  Future<(_Backend, CapturingExport, _Roles)> mount(WidgetTester tester,
      {Size size = const Size(1440, 900),
      String role = 'manager',
      _Delivery? delivery,
      MasterDataProvider? masterData,
      CustomerProvider? customers,
      List<GetProduct> catalog = const [],
      _Products? products,
      bool settle = true}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final backend = _Backend()
      ..all = [for (var i = 11; i <= 40; i++) _sale(i)]
      ..summary = {'orders': 30, 'order_value': 630.0};
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
          ChangeNotifierProvider<CategoryProvider>(
              create: (_) => _Categories()),
          ChangeNotifierProvider<CustomerProvider>(
              create: (_) => customers ?? _Customers()),
          ChangeNotifierProvider<DeliveryMethodsProvider>(
              create: (_) => delivery ?? _Delivery()),
          ChangeNotifierProvider<MasterDataProvider>(
              create: (_) => masterData ?? _MasterData()),
          ChangeNotifierProvider<GridSelectionProvider>(
              create: (_) => products ?? _Products()),
          ChangeNotifierProvider<LocalProductProvider>(
              create: (_) => _Catalog(catalog)),
        ],
        child: GetMaterialApp(
            translations: EnglishTranslations(),
            locale: const Locale('en'),
            home: Scaffold(
                body: SalesReportPage(
                    export: capture,
                    api: SalesReportApi(
                        endpoint: () => 'https://x.test/api/v1/sales-report',
                        get: backend.get,
                        session: const _Session()))))));
    if (settle) await tester.pumpAndSettle();
    return (backend, capture, roles);
  }

  Finder pickerOf(String label) => find
      .byWidgetPredicate((w) => w is NonStockReportPicker && w.label == label);

  NonStockReportPicker picker(WidgetTester tester, String label) =>
      tester.widget<NonStockReportPicker>(pickerOf(label));

  /// Opens [label]'s picker and picks [name] from its menu.
  Future<void> pick(WidgetTester tester, String label, String name) async {
    await tester.tap(
        find.descendant(of: pickerOf(label), matching: find.byType(TextField)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, name));
    await tester.pumpAndSettle();
  }

  testWidgets('a report covered by another screen reloads only when shown',
      (tester) async {
    final (backend, _, _) = await mount(tester, role: 'sales_executive');
    final context = tester.element(find.byType(SalesReportPage));
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
    expect(backend.reportRequests.last.queryParameters['sales_executive_ids'],
        '7');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a user or store switch while open re-locks the report',
      (tester) async {
    final (backend, _, _) = await mount(tester, role: 'sales_executive');
    final context = tester.element(find.byType(SalesReportPage));
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
      'period': 'this_month',
      'sales_executive_ids': '7',
      'store_ids': '5',
      'page': '1',
      'per_page': '25'
    });
    expect(shown('Sales Executives'), 'Second Exec');

    // The store changes underneath the open report.
    (Provider.of<StoreSessionProvider>(context, listen: false) as _Stores)
        .switchTo(Store(storeId: 6, storeName: 'Branch'));
    await tester.pumpAndSettle();
    expect(backend.reportRequests.last.queryParameters, {
      'period': 'this_month',
      'sales_executive_ids': '7',
      'store_ids': '6',
      'page': '1',
      'per_page': '25'
    });
    expect(shown('Stores'), 'Branch');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a sales executive sees only their own sales in their store',
      (tester) async {
    final (backend, _, _) = await mount(tester, role: 'sales_executive');
    expect(backend.reportRequests.first.queryParameters, {
      'period': 'this_month',
      'sales_executive_ids': '4',
      'store_ids': '5',
      'page': '1',
      'per_page': '25'
    });
    for (final (label, id, name) in [
      ('Sales Executives', '4', 'salesexecutiv2'),
      ('Stores', '5', 'Main Store'),
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
      'period': 'this_month',
      'sales_executive_ids': '4',
      'store_ids': '5',
      'page': '1',
      'per_page': '25'
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('products come from the device catalog, not the server',
      (tester) async {
    final server = _Products();
    await mount(tester, products: server, catalog: [
      GetProduct(productId: 31, productName: 'Mango Juice'),
      GetProduct(productId: 32, productName: 'Orange Juice'),
      GetProduct(productName: 'No id'),
    ]);
    expect(picker(tester, 'Products').options,
        {'31': 'Mango Juice', '32': 'Orange Juice'});
    expect(server.serverLoads, 0, reason: 'no page-by-page download');
  });

  testWidgets('an empty device catalog falls back to the server list',
      (tester) async {
    final fallback = _Products();
    await mount(tester, products: fallback);
    expect(picker(tester, 'Products').options, {'9': 'Apple Juice'});
    expect(fallback.serverLoads, 1);
  });

  testWidgets('web filters and columns, this month, all stores',
      (tester) async {
    final (backend, _, _) = await mount(tester);
    for (final column in [
      'SL#',
      'Order#',
      'Order Date',
      'Order Value',
      'Payment Methods',
      'Delivery Method',
      'Sales Exe'
    ]) {
      expect(find.text(column), findsWidgets, reason: column);
    }
    expect(find.text('ORD-0011'), findsOneWidget);
    expect(find.text('2026 Oct 15'), findsWidgets);
    expect(find.text('INR 21.00'), findsWidgets);
    // Payment codes are shown as the app's labels.
    expect(find.text('Card'), findsWidgets);
    expect(find.text('CARD'), findsNothing);
    expect(find.text('ORD-0036'), findsNothing, reason: 'page 2');
    expect(find.text('30 orders · Total INR 630.00'), findsOneWidget);

    final first = backend.reportRequests.single;
    expect(first.path, '/api/v1/sales-report');
    expect(first.queryParameters,
        {'period': 'this_month', 'page': '1', 'per_page': '25'});

    // Every directory is filled from the app's providers.
    expect(picker(tester, 'Stores').options, {'5': 'Main Store'});
    expect(picker(tester, 'Sales Executives').options, {'4': 'salesexecutiv2'});
    expect(
        picker(tester, 'Payment Methods').options, {'1': 'Card', '2': 'Cash'});
    expect(picker(tester, 'Delivery Modes').options, {'11': 'Store Takeaway'});
    expect(picker(tester, 'Categories').options, {'88': 'Juice'});
    expect(picker(tester, 'Products').options, {'9': 'Apple Juice'});
    expect(picker(tester, 'Customers').options, {'7': 'Test Default'});
    // The same single-choice picker as the Discount Sale report.
    expect(find.byType(NonStockReportPicker), findsNWidgets(7));
    expect(find.text('Sort'), findsOneWidget);
    expect(find.text(_optionsUnavailable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pages through the server result', (tester) async {
    final (backend, _, _) = await mount(tester);
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(backend.reportRequests.last.queryParameters,
        {'period': 'this_month', 'page': '2', 'per_page': '25'});
    expect(find.text('ORD-0036'), findsOneWidget);
    expect(find.text('ORD-0011'), findsNothing);
    expect(find.text('30 orders · Total INR 630.00'), findsOneWidget);
  });

  testWidgets('pick a payment method, search, reset', (tester) async {
    final (backend, _, _) = await mount(tester);
    await pick(tester, 'Payment Methods', 'Cash');
    // The id goes to the API; the name stays in the field.
    expect(
        backend.reportRequests.last.queryParameters['payment_method_ids'], '2');
    expect(picker(tester, 'Payment Methods').value, '2');
    final field = find.descendant(
        of: pickerOf('Payment Methods'), matching: find.byType(TextField));
    expect(tester.widget<TextField>(field).controller!.text, 'Cash');

    // Typing narrows the menu; Escape keeps the picked method.
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, 'ca');
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNWidgets(2));
    await tester.enterText(field, 'card');
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(picker(tester, 'Payment Methods').value, '2');
    expect(tester.widget<TextField>(field).controller!.text, 'Cash');

    // Hidden filters still apply, and the toggle says so.
    await tester.tap(find.byKey(SalesReportPage.filterToggleKey));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<AppSquareIconButton>(
                find.byKey(SalesReportPage.filterToggleKey))
            .badge,
        isTrue);
    await tester.tap(find.byKey(SalesReportPage.filterToggleKey));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(backend.reportRequests.last.queryParameters,
        {'period': 'this_month', 'page': '1', 'per_page': '25'});
    expect(picker(tester, 'Payment Methods').value, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sort: oldest first', (tester) async {
    final (backend, _, _) = await mount(tester);
    await tester.tap(find.text('Newest first'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oldest first').last);
    await tester.pumpAndSettle();
    expect(
        backend.reportRequests.last.queryParameters['sort_direction'], 'asc');
    expect(tester.takeException(), isNull);
  });

  testWidgets('date presets and Custom dates', (tester) async {
    final (backend, capture, _) = await mount(tester);
    expect(find.text('From Date'), findsNothing);
    await tester.tap(find.text('This Month'));
    await tester.pumpAndSettle();
    for (final option in ['Last Month', 'Last 3 Months', 'Custom']) {
      expect(find.text(option), findsWidgets, reason: option);
    }
    expect(find.text('Today'), findsNothing);
    expect(find.text('This Week'), findsNothing);
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();
    expect(find.text('From Date'), findsOneWidget);
    expect(find.text('To Date'), findsOneWidget);
    final params = backend.reportRequests.last.queryParameters;
    expect(params['period'], 'custom');
    expect(params['from'], matches(RegExp(r'^\d{4}-\d{2}-01$')));
    expect(params['to'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));

    // A cleared date is fixed in the filters: no request, no Retry, no Export.
    final before = backend.reportRequests.length;
    await tester.tap(find.byTooltip('Clear date').last);
    await tester.pumpAndSettle();
    expect(backend.reportRequests, hasLength(before));
    expect(find.text('Pick both From Date and To Date.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsNothing);
    await tester.tap(find.byKey(SalesReportPage.exportKey),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(capture.runs, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('export reads every page, 100 at a time', (tester) async {
    final (backend, capture, _) = await mount(tester);
    await useTempExportDirectory(tester, 'sales-report-');
    await tester.tap(find.byKey(SalesReportPage.exportKey));
    await tester.pumpAndSettle();
    expect(capture.runs, 1);
    final file = (await tester.runAsync(capture.createFile!))!;
    final sheet =
        Excel.decodeBytes(await tester.runAsync(file.readAsBytes) as List<int>)
            .tables['Sales Report']!;
    expect([
      for (final c in sheet.rows[0]) c?.value.toString()
    ], [
      'SL#',
      'Order#',
      'Order Date',
      'Order Value',
      'Payment Methods',
      'Delivery Method',
      'Sales Exe',
      'Applied Filters'
    ]);
    expect(sheet.maxRows, 31); // header + all 30 orders, not just page 1
    expect(sheet.rows[1][1]!.value.toString(), 'ORD-0011');
    expect(sheet.rows[30][1]!.value.toString(), 'ORD-0040');
    expect(sheet.rows[1][2]!.value.toString(), '2026-10-15');
    // Amounts are numbers, not text (21.0 reads back as an int cell).
    expect(sheet.rows[1][3]!.value,
        anyOf(isA<DoubleCellValue>(), isA<IntCellValue>()));
    expect(sheet.rows[1][4]!.value.toString(), 'Card');
    expect(sheet.rows[1].last!.value.toString(), 'Date Range: This Month');
    expect(backend.reportRequests.last.queryParameters['per_page'], '100');
    await tester.runAsync(() => File(file.path).delete());
  });

  testWidgets('the export file names the picked filters', (tester) async {
    final (_, capture, _) = await mount(tester);
    await useTempExportDirectory(tester, 'sales-report-');
    await pick(tester, 'Stores', 'Main Store');
    await tester.tap(find.byKey(SalesReportPage.exportKey));
    await tester.pumpAndSettle();
    final file = (await tester.runAsync(capture.createFile!))!;
    final sheet =
        Excel.decodeBytes(await tester.runAsync(file.readAsBytes) as List<int>)
            .tables['Sales Report']!;
    expect(sheet.rows[1].last!.value.toString(),
        'Date Range: This Month; Stores: Main Store');
    await tester.runAsync(() => File(file.path).delete());
  });

  testWidgets('a failed load shows Retry and disables Export', (tester) async {
    final (backend, capture, _) = await mount(tester);
    backend.fail = true;
    await tester.tap(find.byKey(SalesReportPage.refreshKey));
    await tester.pumpAndSettle();
    expect(find.text(_unavailable), findsOneWidget);
    expect(find.text('ORD-0011'), findsOneWidget, reason: 'rows are kept');
    await tester.tap(find.byKey(SalesReportPage.exportKey),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(capture.runs, 0, reason: 'Export is disabled');
    backend.fail = false;
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.text(_unavailable), findsNothing);
    await tester.tap(find.byKey(SalesReportPage.exportKey));
    await tester.pumpAndSettle();
    expect(capture.runs, 1, reason: 'Export is back');
  });

  testWidgets('Export needs the permission', (tester) async {
    final (_, capture, roles) = await mount(tester);
    roles.allowed = false;
    roles.notifyListeners();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SalesReportPage.exportKey),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(capture.runs, 0);
  });

  testWidgets(
      'empty directories: payments are fetched; no delivery modes is '
      'fine', (tester) async {
    PaymentMethodRegistry.clear();
    addTearDown(() => PaymentMethodRegistry.update(_payments));
    final master = _MasterData();
    await mount(tester,
        masterData: master, delivery: _Delivery(methods: [], fetched: true));
    expect(master.fetches, 1);
    expect(
        picker(tester, 'Payment Methods').options, {'1': 'Card', '2': 'Cash'});
    expect(picker(tester, 'Delivery Modes').options, isEmpty);
    expect(find.text(_optionsUnavailable), findsNothing);
  });

  testWidgets('payments that never load show Retry', (tester) async {
    PaymentMethodRegistry.clear();
    addTearDown(() => PaymentMethodRegistry.update(_payments));
    final master = _MasterData(payments: const []);
    await mount(tester, masterData: master);
    expect(master.fetches, 1);
    expect(find.text(_optionsUnavailable), findsOneWidget);
    expect(picker(tester, 'Payment Methods').options, isEmpty);
    expect(picker(tester, 'Stores').options, {'5': 'Main Store'});
  });

  testWidgets('a list that never loaded shows Retry, which reloads only it',
      (tester) async {
    final delivery = _Delivery(methods: [], fetched: false);
    final (backend, _, _) = await mount(tester, delivery: delivery);
    expect(find.text(_optionsUnavailable), findsOneWidget);
    expect(picker(tester, 'Stores').options, {'5': 'Main Store'});
    final executives = backend.requests.length - backend.reportRequests.length;
    delivery
      ..methods = [DeliveryMethod(id: '12', name: 'Door', code: 'DOOR')]
      ..fetched = true;
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.text(_optionsUnavailable), findsNothing);
    expect(picker(tester, 'Delivery Modes').options, {'12': 'Door'});
    expect(backend.requests.length - backend.reportRequests.length, executives,
        reason: 'the executives were not reloaded');
  });

  testWidgets('a slow list spins in its own picker only', (tester) async {
    final customers = Completer<List<CustomerListModelData>>();
    await mount(tester, customers: _Customers(customers.future), settle: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(picker(tester, 'Customers').loading, isTrue);
    expect(picker(tester, 'Stores').loading, isFalse);
    expect(find.text('ORD-0011'), findsOneWidget, reason: 'not held back');
    customers.complete([CustomerListModelData(id: 7, name: 'Test Default')]);
    await tester.pumpAndSettle();
    expect(picker(tester, 'Customers').loading, isFalse);
    expect(picker(tester, 'Customers').options, {'7': 'Test Default'});
  });

  testWidgets('phones start with the filters folded away, cards for rows',
      (tester) async {
    await mount(tester, size: const Size(375, 900));
    expect(find.textContaining('ORD-0011'), findsOneWidget);
    expect(find.text('INR 21.00'), findsWidgets);
    expect(find.text('Tap to show filters'), findsNothing);
    await tapFilterToggle(tester, key: SalesReportPage.filterToggleKey);
    await tester.pumpAndSettle();
    expect(find.text('Tap to show filters'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders on a tablet', (tester) async {
    await mount(tester, size: const Size(768, 900));
    expect(find.textContaining('ORD-0011'), findsOneWidget);
    expect(find.text('INR 21.00'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
