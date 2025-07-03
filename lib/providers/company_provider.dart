import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Add this for HTTP requests
import 'package:pos_machine/models/get_faq.dart';
import 'package:pos_machine/resources/app_url.dart';

class FaqProvider with ChangeNotifier {
  List<FaqData>? _faqList;
  bool _isLoading = false;

  List<FaqData>? get faqList => _faqList;
  bool get isLoading => _isLoading;

  Future<void> fetchFaqData() async {
    _isLoading = true;
    notifyListeners(); // Notify listeners about the loading state

    try {
      final url = Uri.parse(APPUrl.listFaqs);

      final response = await http.get(url);

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
