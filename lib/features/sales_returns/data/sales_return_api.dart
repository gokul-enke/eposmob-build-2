import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/helpers/api_response_helper.dart';
import 'package:pos_machine/resources/app_url.dart';

import '../domain/models/list_sales_return.dart';
import '../domain/models/list_sales_return_items.dart';
import '../domain/models/sales_return_refund_breakdown.dart';

typedef SalesReturnGet = Future<http.Response> Function(Uri uri,
    {Map<String, String>? headers});
typedef SalesReturnPost = Future<http.Response> Function(Uri uri,
    {Map<String, String>? headers, Object? body, Encoding? encoding});

class SalesReturnRequest {
  const SalesReturnRequest(this.headers, this.storeId);
  final Map<String, String> headers;
  final int? storeId;
}

class SalesReturnSubmission {
  const SalesReturnSubmission(this.id, this.breakdown);
  final int id;
  final SalesReturnRefundBreakdown? breakdown;
}

/// Return transport only. Request preparation retains the original error boundary.
class SalesReturnApi {
  SalesReturnApi(
      {SalesReturnGet? get,
      SalesReturnPost? post,
      this.session = const TenantSession()})
      : _get = get ?? http.get,
        _post = post ?? http.post;
  final SalesReturnGet _get;
  final SalesReturnPost _post;
  final TenantSession session;

  Future<SalesReturnRequest> prepare(String token,
      {bool includeStore = false}) async {
    final key = await session.apiKey();
    if (key == null || key.isEmpty) {
      throw const HttpException('API key not found. Please restart the app.');
    }
    final store = includeStore ? await session.activeStoreId() : null;
    return SalesReturnRequest(
        TenantSession.headers(accessToken: token, apiKey: key), store);
  }

  Future<SalesReturnResponse> list(SalesReturnRequest request,
      {int? page}) async {
    final uri = Uri.parse(APPUrl.listSalesReturn).replace(queryParameters: {
      if (page != null) 'page': '$page',
      if (request.storeId != null) 'store_id': '${request.storeId}',
    });
    final response = await _get(uri, headers: request.headers)
        .timeout(const Duration(seconds: 15));
    ApiResponseHelper.ensureSuccess(response.statusCode, response.body,
        fallback: 'Failed to load sales returns');
    return SalesReturnResponse.fromJson(json.decode(response.body));
  }

  Future<SalesReturnItemsResponse> items(SalesReturnRequest request,
      {required String orderId, int? page}) async {
    final uri =
        Uri.parse(APPUrl.listSalesReturnItems).replace(queryParameters: {
      'order_number': orderId,
      if (page != null) 'page': '$page',
      if (request.storeId != null) 'store_id': '${request.storeId}',
    });
    final response = await _get(uri, headers: request.headers)
        .timeout(const Duration(seconds: 15));
    ApiResponseHelper.ensureSuccess(response.statusCode, response.body,
        fallback: 'Failed to load return items');
    return SalesReturnItemsResponse.fromJson(json.decode(response.body));
  }

  Future<SalesReturnSubmission> submit(
      {required String accessToken,
      required int orderId,
      required double price,
      required num quantity,
      required int cartItemId,
      required String reason,
      bool isDeliveryRefundable = false}) async {
    if (orderId <= 0)
      throw Exception(
          'Cannot submit this return because the sales order ID is missing.');
    if (cartItemId <= 0) {
      throw Exception(
          'Cannot submit this return because the cart item ID is missing. '
          'Please refresh the order and try again.');
    }
    final request = await prepare(accessToken);
    final response = await _post(Uri.parse(APPUrl.salesReturn),
        headers: request.headers,
        body: jsonEncode({
          'order_id': orderId,
          'price': price,
          'quantity': quantity,
          'cart_item_id': cartItemId,
          'reason': reason,
          'is_delivery_refundable': isDeliveryRefundable,
        }));
    ApiResponseHelper.ensureSuccess(response.statusCode, response.body,
        fallback: 'Failed to submit sales return');
    final decoded = json.decode(response.body);
    final raw = decoded is Map ? decoded['data'] : null;
    final id = raw is Map ? int.tryParse(raw['id']?.toString() ?? '') : null;
    if (id == null || id <= 0) {
      throw Exception(
          'The return item was submitted, but its return order ID was missing. '
          'Please refresh the order before completing the return.');
    }
    return SalesReturnSubmission(
        id, SalesReturnRefundBreakdown.fromResponseBody(response.body));
  }

  Future<SalesReturnRefundBreakdown?> complete(
      {required String accessToken,
      required int returnOrderId,
      String? paymentMethod,
      double? paidAmount,
      bool? hasPayment,
      bool isDeliveryRefundable = false}) async {
    if (returnOrderId <= 0) {
      throw Exception(
          'Cannot complete this return because the return order ID is missing. '
          'Please submit a return item first.');
    }
    final request = await prepare(accessToken);
    final response = await _post(Uri.parse(APPUrl.completeSalesReturn),
        headers: request.headers,
        body: jsonEncode({
          'return_order_id': returnOrderId,
          'is_delivery_refundable': isDeliveryRefundable,
          if (hasPayment == true) ...{
            'payment_method': paymentMethod,
            'paid_amount': paidAmount,
            'has_payment': hasPayment,
          } else
            'has_payment': false,
        }));
    ApiResponseHelper.ensureSuccess(response.statusCode, response.body,
        fallback: 'Failed to complete sales return');
    return SalesReturnRefundBreakdown.fromResponseBody(response.body);
  }
}
