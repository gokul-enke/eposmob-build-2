import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/customers/presentation/widgets/profile/customer_transactions_tab.dart';
import 'package:pos_machine/features/customers/presentation/widgets/profile/transactions/transaction_card.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:provider/provider.dart';

import 'profile_test_helpers.dart';

class _Request {
  _Request(this.page, this.type, this.dateFrom);
  final int? page;
  final String? type;
  final String? dateFrom;
}

class _FakeInvoiceProvider extends InvoiceProvider {
  /// Every updateState value the tab passed.
  final updateStateArgs = <bool>[];
  _FakeInvoiceProvider({this.rows = 3, this.lastPage = 1, this.fail = false});

  final int rows;
  final int lastPage;
  bool fail;
  final requests = <_Request>[];

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
  }) async {
    requests.add(_Request(page, type, dateFrom));
    updateStateArgs.add(updateState);
    if (fail) throw Exception('offline');
    final current = page ?? 1;
    return {
      'data': {
        'current_page': current,
        'last_page': lastPage,
        'data': [
          for (var i = 1; i <= rows; i++)
            {
              'id': current * 100 + i,
              'reference_id': 'TXN-$current-$i',
              'reference': 'Invoice $i',
              'type': i.isEven ? 'debit' : 'credit',
              'amount': i.isEven ? '25.00' : '+100.00',
              'currency': 'INR',
              'payment_method': 'cash',
              'status': 'completed',
              'date': '2026-02-0$i',
              'transaction_comment': 'Comment $i',
            },
        ],
      },
    };
  }
}

Future<_FakeInvoiceProvider> _pump(
  WidgetTester tester, {
  required Size size,
  _FakeInvoiceProvider? invoices,
}) async {
  useSurfaceSize(tester, size);
  final provider = invoices ?? _FakeInvoiceProvider();
  final auth = AuthModel()..login('token', 1);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthModel>.value(value: auth),
        ChangeNotifierProvider<InvoiceProvider>.value(value: provider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: CustomerTransactionsTab(customer: testCustomer()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return provider;
}

final _table = find.byWidgetPredicate((w) => w is AppDataTable);

void main() {
  group('CustomerTransactionsTab', () {
    testWidgets('wide layout shows the table', (tester) async {
      final api = await _pump(tester, size: const Size(1280, 800));

      expect(api.requests.single.page, 1);
      // The tab owns its list and must not replace the shared one.
      expect(api.updateStateArgs, everyElement(isFalse));
      expect(_table, findsOneWidget);
      expect(find.text('TXN-1-1'), findsOneWidget);
      expect(find.byType(TransactionCard), findsNothing);
      expect(find.text('Transactions'), findsOneWidget);
      // Single page: no pagination bar.
      expect(find.byKey(const ValueKey('app_pagination_bar')), findsNothing);
    });

    testWidgets('narrow layout shows cards', (tester) async {
      await _pump(tester, size: const Size(375, 812));

      expect(_table, findsNothing);
      expect(find.byType(TransactionCard), findsWidgets);
      expect(find.text('TXN-1-1'), findsOneWidget);
    });

    testWidgets('pagination loads the next page', (tester) async {
      final api = await _pump(
        tester,
        size: const Size(1280, 800),
        invoices: _FakeInvoiceProvider(lastPage: 2),
      );

      expect(find.byKey(const ValueKey('app_pagination_bar')), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();

      expect(api.requests.last.page, 2);
      expect(find.text('TXN-2-1'), findsOneWidget);
    });

    testWidgets('empty list shows the empty state', (tester) async {
      await _pump(
        tester,
        size: const Size(375, 812),
        invoices: _FakeInvoiceProvider(rows: 0),
      );
      expect(find.text('No Transactions Found'), findsOneWidget);
    });

    testWidgets('a failed load offers a retry', (tester) async {
      final api = _FakeInvoiceProvider(fail: true);
      await _pump(tester, size: const Size(1280, 800), invoices: api);

      expect(find.text('Try Again'), findsOneWidget);
      api.fail = false;
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(find.text('TXN-1-1'), findsOneWidget);
    });

    testWidgets('View opens the transaction details', (tester) async {
      await _pump(tester, size: const Size(375, 812));

      await tester.tap(find.text('View details').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('Transaction ID'), findsOneWidget);
      expect(find.text('Comment 1'), findsOneWidget);
    });

    testWidgets('filters apply the type and reload page 1', (tester) async {
      final api = await _pump(tester, size: const Size(1280, 800));

      await tester.tap(find.byTooltip('Filter transactions'));
      await tester.pumpAndSettle();
      expect(find.text('Apply Filters'), findsOneWidget);

      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      expect(api.requests, hasLength(2));
      expect(api.requests.last.page, 1);
      expect(find.text('Apply Filters'), findsNothing);
    });
  });
}
