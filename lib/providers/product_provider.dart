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
    List<Map<String, dynamic>>? productNames,
    required String accessToken,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? apiKey = prefs.getString('api_key');
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
      if (productNames != null && productNames.isNotEmpty)
        'product_names': productNames,
    }..removeWhere((key, value) {
        if (value == null) return true;
        if (value is String) {
          return value.trim().isEmpty;
        }
        return false;
      });

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
