import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/company_accounts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../resources/app_url.dart';

class CompanyAccountProvider extends ChangeNotifier {
  List<CompanyAccountsData>? companyAccountsList = [];
  List<CompanyAccountsData>? _allCompanyAccounts =
      []; // Store all accounts for local filtering
  CompanyAccountsData? selectedCompanyAccount;

  // Pagination properties
  int _currentPage = 1;
  int _totalPages = 1;
  int _itemsPerPage = 20;
  String? _filterName;
  String? _filterType;
  String? _filterPaymentMethod;
  String? _filterStatus;
  bool _isLoading = false;

  // Getters
  List<CompanyAccountsData>? get getCompanyAccountsList => companyAccountsList;
  CompanyAccountsData? get getSelectedCompanyAccount => selectedCompanyAccount;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get itemsPerPage => _itemsPerPage;
  bool get isLoading => _isLoading;

  // Select a company account
  void selectCompanyAccount(CompanyAccountsData account) {
    selectedCompanyAccount = account;
    notifyListeners();
  }

  // Apply local pagination and filtering
  void applyFiltersLocally({
    String? filterName,
    String? filterType,
    String? filterPaymentMethod,
    String? filterStatus,
    int page = 1,
  }) {
    debugPrint('🔍 applyFiltersLocally called with page: $page');
    debugPrint(
        '🔍 _allCompanyAccounts length: ${_allCompanyAccounts?.length ?? 0}');

    if (_allCompanyAccounts == null || _allCompanyAccounts!.isEmpty) {
      debugPrint('⚠️ _allCompanyAccounts is null or empty');
      companyAccountsList = [];
      _currentPage = 1;
      _totalPages = 1;
      notifyListeners();
      return;
    }

    // Save filter values
    _filterName = filterName;
    _filterType = filterType;
    _filterPaymentMethod = filterPaymentMethod;
    _filterStatus = filterStatus;
    _currentPage = page;

    // Apply filters
    List<CompanyAccountsData> filteredList = [..._allCompanyAccounts!];

    if (filterName != null && filterName.isNotEmpty) {
      filteredList = filteredList
          .where((account) =>
              account.name != null &&
              account.name!.toLowerCase().contains(filterName.toLowerCase()))
          .toList();
    }

    if (filterType != null && filterType.isNotEmpty && filterType != 'All') {
      filteredList = filteredList
          .where((account) =>
              account.type != null &&
              account.type!.toLowerCase() == filterType.toLowerCase())
          .toList();
    }

    if (filterPaymentMethod != null &&
        filterPaymentMethod.isNotEmpty &&
        filterPaymentMethod != 'All') {
      filteredList = filteredList
          .where((account) => account.hasPaymentMethod(filterPaymentMethod))
          .toList();
    }

    // Apply status filter
    if (filterStatus != null &&
        filterStatus.isNotEmpty &&
        filterStatus != 'All') {
      filteredList = filteredList.where((account) {
        String accountStatus = account.accountStatus;
        return accountStatus.toLowerCase() == filterStatus.toLowerCase();
      }).toList();
    }

    // Calculate pagination
    _totalPages = (filteredList.length / _itemsPerPage).ceil();
    _totalPages = _totalPages == 0 ? 1 : _totalPages;

    // Ensure current page is valid
    if (_currentPage > _totalPages) {
      _currentPage = _totalPages;
    }

    // Apply pagination
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;

    if (startIndex >= filteredList.length) {
      companyAccountsList = [];
    } else {
      endIndex =
          endIndex > filteredList.length ? filteredList.length : endIndex;
      companyAccountsList = filteredList.sublist(startIndex, endIndex);
    }

    debugPrint(
        '🔍 Final companyAccountsList length: ${companyAccountsList?.length ?? 0}');
    debugPrint('🔍 Current page: $_currentPage, Total pages: $_totalPages');

    notifyListeners();
  }

  // Reset filters and pagination
  void resetFilters() {
    _filterName = null;
    _filterType = null;
    _filterPaymentMethod = null;
    _filterStatus = null;
    _currentPage = 1;

    if (_allCompanyAccounts != null && _allCompanyAccounts!.isNotEmpty) {
      applyFiltersLocally(page: 1);
    }
  }

  // Change page
  void goToPage(int page) {
    if (page < 1 || page > _totalPages) return;

    applyFiltersLocally(
      filterName: _filterName,
      filterType: _filterType,
      filterPaymentMethod: _filterPaymentMethod,
      filterStatus: _filterStatus,
      page: page,
    );
  }

