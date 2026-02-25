import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/sales_executive.dart';
import 'package:pos_machine/models/sales_executive_report.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SalesExecutiveProvider extends ChangeNotifier {
  List<SalesExecutive> _salesExecutives = [];
  bool _isLoading = false;
  String? _error;

  // Sales Executive Report state variables
  List<SalesExecutiveReportData> _salesExecutiveReportList = [];
  bool _isReportLoading = false;
  String? _reportError;

  List<SalesExecutive> get salesExecutives => _salesExecutives;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Sales Executive Report getters
  List<SalesExecutiveReportData> get salesExecutiveReportList =>
      _salesExecutiveReportList;
  bool get isReportLoading => _isReportLoading;
  String? get reportError => _reportError;

  // Get the current user from the list of sales executives
  SalesExecutive? getCurrentUser(BuildContext context) {
    debugPrint("🔧 SalesExecutiveProvider: getCurrentUser called");

    final authModel = Provider.of<AuthModel>(context, listen: false);
    final userId = authModel.userId;

    debugPrint("🔧 SalesExecutiveProvider: authModel.userId = $userId");
    debugPrint(
        "🔧 SalesExecutiveProvider: authModel.token = ${authModel.token != null ? 'exists' : 'null'}");
    debugPrint(
        "🔧 SalesExecutiveProvider: _salesExecutives.length = ${_salesExecutives.length}");

    if (_salesExecutives.isNotEmpty) {
      debugPrint("🔧 SalesExecutiveProvider: Available executives:");
      for (var exec in _salesExecutives) {
        debugPrint(
            "   - ID: ${exec.id}, Name: ${exec.name}, Email: ${exec.email ?? 'null'}");
      }
    }

    if (userId == null) {
      debugPrint("❌ SalesExecutiveProvider: userId is null, returning null");
      return null;
    }

    try {
      final executive =
          _salesExecutives.firstWhere((executive) => executive.id == userId);
      debugPrint(
          "✅ SalesExecutiveProvider: Found current user: ${executive.name} (ID: ${executive.id})");
      return executive;
    } catch (e) {
      debugPrint(
          "❌ SalesExecutiveProvider: No executive found with userId $userId. Error: $e");
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

      debugPrint(
          "🔧 SalesExecutiveProvider: Auth token exists: ${token != null}");
      debugPrint(
          "🔧 SalesExecutiveProvider: API URL: ${APPUrl.listSalesExecutives}");

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
      final int? activeStoreId = prefs.getInt('active_store_id');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found. Please restart the app.");
      }

      final Map<String, String> queryParameters = {};
      if (activeStoreId != null) {
        queryParameters['store_id'] = activeStoreId.toString();
      }
      final url = Uri.parse(APPUrl.listSalesExecutives).replace(queryParameters: queryParameters);

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'X-Tenant': apiKey,
        },
      );

      debugPrint(
          "🔧 SalesExecutiveProvider: API response status: ${response.statusCode}");
      debugPrint(
          "🔧 SalesExecutiveProvider: API response body: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 'success') {
          final List<dynamic> executivesData = data['data'];
          _salesExecutives = executivesData
              .map((json) => SalesExecutive.fromJson(json))
              .toList();
          debugPrint(
              "✅ SalesExecutiveProvider: Successfully loaded ${_salesExecutives.length} executives");

          for (var exec in _salesExecutives) {
            debugPrint(
                "   - Loaded executive: ID=${exec.id}, Name=${exec.name}, Email=${exec.email ?? 'null'}");
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

  // Fetch sales executive report data
  Future<dynamic> getSalesExecutiveReport({
    required BuildContext context,
    String? fromDate,
    String? toDate,
  }) async {
    debugPrint("📊 SalesExecutiveProvider: getSalesExecutiveReport called");
    debugPrint("📊 From Date: $fromDate, To Date: $toDate");

    _isReportLoading = true;
    _reportError = null;
    notifyListeners();

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final token = authModel.token;

      debugPrint(
          "📊 SalesExecutiveProvider: Auth token exists: ${token != null}");

      if (token == null) {
        debugPrint("❌ SalesExecutiveProvider: No auth token available");
        _reportError = 'Not authenticated';
        _isReportLoading = false;
        notifyListeners();
        return {
          "status": "error",
          "message": "Not authenticated",
        };
      }

      // Build query parameters according to new format
      final queryParameters = <String, String>{};

      // Determine dateFilter mode
      final bool hasCustomDates =
          (fromDate != null && fromDate.isNotEmpty) ||
          (toDate != null && toDate.isNotEmpty);

      if (hasCustomDates) {
        queryParameters['dateFilter'] = 'custom';
        if (fromDate != null && fromDate.isNotEmpty) {
          queryParameters['dateFrom'] = fromDate; // YYYY-MM-DD
        }
        if (toDate != null && toDate.isNotEmpty) {
          queryParameters['dateTo'] = toDate; // YYYY-MM-DD
        }
      } else {
        // default filter
        queryParameters['dateFilter'] = 'today';
      }

      // Attach active store_id if available
      try {
        final storeProvider = Provider.of<StoreSessionProvider>(context, listen: false);
        final storeId = storeProvider.activeStore?.storeId;
        if (storeId != null) {
          queryParameters['store_id'] = storeId.toString();
        } else {
          // fallback to saved active_store_id
          final prefs = await SharedPreferences.getInstance();
          final int? savedStoreId = prefs.getInt('active_store_id');
          if (savedStoreId != null) {
            queryParameters['store_id'] = savedStoreId.toString();
          }
        }
      } catch (_) {
        // ignore if store provider not available
      }

      // Get API key from SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        _isReportLoading = false;
        notifyListeners();
        throw const HttpException("API key not found. Please restart the app.");
      }

      // Construct URL with query parameters
      final Uri url = Uri.parse(APPUrl.getSalesExecutiveReport).replace(
        queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
      );

      debugPrint("📊 Making API call to: ${url.toString()}");

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      );

      debugPrint('📊 API response status code: ${response.statusCode}');
      debugPrint(
          '📊 API response body preview: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          
          // Validate data structure before parsing
          if (jsonData is! Map<String, dynamic>) {
            throw FormatException('Response is not a valid JSON object');
          }
          
          if (jsonData['data'] != null && jsonData['data'] is! List) {
            throw FormatException('Data field is not a list');
          }
          
          SalesExecutiveReportModel reportModel =
              SalesExecutiveReportModel.fromJson(jsonData);

          _salesExecutiveReportList = reportModel.data ?? [];
          _isReportLoading = false;
          notifyListeners();

          debugPrint(
              "✅ Successfully loaded ${_salesExecutiveReportList.length} sales executive reports");

          return jsonData;
        } catch (parseError) {
          debugPrint('❌ JSON parsing error: $parseError');
          debugPrint('❌ Response body: ${response.body}');
          _reportError = 'Failed to parse response data: $parseError';
          _isReportLoading = false;
          notifyListeners();

          return {
            "status": "error",
            "message": "Failed to parse response data: $parseError",
          };
        }
      } else {
        debugPrint('❌ Error in API response: ${response.reasonPhrase}');
        _reportError =
            'Failed to load sales executive report: ${response.reasonPhrase}';
        _isReportLoading = false;
        notifyListeners();

        // Try to parse error response
        if (response.body.isNotEmpty) {
          try {
            final errorJson = json.decode(response.body);
            return errorJson;
          } catch (e) {
            return {
              "status": "error",
              "message":
                  "Failed to load sales executive report: ${response.reasonPhrase}",
            };
          }
        } else {
          return {
            "status": "error",
            "message":
                "Failed to load sales executive report: ${response.reasonPhrase}",
          };
        }
      }
    } catch (error) {
      debugPrint('❌ Exception in getSalesExecutiveReport: $error');
      _reportError = 'Error: $error';
      _isReportLoading = false;
      notifyListeners();

      return {
        "status": "error",
        "message": "Error: $error",
      };
    }
  }

  // Clear report data
  void clearReportData() {
    _salesExecutiveReportList = [];
    _reportError = null;
    notifyListeners();
  }
}
