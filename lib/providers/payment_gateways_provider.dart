import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/payment_gateway.dart';
import 'package:pos_machine/resources/app_url.dart';

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
    final url = Uri.parse(APPUrl.getPaymentGateways);
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
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
