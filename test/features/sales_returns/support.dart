import 'dart:convert';
import 'package:pos_machine/features/sales_returns/data/sales_return_list_repository.dart';
import 'package:pos_machine/features/sales_returns/domain/sales_return_list.dart';

const returnScope = SalesReturnListScope(
    token: 'test-token',
    tenant: 'test-tenant',
    endpoint: 'https://example.invalid/returns',
    storeId: 2);

Map<String, dynamic> returnRow(int id, {int orderId = 10}) => {
      'id': id,
      'order_id': orderId,
      'total_amount': '12.50',
      'status': 1,
      'created_at': '2026-09-29T08:30:00Z',
      'items': [
        {'id': id, 'quantity': '1.25', 'price': '10.00'}
      ],
      'order': {
        'id': orderId,
        'order_number': 'ORD-00010',
        'receipt_number': '000123'
      }
    };

Map<String, dynamic> returnEnvelope(List<Map<String, dynamic>> rows,
    {int page = 1, int perPage = 2, int? total}) {
  final count = total ?? rows.length;
  return {
    'status': 'success',
    'data': {
      'current_page': page,
      'last_page': count == 0 ? 1 : (count / perPage).ceil(),
      'per_page': perPage,
      'total': count,
      'data': rows,
    }
  };
}

SalesReturnListData returnData(List<Map<String, dynamic>> rows,
        {int page = 1, int perPage = 2, int? total}) =>
    SalesReturnListRepository.parse(
        jsonEncode(
            returnEnvelope(rows, page: page, perPage: perPage, total: total)),
        requestedPage: page);

class ReturnSource implements SalesReturnListSource {
  ReturnSource(this.fetchPage, {this.scope = returnScope});
  @override
  final SalesReturnListScope scope;
  final Future<SalesReturnListData> Function(int) fetchPage;
  final calls = <int>[];
  @override
  Future<SalesReturnListData> fetch(int page) {
    calls.add(page);
    return fetchPage(page);
  }
}
