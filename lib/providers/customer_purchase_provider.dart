import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/customer_purchase_history.dart';
import 'package:pos_machine/resources/app_url.dart';

class CustomerPurchaseProvider {
  
  /// Fetch customer's last purchases for a specific product
  Future<CustomerPurchaseHistory?> getCustomerLastPurchases({
    required String accessToken,
    required int customerId,
    required int productId,
  }) async {
    try {
      debugPrint('=== CUSTOMER PURCHASE API CALL START ===');
      debugPrint('Customer ID: $customerId');
      debugPrint('Product ID: $productId');
      debugPrint('Access Token: ${accessToken.length > 0 ? "Available (${accessToken.length} chars)" : "Missing"}');
      
      final String url = APPUrl.customerLastPurchases;
      
      // Prepare request body for POST request
      final Map<String, dynamic> requestBody = {
        'customer_id': customerId,
        'product_id': productId,
      };
      
      debugPrint('Customer Purchase API URL: $url');
      debugPrint('Request Method: POST');
      debugPrint('Request Body: ${json.encode(requestBody)}');
      debugPrint('Making HTTP POST request...');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode(requestBody),
      );

      debugPrint('Customer Purchase API Response Status: ${response.statusCode}');
      debugPrint('Customer Purchase API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('✅ API call successful - parsing response...');
        
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        debugPrint('Parsed JSON keys: ${jsonResponse.keys.toList()}');
        debugPrint('Success field: ${jsonResponse['success']}');
        
        if (jsonResponse['data'] != null) {
          final List<dynamic> dataList = jsonResponse['data'] as List<dynamic>;
          debugPrint('Number of purchase records found: ${dataList.length}');
          
          // Log each purchase record
          for (int i = 0; i < dataList.length; i++) {
            final item = dataList[i];
            debugPrint('Purchase Record $i:');
            debugPrint('  - Price: ${item['price']}');
            debugPrint('  - Quantity: ${item['quantity']}');
            debugPrint('  - Total: ${item['total']}');
            debugPrint('  - Date: ${item['date']}');
            debugPrint('  - Order Number: ${item['order_number']}');
          }
        } else {
          debugPrint('❌ No data field in response');
        }
        
        final CustomerPurchaseHistory history = CustomerPurchaseHistory.fromJson(jsonResponse);
        debugPrint('✅ CustomerPurchaseHistory model created successfully');
        debugPrint('Model success: ${history.success}');
        debugPrint('Model data count: ${history.data.length}');
        debugPrint('=== CUSTOMER PURCHASE API CALL END ===');
        
        return history;
      } else {
        debugPrint('❌ API call failed with status: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        debugPrint('=== CUSTOMER PURCHASE API CALL END ===');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Exception in customer purchase API call: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('=== CUSTOMER PURCHASE API CALL END ===');
      return null;
    }
  }
} 