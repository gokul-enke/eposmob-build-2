import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/discount_list_model.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiscountProvider with ChangeNotifier {
  List<DiscountData> _discounts = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastFetchTime;
  static const _cacheValidityDuration = Duration(minutes: 30);

  List<DiscountData> get discounts => _discounts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  Future<void> fetchDiscounts({bool forceRefresh = false}) async {
    if (_discounts.isNotEmpty && !forceRefresh && _lastFetchTime != null) {
      final age = DateTime.now().difference(_lastFetchTime!);
      if (age < _cacheValidityDuration) {
        debugPrint('🎫 Using cached discounts (age: ${age.inMinutes} min)');
        return;
      }
    }

    debugPrint('🎫 ===============================================');
    debugPrint('🎫 FETCHING DISCOUNTS FROM API');
    debugPrint('🎫 ===============================================');
    debugPrint('🎫 Endpoint: ${APPUrl.listDiscounts}');

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');
      String? accessToken = prefs.getString('access_token');
      final int? activeStoreId = prefs.getInt('active_store_id');

      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('🎫 ⚠️ No API key found, skipping fetch.');
        _isLoading = false;
        _errorMessage = 'API key not found';
        notifyListeners();
        return;
      }

      // Build URL with store_id parameter
      final Map<String, String> queryParams = {};
      if (activeStoreId != null) {
        queryParams['store_id'] = activeStoreId.toString();
      }
      final url = Uri.parse(APPUrl.listDiscounts).replace(
          queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      };

      debugPrint('🎫 Request Headers: $headers');
      debugPrint('🎫 Request URL: $url');
      debugPrint('🎫 Request Method: GET');
      debugPrint('🎫 Access token present: ${accessToken?.isNotEmpty == true}');

      final response = await http.get(url, headers: headers);

      debugPrint('🎫 Response Status Code: ${response.statusCode}');
      debugPrint('🎫 Response Body Length: ${response.body.length} chars');
      debugPrint(
          '🎫 Response Body Preview: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...');
      debugPrint('🎫 ===============================================');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final discountModel = DiscountListModel.fromJson(data);

        if (discountModel.status == 'success' && discountModel.data != null) {
          _discounts = discountModel.data!.data;
          _lastFetchTime = DateTime.now();
          debugPrint('✅ Loaded ${_discounts.length} discounts');
        } else {
          _errorMessage = discountModel.message ?? 'Failed to load discounts';
          _discounts = [];
        }
      } else {
        _errorMessage = 'Failed to load discounts: ${response.statusCode}';
        _discounts = [];
      }
    } catch (error) {
      debugPrint('❌ Error fetching discounts: $error');
      _errorMessage = 'An error occurred: $error';
      _discounts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  DiscountValidity getValidityForDiscount(
      DiscountData discount, double cartTotal) {
    return discount.checkValidity(cartTotal, DateTime.now());
  }

  Future<void> refresh() async {
    await fetchDiscounts(forceRefresh: true);
  }

  void clearCache() {
    debugPrint('🧹 Clearing discount cache');
    _discounts = [];
    _lastFetchTime = null;
    _errorMessage = null;
    notifyListeners();
  }

  DiscountData? findDiscountByCode(String couponCode) {
    try {
      return _discounts.firstWhere(
        (d) => d.couponCode.toLowerCase() == couponCode.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }
}
