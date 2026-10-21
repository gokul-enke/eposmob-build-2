import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/dashboard_widget_data.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/models/role.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/dashboard_widgets_repository.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/resources/app_translations.dart';
import 'package:pos_machine/screens/dashboard/widgets/dashboard_additional_widgets.dart';
import 'package:pos_machine/screens/dashboard/widgets/dashboard_data_section.dart';
import 'package:provider/provider.dart';

const _allNewWidgetPermissions = [
  'dashboard.widgets.orders_widget.total_orders_today.access',
  'dashboard.widgets.orders_widget.average_order_amount.access',
  'dashboard.widgets.latest_orders.access',
  'dashboard.widgets.customer_transactions_summary.total_customers.access',
  'dashboard.widgets.customer_transactions_summary.total_credit.access',
  'dashboard.widgets.customer_transactions_summary.total_debit.access',
  'dashboard.widgets.customer_transactions_summary.total_balance.access',
  'dashboard.widgets.suppliers_graph.access',
  'dashboard.widgets.revenue_stats.access',
];

class _Roles extends RoleProvider {
  _Roles(this.permissions);
  final List<String> permissions;
  @override
  String? get currentUserRole => 'company_admin';
  @override
  List<Role> get roles => [
        Role(
          id: 1,
          name: 'Company Admin',
          originalName: 'company_admin',
          guardName: 'web',
          permissionsCount: permissions.length,
          permissions: permissions,
          companyId: 1,
          companyName: 'Demo',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];
}

class _Settings extends AppSettingsProvider {
  String currency = 'SAR';
  @override
  Future<void> fetchAppSettings() async {}
  @override
  AppSettings get appSettings => AppSettings.fromJson({
        'data': [
          {'code': 'CURRENCY', 'value': currency, 'status': true},
        ]
      });
  void changeCurrency(String value) {
    currency = value;
    notifyListeners();
  }
}

class _Repository extends DashboardWidgetsRepository {
  final calls = <String, int>{};
  bool latestFails = false;
  bool empty = false;
  int today = 1;
  void _called(String name) => calls[name] = (calls[name] ?? 0) + 1;

  @override
  Future<OrdersWidgetData> fetchOrdersWidget(String token) async {
    _called('orders');
    return OrdersWidgetData(todayCount: today, averageAmount: 404.8141128);
  }

  @override
  Future<LatestOrdersData> fetchLatestOrders(String token) async {
    _called('latest');
    if (latestFails) throw const FormatException('Failed latest orders');
    return LatestOrdersData(empty
        ? []
        : [
            const LatestDashboardOrder(
              id: '6892',
              date: '2026-10-13',
              customerName: '',
              status: 'confirmed',
              grandTotal: 14.125,
            ),
            LatestDashboardOrder(
              id: '6893',
              date: '',
              customerName: 'Long customer name ' * 30,
              status: '',
              grandTotal: 999999999.125,
            )
          ]);
  }

  @override
  Future<CustomerTransactionsSummaryData> fetchCustomerTransactionsSummary(
      String token) async {
    _called('customers');
    return const CustomerTransactionsSummaryData(
        customers: 221,
        credit: 1422624.945,
        debit: 1909661.735,
        balance: -487036.79);
  }

  @override
  Future<RevenueStatsData> fetchRevenueStats(String token) async {
    _called('revenue');
    return const RevenueStatsData(
      totalOnOrder: 293624.30000000005,
      creditCollected: 9200,
      creditSales: 36662.2,
      totalInBank: 883490.92,
      totalInCash: 797509.706,
    );
  }

