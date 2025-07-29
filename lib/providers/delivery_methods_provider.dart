import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/delivery_method.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeliveryMethodsProvider with ChangeNotifier {
  List<DeliveryMethod> _deliveryMethods = [];
  bool _isLoading = false;

  List<DeliveryMethod> get deliveryMethods => _deliveryMethods;
  bool get isLoading => _isLoading;

  DeliveryMethodsProvider() {
    fetchDeliveryMethods();
  }

  Future<void> fetchDeliveryMethods() async {
    _isLoading = true;
    notifyListeners();
    final url = Uri.parse(APPUrl.getDeliveryMethods);
        // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }   
    try {
      final response = await http.get(url, headers: {
        'X-Tenant': apiKey,
      });

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          _deliveryMethods = [];
          final methods = data['data'] as Map<String, dynamic>;

          methods.forEach((key, value) {
            _deliveryMethods.add(DeliveryMethod.fromJson(key, value));
          });
        } else {
          // Handle other statuses if necessary
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Failed to load delivery methods');
      }
    } catch (error) {
      debugPrint('Error: $error');
      throw Exception('Failed to load delivery methods: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
