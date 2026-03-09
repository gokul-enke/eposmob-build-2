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
    String? timeZone,
    String? countryName,
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
    if (timeZone != null) {
      prefs.setString('time_zone', timeZone);
    }
    if (countryName != null) {
      prefs.setString('country_name', countryName);
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
    prefs.remove('time_zone');
    prefs.remove('country_name');

    // Remove ZATCA fields
    prefs.remove('zatca_vat_number');
    prefs.remove('zatca_company_name');
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

  Future<String?> getTimeZone() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('time_zone');
  }

  Future<String?> getCountryName() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('country_name');
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

  Future<void> saveServerTimeOffset(int offsetMilliseconds) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('server_time_offset', offsetMilliseconds);
  }

  Future<int?> getServerTimeOffset() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('server_time_offset');
  }

  Future<void> saveLastProductSyncIso(String isoDateTime) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_product_sync_iso', isoDateTime);
  }

  Future<String?> getLastProductSyncIso() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_product_sync_iso');
  }

  Future<void> clearLastProductSyncIso() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_product_sync_iso');
  }

  Future<void> saveManualOfflineMode(bool enabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('manual_offline_mode', enabled);
  }

  Future<bool> getManualOfflineMode() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('manual_offline_mode') ?? false;
  }

  Future<void> clearManualOfflineMode() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('manual_offline_mode');
  }

  // ==================== ZATCA METHODS ====================

  /// Save ZATCA VAT number for Saudi Arabia e-invoicing
  Future<void> saveZatcaVatNumber(String vatNumber) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('zatca_vat_number', vatNumber);
  }

  /// Get ZATCA VAT number
  Future<String?> getZatcaVatNumber() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('zatca_vat_number');
  }

  /// Save ZATCA company name for Saudi Arabia e-invoicing
  Future<void> saveZatcaCompanyName(String companyName) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('zatca_company_name', companyName);
  }

  /// Get ZATCA company name
  Future<String?> getZatcaCompanyName() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('zatca_company_name');
  }

  /// Save both ZATCA credentials at once
  Future<void> saveZatcaCredentials({
    String? vatNumber,
    String? companyName,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (vatNumber != null && vatNumber.isNotEmpty) {
      await prefs.setString('zatca_vat_number', vatNumber);
    }
    if (companyName != null && companyName.isNotEmpty) {
      await prefs.setString('zatca_company_name', companyName);
    }
  }

  /// Check if ZATCA credentials are available
  Future<bool> hasZatcaCredentials() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final vatNumber = prefs.getString('zatca_vat_number');
    final companyName = prefs.getString('zatca_company_name');
    return vatNumber != null &&
        vatNumber.isNotEmpty &&
        companyName != null &&
        companyName.isNotEmpty;
  }

  /// Remove ZATCA credentials
  Future<void> removeZatcaCredentials() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('zatca_vat_number');
    await prefs.remove('zatca_company_name');
  }
}
