import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Add this for HTTP requests
import 'package:pos_machine/models/get_faq.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FaqProvider with ChangeNotifier {
  List<FaqData>? _faqList;
  bool _isLoading = false;

  List<FaqData>? get faqList => _faqList;
  bool get isLoading => _isLoading;

  Future<void> fetchFaqData() async {
    _isLoading = true;
    notifyListeners(); // Notify listeners about the loading state
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final url = Uri.parse(APPUrl.listFaqs);

      final response = await http.get(url, headers: {
        'X-Tenant': apiKey,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        FaqModel faqModel = FaqModel.fromJson(jsonResponse);
        _faqList = faqModel.data;
      } else {
        _faqList = [];
      }
    } catch (error) {
      debugPrint('Error fetching FAQs: $error');
      _faqList = []; // Reset the list on error
    } finally {
      _isLoading = false;
      notifyListeners(); // Notify listeners after data is fetched
    }
  }
}
