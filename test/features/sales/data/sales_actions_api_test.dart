import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/features/sales/data/sales_actions_api.dart';

import 'sales_orders_api_test.dart' show Session;

void main() {
  test('cancel, status and payment preserve distinct field names and types',
      () async {
    final bodies = <Map<String, dynamic>>[];
    final api = SalesActionsApi(
      session: const Session('tenant', 7),
      post: (uri, {headers, body, encoding}) async {
        expect(headers!['X-Tenant'], 'tenant');
        expect(headers['Authorization'], 'Bearer token');
        bodies.add(jsonDecode(body as String) as Map<String, dynamic>);
        return http.Response('{"status":"success"}', 200);
      },
    );
    await api.cancelOrder(
        accessToken: 'token',
        orderId: '12',
        paymentMethod: 'CASH',
        refundAmount: '4.190',
        deliveryChargeRefundable: false);
    await api.changeOrderStatus(
        accessToken: 'token',
        orderId: '12',
        status: 'cancelled',
        refundAmount: 4.19,
        paymentMethod: 'CASH',
        deliveryChargeRefundable: true,
        deliveryLogistics: '8');
    await api.changePaymentStatus(
        accessToken: 'token', orderId: '12', status: 'paid', amount: 4.19);
    expect(bodies, [
      {
        'order_id': '12',
        'refund_method': 'CASH',
        'refund_amount': '4.190',
        'delivery_charge_refundable': false
      },
      {
        'order_id': '12',
        'status': 'cancelled',
        'refund_amount': 4.19,
        'payment_method': 'CASH',
        'delivery_charge_refundable': true,
        'delivery_logistics': '8'
      },
      {'order_id': '12', 'status': 'paid', 'amount': 4.19},
    ]);
  });
}
