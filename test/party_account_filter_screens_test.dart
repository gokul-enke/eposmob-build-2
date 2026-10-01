import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/filter_toggle_button.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/transaction_provider.dart';
import 'package:pos_machine/screens/transactions/supplier_transactions/supplier_transactions.dart';
import 'package:pos_machine/screens/transactions/transaction_list.dart';
import 'package:provider/provider.dart';

class _TestTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': {
          'pagination.page_of': 'Page @current of @total',
          'party_accounts.page_count': '@count transactions on this page',
          'supplier_transactions.page_count':
              '@count transactions on this page',
          'party_accounts.title': 'Customer Transaction',
          'party_accounts.hint_select_type': 'Select Type',
          'party_accounts.filters': 'Filters',
          'party_accounts.hide_filters': 'Hide Filters',
          'supplier_transactions.title': 'Supplier Transactions',
          'supplier_transactions.filters': 'Filters',
          'supplier_transactions.hide_filters': 'Hide Filters',
        },
      };
}

class _FakeInvoiceProvider extends InvoiceProvider {
  @override
  Future<dynamic> listCustomerTransactions({
    required String accessToken,
    String? customerId,
    String? dateFrom,
    String? dateTo,
    String? transactionType,
    String? type,
    int? perPage,
    int? page,
    bool updateState = true,
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

class _FakeTransactionProvider extends TransactionProvider {
  @override
  Future<void> fetchTransactionsFromServerV2({
    String? supplierId,
    String? transactionType,
    String? type,
    String? dateFrom,
    String? dateTo,
    int? perPage,
    int? page,
  }) async {}
}

void main() {
  setUpAll(() => Get.testMode = true);
  tearDown(() => Get.reset());

  Future<void> verifyFiltersCollapse(
    WidgetTester tester, {
    required Widget screen,
    required Key toggleKey,
    required Key filterKey,
    Size surfaceSize = const Size(1440, 900),
  }) async {
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthModel()),
          ChangeNotifierProvider<InvoiceProvider>(
            create: (_) => _FakeInvoiceProvider(),
          ),
          ChangeNotifierProvider<TransactionProvider>(
            create: (_) => _FakeTransactionProvider(),
          ),
        ],
        child: GetMaterialApp(
          translations: _TestTranslations(),
          locale: const Locale('en', 'US'),
          home: Scaffold(body: screen),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(toggleKey), findsOneWidget);
    if (find.byKey(filterKey).evaluate().isEmpty) {
      await tester.tap(find.byKey(toggleKey));
      await tester.pump();
    }
    expect(find.byKey(filterKey), findsOneWidget);

    await tester.tap(find.byKey(toggleKey));
    await tester.pump();

    expect(find.byKey(filterKey), findsNothing);
    expect(find.byType(FilterToggleButton), findsOneWidget);
  }

  testWidgets('Customer Transactions collapses its desktop filters',
      (tester) async {
    await verifyFiltersCollapse(
      tester,
      screen: const CustomerTransactionListScreen(),
      toggleKey: const ValueKey('customer-transactions-filter-toggle'),
      filterKey: const ValueKey('customer-transactions-desktop-filters'),
    );
  });

  testWidgets('Supplier Transactions collapses its desktop filters',
      (tester) async {
    await verifyFiltersCollapse(
      tester,
      screen: const TransactionScreen(),
      toggleKey: const ValueKey('supplier-transactions-filter-toggle'),
      filterKey: const ValueKey('supplier-transactions-filters'),
    );
  });

  testWidgets('Customer Transactions collapses its mobile filters',
      (tester) async {
    await verifyFiltersCollapse(
      tester,
      screen: const CustomerTransactionListScreen(),
      toggleKey: const ValueKey('customer-transactions-filter-toggle'),
      filterKey: const ValueKey('customer-transactions-mobile-filters'),
      surfaceSize: const Size(600, 900),
    );
  });

  testWidgets('Supplier Transactions collapses its mobile filters',
      (tester) async {
    await verifyFiltersCollapse(
      tester,
      screen: const TransactionScreen(),
      toggleKey: const ValueKey('supplier-transactions-filter-toggle'),
      filterKey: const ValueKey('supplier-transactions-filters'),
      surfaceSize: const Size(600, 900),
    );
  });

  testWidgets('Customer date remains visible after filters are reopened',
      (tester) async {
    await verifyFiltersCollapse(
      tester,
      screen: const CustomerTransactionListScreen(),
      toggleKey: const ValueKey('customer-transactions-filter-toggle'),
      filterKey: const ValueKey('customer-transactions-desktop-filters'),
      surfaceSize: const Size(1920, 1080),
    );

    await tester.tap(
      find.byKey(const ValueKey('customer-transactions-filter-toggle')),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('customer-transactions-date')));
    await tester.pumpAndSettle();

    final calendar = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    final selectedDate = DateTime(DateTime.now().year, 1, 15);
    final selectedDateLabel = DateFormat('MMM dd, yyyy').format(selectedDate);
    calendar.onDateChanged(selectedDate);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text(selectedDateLabel), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('customer-transactions-filter-toggle')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('customer-transactions-filter-toggle')),
    );
    await tester.pump();

    expect(find.text(selectedDateLabel), findsOneWidget);
  });

  testWidgets('party account filters expand without overflow on a short phone',
      (tester) async {
    final cases = <(Widget, Key, Key)>[
      (
        const CustomerTransactionListScreen(),
        const ValueKey('customer-transactions-filter-toggle'),
        const ValueKey('customer-transactions-mobile-filters'),
      ),
      (
        const TransactionScreen(),
        const ValueKey('supplier-transactions-filter-toggle'),
        const ValueKey('supplier-transactions-filters'),
      ),
    ];
    final failures = <String>[];

    for (final testCase in cases) {
      tester.view.physicalSize = const Size(390, 650);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthModel()),
            ChangeNotifierProvider<InvoiceProvider>(
              create: (_) => _FakeInvoiceProvider(),
            ),
            ChangeNotifierProvider<TransactionProvider>(
              create: (_) => _FakeTransactionProvider(),
            ),
          ],
          child: GetMaterialApp(
            translations: _TestTranslations(),
            locale: const Locale('en', 'US'),
            home: Scaffold(body: testCase.$1),
          ),
        ),
      );
      await tester.pump();

      if (find.byKey(testCase.$3).evaluate().isEmpty) {
        await tester.tap(find.byKey(testCase.$2));
        await tester.pump();
      }
      expect(find.byKey(testCase.$3), findsOneWidget);

      await tester.pumpAndSettle();
      final exception = tester.takeException();
      if (exception != null) {
        failures.add('${testCase.$1.runtimeType}: $exception');
      }
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    expect(failures, isEmpty);
  });
}
