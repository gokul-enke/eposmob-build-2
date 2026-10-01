import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/models/supplier.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/report_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/providers/supplier_provider.dart';
import 'package:pos_machine/providers/transaction_provider.dart';
import 'package:pos_machine/screens/reports/consumed_stocks_report/consumed_stocks_report.dart';
import 'package:pos_machine/screens/reports/customer_transactions_reports/customer_tranctions_reports .dart';
import 'package:pos_machine/screens/reports/non_stock_report/non_stock_report.dart';
import 'package:pos_machine/screens/reports/sales_executive_report/sales_executive_report.dart';
import 'package:pos_machine/screens/reports/stock_report/stock_report.dart';
import 'package:pos_machine/screens/reports/supplier_transaction_report/supplier_transaction_report.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support/hive_test_teardown.dart';

class _FakeSalesExecutiveProvider extends SalesExecutiveProvider {
  @override
  Future<void> fetchSalesExecutives(BuildContext context) async {}

  @override
  Future<dynamic> getSalesExecutiveReport({
    required BuildContext context,
    String? fromDate,
    String? toDate,
    bool updateState = true,
  }) async =>
      {'status': 'success', 'data': <dynamic>[]};
}

class _FakeInvoiceProvider extends InvoiceProvider {
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
  }) async =>
      {
        'status': 'success',
        'data': {
          'data': <dynamic>[],
          'current_page': 1,
          'last_page': 1,
        },
      };
}

class _FakeCustomerProvider extends CustomerProvider {
  @override
  Future<void> fetchCustomers({
    required String accessToken,
    String? customerName,
    bool listAll = true,
  }) async {}
}

class _FakeSupplierProvider extends SupplierProvider {
  @override
  Future<List<Supplier>?> fetchSuppliers({
    required String accessToken,
    String? supplierName,
  }) async =>
      <Supplier>[];

  @override
  Future<Map<String, dynamic>> fetchSupplierTransactions({
    required String accessToken,
    String? supplierName,
    String? supplierId,
    String? transactionType,
    String? fromDate,
    String? toDate,
    bool listAll = true,
    int? page,
  }) async =>
      {
        'data': {
          'data': <dynamic>[],
          'current_page': 1,
          'last_page': 1,
        },
      };
}

class _FakeReportsProvider extends ReportsProvider {
  @override
  Future<void> fetchStockReport({
    required String accessToken,
    String? product,
    String? sortBy,
    String? sortDirection,
    int? storeId,
    int? categoryId,
    String? stockLevel,
    String? expiringWithin,
    String? snapshotDate,
    String? from,
    String? until,
    int? page,
    int? perPage,
  }) async {}

  @override
  Future<void> fetchNonStockReport({
    required String accessToken,
    String? store,
    String? category,
    String? product,
    String? barcode,
    int? page,
  }) async {}

  @override
  Future<void> fetchConsumedStocksReport({
    required String accessToken,
    String? productId,
    String? storeId,
    String? from,
    String? until,
    int? page,
  }) async {}
}

