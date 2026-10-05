import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/helpers/api_response_helper.dart';
import 'package:pos_machine/resources/app_url.dart';

import '../domain/models/list_sales_order.dart';
import '../domain/sales_action_error.dart';
import '../domain/sales_order_query.dart';
import 'sales_http.dart';

class SalesOrdersApi {
  SalesOrdersApi({SalesHttpGet? get, this.session = const TenantSession()})
      : _get = get ?? http.get;
  final SalesHttpGet _get;
  final TenantSession session;
  Future<ListSalesOrderModel> fetchOrders(
      String token, SalesOrderQuery query) async {
    final store = query.storeId == null ? await session.activeStoreId() : null;
    final uri = Uri.parse(APPUrl.getListOrder)
        .replace(queryParameters: query.parameters(store));
    final headers = await salesHeaders(session, token);
    final response =
        await _get(uri, headers: headers).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      if (response.body.isEmpty) throw Exception('Received empty response');
      final decoded = json.decode(response.body);
      try {
        return ListSalesOrderModel.fromJson(decoded);
      } catch (e) {
        throw Exception('Failed to parse order list data: $e');
      }
    }
    if (response.statusCode == 500 && response.body.isNotEmpty) {
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map &&
            decoded['status'] == 'failed' &&
            decoded['message'] == 'No Orders Found') {
          return ListSalesOrderModel(data: const [], pagination: null);
        }
      } catch (_) {}
    }
    throw SalesApiException(ApiResponseHelper.messageFromBody(response.body,
        fallback: 'Failed to load orders: HTTP ${response.statusCode}'));
  }

  Future<dynamic> details(String token, String number) async {
    final key = await session.apiKey();
    final store = await session.activeStoreId();
    if (key == null || key.isEmpty)
      throw const HttpException('API key not found. Please restart the app.');
    final uri = Uri.parse('${APPUrl.getListOrderDetails}/$number')
        .replace(queryParameters: {
      if (store != null) 'store_id': '$store',
    });
    final response = await _get(uri, headers: {
      'Authorization': 'Bearer $token',
      'content-type': 'application/json',
      'X-Tenant': key,
    });
    return json.decode(response.body);
  }
}
