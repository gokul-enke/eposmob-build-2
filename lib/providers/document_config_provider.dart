import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/document_configurations.dart';
import '../resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DocumentConfigProvider extends ChangeNotifier {
  bool isLoading = false;
  DocumentConfigurationsModel? _documentConfigurations;
  String? _errorMessage;

  DocumentConfigurationsModel? get documentConfigurations =>
      _documentConfigurations;
  String? get errorMessage => _errorMessage;

  Future<void> fetchDocumentConfigurations(
      {required String accessToken}) async {
    isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final url = Uri.parse(APPUrl.documentConfigs);
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        _documentConfigurations =
            DocumentConfigurationsModel.fromJson(jsonData);
        isLoading = false;
        notifyListeners();
      } else {
        _errorMessage =
            'Failed to load document configurations: ${response.statusCode}';
        isLoading = false;
        notifyListeners();
        // You might want to throw an exception or handle specific status codes
        throw Exception('Failed to load document configurations');
      }
    } catch (error) {
      _errorMessage = 'Error fetching document configurations: $error';
      isLoading = false;
      notifyListeners();
      rethrow; // Re-throw the error for the calling code to handle if needed
    }
  }

  // You can add more helper getters or methods here
  // For example, a getter to easily access a specific document config
  DocumentConfig? getDocumentConfig(String type) {
    return _documentConfigurations?.documentConfigurations?[type];
  }

  // Example: Getter to get template options
  Map<String, String>? get templateOptions {
    return _documentConfigurations?.options?.templateOptions;
  }

  // Debug method to clear cached data
  void clearConfiguration() {
    debugPrint("🗑️ Clearing cached document configurations");
    _documentConfigurations = null;
    _errorMessage = null;
    notifyListeners();
  }

  // Debug method to inspect current configuration
  void debugCurrentConfiguration() {
    debugPrint("===== CURRENT DOCUMENT CONFIG PROVIDER STATE =====");
    debugPrint("Has configurations: ${_documentConfigurations != null}");
    debugPrint("Error message: $_errorMessage");
    debugPrint("Is loading: $isLoading");
    
    if (_documentConfigurations != null) {
      final billConfig = _documentConfigurations!.documentConfigurations?['Bill'];
      if (billConfig != null) {
        debugPrint("\n📄 CURRENT BILL CONFIG:");
        debugPrint("- ID: ${billConfig.id}");
        debugPrint("- Updated At: ${billConfig.updatedAt}");
        
        final displayConfig = billConfig.displayConfiguration?.options;
        if (displayConfig != null && displayConfig.containsKey('showDiscount')) {
          final showDiscount = displayConfig['showDiscount'];
          debugPrint("\n🔍 CURRENT showDiscount:");
          debugPrint("  * visible: ${showDiscount?.visible}");
          debugPrint("  * value: ${showDiscount?.value}");
        }
      }
    }
    debugPrint("===== END CURRENT CONFIG PROVIDER STATE =====");
  }

  // Force refresh method for debugging
  Future<void> forceRefreshConfiguration(String accessToken) async {
    debugPrint("🔄 Force refreshing document configurations...");
    clearConfiguration();
    await fetchDocumentConfigurations(accessToken: accessToken);
    debugCurrentConfiguration();
  }
}
