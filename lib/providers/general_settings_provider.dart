import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/get_general_settings.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'dart:convert';

import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeneralSettingsProvider with ChangeNotifier {
  GeneralSettings? _generalSettings;
  bool _loading = false;

  GeneralSettings? get generalSettings => _generalSettings;
  bool get loading => _loading;

  GeneralSettingsProvider() {
    fetchGeneralSettings();
  }

  Future<void> fetchGeneralSettings() async {
    _loading = true;
    notifyListeners();
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    // Build URL with store_id parameter
    final Map<String, String> queryParams = {};
    if (activeStoreId != null) {
      queryParams['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse(APPUrl.getGeneralSettings)
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    try {
      final response =
          await http.get(url, headers: {
        'X-Tenant': apiKey,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        // Debug the raw response and the parsed structure
        debugPrint(' GeneralSettings API raw: ${response.body}');
        // Handle both wrapped and unwrapped formats
        final Map<String, dynamic> payload =
            (data.containsKey('data') && data['data'] is Map<String, dynamic>)
                ? (data['data'] as Map<String, dynamic>)
                : data;
        if (!payload.containsKey('stock_enabled')) {
          debugPrint(' GeneralSettings payload missing stock_enabled key');
        }
        _generalSettings = GeneralSettings.fromJson(payload);
        LocalProductProvider.cacheStockEnabled(
          _generalSettings?.stockEnabled ?? false,
        );
        await prefs.setBool(
          'general_stock_enabled',
          _generalSettings?.stockEnabled ?? false,
        );
        debugPrint(
            ' Parsed GeneralSettings: stock_enabled=${_generalSettings?.stockEnabled}');
      } else {
        throw Exception('Failed to load general settings');
      }
    } catch (error) {
      debugPrint("Error fetching general settings: $error");
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
