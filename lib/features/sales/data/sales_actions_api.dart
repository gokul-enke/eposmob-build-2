import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/resources/app_url.dart';

import 'sales_action_response.dart';
import 'sales_http.dart';

class SalesActionsApi {
  SalesActionsApi({SalesHttpPost? post, this.session = const TenantSession()})
      : _postRequest = post ?? http.post;
  final SalesHttpPost _postRequest;
  final TenantSession session;
  Future<void> cancelOrder({
    required String accessToken,
    required String orderId,
    String? paymentMethod,
    String? refundAmount,
    bool? deliveryChargeRefundable,
  }) async {
    final url = Uri.parse(APPUrl.cancelOrderUrl);

    final headers = await salesHeaders(session, accessToken);
    final requestBody = <String, dynamic>{
      'order_id': orderId,
      if (paymentMethod != null) 'refund_method': paymentMethod,
      if (refundAmount != null) 'refund_amount': refundAmount,
      if (deliveryChargeRefundable != null)
        'delivery_charge_refundable': deliveryChargeRefundable,
    };

    final response = await _postRequest(
      url,
      headers: headers,
      body: jsonEncode(requestBody),
    );

    SalesActionResponse.ensureSalesActionSucceeded(
      response.statusCode,
      response.body,
      fallback: 'Failed to cancel order',
    );
  }

  Future<void> changeOrderStatus({
    required String accessToken,
    required String orderId,
    required String status,
    double? refundAmount,
    String? paymentMethod,
    bool? deliveryChargeRefundable,
    String? deliveryLogistics,
  }) async {
    final url = Uri.parse(APPUrl.orderChangeStatusUrl);

    final headers = await salesHeaders(session, accessToken);
    final requestBody = {
      'order_id': orderId,
      'status': status,
      if (refundAmount != null) 'refund_amount': refundAmount,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (deliveryChargeRefundable != null)
        'delivery_charge_refundable': deliveryChargeRefundable,
      if (deliveryLogistics != null) 'delivery_logistics': deliveryLogistics,
    };

    final response = await _postRequest(
      url,
      headers: headers,
      body: jsonEncode(requestBody),
    );

    SalesActionResponse.ensureSalesActionSucceeded(
      response.statusCode,
      response.body,
      fallback: 'Failed to change order status',
    );
  }

  Future<void> changePaymentStatus({
    required String accessToken,
    required String orderId,
    required String status,
    required double amount,
  }) async {
    final url = Uri.parse(APPUrl.orderChangePaymentStatusUrl);

    final headers = await salesHeaders(session, accessToken);
    final requestBody = {
      'order_id': orderId,
      'status': status,
      'amount': amount,
    };

    final response = await _postRequest(
      url,
      headers: headers,
      body: jsonEncode(requestBody),
    );

    SalesActionResponse.ensureSalesActionSucceeded(
      response.statusCode,
      response.body,
      fallback: 'Failed to change payment status',
    );
  }
}
