import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';

typedef VoucherHttpGet = Future<http.Response> Function(Uri url,
    {Map<String, String>? headers});
typedef VoucherHttpPost = Future<http.Response> Function(Uri url,
    {Map<String, String>? headers, Object? body, Encoding? encoding});

/// Shared transport for the two voucher contracts, without provider/UI state.
class VoucherHttp {
  VoucherHttp(
      {VoucherHttpGet? httpGet,
      VoucherHttpPost? httpPost,
      this.session = const TenantSession()})
      : get = httpGet ?? http.get,
        post = httpPost ?? http.post;

  final VoucherHttpGet get;
  final VoucherHttpPost post;
  final TenantSession session;

  Future<String> requireTenant() async {
    final key = await session.apiKey();
    if (key == null || key.isEmpty) {
      throw const HttpException('API key not found. Please restart the app.');
    }
    return key;
  }

  Map<String, String> headers(String token, String tenant) => {
        'Authorization': 'Bearer $token',
        'X-Tenant': tenant,
      };

  Future<Map<String, dynamic>> create(String endpoint, String token,
      String tenant, Map<String, dynamic> payload) async {
    final response = await post(Uri.parse(endpoint),
        headers: {
          ...headers(token, tenant),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return {
        'success': true,
        'message': data['message'] ?? 'Voucher created successfully',
        'data': data['data']
      };
    }
    return {
      'success': false,
      'message': data['message'] ?? 'Failed to create voucher',
      'errors': data['errors']
    };
  }

  Future<dynamic> zatca(String endpoint, String token, int id) async {
    // Tenant errors were thrown before the request catch in the original API.
    final tenant = await requireTenant();
    try {
      final response = await post(Uri.parse(endpoint),
          headers: headers(token, tenant),
          body: {'id': id.toString()}).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        return {
          'status': 'error',
          'message': 'Failed with status ${response.statusCode}'
        };
      }
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return response.body;
      }
    } on TimeoutException {
      return {'status': 'error', 'message': 'Request timed out'};
    } catch (error) {
      return {'status': 'error', 'message': error.toString()};
    }
  }

  /// Raw form choices retain their existing endpoint and response shape.
  Future<List<Map<String, dynamic>>?> choices(
      String endpoint, String? token) async {
    final tenant = await session.apiKey();
    final store = await session.activeStoreId();
    if (token == null || tenant == null) return null;
    final response = await get(
        Uri.parse(endpoint).replace(queryParameters: {
          if (store != null) 'store_id': '$store',
        }),
        headers: headers(token, tenant));
    if (response.statusCode != 200) return null;
    return List<Map<String, dynamic>>.from(
        jsonDecode(response.body)['data'] ?? []);
  }
}
