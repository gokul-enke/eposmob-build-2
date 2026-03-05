import 'dart:convert';
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

  // Add method to get default delivery method (Store Takeaway)
  DeliveryMethod? get defaultDeliveryMethod {
    try {
      return _deliveryMethods.firstWhere(
        (method) => method.name.toLowerCase().contains('store takeaway'),
        orElse: () => _deliveryMethods.isNotEmpty
            ? _deliveryMethods.first
            : DeliveryMethod(id: "11", name: "Store Takeaway"),
      );
    } catch (e) {
      // Fallback to first method or default
      return _deliveryMethods.isNotEmpty
          ? _deliveryMethods.first
          : DeliveryMethod(id: "11", name: "Store Takeaway");
    }
  }

  DeliveryMethodsProvider() {
    // Removed direct fetch to prevent early crashes or unauthorized requests
  }

  List<DeliveryMethod> _parseDeliveryMethods(dynamic rawData) {
    final List<DeliveryMethod> parsedMethods = [];

    if (rawData is List) {
      for (final item in rawData) {
        if (item is Map<String, dynamic>) {
          final id = item['id']?.toString();
          final name = item['name']?.toString();
          final code = item['code']?.toString();

          if (id != null && id.isNotEmpty && name != null && name.isNotEmpty) {
            // Parse prices array if available
            final List<DeliveryPrice> prices = [];
            if (item['prices'] is List) {
              for (final priceItem in item['prices']) {
                if (priceItem is Map<String, dynamic>) {
                  try {
                    prices.add(DeliveryPrice.fromJson(priceItem));
                  } catch (e) {
                    debugPrint('Error parsing delivery price: $e');
                  }
                }
              }
            }

            parsedMethods.add(DeliveryMethod(
              id: id,
              name: name,
              code: code,
              prices: prices,
            ));
          }
        }
      }
      return parsedMethods;
    }

    if (rawData is Map<String, dynamic>) {
      rawData.forEach((key, value) {
        if (value is String) {
          parsedMethods.add(DeliveryMethod.fromJson(key, value));
        } else if (value is Map<String, dynamic>) {
          final id = value['id']?.toString() ?? key;
          final name = value['name']?.toString() ?? value['label']?.toString();

          if (name != null && name.isNotEmpty) {
            parsedMethods.add(DeliveryMethod(id: id, name: name));
          }
        }
      });
    }

    return parsedMethods;
  }

  Future<void> fetchDeliveryMethods() async {
    _isLoading = true;
    notifyListeners();

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');
      final int? activeStoreId = prefs.getInt('active_store_id');

      if (apiKey == null || apiKey.isEmpty) {
        debugPrint(
            '⚠️ DeliveryMethodsProvider: No API key found, skipping fetch.');
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Build query parameters with store_id
      final Map<String, String> queryParameters = {};
      if (activeStoreId != null) {
        queryParameters['store_id'] = activeStoreId.toString();
      }

      final url = Uri.parse(APPUrl.getDeliveryMethods)
          .replace(queryParameters: queryParameters);

      final response = await http.get(url, headers: {
        'X-Tenant': apiKey,
      });

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          _deliveryMethods = _parseDeliveryMethods(data['data']);
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