  //                 *********************** LIST COMPANY ACCOUNTS API ***************************************************

  Future<dynamic> listCompanyAccounts({
    required String accessToken,
    String? filterName,
    String? filterType,
    String? filterPaymentMethod,
    String? filterStatus,
    bool sortAscending = false,
    int page = 1,
    bool loadAll = false, // Add parameter to load all accounts
  }) async {
    _isLoading = true;
    notifyListeners();

    debugPrint("listCompanyAccounts API called");

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      _isLoading = false;
      notifyListeners();
      throw const HttpException("API key not found. Please restart the app.");
    }

    final queryParameters = <String, String>{
      'page': page.toString(),
      if (sortAscending) 'sort_asc': 'true',
      // If loadAll is true, request a large page size to get all accounts
      if (loadAll) 'per_page': '1000',
    };

    if (filterName != null && filterName.isNotEmpty) {
      queryParameters['filter_name'] = filterName;
    }
    if (filterType != null && filterType.isNotEmpty) {
      queryParameters['filter_type'] = filterType;
    }
    if (filterPaymentMethod != null && filterPaymentMethod.isNotEmpty) {
      queryParameters['filter_payment_method'] = filterPaymentMethod;
    }
    if (filterStatus != null && filterStatus.isNotEmpty) {
      queryParameters['filter_status'] = filterStatus;
    }

    final url = Uri.parse(APPUrl.getCompanyaccounts)
        .replace(queryParameters: queryParameters);

    try {
      debugPrint("Making API call to ${url.toString()}");
      debugPrint("Query Parameters: $queryParameters");
      debugPrint(
          "Using token: ${accessToken.substring(0, min(accessToken.length, 10))}...");

      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      });

      debugPrint('API response status code: ${response.statusCode}');
      debugPrint(
          'API response body: ${response.body.substring(0, min(response.body.length, 100))}...');

      if (response.statusCode == 200) {
        try {
          debugPrint('✅ API call successful - parsing response...');
          final jsonData = json.decode(response.body);
          debugPrint('📊 Full JSON response: ${jsonData.toString()}');
          debugPrint('📊 Response keys: ${jsonData.keys.toList()}');
          debugPrint('📊 Status: ${jsonData['status']}');
          debugPrint('📊 Message: ${jsonData['message']}');
          debugPrint('📊 Data: ${jsonData['data']}');

          CompanyAccountsModel companyAccountsModel =
              CompanyAccountsModel.fromJson(jsonData);

          debugPrint('🔍 Model parsed successfully');
          debugPrint(
              '🔍 Model data length: ${companyAccountsModel.data?.length ?? 0}');

          if (loadAll) {
            // Store all accounts for local filtering and pagination
            _allCompanyAccounts = companyAccountsModel.data;
            debugPrint(
                '💾 Stored ${_allCompanyAccounts?.length ?? 0} accounts in _allCompanyAccounts');
            applyFiltersLocally(page: 1);
          } else {
            companyAccountsList = companyAccountsModel.data;
            debugPrint(
                '📋 Set companyAccountsList to ${companyAccountsList?.length ?? 0} accounts');
            notifyListeners();
          }

          _isLoading = false;
          notifyListeners();
          return jsonData;
        } catch (parseError) {
          debugPrint('JSON parsing error: $parseError');
          _isLoading = false;
          notifyListeners();
          return {
            "status": "error",
            "message": "Failed to parse response data: $parseError",
          };
        }
      } else {
        debugPrint('Error in API response: ${response.reasonPhrase}');
        _isLoading = false;
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
                  "Failed to load company accounts: ${response.reasonPhrase}",
            };
          }
        } else {
          return {
            "status": "error",
            "message":
                "Failed to load company accounts: ${response.reasonPhrase}",
          };
        }
      }
    } catch (error) {
      debugPrint('Exception in listCompanyAccounts: $error');
      _isLoading = false;
      notifyListeners();
      return {
        "status": "error",
        "message": "Error: $error",
      };
    }
  }

  // Load all company accounts for local filtering
  Future<void> loadAllCompanyAccounts(String accessToken) async {
    await listCompanyAccounts(
      accessToken: accessToken,
      loadAll: true,
    );
  }

  // Clear all data
  void clearData() {
    companyAccountsList = [];
    _allCompanyAccounts = [];
    selectedCompanyAccount = null;
    resetFilters();
    notifyListeners();
  }
}
