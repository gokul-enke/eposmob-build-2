import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/sales_executive.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SalesExecutiveProvider extends ChangeNotifier {
  List<SalesExecutive> _salesExecutives = [];
  bool _isLoading = false;
  String? _error;

  List<SalesExecutive> get salesExecutives => _salesExecutives;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get the current user from the list of sales executives
  SalesExecutive? getCurrentUser(BuildContext context) {
    debugPrint("🔧 SalesExecutiveProvider: getCurrentUser called");
    
    final authModel = Provider.of<AuthModel>(context, listen: false);
    final userId = authModel.userId;
    
    debugPrint("🔧 SalesExecutiveProvider: authModel.userId = $userId");
    debugPrint("🔧 SalesExecutiveProvider: authModel.token = ${authModel.token != null ? 'exists' : 'null'}");
    debugPrint("🔧 SalesExecutiveProvider: _salesExecutives.length = ${_salesExecutives.length}");
    
    if (_salesExecutives.isNotEmpty) {
      debugPrint("🔧 SalesExecutiveProvider: Available executives:");
      for (var exec in _salesExecutives) {
        debugPrint("   - ID: ${exec.id}, Name: ${exec.name}, Email: ${exec.email ?? 'null'}");
      }
    }
    
    if (userId == null) {
      debugPrint("❌ SalesExecutiveProvider: userId is null, returning null");
      return null;
    }
    
    try {
      final executive = _salesExecutives.firstWhere((executive) => executive.id == userId);
      debugPrint("✅ SalesExecutiveProvider: Found current user: ${executive.name} (ID: ${executive.id})");
      return executive;
    } catch (e) {
      debugPrint("❌ SalesExecutiveProvider: No executive found with userId $userId. Error: $e");
      return null;
    }
  }

  // Fetch sales executives from the API
  Future<void> fetchSalesExecutives(BuildContext context) async {
    debugPrint("🔧 SalesExecutiveProvider: fetchSalesExecutives started");
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final token = authModel.token;
      
      debugPrint("🔧 SalesExecutiveProvider: Auth token exists: ${token != null}");
      debugPrint("🔧 SalesExecutiveProvider: API URL: ${APPUrl.listSalesExecutives}");
      
      if (token == null) {
        debugPrint("❌ SalesExecutiveProvider: No auth token available");
        _error = 'Not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      debugPrint("🔧 SalesExecutiveProvider: Making API request...");
      // Get API key from SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found. Please restart the app.");
      }
      final response = await http.get(
        Uri.parse(APPUrl.listSalesExecutives),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'X-Tenant': apiKey,
        },
      );

      debugPrint("🔧 SalesExecutiveProvider: API response status: ${response.statusCode}");
      debugPrint("🔧 SalesExecutiveProvider: API response body: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['status'] == 'success') {
          final List<dynamic> executivesData = data['data'];
          _salesExecutives = executivesData
              .map((json) => SalesExecutive.fromJson(json))
              .toList();
          debugPrint("✅ SalesExecutiveProvider: Successfully loaded ${_salesExecutives.length} executives");
          
          for (var exec in _salesExecutives) {
            debugPrint("   - Loaded executive: ID=${exec.id}, Name=${exec.name}, Email=${exec.email ?? 'null'}");
          }
        } else {
          _error = data['message'] ?? 'Failed to fetch sales executives';
          debugPrint("❌ SalesExecutiveProvider: API returned error: $_error");
        }
      } else {
        _error = 'Failed to fetch sales executives: ${response.statusCode}';
        debugPrint("❌ SalesExecutiveProvider: HTTP error: $_error");
      }
    } catch (e) {
      _error = 'Error: $e';
      debugPrint("❌ SalesExecutiveProvider: Exception occurred: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
      debugPrint("🔧 SalesExecutiveProvider: fetchSalesExecutives completed");
    }
  }

  // Switch to a different sales executive
  Future<bool> switchToExecutive(BuildContext context, int executiveId) async {
    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final token = authModel.token;
      
      if (token == null) {
        _error = 'Not authenticated';
        return false;
      }

      // Find the executive to switch to
      final executive = _salesExecutives.firstWhere(
        (exec) => exec.id == executiveId,
        orElse: () => throw Exception('Executive not found'),
      );

      // Update the auth model with the new user ID
      authModel.login(token, executiveId);
      
      return true;
    } catch (e) {
      _error = 'Error switching executive: $e';
      return false;
    }
  }
} 