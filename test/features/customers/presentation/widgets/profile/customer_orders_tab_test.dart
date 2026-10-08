import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_orders_controller.dart';
import 'package:pos_machine/features/customers/presentation/widgets/profile/customer_orders_tab.dart';
import 'package:pos_machine/features/customers/presentation/widgets/profile/orders/customer_orders_view.dart';
import 'package:pos_machine/features/customers/presentation/widgets/profile/orders/order_card.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:provider/provider.dart';

import 'profile_test_helpers.dart';

final _table = find.byWidgetPredicate((w) => w is AppDataTable);

ListOrderModelData _order(int page, int i) => ListOrderModelData(
      id: page * 100 + i,
      orderNumber: 'ORD-$page-$i',
      orderDate: DateTime(2026, 2, i),
      status: i.isEven ? 'pending' : 'completed',
      paymentStatus: 'paid',
      grantTotal: '${i}0.00',
      priceSummary: PriceSummary(grandTotal: '${i}0.00', taxTotal: '1.50'),
      cartItems: [
        CartItem(productName: 'Tea', quantity: 2, totalPrice: '9.00')
      ],
    );

class _FakeOrders {
  _FakeOrders({this.count = 3, this.totalPages = 1});

  final int count;
  final int totalPages;
  bool fail = false;
  final pages = <int>[];

  Future<CustomerOrdersPage> call({
    required String accessToken,
    required int customerId,
    required int page,
  }) async {
    pages.add(page);
    if (fail) throw Exception('offline');
    return CustomerOrdersPage(
      orders: [for (var i = 1; i <= count; i++) _order(page, i)],
      currentPage: page,
      totalPages: totalPages,
    );
  }
}

Future<CustomerOrdersController> _pumpView(
  WidgetTester tester, {
  required Size size,
  required _FakeOrders api,
}) async {
  useSurfaceSize(tester, size);
  final controller = CustomerOrdersController(
    fetch: api.call,
    readToken: () => 'token',
    customerId: 42,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: CustomerOrdersView(
            controller: controller,
            currency: '₹',
            customerName: 'Asha Menon',
          ),
        ),
      ),
    ),
  );
  await controller.load(page: 1);
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  group('CustomerOrdersView', () {
    testWidgets('wide layout shows the table', (tester) async {
      await _pumpView(tester, size: const Size(1280, 800), api: _FakeOrders());

      expect(_table, findsOneWidget);
      expect(find.byType(OrderCard), findsNothing);
      expect(find.text('Order #ORD-1-1'), findsOneWidget);
      expect(find.text('₹10.00'), findsOneWidget);
      expect(find.text('COMPLETED'), findsWidgets);
      expect(find.byKey(const ValueKey('app_pagination_bar')), findsNothing);
    });

    testWidgets('narrow layout shows cards', (tester) async {
      await _pumpView(tester, size: const Size(375, 812), api: _FakeOrders());

      expect(_table, findsNothing);
      expect(find.byType(OrderCard), findsWidgets);
      expect(find.text('Order #ORD-1-1'), findsOneWidget);
    });

    testWidgets('pagination requests the next page', (tester) async {
      final api = _FakeOrders(totalPages: 2);
      await _pumpView(tester, size: const Size(375, 812), api: api);

      expect(find.byKey(const ValueKey('app_pagination_bar')), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();

      expect(api.pages, [1, 2]);
      expect(find.text('Order #ORD-2-1'), findsOneWidget);
    });

    testWidgets('empty list shows the empty state', (tester) async {
      await _pumpView(tester,
          size: const Size(1280, 800), api: _FakeOrders(count: 0));
      expect(find.text('No Orders Found'), findsOneWidget);
    });

    testWidgets('error shows the message and Try Again reloads',
        (tester) async {
      final api = _FakeOrders()..fail = true;
      await _pumpView(tester, size: const Size(375, 812), api: api);

      expect(find.text('Error Loading Orders'), findsOneWidget);
      expect(find.text('Failed to load orders'), findsOneWidget);

      api.fail = false;
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(find.text('Order #ORD-1-1'), findsOneWidget);
    });

    testWidgets('View opens the order details', (tester) async {
      await _pumpView(tester,
          size: const Size(1280, 800), api: _FakeOrders(count: 1));

      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('Grand Total'), findsOneWidget);
      expect(find.text('Product: Tea (x2)'), findsOneWidget);
      expect(find.text('₹1.50'), findsOneWidget);
    });
  });

  group('CustomerOrdersTab', () {
    testWidgets('asks to log in again when there is no token', (tester) async {
      useSurfaceSize(tester, const Size(375, 812));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthModel>(create: (_) => AuthModel()),
            ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) => FakeAppSettingsProvider(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CustomerOrdersTab(customer: testCustomer()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Please login again.'), findsOneWidget);
    });
  });
}
