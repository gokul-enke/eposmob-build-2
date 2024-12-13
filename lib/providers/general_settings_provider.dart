import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/get_general_settings.dart';
import 'dart:convert';

import 'package:pos_machine/resources/app_url.dart';

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

    try {
      final response = await http.get(Uri.parse(APPUrl.getGeneralSettings));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        _generalSettings = GeneralSettings.fromJson(data);
      } else {
        throw Exception('Failed to load general settings');
      }
    } catch (error) {
      print("Error fetching general settings: $error");
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