  @override
  Future<SuppliersGraphData> fetchSuppliersGraph(String token) async {
    _called('suppliers');
    return SuppliersGraphData(
      labels: empty
          ? []
          : [
              'Jan',
              'Feb',
              'Mar',
              'Apr',
              'May',
              'Jun',
              'Jul',
              'Aug',
              'Sep',
              'Oct',
              'Nov',
              'Dec'
            ],
      counts: empty ? [] : [3, 14, 3, 1, 7, 1, 8, 6, 0, 0, 0, 15],
    );
  }
}

Map<String, String> _flatten(Map<String, dynamic> values,
    [String prefix = '']) {
  final result = <String, String>{};
  for (final entry in values.entries) {
    final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
    if (entry.value is Map<String, dynamic>) {
      result.addAll(_flatten(entry.value as Map<String, dynamic>, key));
    } else {
      result[key] = entry.value.toString();
    }
  }
  return result;
}

void main() {
  final translations = {
    for (final locale in ['en', 'ar', 'ml'])
      locale: _flatten(
          jsonDecode(File('lib/resources/i18n/$locale.json').readAsStringSync())
              as Map<String, dynamic>),
  };
  tearDown(Get.reset);

  Future<void> mount(
    WidgetTester tester,
    _Repository repository, {
    String locale = 'en',
    double width = 1280,
    bool supplierOnly = false,
    AuthModel? auth,
    _Settings? settings,
    List<String> permissions = _allNewWidgetPermissions,
  }) async {
    tester.view.reset();
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final account = auth ?? (AuthModel()..login('demo-token', 1));
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthModel>.value(value: account),
        ChangeNotifierProvider<AppSettingsProvider>.value(
            value: settings ?? _Settings()),
        ChangeNotifierProvider<RoleProvider>.value(value: _Roles(permissions)),
      ],
      child: GetMaterialApp(
        locale: Locale(locale),
        fallbackLocale: const Locale('en'),
        translations: AppTranslations(translations),
        home: Scaffold(
            body: SingleChildScrollView(
                child: DashboardAdditionalWidgets(
                    repository: repository, supplierOnly: supplierOnly))),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final locale in ['en', 'ar', 'ml']) {
    for (final width in [320.0, 768.0, 1440.0]) {
      testWidgets('four widgets render without overflow in $locale at $width',
          (tester) async {
        final repository = _Repository();
        await mount(tester, repository, locale: locale, width: width);
        expect(repository.calls, {
          'orders': 1,
          'latest': 1,
          'customers': 1,
          'revenue': 1,
          'suppliers': 1
        });
        expect(
            find.text(
                translations[locale]!['dashboard.new_widgets.orders_summary']!),
            findsOneWidget);
        expect(
            find.text(translations[locale]![
                'dashboard.new_widgets.unknown_customer']!),
            findsOneWidget);
        expect(find.text(translations[locale]!['sales.status_confirmed']!),
            findsOneWidget);
        expect(find.textContaining('-487,036.79'), findsOneWidget);
        expect(find.textContaining('883,490.92'), findsOneWidget);
        expect(find.textContaining('14.13'), findsOneWidget);
        expect(find.byType(BarChart), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('widgets without role permission are hidden and not fetched',
      (tester) async {
    final repository = _Repository();
    await mount(tester, repository, permissions: const []);
    expect(repository.calls, isEmpty);
    expect(find.byType(BarChart), findsNothing);
    expect(find.text('Latest Orders'), findsNothing);
  });

  testWidgets('only permitted cards of a widget are shown', (tester) async {
    final repository = _Repository();
    await mount(tester, repository, permissions: const [
      'dashboard.widgets.orders_widget.total_orders_today.access',
      'dashboard.widgets.latest_orders.access',
    ]);
    expect(repository.calls, {'orders': 1, 'latest': 1});
    expect(find.text('Orders Today'), findsOneWidget);
    expect(find.text('Average Order Amount'), findsNothing);
    expect(find.byType(BarChart), findsNothing);
  });

  testWidgets('one failed API does not block others; only that widget retries',
      (tester) async {
    final repository = _Repository()..latestFails = true;
    await mount(tester, repository);
    expect(find.text('Could not load this widget.'), findsOneWidget);
    expect(find.text('221'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    repository.latestFails = false;
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load this widget.'), findsNothing);
    expect(find.text('6892'), findsOneWidget);
    expect(repository.calls, {
      'orders': 1,
      'latest': 2,
      'customers': 1,
      'revenue': 1,
      'suppliers': 1
    });
  });

  testWidgets(
      'refresh updates only its section; currency rebuild does not refetch',
      (tester) async {
    final repository = _Repository();
    final settings = _Settings();
    await mount(tester, repository, settings: settings);
    repository.today = 2;
    final orders = find.byKey(const ValueKey('new_orders_widget'));
    final refresh =
        find.descendant(of: orders, matching: find.byType(IconButton));
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(
        find.descendant(of: orders, matching: find.text('2')), findsOneWidget);
    expect(repository.calls, {
      'orders': 2,
      'latest': 1,
      'customers': 1,
      'revenue': 1,
      'suppliers': 1
    });
    settings.changeCurrency('AED');
    await tester.pumpAndSettle();
    expect(find.textContaining('AED 404.81'), findsOneWidget);
    expect(repository.calls, {
      'orders': 2,
      'latest': 1,
      'customers': 1,
      'revenue': 1,
      'suppliers': 1
    });
  });

  testWidgets(
      'empty data is visible and supplier role loads only supplier graph',
      (tester) async {
    final repository = _Repository()..empty = true;
    await mount(tester, repository, supplierOnly: true);
    expect(repository.calls, {'suppliers': 1});
    expect(find.text('No data available'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
    expect(find.byKey(const ValueKey('new_orders_widget')), findsNothing);
  });

  testWidgets(
      'no widget requests are made before login; logout removes loaded data',
      (tester) async {
    final repository = _Repository();
    final auth = AuthModel();
    await mount(tester, repository, auth: auth);
    expect(repository.calls, isEmpty);
    auth.login('demo-token', 1);
    await tester.pumpAndSettle();
    expect(repository.calls.length, 5);
    expect(find.text('6892'), findsOneWidget);
    auth.logout();
    await tester.pumpAndSettle();
    expect(find.text('6892'), findsNothing);
  });

  testWidgets('empty latest orders and all-zero supplier counts are valid',
      (tester) async {
    final repository = _Repository()..empty = true;
    await mount(tester, repository);
    expect(find.text('No data available'), findsNWidgets(2));
    expect(find.byType(DataTable), findsNothing);
    final data =
        SuppliersGraphData(labels: ['Jan', 'Feb', 'Mar'], counts: [0, 0, 0]);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SuppliersCountGraph(data: data)),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(BarChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'new request scope discards stale completion and disposal is safe',
      (tester) async {
    final old = Completer<int>();
    final current = Completer<int>();
    var calls = 0;
    Widget section(Object requestKey, Future<int> result) => GetMaterialApp(
          translations: AppTranslations(translations),
          locale: const Locale('en'),
          home: Scaffold(
              body: DashboardDataSection<int>(
            title: 'Scope test',
            requestKey: requestKey,
            load: () {
              calls++;
              return result;
            },
            builder: (value) => Text('Result $value'),
          )),
        );
    await tester.pumpWidget(section('old-login', old.future));
    final refresh = tester.widget<IconButton>(find.byType(IconButton));
    expect(refresh.onPressed, isNull);
    await tester.pumpWidget(section('new-login', current.future));
    current.complete(2);
    await tester.pumpAndSettle();
    old.complete(1);
    await tester.pumpAndSettle();
    expect(find.text('Result 2'), findsOneWidget);
    expect(find.text('Result 1'), findsNothing);
    expect(calls, 2);
    final pending = Completer<int>();
    await tester.pumpWidget(section('another-login', pending.future));
    await tester.pumpWidget(const SizedBox());
    pending.completeError(StateError('Late request failed'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
