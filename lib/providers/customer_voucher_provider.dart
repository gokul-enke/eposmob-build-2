import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/customer_voucher.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'dart:async';

class CustomerVoucherProvider extends ChangeNotifier {
  bool _isLoading = false;
  Object? loadError;
  int _loadGeneration = 0;
  List<CustomerVoucher>? _allVouchers;
  List<CustomerVoucher>? voucherListDetails;

  // Pagination properties
  int _currentPage = 1;
  int _totalPages = 1;
  int _itemsPerPage = 20;

  // Filter properties
  String? _filterCustomerName;
  String? _filterVoucherNumber;
  String? _filterType;
  String? _filterStatus;
  String? _filterDateFrom;
  String? _filterDateTo;
  String? _lastAccessToken;

  // Getters
  bool get isLoading => _isLoading;
  List<CustomerVoucher>? get allVouchers => _allVouchers;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get itemsPerPage => _itemsPerPage;

  // Status options
  List<String> getStatusOptions() {
    return ['All Status', 'paid', 'pending', 'cancelled'];
  }

  // Type options
  List<String> getTypeOptions() {
    return [
      'All Types',
      ...{
        'other',
        'refund',
        'adjustment',
        for (final v in _allVouchers ?? <CustomerVoucher>[])
          if (v.type.isNotEmpty) v.type
      }
    ];
  }