class _ReportTestTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': {
          'pagination.page_of': 'Page @current of @total',
          'pagination.previous': 'Previous',
          'pagination.page': 'Page',
          'pagination.of': 'of',
          'pagination.next': 'Next',
        },
      };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    Get.testMode = true;
    hiveDir = await Directory.systemTemp.createTemp('report_filter_screens_');
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'api_key': 'test-api-key',
      'stores': '[]',
    });
    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
  });

  tearDown(() async {
    Get.reset();
    await awaitPendingHiveBoxWrites();
  });

  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

  Widget wrapScreen(
    Widget screen, {
    CustomerProvider? customerProvider,
  }) {
    final auth = AuthModel()..login('test-token', 1);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthModel>.value(value: auth),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider<SalesExecutiveProvider>(
          create: (_) => _FakeSalesExecutiveProvider(),
        ),
        ChangeNotifierProvider<CustomerProvider>.value(
          value: customerProvider ?? _FakeCustomerProvider(),
        ),
        ChangeNotifierProvider<InvoiceProvider>(
          create: (_) => _FakeInvoiceProvider(),
        ),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider<SupplierProvider>(
          create: (_) => _FakeSupplierProvider(),
        ),
        ChangeNotifierProvider<ReportsProvider>(
          create: (_) => _FakeReportsProvider(),
        ),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => LocalProductProvider()),
        ChangeNotifierProvider(create: (_) => StoreSessionProvider()),
        ChangeNotifierProvider(create: (_) => RoleProvider()),
      ],
      child: GetMaterialApp(
        translations: _ReportTestTranslations(),
        locale: const Locale('en', 'US'),
        home: Scaffold(body: screen),
      ),
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    CustomerProvider? customerProvider,
    Size size = const Size(1440, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapScreen(screen, customerProvider: customerProvider),
    );
    await tester.pump();
  }

  Future<void> verifyDesktopCollapse(
    WidgetTester tester, {
    required Widget screen,
    required Key toggleKey,
    required Key panelKey,
  }) async {
    await pumpScreen(tester, screen);

    expect(find.byKey(toggleKey), findsOneWidget);
    expect(find.byKey(panelKey), findsOneWidget);

    await tester.tap(find.byKey(toggleKey));
    await tester.pump();

    expect(find.byKey(panelKey), findsNothing);
    expect(find.byKey(toggleKey), findsOneWidget);
  }

  Future<void> verifyMobileExpansion(
    WidgetTester tester, {
    required Widget screen,
    required Key toggleKey,
    required Key panelKey,
  }) async {
    await pumpScreen(tester, screen, size: const Size(390, 650));

    expect(find.byKey(toggleKey), findsOneWidget);
    expect(find.byKey(panelKey), findsNothing);

    await tester.tap(find.byKey(toggleKey));
    await tester.pump();

    expect(find.byKey(panelKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  testWidgets('Sales Executive Report collapses its desktop filters',
      (tester) async {
    await verifyDesktopCollapse(
      tester,
      screen: const SalesExecutiveReportScreen(),
      toggleKey: const ValueKey('sales-executive-report-filter-toggle'),
      panelKey: const ValueKey('sales-executive-report-filters'),
    );
  });

  testWidgets('Customer Transactions Report collapses its desktop filters',
      (tester) async {
    await verifyDesktopCollapse(
      tester,
      screen: const CustomerTransactionsReportScreen(),
      toggleKey: const ValueKey('customer-transactions-report-filter-toggle'),
      panelKey: const ValueKey('customer-transactions-report-filters'),
    );
  });

  testWidgets('Supplier Transactions Report collapses its desktop filters',
      (tester) async {
    await verifyDesktopCollapse(
      tester,
      screen: const SupplierTransactionReportScreen(),
      toggleKey: const ValueKey('supplier-transactions-report-filter-toggle'),
      panelKey: const ValueKey('supplier-transactions-report-filters'),
    );
  });

  testWidgets('Stock Report collapses its desktop filters', (tester) async {
    await verifyDesktopCollapse(
      tester,
      screen: const StockReportScreen(),
      toggleKey: const ValueKey('stock-report-filter-toggle'),
      panelKey: const ValueKey('stock-report-filters'),
    );
  });

  testWidgets('Non-Stock Report collapses its desktop filters', (tester) async {
    await verifyDesktopCollapse(
      tester,
      screen: const NonStockReportScreen(),
      toggleKey: const ValueKey('non-stock-report-filter-toggle'),
      panelKey: const ValueKey('non-stock-report-filters'),
    );
  });

  testWidgets('Consumed Stocks Report collapses its desktop filters',
      (tester) async {
    await verifyDesktopCollapse(
      tester,
      screen: const ConsumedStocksReportScreen(),
      toggleKey: const ValueKey('consumed-stocks-report-filter-toggle'),
      panelKey: const ValueKey('consumed-stocks-report-filters'),
    );
  });

  testWidgets('report filters expand without overflow on a short phone',
      (tester) async {
    final cases = <(Widget, Key, Key)>[
      (
        const SalesExecutiveReportScreen(),
        const ValueKey('sales-executive-report-filter-toggle'),
        const ValueKey('sales-executive-report-filters'),
      ),
      (
        const CustomerTransactionsReportScreen(),
        const ValueKey('customer-transactions-report-filter-toggle'),
        const ValueKey('customer-transactions-report-filters'),
      ),
      (
        const SupplierTransactionReportScreen(),
        const ValueKey('supplier-transactions-report-filter-toggle'),
        const ValueKey('supplier-transactions-report-filters'),
      ),
      (
        const StockReportScreen(),
        const ValueKey('stock-report-filter-toggle'),
        const ValueKey('stock-report-filters'),
      ),
      (
        const NonStockReportScreen(),
        const ValueKey('non-stock-report-filter-toggle'),
        const ValueKey('non-stock-report-filters'),
      ),
      (
        const ConsumedStocksReportScreen(),
        const ValueKey('consumed-stocks-report-filter-toggle'),
        const ValueKey('consumed-stocks-report-filters'),
      ),
    ];

    for (final testCase in cases) {
      await verifyMobileExpansion(
        tester,
        screen: testCase.$1,
        toggleKey: testCase.$2,
        panelKey: testCase.$3,
      );
    }
  });

  testWidgets('Customer selection marks filters active and reset clears it',
      (tester) async {
    final customerProvider = _FakeCustomerProvider()
      ..setSelectedCustomerId('42')
      ..setSelectedCustomerName('Test Customer');

    await pumpScreen(
      tester,
      const CustomerTransactionsReportScreen(),
      customerProvider: customerProvider,
    );

    final toggle = find.byKey(
      const ValueKey('customer-transactions-report-filter-toggle'),
    );
    expect(
      find.descendant(
        of: toggle,
        matching: find.byType(PositionedDirectional),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('customer-transactions-report-reset')),
    );
    await tester.pump();

    expect(customerProvider.selectedCustomerId, isNull);
    expect(
      find.descendant(
        of: toggle,
        matching: find.byType(PositionedDirectional),
      ),
      findsNothing,
    );
  });
}
