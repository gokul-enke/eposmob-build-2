import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MasterDataProvider with ChangeNotifier {
  MasterData? _masterData;
  bool _isLoading = false;
  String? _error;

  MasterData? get masterData => _masterData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<MasterData?> fetchMasterData(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      _error = "API key not found. Please restart the app.";
      _isLoading = false;
      notifyListeners();
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final url = Uri.parse('${APPUrl.getMasterDataValues}?code=$code');
      debugPrint('🔄 Fetching master data for code: $code');
      debugPrint('📡 URL: $url');

      final response = await http.get(url, headers: {
        'X-Tenant': apiKey,
      });

      debugPrint('📊 Response status: ${response.statusCode}');
      debugPrint('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 'success') {
          _masterData = MasterData.fromJson(data);
          debugPrint('✅ Master data fetched successfully for code: $code');
          debugPrint('📋 Data keys: ${_masterData?.data.keys.toList()}');
          return _masterData;
        } else {
          _error = data['message'] ?? 'Failed to fetch master data';
          debugPrint('❌ API returned error: $_error');
          throw Exception(_error);
        }
      } else {
        _error = 'HTTP ${response.statusCode}: Failed to fetch master data';
        debugPrint('❌ HTTP Error: $_error');
        throw Exception(_error);
      }
    } catch (error) {
      _error = 'Error fetching master data: $error';
      debugPrint('💥 Exception: $_error');
      throw Exception(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear current data
  void clearData() {
    _masterData = null;
    _error = null;
    notifyListeners();
  }
}
