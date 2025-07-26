import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/get_general_settings.dart';
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

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response =
          await http.get(Uri.parse(APPUrl.getGeneralSettings), headers: {
        'X-Tenant': apiKey,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        _generalSettings = GeneralSettings.fromJson(data);
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
