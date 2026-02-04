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

  /// Fetch document configuration with type and language parameters.
  /// This returns localized configuration based on the selected language.
  ///
  /// [type] - Document type: "bill", "sales_and_return_bill", etc.
  /// [language] - Language code: "en", "ar", etc.
  Future<DocumentConfig?> fetchDocumentConfigByTypeAndLanguage({
    required String accessToken,
    required String type,
    String? language,
  }) async {
    debugPrint("📄 Fetching document config: type=$type, language=$language");

    String urlString = '${APPUrl.documentConfigs}?type=$type';
    if (language != null && language.isNotEmpty) {
      urlString += '&language=$language';
    }
    final url = Uri.parse(urlString);

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
        debugPrint("✅ Document config API response received");

        // Parse the response - the config is nested under document_configurations
        final documentConfigs = jsonData['document_configurations'];
        if (documentConfigs != null && documentConfigs is Map) {
          // Get the first (and likely only) config from the response
          // The key could be "Bill", "Sales and Return Bill", etc.
          final firstKey = documentConfigs.keys.first;
          if (firstKey != null) {
            final configJson = documentConfigs[firstKey];
            final config = DocumentConfig.fromJson(configJson);
            debugPrint("✅ Parsed config for: $firstKey");
            return config;
          }
        }

        debugPrint("❌ No document configuration found in response");
        return null;
      } else {
        debugPrint("❌ API error: ${response.statusCode}");
        throw Exception(
            'Failed to load document config: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint("❌ Error fetching document config: $error");
      rethrow;
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
      // Check for Customer Statement config (for transaction reports)
      final customerStatementConfig = _documentConfigurations!
          .documentConfigurations?['Customer Statement'];
      if (customerStatementConfig != null) {
        debugPrint("\n📄 CURRENT CUSTOMER STATEMENT CONFIG:");
        debugPrint("- ID: ${customerStatementConfig.id}");
        debugPrint("- Updated At: ${customerStatementConfig.updatedAt}");
        debugPrint(
            "- Has Display Config: ${customerStatementConfig.displayConfiguration != null}");

        final displayConfig =
            customerStatementConfig.displayConfiguration?.options;
        if (displayConfig != null) {
          debugPrint("- Display Config Options Count: ${displayConfig.length}");
          debugPrint("- Display Config Keys: ${displayConfig.keys.toList()}");

          // Show a few key options
          ['showHeader', 'showSubheader', 'showFooter', 'showCustomerName']
              .forEach((key) {
            if (displayConfig.containsKey(key)) {
              final option = displayConfig[key];
              debugPrint(
                  "  * $key: visible=${option?.visible}, value=${option?.value}");
            }
          });
        } else {
          debugPrint("❌ Display Config Options is NULL");
        }
      } else {
        debugPrint("❌ Customer Statement config not found");
        debugPrint(
            "Available configs: ${_documentConfigurations!.documentConfigurations?.keys.toList()}");
      }

      // Also check for Bill config (legacy)
      final billConfig =
          _documentConfigurations!.documentConfigurations?['Bill'];
      if (billConfig != null) {
        debugPrint("\n📄 CURRENT BILL CONFIG:");
        debugPrint("- ID: ${billConfig.id}");
        debugPrint("- Updated At: ${billConfig.updatedAt}");

        final displayConfig = billConfig.displayConfiguration?.options;
        if (displayConfig != null &&
            displayConfig.containsKey('showDiscount')) {
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

  // Debug method to test parsing with raw JSON
  void debugParseRawJson(String rawJson) {
    debugPrint("🧪 Testing JSON parsing with raw data...");
    try {
      final jsonData = json.decode(rawJson);
      debugPrint("✅ JSON decode successful");

      final model = DocumentConfigurationsModel.fromJson(jsonData);
      debugPrint("✅ Model parsing successful");

      final customerStatement =
          model.documentConfigurations?['Customer Statement'];
      if (customerStatement != null) {
        debugPrint("✅ Customer Statement config found");
        debugPrint(
            "Display config exists: ${customerStatement.displayConfiguration != null}");
        debugPrint(
            "Display config options count: ${customerStatement.displayConfiguration?.options?.length ?? 0}");

        if (customerStatement.displayConfiguration?.options != null) {
          customerStatement.displayConfiguration!.options!
              .forEach((key, value) {
            debugPrint(
                "  $key: visible=${value.visible}, value=${value.value}");
          });
        }
      } else {
        debugPrint("❌ Customer Statement config not found");
      }
    } catch (e) {
      debugPrint("❌ Error parsing JSON: $e");
    }
  }

  // Test method with the provided API response
  void testWithProvidedApiResponse() {
    const testJson = '''
{
  "status": "success",
  "document_configurations": {
    "Customer Statement": {
      "id": 13,
      "company_id": 1,
      "type": "Customer Statement",
      "logo": null,
      "show_logo": 0,
      "number_prefix": null,
      "discount_method": null,
      "header": "EPosenke",
      "subheader": "Customer Transaction Report",
      "terms": null,
      "footer": null,
      "accent_color": null,
      "font": null,
      "template": "customer_statement",
      "item_name": null,
      "tax_name": null,
      "unit_name": null,
      "price_name": null,
      "amount_name": null,
      "created_by": null,
      "updated_by": null,
      "created_at": "2025-09-16T11:15:46.000000Z",
      "updated_at": "2025-09-26T14:40:06.000000Z",
      "display_configuration": {
        "showHeader": {"visible": true, "value": null},
        "showSubheader": {"visible": true, "value": null},
        "showFooter": {"visible": true, "value": null},
        "showDates": {"visible": true, "value": null},
        "showCustomerName": {"visible": true, "value": null},
        "showCustomerEmail": {"visible": true, "value": null},
        "showCustomerPhone": {"visible": true, "value": null},
        "showCustomerAddress": {"visible": true, "value": null},
        "showTotalCredit": {"visible": true, "value": null},
        "showTotalDebit": {"visible": true, "value": null},
        "showBalance": {"visible": true, "value": null},
        "showOrderNumber": {"visible": true, "value": null},
        "showStatus": {"visible": true, "value": null},
        "showTax": {"visible": true, "value": null}
      },
      "resolved_labels": {
        "item_name": "PRT",
        "unit_name": "QTY",
        "price_name": "Rate",
        "tax_name": "Tax",
        "amount_name": "AMT"
      }
    }
  },
  "options": {
    "item_name_options": {"items": "Items", "products": "Products", "services": "Services", "other": "Other"},
    "unit_name_options": {"quantity": "Quantity", "hours": "Hours", "other": "Other"},
    "price_name_options": {"price": "Price", "rate": "Rate", "other": "Other"},
    "tax_name_options": {"tax": "Tax", "GST": "GST", "VAT": "VAT", "tax (%)": "Tax (%)", "other": "Other"},
    "amount_name_options": {"amount": "Amount", "total": "Total", "other": "Other"},
    "template_options": {"default": "Default", "bill": "Bill", "receipt": "Receipt", "voucher": "Voucher", "payslip": "Payslip", "email": "Email", "supplier_invoice": "Supplier Invoice", "delivery_note": "Delivery Note", "customer_statement": "Customer Statement", "supplier_statement": "Supplier Statement"}
  }
}
''';
    debugParseRawJson(testJson);
  }
}
