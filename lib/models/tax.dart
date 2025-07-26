import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaxCalculationResult {
  final double retailPrice;
  final double taxAmount;
  final double taxRate;

  TaxCalculationResult({
    required this.retailPrice,
    required this.taxAmount,
    required this.taxRate,
  });

  factory TaxCalculationResult.fromJson(Map<String, dynamic> json) {
    return TaxCalculationResult(
      retailPrice: json['retail_price'].toDouble(),
      taxAmount: json['tax_amount'].toDouble(),
      taxRate: json['tax_rate'].toDouble(),
    );
  }
}

Future<TaxCalculationResult> getCategoryTax({
  required String accessToken,
  required String taxInclude,
  required String categoryId,
  required String productId,
  required String retailPrice,
}) async {
  final queryParameters = <String, String>{
    'tax_include': taxInclude,
    'category_id': categoryId.toString(),
    'product_id': productId.toString(),
    'retail_price': retailPrice.toString(),
  };

  // debugPrint(queryParameters.toString());

  final uri = Uri.parse(APPUrl.getTaxtDetails)
      .replace(queryParameters: queryParameters);

  // Get API key from SharedPreferences
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? apiKey = prefs.getString('api_key');

  if (apiKey == null || apiKey.isEmpty) {
    throw const HttpException("API key not found. Please restart the app.");
  }

  try {
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      },
    ).timeout(const Duration(seconds: 15));

    // debugPrint('getCategoryTax API response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      if (response.body.isNotEmpty) {
        final jsonData = json.decode(response.body);
        // debugPrint('Received JSON data: ${jsonData.toString()}');

        if (jsonData['status'] == 'success') {
          return TaxCalculationResult.fromJson(jsonData['data']);
        } else {
          throw Exception('API returned error: ${jsonData['message']}');
        }
      } else {
        // debugPrint('Empty response body');
        throw Exception('Received empty response');
      }
    } else {
      debugPrint(
          'Failed to calculate tax: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to calculate tax');
    }
  } catch (error) {
    // debugPrint('Error in getCategoryTax: $error');
    rethrow;
  }
}
