import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/features/sales_returns/data/sales_return_api.dart';
import 'package:pos_machine/features/sales_returns/data/sales_return_repository.dart';
import '../../../../test_support/network_fakes.dart';
import '../../support/return_fixtures.dart';

void main() {
  test(
      'SalesProvider delegates state and forwards each return notification once',
      () async {
    final repository = SalesReturnRepository(
        api: SalesReturnApi(
            session: const FakeTenantSession(),
            get: (uri, {headers}) async => jsonResponse(returnListBody()),
            post: (uri, {headers, body, encoding}) async => jsonResponse({
                  'status': 'success',
                  'data': {'id': 75}
                })));
    final sales = SalesProvider(salesReturnRepository: repository);
    var notifications = 0;
    sales.addListener(() => notifications++);
    await sales.fetchSalesReturn(accessToken: 'token', page: 2);
    expect(sales.salesReturnOrders.single.id, 10);
    expect(notifications, 1);
    sales.salesReturnCurrentPage = 2;
    expect(sales.salesReturns.currentPage, 2);
    expect(
        await sales.submitSalesReturn(
            accessToken: 'token',
            orderId: 100,
            price: 10,
            quantity: 1,
            cartItemId: 40,
            reason: 'Damaged'),
        75);
    expect(notifications, 2);
    await sales.completeSalesReturn(accessToken: 'token', returnOrderId: 75);
    expect(notifications, 3);
    sales.clearServerRefundBreakdown();
    expect(notifications, 4);
    sales.dispose();
  });
  test('repository item snapshot does not replace shared return state',
      () async {
    final repository = SalesReturnRepository(
        api: SalesReturnApi(
            session: const FakeTenantSession(),
            get: (uri, {headers}) async => jsonResponse(
                {'status': 'success', 'message': 'ok', 'data': []})));
    final sales = SalesProvider(salesReturnRepository: repository);
    sales.salesReturns.items = returnItems().data;
    await repository.fetchItems('token', orderId: 'another');
    expect(sales.salesReturnItems.single.cartItemId, 40);
    sales.dispose();
  });
  test(
      'legacy list error boundary preserves missing-tenant state and clears HTTP failure',
      () async {
    final repository = SalesReturnRepository(
        api: SalesReturnApi(session: const FakeTenantSession(key: null)));
    final sales = SalesProvider(salesReturnRepository: repository);
    sales.salesReturns.orders = returnPage().data.data;
    await expectLater(
        sales.fetchSalesReturn(accessToken: 'token'), throwsException);
    expect(sales.salesReturnOrders.single.id, 10);
    sales.dispose();
    final failed = SalesProvider(
        salesReturnRepository: SalesReturnRepository(
            api: SalesReturnApi(
                session: const FakeTenantSession(),
                get: (uri, {headers}) async =>
                    jsonResponse({'message': 'Failed'}, 500))));
    failed.salesReturns.orders = returnPage().data.data;
    await expectLater(
        failed.fetchSalesReturn(accessToken: 'token'), throwsException);
    expect(failed.salesReturnOrders, isEmpty);
    failed.dispose();
  });
  test('late shared request can finish without notifying a disposed facade',
      () async {
    final response = Completer<http.Response>();
    final sales = SalesProvider(
        salesReturnRepository: SalesReturnRepository(
            api: SalesReturnApi(
                session: const FakeTenantSession(),
                get: (uri, {headers}) => response.future)));
    final result = sales.fetchSalesReturn(accessToken: 'token');
    sales.dispose();
    response.complete(jsonResponse(returnListBody()));
    await result;
  });
}
