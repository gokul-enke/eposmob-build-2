import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/features/subscription/presentation/subscription_provider.dart';

import '../models/quotation_model.dart';
import '../resources/app_url.dart';

class QuotationsProvider with ChangeNotifier {
  List<Quotation> _quotations = [];
  List<Quotation> get quotations => _quotations;

  int currentPage = 1;
  int totalPages = 1;
  int paginationFrom = 1;

  QuotationDetailsData? _currentQuotationDetails;
  QuotationDetailsData? get currentQuotationDetails => _currentQuotationDetails;

  dynamic _selectedQuotationId;
  dynamic get selectedQuotationId => _selectedQuotationId;

  void setSelectedQuotationId(dynamic id) {
    _selectedQuotationId = id;
    notifyListeners();
  }

  bool _isSuccessResponse(Map<String, dynamic> jsonData) {
    return jsonData['success'] == true ||
        jsonData['status']?.toString().toLowerCase() == 'success';
  }

  Future<Map<String, String>> _authHeaders(String accessToken) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException('API key not found. Please restart the app.');
    }

    return {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
      'X-Tenant': apiKey,
    };
  }

  Future<void> fetchQuotations({
    required String accessToken,
    int? storeId,
    String? quotationNumber,
    String? startDate,
    String? endDate,
    String? customerId,
    String? filterStatus,
    int? page,
  }) async {
    final queryParameters = <String, String>{};

    if (storeId != null) {
      queryParameters['store_id'] = storeId.toString();
    } else {
      final prefs = await SharedPreferences.getInstance();
      final int? activeStoreId = prefs.getInt('active_store_id');
      if (activeStoreId != null) {
        queryParameters['store_id'] = activeStoreId.toString();
      }
    }

    if (quotationNumber != null && quotationNumber.isNotEmpty) {
      queryParameters['quotation_number'] = quotationNumber;
    }
    if (startDate != null && startDate.isNotEmpty) {
      queryParameters['quotation_date_from'] = startDate;
      queryParameters['quotation_date_to'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      queryParameters['expiry_date_from'] = endDate;
      queryParameters['expiry_date_to'] = endDate;
    }
    if (customerId != null && customerId.isNotEmpty) {
      queryParameters['customer_id'] = customerId;
    }
    if (filterStatus != null &&
        filterStatus.isNotEmpty &&
        filterStatus.toLowerCase() != 'all') {
      queryParameters['status'] = filterStatus;
    }
    if (page != null) {
      queryParameters['page'] = page.toString();
    }

    final uri = Uri.parse(APPUrl.listQuotations)
        .replace(queryParameters: queryParameters);

    try {
      final response = await http
          .get(uri, headers: await _authHeaders(accessToken))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Received empty response');
        }
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        List<Quotation> loadedQuotations = [];
        if (_isSuccessResponse(jsonData) && jsonData['data'] != null) {
          final dataWrapper = QuotationDataWrapper.fromJson(jsonData['data']);
          loadedQuotations = dataWrapper.data ?? [];

          currentPage = dataWrapper.currentPage ?? 1;
          totalPages = dataWrapper.lastPage ?? 1;
          paginationFrom = dataWrapper.from ?? 1;
        }

        _quotations = loadedQuotations;
        notifyListeners();
      } else {
        throw Exception(
            'Failed to load quotations: HTTP ${response.statusCode}');
      }
    } catch (_) {
      _quotations = [];
      notifyListeners();
      rethrow;
    }
  }

  Future<QuotationDetailsData?> fetchQuotationDetails({
    required String accessToken,
    required dynamic quotationId,
  }) async {
    final uri = Uri.parse(APPUrl.viewQuotation(quotationId));

    try {
      final response = await http
          .get(uri, headers: await _authHeaders(accessToken))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;

        if (_isSuccessResponse(jsonData) && jsonData['data'] != null) {
          _currentQuotationDetails =
              QuotationDetailsData.fromJson(jsonData['data']);
          notifyListeners();
          return _currentQuotationDetails;
        }
      }
      return null;
    } catch (_) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createQuotation({
    required String accessToken,
    required Map<String, dynamic> data,
  }) async {
    final uri = Uri.parse(APPUrl.listQuotations);

    try {
      debugPrint('CREATE QUOTATION REQUEST URL: $uri');
      debugPrint('CREATE QUOTATION REQUEST BODY: ${json.encode(data)}');

      final response = await http
          .post(
            uri,
            headers: await _authHeaders(accessToken),
            body: json.encode(data),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('CREATE QUOTATION HTTP STATUS: ${response.statusCode}');
      debugPrint('CREATE QUOTATION RESPONSE BODY: ${response.body}');

      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonData;
      }

      final errorMsg = jsonData['message'] ??
          jsonData['error'] ??
          'Failed to create quotation (HTTP ${response.statusCode})';
      if (jsonData['errors'] != null) {
        debugPrint('CREATE QUOTATION VALIDATION ERRORS: ${jsonData['errors']}');
      }
      throw Exception(errorMsg);
    } catch (_) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateQuotationStatus({
    required String accessToken,
    required int quotationId,
    required String status,
  }) async {
    final uri = Uri.parse(APPUrl.updateQuotationStatus);

    try {
      final response = await http
          .post(
            uri,
            headers: await _authHeaders(accessToken),
            body: json.encode({
              'quotation_id': quotationId,
              'status': status,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonData;
      }
      throw Exception(jsonData['message'] ?? 'Failed to update status');
    } catch (_) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> convertQuotationToOrder({
    required String accessToken,
    required int quotationId,
    String? customerType,
    int? customerId,
    String? customerName,
    String? customerPhone,
    String? paymentMethod,
    String? paymentType,
    num? discount,
    num? shippingCost,
    int? deliveryMethodId,
  }) async {
    final subscriptionRejection =
        SubscriptionAccessRegistry.rejectedOrderResponse();
    if (subscriptionRejection != null) return subscriptionRejection;

    final uri = Uri.parse(APPUrl.convertQuotationToOrder);
    final body = <String, dynamic>{
      'quotation_id': quotationId,
      if (customerType != null) 'customer_type': customerType,
      if (customerId != null) 'customer_id': customerId,
      if (customerName != null && customerName.trim().isNotEmpty)
        'customer_name': customerName.trim(),
      if (customerPhone != null && customerPhone.trim().isNotEmpty)
        'customer_phone': customerPhone.trim(),
      if (paymentMethod != null && paymentMethod.trim().isNotEmpty)
        'payment_method': paymentMethod.trim(),
      if (paymentType != null && paymentType.trim().isNotEmpty)
        'payment_type': paymentType.trim(),
      if (discount != null) 'discount': discount,
      if (shippingCost != null) 'shipping_cost': shippingCost,
      if (deliveryMethodId != null) 'delivery_method_id': deliveryMethodId,
    };

    final response = await http
        .post(
          uri,
          headers: await _authHeaders(accessToken),
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 30));
    final jsonData = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonData;
    }
    throw Exception(jsonData['message'] ?? 'Failed to convert quotation');
  }

  Future<Map<String, dynamic>> fetchProformaInvoices({
    required String accessToken,
    Map<String, String>? filters,
  }) async {
    final uri = Uri.parse(APPUrl.listProformaInvoices)
        .replace(queryParameters: filters);
    final response = await http
        .get(uri, headers: await _authHeaders(accessToken))
        .timeout(const Duration(seconds: 15));
    final jsonData = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && _isSuccessResponse(jsonData)) {
      return jsonData;
    }
    throw Exception(jsonData['message'] ?? 'Failed to load proforma invoices');
  }

  Future<Map<String, dynamic>> fetchProformaInvoiceDetails({
    required String accessToken,
    required dynamic invoiceId,
  }) async {
    final uri = Uri.parse(APPUrl.viewProformaInvoice(invoiceId));
    final response = await http
        .get(uri, headers: await _authHeaders(accessToken))
        .timeout(const Duration(seconds: 15));
    final jsonData = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && _isSuccessResponse(jsonData)) {
      return jsonData;
    }
    throw Exception(jsonData['message'] ?? 'Proforma invoice not found');
  }
}
