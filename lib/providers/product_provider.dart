import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProductProvider extends ChangeNotifier {
  bool _isUpdating = false;

  bool get isUpdating => _isUpdating;

  void _setUpdating(bool value) {
    if (_isUpdating != value) {
      _isUpdating = value;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> editProduct({
    required int productId,
    required String name,
    required String slug,
    required String barcode,
    required String unit,
    String? unitId,
    double? price,
    double? mrp,
    double? purchasePrice,
    int? categoryId,
    int? rackNumber,
    num? quantity,
    List<Map<String, dynamic>>? productNames,
    String? minMarginPercentage,
    String? minMarginPrice,
    required String accessToken,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException('API key not found. Please restart the app.');
    }

    if (productId <= 0) {
      throw const HttpException('Product ID missing.');
    }

    debugPrint('🛠️ editProduct → productId=$productId');

    final uri =
        Uri.parse('${APPUrl.baseURL}/api/v1/product/edit-product/$productId');

    final Map<String, dynamic> body = {
      'name': name,
      'slug': slug,
      'price': price,
      'mrp': mrp,
      'purchase_price': purchasePrice,
      'category_id': categoryId,
      'barcode': barcode,
      'unit': unit,
      if (unitId != null && unitId.isNotEmpty) 'unit_id': unitId,
      if (rackNumber != null) 'rack_number': rackNumber,
      if (quantity != null) 'quantity': quantity,
      'store_id': activeStoreId,
      if (productNames != null && productNames.isNotEmpty)
        'product_names': productNames,
    }..removeWhere((key, value) {
        if (value == null) return true;
        if (value is String) {
          return value.trim().isEmpty;
        }
        return false;
      });

    // Margin fields are explicitly clearable: when the caller passes a non-null
    // value, always include the key so an erased field is sent to the server
    // (instead of being dropped). The server requires a number, and 0 is
    // treated as "no floor" by the cart logic, so an erased field is sent as 0.
    // Added after removeWhere so a cleared value survives.
    if (minMarginPercentage != null) {
      body['min_margin_percentage'] = minMarginPercentage.trim().isEmpty
          ? 0
          : (num.tryParse(minMarginPercentage.trim()) ?? 0);
    }
    if (minMarginPrice != null) {
      body['min_margin_price'] = minMarginPrice.trim().isEmpty
          ? 0
          : (num.tryParse(minMarginPrice.trim()) ?? 0);
    }

    _setUpdating(true);
    try {
      debugPrint(
          '🛠️ editProduct → Sending update for productId=$productId with payload: ${jsonEncode(body)}');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
        body: json.encode(body),
      );

      debugPrint(
          '🛠️ editProduct ← Response ${response.statusCode}: ${response.body}');

      final decodedBody = _decodeBody(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
            '❌ editProduct failed (status ${response.statusCode}): ${decodedBody['message'] ?? 'Unknown error'}');
        final message = decodedBody['message']?.toString() ??
            'Failed to update product on server.';
        throw HttpException(message);
      }

      debugPrint(
          '✅ editProduct success: ${decodedBody['message'] ?? 'Product updated'}');
      return decodedBody;
    } on SocketException {
      debugPrint('⚠️ editProduct network error for productId=$productId');
      throw const HttpException('No internet connection. Please try again.');
    } finally {
      _setUpdating(false);
    }
  }

  Map<String, dynamic> _decodeBody(String source) {
    if (source.isEmpty) return {};
    try {
      final decoded = json.decode(source);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'data': decoded};
    } on FormatException {
      return {};
    }
  }
}
