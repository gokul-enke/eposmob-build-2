import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/supplier.dart';
import '../resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupplierProvider with ChangeNotifier {
  List<Supplier>? _supplierList;
  List<Supplier>? _allSuppliers = []; // Store all suppliers for local filtering
  bool _isLoading = false;
  Supplier? _selectedSupplier;
  String? _selectedSupplierName; // For supplier transaction report
  String? _selectedSupplierId; // String id for report/details linkage

  // Pagination properties
  int _currentPage = 1;
  int _totalPages = 1;
  int _itemsPerPage = 20;
  String? _filterName;
  String? _filterEmail;
  String? _filterPhone;
  String? _filterBalance;

  List<Supplier>? get supplierList => _supplierList;
  List<Supplier>? get allSuppliers => _allSuppliers; // Getter for all suppliers
  bool get isLoading => _isLoading;
  Supplier? get selectedSupplier => _selectedSupplier;
  String? get selectedSupplierName => _selectedSupplierName;
  String? get selectedSupplierId => _selectedSupplierId;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get itemsPerPage => _itemsPerPage;

  // Default constructor
  SupplierProvider() {
    _supplierList = [];
    _allSuppliers = [];
  }

  // Select a supplier
  void selectSupplier(Supplier supplier) {
    _selectedSupplier = supplier;
    notifyListeners();
  }

  // Clear selected supplier
  void clearSelectedSupplier() {
    _selectedSupplier = null;
    notifyListeners();
  }

  // Set selected supplier name for transaction report
  void setSelectedSupplierName(String supplierName) {
    _selectedSupplierName = supplierName;
    notifyListeners();
  }

  // Clear selected supplier name
  void clearSelectedSupplierName() {
    _selectedSupplierName = null;
    notifyListeners();
  }

  // Set selected supplier id for transaction report/details
  void setSelectedSupplierId(String? supplierId) {
    _selectedSupplierId = supplierId;
    notifyListeners();
  }

  void clearSelectedSupplierId() {
    _selectedSupplierId = null;
    notifyListeners();
  }

  /// Clears in-memory supplier cache for offline data management.
  void clearCachedSuppliers() {
    _supplierList = [];
    _allSuppliers = [];
    _currentPage = 1;
    _totalPages = 1;
    _filterName = null;
    _filterEmail = null;
    _filterPhone = null;
    _filterBalance = null;
    notifyListeners();
    debugPrint('Cleared cached suppliers');
  }

  // Apply local pagination and filtering
  void applyFiltersLocally({
    String? supplierName,
    String? supplierEmail,
    String? supplierPhone,
    String? filterBalance,
    int page = 1,
  }) {
    if (_allSuppliers == null || _allSuppliers!.isEmpty) {
      _supplierList = [];
      _currentPage = 1;
      _totalPages = 1;
      notifyListeners();
      return;
    }

    // Save filter values
    _filterName = supplierName;
    _filterEmail = supplierEmail;
    _filterPhone = supplierPhone;
    _filterBalance = filterBalance;
    _currentPage = page;

    // Apply filters
    List<Supplier> filteredList = [..._allSuppliers!];

    if (supplierName != null && supplierName.isNotEmpty) {
      filteredList = filteredList
          .where((supplier) =>
              supplier.name.toLowerCase().contains(supplierName.toLowerCase()))
          .toList();
    }
    //Email filter
    if (supplierEmail != null && supplierEmail.isNotEmpty) {
      filteredList = filteredList
          .where((supplier) => supplier.email
              .toLowerCase()
              .contains(supplierEmail.toLowerCase()))
          .toList();
    }

    //phone filter
    if (supplierPhone != null && supplierPhone.isNotEmpty) {
      filteredList = filteredList
          .where((supplier) => supplier.phone
              .toLowerCase()
              .contains(supplierPhone.toLowerCase()))
          .toList();
    }

    // Apply balance filter
    if (filterBalance != null && filterBalance.isNotEmpty) {
      filteredList = filteredList.where((supplier) {
        double balance = supplier.currentBalance;

        switch (filterBalance) {
          case 'Positive (+ve)':
            return balance > 0;
          case 'Negative (-ve)':
            return balance < 0;
          case 'Zero (0)':
            return balance == 0;
          default:
            return true; // 'All' or any other value
        }
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
      _supplierList = [];
    } else {
      endIndex =
          endIndex > filteredList.length ? filteredList.length : endIndex;
      _supplierList = filteredList.sublist(startIndex, endIndex);
    }

    notifyListeners();
  }

  // Reset filters and pagination
  void resetFilters() {
    _filterName = null;
    _filterEmail = null;
    _filterPhone = null;
    _filterBalance = null;
    _currentPage = 1;

    if (_allSuppliers != null && _allSuppliers!.isNotEmpty) {
      // Apply pagination without any filters to show all suppliers
      _supplierList = [];

      List<Supplier> filteredList = [..._allSuppliers!];

      // Calculate pagination
      _totalPages = (filteredList.length / _itemsPerPage).ceil();
      _totalPages = _totalPages == 0 ? 1 : _totalPages;

      // Apply pagination
      int startIndex = 0; // Start from first page
      int endIndex = startIndex + _itemsPerPage;

      if (startIndex >= filteredList.length) {
        _supplierList = [];
      } else {
        endIndex =
            endIndex > filteredList.length ? filteredList.length : endIndex;
        _supplierList = filteredList.sublist(startIndex, endIndex);
      }
    }

    notifyListeners();
  }

  // Change pagei

  void goToPage(int page) {
    if (page < 1 || page > _totalPages) return;

    applyFiltersLocally(
        supplierName: _filterName,
        supplierEmail: _filterEmail,
        supplierPhone: _filterPhone,
        filterBalance: _filterBalance,
        page: page);
  }

  // Fetch all suppliers from API
  Future<List<Supplier>?> fetchSuppliers({
    required String accessToken,
    String? supplierName,
  }) async {
    _isLoading = true;
    notifyListeners();

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    final Map<String, String> queryParameters = {};
    if (supplierName != null && supplierName.isNotEmpty) {
      queryParameters['supplier_name'] = supplierName;
    }
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse(APPUrl.getSuppliers).replace(queryParameters: queryParameters);

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
      );

      debugPrint('Supplier API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        SupplierResponse supplierResponse = SupplierResponse.fromJson(jsonData);

        // Store all suppliers for local filtering and pagination
        _allSuppliers = supplierResponse.data;
        applyFiltersLocally(supplierName: supplierName);

        debugPrint('Fetched ${_allSuppliers?.length ?? 0} suppliers');

        _isLoading = false;
        notifyListeners();
        return _supplierList;
      } else {
        debugPrint('Error fetching suppliers: ${response.body}');
        _isLoading = false;
        notifyListeners();
        return [];
      }
    } catch (e) {
      debugPrint('Exception in fetchSuppliers: $e');
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  // Fetch filtered supplier transactions from API
  Future<Map<String, dynamic>> fetchSupplierTransactions({
    required String accessToken,
    String? supplierName,
    String? supplierId,
    String? transactionType,
    String? fromDate,
    String? toDate,
    bool listAll = true,
    int? page,
  }) async {
    _isLoading = true;
    notifyListeners();

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    // Build URL with query parameters
    final Map<String, String> queryParameters = {};
    if (supplierName != null && supplierName.isNotEmpty) {
      queryParameters['supplier_name'] = supplierName;
    }
    if (supplierId != null && supplierId.isNotEmpty) {
      queryParameters['supplier_id'] = supplierId;
    }
    if (transactionType != null && transactionType.isNotEmpty) {
      // SupplierController expects the transaction type in the `type` query key.
      queryParameters['type'] = transactionType;
    }
    if (fromDate != null && fromDate.isNotEmpty) {
      queryParameters['from_date'] = fromDate;
    }
    if (toDate != null && toDate.isNotEmpty) {
      queryParameters['to_date'] = toDate;
    }
    queryParameters['list_all'] = listAll.toString();
    if (page != null && page > 0) {
      queryParameters['page'] = page.toString();
    }
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }

    final url = Uri.parse(APPUrl.supplierTransactions).replace(queryParameters: queryParameters);

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
      );

      debugPrint(
          'Supplier Transactions API Response status: ${response.statusCode}');
      debugPrint('Supplier Transactions API URL: $url');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        _isLoading = false;
        notifyListeners();
        return jsonData;
      } else {
        debugPrint('Error fetching supplier transactions: ${response.body}');
        _isLoading = false;
        notifyListeners();
        throw Exception('Failed to load supplier transactions');
      }
    } catch (e) {
      debugPrint('Exception in fetchSupplierTransactions: $e');
      _isLoading = false;
      notifyListeners();
      throw e;
    }
  }

  // Add a new supplier
  Future<Map<String, dynamic>> addSupplier({
    required String name,
    required String email,
    required String phone,
    required String accessToken,
    required String balance,
    required String paymentStatus, // "to_pay" or "to_receive"
    required String address,
    required String altPhone,
    required List<int> productCategories,
  }) async {
    _isLoading = true;
    notifyListeners();

    final Map<String, dynamic> apiBodyData = {
      'name': name,
      'email': email,
      'phone': phone,
      'balance': double.tryParse(balance) ?? 0.0, // ✅ send number not string
      'type': 1,
      'address': address,
      'alt_phone': altPhone,
      'payment_type': paymentStatus,
      // 'product_categories': productCategories,
    };

    final url = Uri.parse(APPUrl.addSupplier);

    debugPrint('Add Supplier API Body: ${json.encode(apiBodyData)}');
    debugPrint('Add Supplier API URL: $url');

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final response = await http.post(
        url,
        body: json.encode(apiBodyData),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
      );

      _isLoading = false;
      notifyListeners();

      debugPrint('Add Supplier API Response status: ${response.statusCode}');
      debugPrint('Add Supplier API Response body: ${response.body}');
      debugPrint(
          'Add Supplier API Response body type: ${response.body.runtimeType}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Refresh supplier list after adding
        await fetchSuppliers(accessToken: accessToken);
        final jsonResponse = json.decode(response.body);
        return Map<String, dynamic>.from(jsonResponse);
      } else {
        // Handle non-200 status codes
        try {
          final errorResponse = json.decode(response.body);
          final safeErrorResponse = Map<String, dynamic>.from(errorResponse);
          return {
            'status': 'error',
            'message': safeErrorResponse['message'] ?? 'Failed to add supplier',
            'errors': safeErrorResponse['data'] ?? {},
          };
        } catch (jsonError) {
          // If response body is not valid JSON (e.g., HTML error page)
          debugPrint('JSON parsing error: $jsonError');
          return {
            'status': 'error',
            'message':
                'Server error (Status: ${response.statusCode}). Please check your network connection and try again.',
            'errors': {},
          };
        }
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Network/Exception error: $e');
      return {
        'status': 'error',
        'message':
            'Network error: Please check your internet connection and try again.'
      };
    }
  }

  Future<Map<String, dynamic>> updateSupplier({
    required int id,
    required String name,
    required String phone,
    required String accessToken,
    required double balance,
    String? email,
    String? address,
    String? altPhone,
    String? paymentStatus,
    String? productCategories,
  }) async {
    _isLoading = true;
    notifyListeners();

    final Map<String, dynamic> apiBodyData = {
      'id': id,
      'name': name,
      'phone': phone,
      'balance': balance,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      if (altPhone != null) 'alt_phone': altPhone,
      if (paymentStatus != null) 'payment_type': paymentStatus,
      if (productCategories != null) 'product_categories': productCategories,
    };

    final url = Uri.parse(APPUrl.updateSupplier);

    debugPrint('Update Supplier API Body: ${json.encode(apiBodyData)}');
    debugPrint('Update Supplier API URL: $url');

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final response = await http.post(
        url,
        body: json.encode(apiBodyData),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
      );

      _isLoading = false;
      notifyListeners();

      debugPrint('Update Supplier API Response status: ${response.statusCode}');
      debugPrint('Update Supplier API Response body: ${response.body}');

      if (response.statusCode == 200) {
        await fetchSuppliers(accessToken: accessToken);
        final jsonResponse = json.decode(response.body);
        return Map<String, dynamic>.from(jsonResponse);
      } else {
        try {
          final errorResponse = json.decode(response.body);
          final safeErrorResponse = Map<String, dynamic>.from(errorResponse);
          return {
            'status': 'error',
            'message':
                safeErrorResponse['message'] ?? 'Failed to update supplier',
            'errors': safeErrorResponse['data'] ?? {},
          };
        } catch (jsonError) {
          debugPrint('JSON parsing error: $jsonError');
          return {
            'status': 'error',
            'message':
                'Server error (Status: ${response.statusCode}). Please check your network connection and try again.',
            'errors': {},
          };
        }
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Network/Exception error: $e');
      return {
        'status': 'error',
        'message':
            'Network error: Please check your internet connection and try again.'
      };
    }
  }
}
