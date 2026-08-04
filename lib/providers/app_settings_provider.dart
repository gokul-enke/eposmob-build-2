import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/get_app_settings.dart';
import 'dart:convert';

import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsProvider extends ChangeNotifier {
  AppSettings? _appSettings;
  bool _loading = false;

  AppSettings? get appSettings => _appSettings;
  bool get loading => _loading;
  bool get allowOverselling => appSettings?.allowOverselling ?? true;
  bool get multiSaleUnitEnabled => appSettings?.multiSaleUnitEnabled ?? false;

  AppSettingsProvider() {
    fetchAppSettings();
  }

  Future<void> fetchAppSettings() async {
    _loading = true;
    notifyListeners();
    // debugPrint("fetchAppSettings");
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final Map<String, String> queryParameters = {};
      if (activeStoreId != null) {
        queryParameters['store_id'] = activeStoreId.toString();
      }
      final url = Uri.parse(APPUrl.getAppSettings)
          .replace(queryParameters: queryParameters);

      final response = await http.get(url, headers: {
        'X-Tenant': apiKey,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        _appSettings = AppSettings.fromJson(data);
      } else {
        throw Exception('Failed to load app settings');
      }
    } catch (error) {
      debugPrint("Error fetching app settings: $error");
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
