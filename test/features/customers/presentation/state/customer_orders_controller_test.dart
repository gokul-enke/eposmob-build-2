import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_orders_controller.dart';
import 'package:pos_machine/models/list_sales_order.dart';

class _Call {
  _Call(this.token, this.customerId, this.page);
  final String token;
  final int customerId;
  final int page;
}

class _FakeOrdersApi {
  final calls = <_Call>[];
  int totalPages = 1;
  int perPage = 2;
  bool fail = false;

  Future<CustomerOrdersPage> call({
    required String accessToken,
    required int customerId,
    required int page,
  }) async {
    calls.add(_Call(accessToken, customerId, page));
    if (fail) throw Exception('boom');
    return CustomerOrdersPage(
      orders: [
        for (var i = 0; i < perPage; i++)
          ListOrderModelData(id: page * 100 + i, orderNumber: 'ORD-$page-$i'),
      ],
      currentPage: page,
      totalPages: totalPages,
    );
  }
}

CustomerOrdersController _controller(
  _FakeOrdersApi api, {
  String? token = 'token',
  int? customerId = 42,
}) =>
    CustomerOrdersController(
      fetch: api.call,
      readToken: () => token,
      customerId: customerId,
    );

void main() {
  group('CustomerOrdersController', () {
    test('loads the first page for the customer', () async {
      final api = _FakeOrdersApi()..totalPages = 3;
      final controller = _controller(api);

      await controller.load(page: 1);

      expect(api.calls.single.token, 'token');
      expect(api.calls.single.customerId, 42);
      expect(api.calls.single.page, 1);
      expect(controller.orders, hasLength(2));
      expect(controller.currentPage, 1);
      expect(controller.totalPages, 3);
      expect(controller.errorKey, isNull);
      expect(controller.showPagination, isTrue);
    });

    test('goToPage ignores out-of-range and current pages', () async {
      final api = _FakeOrdersApi()..totalPages = 2;
      final controller = _controller(api);
      await controller.load(page: 1);

      controller
        ..goToPage(0)
        ..goToPage(1)
        ..goToPage(3);
      expect(api.calls, hasLength(1));

      controller.goToPage(2);
      await Future<void>.delayed(Duration.zero);
      expect(api.calls.last.page, 2);
      expect(controller.currentPage, 2);
      expect(controller.orders.first.orderNumber, 'ORD-2-0');
    });

    test('empty result hides pagination', () async {
      final api = _FakeOrdersApi()
        ..perPage = 0
        ..totalPages = 4;
      final controller = _controller(api);
      await controller.load(page: 1);
      expect(controller.orders, isEmpty);
      expect(controller.errorKey, isNull);
      expect(controller.showPagination, isFalse);
    });

    test('single page hides pagination', () async {
      final controller = _controller(_FakeOrdersApi());
      await controller.load(page: 1);
      expect(controller.showPagination, isFalse);
    });

    test('a failed request clears orders and sets err_load; retry recovers',
        () async {
      final api = _FakeOrdersApi()..fail = true;
      final controller = _controller(api);

      await controller.load(page: 1);
      expect(controller.orders, isEmpty);
      expect(controller.errorKey, CustomerOrdersController.errLoad);
      expect(controller.isLoading, isFalse);
      expect(controller.showPagination, isFalse);

      api.fail = false;
      await controller.retry();
      expect(controller.errorKey, isNull);
      expect(controller.orders, hasLength(2));
    });

    test('missing customer id or token is reported without a request',
        () async {
      final api = _FakeOrdersApi();

      final noId = _controller(api, customerId: null);
      await noId.load(page: 1);
      expect(noId.errorKey, CustomerOrdersController.errNoCustomerId);

      final noToken = _controller(api, token: '');
      await noToken.load(page: 1);
      expect(noToken.errorKey, CustomerOrdersController.errLoginAgain);

      expect(api.calls, isEmpty);
    });

    test('setCustomer reloads page 1 for the new customer', () async {
      final api = _FakeOrdersApi();
      final controller = _controller(api);
      await controller.setCustomer(7);
      expect(api.calls.single.customerId, 7);
      expect(api.calls.single.page, 1);
    });

    test('notifies loading then loaded', () async {
      final controller = _controller(_FakeOrdersApi());
      final states = <bool>[];
      controller.addListener(() => states.add(controller.isLoading));
      await controller.load(page: 1);
      expect(states, [true, false]);
    });
  });
}
