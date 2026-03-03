import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MasterDataProvider with ChangeNotifier {
  MasterData? _masterData;
  bool _isLoading = false;
  String? _error;

  // Payment methods cache - now stores list of MasterDataValue
  List<MasterDataValue>? _paymentMethods;
  bool _isLoadingPaymentMethods = false;

  MasterData? get masterData => _masterData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Payment methods getters
  List<MasterDataValue>? get paymentMethods => _paymentMethods;
  bool get isLoadingPaymentMethods => _isLoadingPaymentMethods;

  /// Get payment method ID by its value (e.g., "CASH" -> 3200)
  int? getPaymentMethodId(String? value) {
    if (value == null || _paymentMethods == null) return null;
    try {
      return _paymentMethods!.firstWhere((item) => item.value == value).id;
    } catch (e) {
      return null;
    }
  }

  /// Get payment method value by its ID (e.g., 3200 -> "CASH")
  String? getPaymentMethodValue(int? id) {
    if (id == null || _paymentMethods == null) return null;
    try {
      return _paymentMethods!.firstWhere((item) => item.id == id).value;
    } catch (e) {
      return null;
    }
  }

  /// Get payment method description by its value
  String? getPaymentMethodDescription(String? value) {
    if (value == null || _paymentMethods == null) return null;
    try {
      return _paymentMethods!
          .firstWhere((item) => item.value == value)
          .description;
    } catch (e) {
      return null;
    }
  }

  /// Fetches payment methods from the API and caches them
  /// Returns a List of MasterDataValue objects
  Future<List<MasterDataValue>?> fetchPaymentMethods() async {
    // Return cached data if available
    if (_paymentMethods != null && _paymentMethods!.isNotEmpty) {
      return _paymentMethods;
    }

    _isLoadingPaymentMethods = true;
    notifyListeners();

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      _error = "API key not found. Please restart the app.";
      _isLoadingPaymentMethods = false;
      notifyListeners();
      return null;
    }

    try {
      final baseUri = Uri.parse(APPUrl.getPaymentMethods);
      final queryParameters =
          Map<String, String>.from(baseUri.queryParameters);
      if (activeStoreId != null) {
        queryParameters['store_id'] = activeStoreId.toString();
      }
      final url = baseUri.replace(queryParameters: queryParameters);
      debugPrint('🔄 Fetching payment methods');
      debugPrint('📡 URL: $url');

      final response = await http.get(url, headers: {
        'X-Tenant': apiKey,
      });

      debugPrint('📊 Response status: ${response.statusCode}');
      debugPrint('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 'success') {
          final dataList = data['data'] as List<dynamic>? ?? [];
          _paymentMethods =
              dataList.map((item) => MasterDataValue.fromJson(item)).toList();
          debugPrint('✅ Payment methods fetched successfully');
          debugPrint('📋 Payment methods: $_paymentMethods');
          return _paymentMethods;
        } else {
          _error = data['message'] ?? 'Failed to fetch payment methods';
          debugPrint('❌ API returned error: $_error');
          return null;
        }
      } else {
        _error = 'HTTP ${response.statusCode}: Failed to fetch payment methods';
        debugPrint('❌ HTTP Error: $_error');
        return null;
      }
    } catch (error) {
      _error = 'Error fetching payment methods: $error';
      debugPrint('💥 Exception: $_error');
      return null;
    } finally {
      _isLoadingPaymentMethods = false;
      notifyListeners();
    }
  }

  /// Clears payment methods cache to force re-fetch
  void clearPaymentMethodsCache() {
    _paymentMethods = null;
    notifyListeners();
  }

  Future<MasterData?> fetchMasterData(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      _error = "API key not found. Please restart the app.";
      _isLoading = false;
      notifyListeners();
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final baseUri = Uri.parse('${APPUrl.getMasterDataValues}?code=$code');
      final queryParams = Map<String, String>.from(baseUri.queryParameters);

      final int? activeStoreId = prefs.getInt('active_store_id');
      if (activeStoreId != null) {
        queryParams['store_id'] = activeStoreId.toString();
      }

      final url = baseUri.replace(queryParameters: queryParams);
      debugPrint('🔄 Fetching master data for code: $code');
      debugPrint('📡 URL: $url');

      final response = await http.get(url, headers: {
        'X-Tenant': apiKey,
      });

      debugPrint('📊 Response status: ${response.statusCode}');
      debugPrint('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 'success') {
          _masterData = MasterData.fromJson(data);
          debugPrint('✅ Master data fetched successfully for code: $code');
          debugPrint('📋 Data count: ${_masterData?.data.length}');
          return _masterData;
        } else {
          _error = data['message'] ?? 'Failed to fetch master data';
          debugPrint('❌ API returned error: $_error');
          throw Exception(_error);
        }
      } else {
        _error = 'HTTP ${response.statusCode}: Failed to fetch master data';
        debugPrint('❌ HTTP Error: $_error');
        throw Exception(_error);
      }
    } catch (error) {
      _error = 'Error fetching master data: $error';
      debugPrint('💥 Exception: $_error');
      throw Exception(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear current data
  void clearData() {
    _masterData = null;
    _error = null;
    notifyListeners();
  }
}
