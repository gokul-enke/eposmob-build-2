import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/payment_gateway.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentGatewaysProvider with ChangeNotifier {
  List<PaymentGateway> _paymentGateways = [];
  bool _isLoading = false;

  List<PaymentGateway> get paymentGateways => _paymentGateways;
  bool get isLoading => _isLoading;

  Future<void> fetchPaymentGateways({
    required String accessToken,
  }) async {
    _isLoading = true;
    notifyListeners();

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    final Map<String, String> queryParameters = {};
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse(APPUrl.getPaymentGateways).replace(queryParameters: queryParameters);

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          _paymentGateways = [];
          final gateways = data['data'] as List;

          for (var gateway in gateways) {
            _paymentGateways.add(PaymentGateway.fromJson(gateway));
          }
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Failed to load payment gateways');
      }
    } catch (error) {
      debugPrint('Error: $error');
      throw Exception('Failed to load payment gateways: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
