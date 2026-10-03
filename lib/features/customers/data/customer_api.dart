import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/resources/app_url.dart';

import '../domain/models/customer_list.dart';

typedef CustomerHttpGet = Future<http.Response> Function(
  Uri url, {
  Map<String, String>? headers,
});

typedef CustomerHttpPost = Future<http.Response> Function(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
});

/// One page of the customer list endpoint.
class CustomerPage {
  const CustomerPage({required this.payload, required this.model});

  /// The decoded response body.
  final Map<String, dynamic> payload;
  final CustomerListModel model;
}

/// Every customer of the store, fetched page by page and de-duplicated.
class CustomerDirectory {
  const CustomerDirectory({required this.customers, required this.message});

  final List<CustomerListModelData> customers;
  final String? message;

  Map<String, dynamic> toJson() => {
        'status': 'success',
        'message': message,
        'data': customers.map((customer) => customer.toJson()).toList(),
      };
}

/// HTTP access to the customer endpoints. No state, no caching.
class CustomerApi {
  CustomerApi({
    CustomerHttpGet? httpGet,
    CustomerHttpPost? httpPost,
    this.session = const TenantSession(),
  })  : _get = httpGet ?? http.get,
        _post = httpPost ?? http.post;

  static const loadAllPageSize = 100;
  static const maximumPages = 1000;
  static const missingApiKeyMessage =
      'API key not found. Please restart the app.';

  final CustomerHttpGet _get;
  final CustomerHttpPost _post;
  final TenantSession session;

  Future<String> _requireApiKey() async {
    final apiKey = await session.apiKey();
    if (apiKey == null) throw const HttpException(missingApiKeyMessage);
    return apiKey;
  }

  // ---------------------------------------------------------------- listing

