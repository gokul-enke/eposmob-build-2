import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
      queryParameters['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      queryParameters['end_date'] = endDate;
    }
    if (customerId != null && customerId.isNotEmpty) {
      queryParameters['customer_id'] = customerId;
    }
    if (filterStatus != null && filterStatus.isNotEmpty && filterStatus.toLowerCase() != 'all') {
      queryParameters['status'] = filterStatus;
    }
    if (page != null) {
      queryParameters['page'] = page.toString();
    }

    final uri = Uri.parse(APPUrl.listQuotations).replace(queryParameters: queryParameters);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found. Please restart the app.");
      }

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final jsonData = json.decode(response.body);
          
          List<Quotation> loadedQuotations = [];
          if (jsonData['status'] == 'success' && jsonData['data'] != null) {
            final dataWrapper = QuotationDataWrapper.fromJson(jsonData['data']);
            loadedQuotations = dataWrapper.data ?? [];
            
            currentPage = dataWrapper.currentPage ?? 1;
            totalPages = dataWrapper.lastPage ?? 1;
            paginationFrom = dataWrapper.from ?? 1;
          }
          
          _quotations = loadedQuotations;
          notifyListeners();
        } else {
          throw Exception('Received empty response');
        }
      } else {
        throw Exception('Failed to load quotations: HTTP ${response.statusCode}');
      }
    } catch (error) {
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
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found. Please restart the app.");
      }

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final jsonData = json.decode(response.body);
          
          if (jsonData['status'] == 'success' && jsonData['data'] != null) {
            _currentQuotationDetails = QuotationDetailsData.fromJson(jsonData['data']);
            notifyListeners();
            return _currentQuotationDetails;
          }
        }
      }
      return null;
    } catch (error) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createQuotation({
    required String accessToken,
    required Map<String, dynamic> data,
  }) async {
    final uri = Uri.parse(APPUrl.listQuotations); // POST /api/v1/quotations

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found. Please restart the app.");
      }

      debugPrint('📡 CREATE QUOTATION REQUEST URL: $uri');
      debugPrint('📡 CREATE QUOTATION REQUEST HEADERS: Authorization=Bearer *****, X-Tenant=$apiKey');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
        body: json.encode(data),
      ).timeout(const Duration(seconds: 30));

      debugPrint('📥 CREATE QUOTATION HTTP STATUS: ${response.statusCode}');
      debugPrint('📥 CREATE QUOTATION RESPONSE BODY: ${response.body}');

      final jsonData = json.decode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonData;
      } else {
        final errorMsg = jsonData['message'] ?? jsonData['error'] ?? 'Failed to create quotation (HTTP ${response.statusCode})';
        debugPrint('❌ CREATE QUOTATION FAILED: $errorMsg');
        if (jsonData['errors'] != null) {
          debugPrint('❌ VALIDATION ERRORS: ${jsonData['errors']}');
        }
        throw Exception(errorMsg);
      }
    } catch (error) {
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
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found. Please restart the app.");
      }

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
        body: json.encode({
          'quotation_id': quotationId,
          'status': status,
        }),
      ).timeout(const Duration(seconds: 15));

      final jsonData = json.decode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonData;
      } else {
        throw Exception(jsonData['message'] ?? 'Failed to update status');
      }
    } catch (error) {
      rethrow;
    }
  }
}
