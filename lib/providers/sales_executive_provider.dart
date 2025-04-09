import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/sales_executive.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:provider/provider.dart';

class SalesExecutiveProvider extends ChangeNotifier {
  List<SalesExecutive> _salesExecutives = [];
  bool _isLoading = false;
  String? _error;

  List<SalesExecutive> get salesExecutives => _salesExecutives;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get the current user from the list of sales executives
  SalesExecutive? getCurrentUser(BuildContext context) {
    final authModel = Provider.of<AuthModel>(context, listen: false);
    final userId = authModel.userId;
    
    if (userId == null) return null;
    
    try {
      return _salesExecutives.firstWhere((executive) => executive.id == userId);
    } catch (e) {
      return null;
    }
  }

  // Fetch sales executives from the API
  Future<void> fetchSalesExecutives(BuildContext context) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final token = authModel.token;
      
      if (token == null) {
        _error = 'Not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse(APPUrl.listSalesExecutives),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['status'] == 'success') {
          final List<dynamic> executivesData = data['data'];
          _salesExecutives = executivesData
              .map((json) => SalesExecutive.fromJson(json))
              .toList();
        } else {
          _error = data['message'] ?? 'Failed to fetch sales executives';
        }
      } else {
        _error = 'Failed to fetch sales executives: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
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