  Future<CustomerPage> fetchPage({
    required String accessToken,
    required String apiKey,
    required Map<String, String> queryParameters,
  }) async {
    final url = Uri.parse(APPUrl.customerListUrl)
        .replace(queryParameters: queryParameters);
    final response = await _get(
      url,
      headers: TenantSession.headers(accessToken: accessToken, apiKey: apiKey),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw HttpException('Failed to load customers (${response.statusCode}).');
    }

    final decoded = json.decode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Customer response must be a JSON object.');
    }
    final payload = Map<String, dynamic>.from(decoded);
    if (payload['status']?.toString().toLowerCase() == 'error') {
      throw HttpException(
        payload['message']?.toString() ?? 'Failed to load customers.',
      );
    }
    return CustomerPage(
      payload: payload,
      model: CustomerListModel.fromJson(payload),
    );
  }

  static String _identity(CustomerListModelData customer) {
    final id = customer.id;
    if (id != null) return 'id:$id';
    return 'fallback:${customer.name ?? ''}|${customer.phone ?? ''}|'
        '${customer.email ?? ''}|${customer.altPhone ?? ''}';
  }

  /// Fetches every page. Handles paginated responses (declared `last_page` /
  /// `total`) and flat ones (keeps going until a short page), drops
  /// duplicates across pages and stops after [maximumPages].
  Future<CustomerDirectory> fetchDirectory({
    required String accessToken,
    required String apiKey,
    required Map<String, String> queryParameters,
  }) async {
    final baseQuery = Map<String, String>.from(queryParameters)
      ..['page'] = '1'
      ..['per_page'] = loadAllPageSize.toString();
    final firstPage = await fetchPage(
      accessToken: accessToken,
      apiKey: apiKey,
      queryParameters: baseQuery,
    );
    final firstPageCustomers =
        firstPage.model.data ?? const <CustomerListModelData>[];
    final customers = <CustomerListModelData>[];
    final seen = <String>{};
    for (final customer in firstPageCustomers) {
      if (seen.add(_identity(customer))) customers.add(customer);
    }
    final declaredPageSize = firstPage.model.perPage ?? loadAllPageSize;
    final responsePageSize =
        declaredPageSize > 0 ? declaredPageSize : loadAllPageSize;
    final total = firstPage.model.total;
    final declaredLastPage = firstPage.model.lastPage ??
        (total == null
            ? null
            : (total + responsePageSize - 1) ~/ responsePageSize);
    var lastFetchedCount = firstPageCustomers.length;
    var nextPage = 2;

    while (nextPage <= maximumPages) {
      if (declaredLastPage != null) {
        if (nextPage > declaredLastPage) break;
      } else if (lastFetchedCount != responsePageSize) {
        // A flat response with more than the requested page size is an
        // unpaginated endpoint. Fewer items means the final page.
        break;
      }

      final page = await fetchPage(
        accessToken: accessToken,
        apiKey: apiKey,
        queryParameters: Map<String, String>.from(baseQuery)
          ..['page'] = nextPage.toString(),
      );
      final pageCustomers = page.model.data ?? const <CustomerListModelData>[];
      if (pageCustomers.isEmpty) break;
      lastFetchedCount = pageCustomers.length;

      var added = 0;
      for (final customer in pageCustomers) {
        if (seen.add(_identity(customer))) {
          customers.add(customer);
          added++;
        }
      }
      if (added == 0) break;
      if (declaredLastPage == null && lastFetchedCount < responsePageSize) {
        break;
      }
      nextPage++;
    }

    final hasUnfetchedPages =
        declaredLastPage == null || nextPage <= declaredLastPage;
    if (nextPage > maximumPages && hasUnfetchedPages) {
      throw const HttpException('Customer pagination exceeded safe limit.');
    }

    return CustomerDirectory(
      customers: customers,
      message: firstPage.model.message,
    );
  }

  // -------------------------------------------------------------- mutations

  /// Sends [body] to [url]. Returns the decoded body on 200/201, the decoded
  /// error body (or a generic error map) otherwise, and a connection error
  /// map when the request itself fails. Throws only when the API key is
  /// missing.
  Future<dynamic> _postMutation(
    String url,
    String accessToken,
    Map<String, dynamic> body, {
    required String failurePrefix,
  }) async {
    final apiKey = await _requireApiKey();
    try {
      final response = await _post(
        Uri.parse(url),
        body: json.encode(body),
        headers:
            TenantSession.headers(accessToken: accessToken, apiKey: apiKey),
      );
      debugPrint('[CustomerApi] $url -> ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      final genericError = {
        'status': 'error',
        'message': '$failurePrefix: ${response.reasonPhrase}',
        'errors': {
          'general': ['Error processing your request'],
        },
      };
      if (response.body.isEmpty) return genericError;
      try {
        return json.decode(response.body);
      } catch (_) {
        return genericError;
      }
    } catch (error) {
      debugPrint('[CustomerApi] $url failed: $error');
      return {
        'status': 'error',
        'message': 'Failed to connect to server',
        'errors': {
          'connection': [error.toString()],
        },
      };
    }
  }

  Future<dynamic> create(String accessToken, Map<String, dynamic> body) =>
      _postMutation(
        APPUrl.addCustomerUrl,
        accessToken,
        body,
        failurePrefix: 'Failed to add customer',
      );

  Future<dynamic> update(String accessToken, Map<String, dynamic> body) =>
      _postMutation(
        APPUrl.updateCustomerUrl,
        accessToken,
        body,
        failurePrefix: 'Failed to update customer',
      );

  // ---------------------------------------------------------------- lookups

  Future<dynamic> _lookup(
    String url,
    String accessToken,
    Map<String, String> queryParameters,
  ) async {
    final storeId = await session.activeStoreId();
    if (storeId != null) queryParameters['store_id'] = storeId.toString();
    final uri = Uri.parse(url).replace(queryParameters: queryParameters);
    final apiKey = await _requireApiKey();

    final response = await _get(
      uri,
      headers: TenantSession.headers(accessToken: accessToken, apiKey: apiKey),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    if (response.statusCode > 400) {
      throw const HttpException('Customer Not Found. Try Again!');
    }
    throw const HttpException('Failed to load data, Try Again Later!');
  }

  Future<dynamic> findByPhone(String accessToken, String phone) =>
      _lookup(APPUrl.customerListUrl, accessToken, {'filter_phone': phone});

  Future<dynamic> findByName(String accessToken, String name) =>
      _lookup(APPUrl.customerListUrl, accessToken, {'filter_name': name});

  Future<dynamic> fetchById(String accessToken, int customerId) =>
      _lookup('${APPUrl.userDetailsUrl}/$customerId', accessToken, {});

  // -------------------------------------------------------------- addresses

  Future<dynamic> _postAddress(
    String url,
    String accessToken,
    Map<String, dynamic> addressData,
  ) async {
    final apiKey = await _requireApiKey();
    try {
      final response = await _post(
        Uri.parse(url),
        body: json.encode(addressData),
        headers:
            TenantSession.headers(accessToken: accessToken, apiKey: apiKey),
      );
      return json.decode(response.body);
    } catch (error) {
      debugPrint('[CustomerApi] $url failed: $error');
      return {'status': 'error', 'message': error.toString()};
    }
  }

  Future<dynamic> addAddress(
    String accessToken,
    Map<String, dynamic> addressData,
  ) =>
      _postAddress(APPUrl.executiveAddAddressUrl, accessToken, addressData);

  Future<dynamic> updateAddress(
    String accessToken,
    int addressId,
    Map<String, dynamic> addressData,
  ) =>
      _postAddress(
        '${APPUrl.executiveUpdateAddressUrl}/$addressId',
        accessToken,
        addressData,
      );
}
