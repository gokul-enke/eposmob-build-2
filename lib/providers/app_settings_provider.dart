import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/get_app_settings.dart';
import 'dart:convert';

import 'package:pos_machine/resources/app_url.dart';

class AppSettingsProvider with ChangeNotifier {
  AppSettings? _appSettings;
  bool _loading = false;

  AppSettings? get appSettings => _appSettings;
  bool get loading => _loading;

  AppSettingsProvider() {
    fetchAppSettings();
  }

  Future<void> fetchAppSettings() async {
    _loading = true;
    notifyListeners();
    debugPrint("fetchAppSettings");
    try {
      final response = await http.get(Uri.parse(APPUrl.getAppSettings));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        _appSettings = AppSettings.fromJson(data);
      } else {
        throw Exception('Failed to load app settings');
      }
    } catch (error) {
      print("Error fetching app settings: $error");
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
