import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/resources/app_url.dart';

import '../domain/models/supplier.dart';

typedef SupplierHttpGet = Future<http.Response> Function(
  Uri url, {
  Map<String, String>? headers,
});

typedef SupplierHttpPost = Future<http.Response> Function(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
});

/// HTTP access to the supplier endpoints. No state.
class SupplierApi {
  SupplierApi({
    SupplierHttpGet? httpGet,
    SupplierHttpPost? httpPost,
    this.session = const TenantSession(),
  })  : _get = httpGet ?? http.get,
        _post = httpPost ?? http.post;

  static const missingApiKeyMessage =
      'API key not found. Please restart the app.';

  final SupplierHttpGet _get;
  final SupplierHttpPost _post;
  final TenantSession session;

  Future<String> _requireApiKey() async {
    final apiKey = await session.apiKey();
    if (apiKey == null) throw const HttpException(missingApiKeyMessage);
    return apiKey;
  }

  Future<Map<String, String>> _storeQuery([Map<String, String>? query]) async {
    final result = <String, String>{...?query};
    final storeId = await session.activeStoreId();
    if (storeId != null) result['store_id'] = storeId.toString();
    return result;
  }

  /// Every supplier of the active store (optionally by name). Returns
  /// `null` when the server answers with a non-200 status. Throws
  /// [HttpException] when no API key is stored.
  Future<List<Supplier>?> fetchAll(
    String accessToken, {
    String? name,
  }) async {
    final apiKey = await _requireApiKey();
    final url = Uri.parse(APPUrl.getSuppliers).replace(
      queryParameters: await _storeQuery({
        if (name != null && name.isNotEmpty) 'supplier_name': name,
      }),
    );
    final response = await _get(
      url,
      headers: TenantSession.headers(accessToken: accessToken, apiKey: apiKey),
    );
    debugPrint('Supplier API Response status: ${response.statusCode}');
    if (response.statusCode != 200) {
      debugPrint('Error fetching suppliers: ${response.body}');
      return null;
    }
    return SupplierResponse.fromJson(
      Map<String, dynamic>.from(json.decode(response.body) as Map),
    ).data;
  }

  /// One page (or, with [listAll], everything) of supplier transactions.
  Future<Map<String, dynamic>> fetchTransactions(
    String accessToken, {
    String? supplierName,
    String? supplierId,
    String? transactionType,
    String? fromDate,
    String? toDate,
    bool listAll = true,
    int? page,
  }) async {
    final apiKey = await _requireApiKey();
    void put(Map<String, String> query, String key, String? value) {
      if (value != null && value.isNotEmpty) query[key] = value;
    }

    final query = <String, String>{};
    put(query, 'supplier_name', supplierName);
    put(query, 'supplier_id', supplierId);
    // The server expects the transaction type in the `type` key.
    put(query, 'type', transactionType);
    put(query, 'from_date', fromDate);
    put(query, 'to_date', toDate);
    query['list_all'] = listAll.toString();
    if (page != null && page > 0) query['page'] = page.toString();

    final url = Uri.parse(APPUrl.supplierTransactions)
        .replace(queryParameters: await _storeQuery(query));
    final response = await _get(
      url,
      headers: TenantSession.headers(accessToken: accessToken, apiKey: apiKey),
    );
    debugPrint('Supplier Transactions API ${response.statusCode}: $url');
    if (response.statusCode != 200) {
      debugPrint('Error fetching supplier transactions: ${response.body}');
      throw Exception('Failed to load supplier transactions');
    }
    return Map<String, dynamic>.from(json.decode(response.body) as Map);
  }

  /// Posts [body] to [url]. Success: the decoded response. Failure: an
  /// error map with `status`, `message` and `errors`.
  Future<Map<String, dynamic>> _mutate(
    String url,
    String accessToken,
    Map<String, dynamic> body, {
    required bool Function(int status) succeeded,
    required String fallbackMessage,
  }) async {
    final apiKey = await _requireApiKey();
    try {
      final response = await _post(
        Uri.parse(url),
        body: json.encode(body),
        headers:
            TenantSession.headers(accessToken: accessToken, apiKey: apiKey),
      );
      debugPrint('[SupplierApi] $url -> ${response.statusCode}');
      if (succeeded(response.statusCode)) {
        return Map<String, dynamic>.from(json.decode(response.body) as Map);
      }
      try {
        final error =
            Map<String, dynamic>.from(json.decode(response.body) as Map);
        return {
          'status': 'error',
          'message': error['message'] ?? fallbackMessage,
          'errors': error['data'] ?? {},
        };
      } catch (_) {
        return {
          'status': 'error',
          'message':
              'Server error (Status: ${response.statusCode}). Please check your network connection and try again.',
          'errors': {},
        };
      }
    } catch (error) {
      debugPrint('[SupplierApi] $url failed: $error');
      return {
        'status': 'error',
        'message':
            'Network error: Please check your internet connection and try again.',
      };
    }
  }

  Future<Map<String, dynamic>> create(
    String accessToken,
    Map<String, dynamic> body,
  ) =>
      _mutate(
        APPUrl.addSupplier,
        accessToken,
        body,
        succeeded: (status) => status == 200 || status == 201,
        fallbackMessage: 'Failed to add supplier',
      );

  Future<Map<String, dynamic>> update(
    String accessToken,
    Map<String, dynamic> body,
  ) =>
      _mutate(
        APPUrl.updateSupplier,
        accessToken,
        body,
        succeeded: (status) => status == 200,
        fallbackMessage: 'Failed to update supplier',
      );
}
