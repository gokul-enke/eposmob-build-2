import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/list_sales_order.dart';

Map<String, dynamic> _order(Map<String, dynamic> overrides) => {
      'id': 1,
      'cart_id': 10,
      'order_date': '2026-09-21 10:15:00',
      'order_number': 'ORD-004662',
      'grand_total': '1445.00',
      'payment_status': 'paid',
      'status': 'confirmed',
      'customer_name': 'Test Default',
      ...overrides,
    };

Map<String, dynamic> _response(List<Map<String, dynamic>> orders) => {
      'status': 'success',
      'message': 'ok',
      'data': {
        'data': orders,
        'current_page': 1,
        'last_page': 1,
        'from': 1,
        'to': orders.length,
      },
    };

void main() {
  group('ListSalesOrderModel row parsing', () {
    test('parses a well formed page unchanged', () {
      final model = ListSalesOrderModel.fromJson(_response([
        _order({}),
        _order({'id': 2, 'order_number': 'ORD-004653'}),
      ]));

      expect(model.data, hasLength(2));
      expect(model.data!.first.orderNumber, 'ORD-004662');
      expect(model.data!.first.grantTotal, '1445.00');
      expect(model.data!.first.orderDate, DateTime(2026, 9, 21, 10, 15));
    });

    test('a numeric grand_total or string id no longer breaks the row', () {
      final model = ListSalesOrderModel.fromJson(_response([
        _order({'id': '7', 'grand_total': 1445}),
      ]));

      expect(model.data, hasLength(1));
      expect(model.data!.single.id, 7);
      expect(model.data!.single.grantTotal, '1445');
    });

    test('a non-string order_date drops only the date, not the order', () {
      final model = ListSalesOrderModel.fromJson(_response([
        _order({'order_date': 20260921}),
      ]));

      expect(model.data, hasLength(1));
      expect(model.data!.single.orderDate, isNull);
      expect(model.data!.single.orderNumber, 'ORD-004662');
    });

    test('one unparseable row does not empty the whole page', () {
      final model = ListSalesOrderModel.fromJson(_response([
        _order({}),
        // order_props must be a list; a map used to throw and take the whole
        // response down with it, leaving the screen on "No Orders Found".
        _order({'id': 2, 'order_props': <String, dynamic>{'bad': 'shape'}}),
        _order({'id': 3, 'order_number': 'ORD-004652'}),
      ]));

      expect(model.data, hasLength(2));
      expect(
        model.data!.map((order) => order.id),
        [1, 3],
      );
    });

    test('an empty or missing order list stays empty rather than throwing', () {
      expect(ListSalesOrderModel.fromJson(_response([])).data, isEmpty);
      expect(
        ListSalesOrderModel.fromJson({
          'status': 'success',
          'data': {'data': null},
        }).data,
        isEmpty,
      );
    });
  });
}
