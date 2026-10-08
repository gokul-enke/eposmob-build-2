import 'package:pos_machine/features/sales_returns/domain/models/list_sales_return.dart';
import 'package:pos_machine/features/sales_returns/domain/models/list_sales_return_items.dart';

Map<String, dynamic> returnListBody({int page = 1, int id = 10}) => {
      'status': 'success',
      'message': 'ok',
      'data': {
        'current_page': page,
        'last_page': 3,
        'data': [
          {
            'id': id,
            'order_id': 100,
            'total_amount': '2.00',
            'user_id': 1,
            'status': 1,
            'items': [],
            'created_at': '2026-10-01T00:00:00Z'
          }
        ]
      }
    };
SalesReturnResponse returnPage({int page = 1, int id = 10}) =>
    SalesReturnResponse.fromJson(returnListBody(page: page, id: id));
SalesReturnItemsResponse returnItems({int id = 40}) =>
    SalesReturnItemsResponse.fromJson({
      'status': 'success',
      'message': 'ok',
      'order': {'id': 100, 'shipping_cost': '0'},
      'data': [
        {
          'cart_item_id': id,
          'product_name': 'Rice',
          'quantity': '2',
          'unit_price': '10',
          'total_price': '20',
          'returned_quantity': 1,
          'returned_total': '10',
          'is_returned': false
        }
      ]
    });
