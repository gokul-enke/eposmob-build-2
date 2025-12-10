import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferenceProvider extends ChangeNotifier {
  saveAccessToken(String accessToken) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // debugPrint('inside shared ');

    prefs.setString('access_token', accessToken);
    // debugPrint('inside shared ,$accessToken');
  }

  saveAccessTokenandCustomerId(
    String accessToken,
    int customerId,
    String customerName,
    String userRole, {
    String? tokenType,
    int? companyId,
    String? companyName,
    String? storesJson,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // debugPrint('inside shared ');

    prefs.setString('access_token', accessToken);
    prefs.setInt('customerId', customerId);
    prefs.setString('customerName', customerName);
    prefs.setString('userRole', userRole);

    // Save new fields
    if (tokenType != null) {
      prefs.setString('token_type', tokenType);
    }
    if (companyId != null) {
      prefs.setInt('company_id', companyId);
    }
    if (companyName != null) {
      prefs.setString('company_name', companyName);
    }
    if (storesJson != null) {
      prefs.setString('stores', storesJson);
    }
    // debugPrint('inside shared ,$customerName');
  }

  removeToken() async {
    // debugPrint("removeToken  prefs.remove('access_token');");
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    prefs.remove('access_token');
  }

  removeTokenAndCustomerId() async {
    // debugPrint("removeTokenAndCustomerId  prefs.remove('access_token');");
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    prefs.remove('access_token');
    prefs.remove('customerId');
    prefs.remove('customerName');
    prefs.remove('userRole');

    // Remove new fields
    prefs.remove('token_type');
    prefs.remove('company_id');
    prefs.remove('company_name');
    prefs.remove('stores');
    prefs.remove('active_store_id');
  }

  Future<String?> getToken() async {
    // debugPrint("getToken  String? token = prefs.getString('access_token');");
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    String? token = prefs.getString('access_token');
    return token;
    // return '101|LbzEubzMNqBffc10NqHnnbDu1pWcTOhplh2D9Kfo';
  }

  Future<int?> getCustomerId() async {
    // debugPrint(" int? customerId = prefs.getInt('customerId');");
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    int? customerId = prefs.getInt('customerId');
    return customerId;
    // return '101|LbzEubzMNqBffc10NqHnnbDu1pWcTOhplh2D9Kfo';
  }

  Future<String> getCustomerName() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? customerName = prefs.getString('customerName');
    return customerName ?? 'Default Name'; // Return a default value if null
  }

  Future<String> getUserRole() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userRole = prefs.getString('userRole');
    return userRole ?? 'user'; // Return a default value if null
  }

  // API Key management methods
  Future<void> saveApiKey(String apiKey) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', apiKey);
  }

  Future<String?> getApiKey() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_key');
  }

  Future<bool> hasApiKey() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    return apiKey != null && apiKey.isNotEmpty;
  }

  Future<void> removeApiKey() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_key');
  }

  // Getter methods for new fields
  Future<String?> getTokenType() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token_type');
  }

  Future<int?> getCompanyId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('company_id');
  }

  Future<String?> getCompanyName() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('company_name');
  }

  Future<String?> getStoresJson() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('stores');
  }

  Future<List<dynamic>?> getStores() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storesJson = prefs.getString('stores');
    if (storesJson != null && storesJson.isNotEmpty) {
      try {
        return json.decode(storesJson) as List<dynamic>;
      } catch (e) {
        debugPrint('Error decoding stores: $e');
        return null;
      }
    }
    return null;
  }

  // Active store management
  Future<void> saveActiveStoreId(int storeId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_store_id', storeId);
  }

  Future<int?> getActiveStoreId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('active_store_id');
  }

  Future<void> removeActiveStoreId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_store_id');
  }

  // Printer settings management
  Future<void> clearPrinterSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('default_printer');
    await prefs.remove('default_paper_size');
    await prefs.remove('default_font_style');
  }
}
