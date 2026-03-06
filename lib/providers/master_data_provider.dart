import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MasterDataProvider with ChangeNotifier {
  static const String _paymentMethodsCacheKeyPrefix =
      'payment_methods_cache';

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
  Future<List<MasterDataValue>?> fetchPaymentMethods({
    bool forceRefresh = false,
  }) async {
    // Return cached data if available
    if (!forceRefresh && _paymentMethods != null && _paymentMethods!.isNotEmpty) {
      return _paymentMethods;
    }

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (!forceRefresh) {
      final cachedMethods = _loadPaymentMethodsFromLocalCache(prefs, activeStoreId);
      if (cachedMethods != null && cachedMethods.isNotEmpty) {
        _paymentMethods = cachedMethods;
        return _paymentMethods;
      }
    }

    _isLoadingPaymentMethods = true;
    notifyListeners();

    if (apiKey == null || apiKey.isEmpty) {
      _error = "API key not found. Please restart the app.";
      _isLoadingPaymentMethods = false;
      notifyListeners();
      return _loadPaymentMethodsFromLocalCache(prefs, activeStoreId);
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
          await _savePaymentMethodsToLocalCache(
            prefs,
            activeStoreId,
            _paymentMethods!,
          );
          debugPrint('✅ Payment methods fetched successfully');
          debugPrint('📋 Payment methods: $_paymentMethods');
          return _paymentMethods;
        } else {
          _error = data['message'] ?? 'Failed to fetch payment methods';
          debugPrint('❌ API returned error: $_error');
          return _loadPaymentMethodsFromLocalCache(prefs, activeStoreId);
        }
      } else {
        _error = 'HTTP ${response.statusCode}: Failed to fetch payment methods';
        debugPrint('❌ HTTP Error: $_error');
        return _loadPaymentMethodsFromLocalCache(prefs, activeStoreId);
      }
    } catch (error) {
      _error = 'Error fetching payment methods: $error';
      debugPrint('💥 Exception: $_error');
      return _loadPaymentMethodsFromLocalCache(prefs, activeStoreId);
    } finally {
      _isLoadingPaymentMethods = false;
      notifyListeners();
    }
  }

  List<MasterDataValue>? _loadPaymentMethodsFromLocalCache(
    SharedPreferences prefs,
    int? activeStoreId,
  ) {
    final raw = prefs.getString(_paymentMethodsCacheKey(activeStoreId));
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = json.decode(raw) as List<dynamic>;
      final cachedMethods = decoded
          .map((item) => MasterDataValue.fromJson(item as Map<String, dynamic>))
          .toList();
      if (cachedMethods.isNotEmpty) {
        debugPrint(
            '📦 Loaded payment methods from local cache: ${cachedMethods.length}');
      }
      return cachedMethods;
    } catch (error) {
      debugPrint('❌ Failed to read cached payment methods: $error');
      return null;
    }
  }

  Future<void> _savePaymentMethodsToLocalCache(
    SharedPreferences prefs,
    int? activeStoreId,
    List<MasterDataValue> methods,
  ) async {
    try {
      await prefs.setString(
        _paymentMethodsCacheKey(activeStoreId),
        json.encode(methods.map((item) => item.toJson()).toList()),
      );
    } catch (error) {
      debugPrint('❌ Failed to cache payment methods locally: $error');
    }
  }

  String _paymentMethodsCacheKey(int? activeStoreId) {
    return activeStoreId == null
        ? _paymentMethodsCacheKeyPrefix
        : '${_paymentMethodsCacheKeyPrefix}_$activeStoreId';
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