  // Pagination navigation
  void goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    applyFiltersLocally(
      filterCustomerName: _filterCustomerName,
      filterVoucherNumber: _filterVoucherNumber,
      filterType: _filterType,
      filterStatus: _filterStatus,
      page: page,
    );
  }

  // Apply filters
  void applyFilters({
    String? customerName,
    String? voucherNumber,
    String? type,
    String? status,
    String? dateFrom,
    String? dateTo,
    int page = 1,
  }) {
    final datesChanged = dateFrom != _filterDateFrom || dateTo != _filterDateTo;
    _filterCustomerName = customerName;
    _filterVoucherNumber = voucherNumber;
    _filterType = type;
    _filterStatus = status;
    _filterDateFrom = dateFrom;
    _filterDateTo = dateTo;
    _currentPage = page;

    if (datesChanged && _lastAccessToken != null) {
      listAllCustomerVouchers(accessToken: _lastAccessToken!);
    } else {
      applyFiltersLocally(
        filterCustomerName: customerName,
        filterVoucherNumber: voucherNumber,
        filterType: type,
        filterStatus: status,
        page: page,
      );
    }
  }

  // Reset filters
  void resetFilters() {
    _filterCustomerName = null;
    _filterVoucherNumber = null;
    _filterType = null;
    _filterStatus = null;
    _filterDateFrom = null;
    _filterDateTo = null;
    _currentPage = 1;
    if (_lastAccessToken != null) {
      listAllCustomerVouchers(accessToken: _lastAccessToken!);
    } else {
      applyFiltersLocally(page: 1);
    }
  }

  // Apply filters locally
  void applyFiltersLocally({
    String? filterCustomerName,
    String? filterVoucherNumber,
    String? filterType,
    String? filterStatus,
    int page = 1,
  }) {
    debugPrint(
        "applyFiltersLocally: filterCustomerName=$filterCustomerName, page=$page");
    debugPrint("_allVouchers: ${_allVouchers?.length ?? 0} vouchers");

    if (_allVouchers == null || _allVouchers!.isEmpty) {
      debugPrint("No vouchers available for filtering");
      voucherListDetails = [];
      _currentPage = 1;
      _totalPages = 1;
      notifyListeners();
      return;
    }

    final filteredVouchers = filterForExport(
        customerName: filterCustomerName,
        voucherNumber: filterVoucherNumber,
        type: filterType,
        status: filterStatus);

    // Update total pages
    _totalPages = (filteredVouchers.length / _itemsPerPage).ceil();
    _totalPages = _totalPages == 0 ? 1 : _totalPages;
    debugPrint(
        "Total pages: $_totalPages (${filteredVouchers.length} items / $_itemsPerPage per page)");

    // Adjust current page if it's out of bounds
    if (page > _totalPages) {
      _currentPage = _totalPages;
      debugPrint("Adjusted current page to $_currentPage (was $page)");
    } else {
      _currentPage = page;
      debugPrint("Set current page to $_currentPage");
    }

    // Paginate
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    debugPrint("Pagination: startIndex=$startIndex, endIndex=$endIndex");

    if (startIndex >= filteredVouchers.length) {
      debugPrint("Start index out of bounds, showing empty list");
      voucherListDetails = [];
    } else {
      endIndex = endIndex > filteredVouchers.length
          ? filteredVouchers.length
          : endIndex;
      debugPrint("Taking items $startIndex to $endIndex");
      voucherListDetails = filteredVouchers.sublist(startIndex, endIndex);
      debugPrint("Final list has ${voucherListDetails?.length ?? 0} vouchers");
    }

    notifyListeners();
  }

  List<CustomerVoucher> filterForExport(
      {String? customerName,
      String? voucherNumber,
      String? type,
      String? status}) {
    // Filter vouchers
    List<CustomerVoucher> filteredVouchers = [...?_allVouchers];
    debugPrint("Starting with ${filteredVouchers.length} vouchers");

    // Filter by customer name
    if (customerName != null && customerName.isNotEmpty) {
      filteredVouchers = filteredVouchers.where((voucher) {
        final bool matchesName = voucher.customer.user.name
            .toLowerCase()
            .contains(customerName.toLowerCase());
        return matchesName;
      }).toList();
      debugPrint(
          "After customer name filter: ${filteredVouchers.length} vouchers match '$customerName'");
    }

    // Filter by voucher number
    if (voucherNumber != null && voucherNumber.isNotEmpty) {
      filteredVouchers = filteredVouchers.where((voucher) {
        return voucher.voucherNumber
            .toLowerCase()
            .contains(voucherNumber.toLowerCase());
      }).toList();
      debugPrint(
          "After voucher number filter: ${filteredVouchers.length} vouchers match '$voucherNumber'");
    }

    // Filter by type
    if (type != null && type.isNotEmpty && type != 'All Types') {
      filteredVouchers = filteredVouchers.where((voucher) {
        return voucher.type.toLowerCase() == type.toLowerCase();
      }).toList();
      debugPrint(
          "After type filter: ${filteredVouchers.length} vouchers match '$type'");
    }

    // Filter by status
    if (status != null && status.isNotEmpty && status != 'All Status') {
      filteredVouchers = filteredVouchers.where((voucher) {
        return voucher.status.toLowerCase() == status.toLowerCase();
      }).toList();
      debugPrint(
          "After status filter: ${filteredVouchers.length} vouchers match '$status'");
    }

    return filteredVouchers;
  }

  // List all customer vouchers
  Future<void> listAllCustomerVouchers({
    required String accessToken,
  }) async {
    debugPrint("listAllCustomerVouchers called");
    final generation = ++_loadGeneration;
    loadError = null;
    _lastAccessToken = accessToken;
    _isLoading = true;
    notifyListeners();

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');
      final int? activeStoreId = prefs.getInt('active_store_id');

      final queryParams = {
        'page': '1',
        'per_page': '1000',
        if (_filterDateFrom != null && _filterDateFrom!.isNotEmpty)
          'date_from': _filterDateFrom!,
        if (_filterDateTo != null && _filterDateTo!.isNotEmpty)
          'date_to': _filterDateTo!,
      };
      if (activeStoreId != null) {
        queryParams['store_id'] = activeStoreId.toString();
      }

      final uri = Uri.parse(APPUrl.listCustomerVouchers)
          .replace(queryParameters: queryParams);
      debugPrint("Fetching vouchers from: $uri");

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found. Please restart the app.");
      }

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 30));

      if (generation != _loadGeneration) return;
      debugPrint("Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData is! Map<String, dynamic> ||
            jsonData['status'] != true ||
            jsonData['data'] is! List) {
          throw const FormatException('Invalid customer voucher response');
        }
        CustomerVoucherModel customerVoucherModel =
            CustomerVoucherModel.fromJson(jsonData);

        _allVouchers = customerVoucherModel.data;
        debugPrint("Loaded ${_allVouchers?.length ?? 0} vouchers");

        // Apply initial filters
        applyFiltersLocally(
          filterCustomerName: _filterCustomerName,
          filterVoucherNumber: _filterVoucherNumber,
          filterType: _filterType,
          filterStatus: _filterStatus,
          page: 1,
        );
      } else {
        debugPrint("Error: ${response.statusCode} - ${response.body}");
        throw HttpException("Unable to load vouchers (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("Exception: $e");
      if (generation == _loadGeneration) loadError = e;
    } finally {
      if (generation == _loadGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // Create voucher
  Future<Map<String, dynamic>> createVoucher({
    required String type,
    required double amount,
    required String voucherDate,
    required String dueDate,
    required String status,
    required int? paymentMethodId,
    required int customerId,
    required List<Map<String, dynamic>> voucherItems,
    required String accessToken,
  }) async {
    _isLoading = true;
    notifyListeners();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final body = {
        'type': type,
        'amount': amount,
        'voucher_date': voucherDate,
        'due_date': dueDate,
        'status': status,
        'payment_method': paymentMethodId,
        'customer_id': customerId,
        'voucher_items': voucherItems,
      };

      debugPrint("=== CREATE CUSTOMER VOUCHER API REQUEST ===");
      debugPrint("URL: ${APPUrl.createCustomerVoucher}");
      debugPrint("Request Body:");
      debugPrint(const JsonEncoder.withIndent('  ').convert(body));

      final response = await http.post(
        Uri.parse(APPUrl.createCustomerVoucher),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      debugPrint("Response status: ${response.statusCode}");
      debugPrint("Response body: ${response.body}");

      final jsonData = json.decode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Refresh the voucher list
        await listAllCustomerVouchers(accessToken: accessToken);
        return {
          'success': true,
          'message': jsonData['message'] ?? 'Voucher created successfully',
          'data': jsonData['data'],
        };
      } else {
        return {
          'success': false,
          'message': jsonData['message'] ?? 'Failed to create voucher',
          'errors': jsonData['errors'],
        };
      }
    } catch (e) {
      debugPrint("Exception: $e");
      return {
        'success': false,
        'message': 'Error creating voucher: $e',
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  //          *********************** ZATCA PHASE 2 VOUCHER PRINT ***************************************************
  Future<dynamic> zatcaPhase2VoucherPrint({
    required int id,
    required String accessToken,
  }) async {
    final uri = Uri.parse(APPUrl.zatcaPhase2VoucherPrint);

    debugPrint('[ZATCA][Provider] Phase2 Voucher Print URL: $uri');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final headers = {
        'Authorization':
            'Bearer ${accessToken.length > 10 ? accessToken.substring(0, 6) + '...' : '***'}',
        'X-Tenant': apiKey,
      };
      debugPrint('[ZATCA][Provider] Headers: $headers');
      debugPrint('[ZATCA][Provider] Body: {id: $id} (POST)');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
        body: {'id': id.toString()},
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        try {
          return json.decode(response.body);
        } catch (_) {
          return response.body;
        }
      } else {
        debugPrint(
            '[ZATCA][Provider] HTTP ${response.statusCode}: ${response.body}');
        return {
          'status': 'error',
          'message': 'Failed with status ${response.statusCode}'
        };
      }
    } on TimeoutException catch (_) {
      debugPrint('[ZATCA][Provider] ERROR: Request timed out');
      return {'status': 'error', 'message': 'Request timed out'};
    } catch (e) {
      debugPrint('[ZATCA][Provider] EXCEPTION: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  //          *********************** ZATCA PHASE 2 VOUCHER RESYNC ***************************************************
  Future<dynamic> zatcaPhase2VoucherResync({
    required int id,
    required String accessToken,
  }) async {
    final uri = Uri.parse(APPUrl.zatcaPhase2VoucherResync);

    debugPrint('[ZATCA][Provider] Phase2 Voucher Resync URL: $uri');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final maskedHeaders = {
        'Authorization':
            'Bearer ${accessToken.length > 10 ? accessToken.substring(0, 6) + '...' : '***'}',
        'X-Tenant': apiKey,
      };
      debugPrint('[ZATCA][Provider] Headers: $maskedHeaders');
      debugPrint('[ZATCA][Provider] Body: {id: $id} (POST)');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
        body: {'id': id.toString()},
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        try {
          return json.decode(response.body);
        } catch (_) {
          return response.body;
        }
      } else {
        debugPrint(
            '[ZATCA][Provider] HTTP ${response.statusCode}: ${response.body}');
        return {
          'status': 'error',
          'message': 'Failed with status ${response.statusCode}'
        };
      }
    } on TimeoutException catch (_) {
      debugPrint('[ZATCA][Provider] ERROR: Request timed out');
      return {'status': 'error', 'message': 'Request timed out'};
    } catch (e) {
      debugPrint('[ZATCA][Provider] EXCEPTION: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }
}
