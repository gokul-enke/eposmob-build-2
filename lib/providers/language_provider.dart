import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/language.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  /// Language codes returned by the API that must never reach the UI.
  /// `en_ar` ("English + Arabic") is a composite entry used server-side only.
  static const Set<String> hiddenLanguageCodes = {'en_ar'};

  static bool _isHidden(Language language) =>
      hiddenLanguageCodes.contains(language.code.toLowerCase().trim());

  List<Language> _languages = [];
  bool _isLoading = false;
  String? _error;

  List<Language> get languages => _languages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchLanguages({required String accessToken}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');
      final int? activeStoreId = prefs.getInt('active_store_id');

      final Map<String, String> queryParameters = {};
      if (activeStoreId != null) {
        queryParameters['store_id'] = activeStoreId.toString();
      }
      final url = Uri.parse(APPUrl.listLanguages).replace(queryParameters: queryParameters);

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found. Please restart the app.");
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      };

      if (accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }

      final response = await http.get(url, headers: headers);
      debugPrint('Languages API status: ${response.statusCode}');
      debugPrint('Languages API body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] is List) {
          final List<dynamic> rawList = data['data'];
          _languages = rawList
              .map((item) => Language.fromJson(item as Map<String, dynamic>))
              .where((language) => !_isHidden(language))
              .toList();
        } else {
          _error = data['message']?.toString() ?? 'Failed to load languages';
        }
      } else {
        _error = 'Failed to load languages: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Failed to load languages: $e';
      debugPrint('LanguageProvider error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> translateText({
    required String accessToken,
    required String targetLang,
    required String text,
  }) async {
    try {
      final url = Uri.parse(APPUrl.translateText);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found. Please restart the app.");
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      };

      if (accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({
          'target_lang': targetLang,
          'text': text,
        }),
      );

      debugPrint('Translate API status: ${response.statusCode}');
      debugPrint('Translate API body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] is Map<String, dynamic>) {
          final translated = data['data']['translated_text'];
          return translated?.toString();
        }
      }
      return null;
    } catch (e) {
      debugPrint('Translate error: $e');
      return null;
    }
  }
}
