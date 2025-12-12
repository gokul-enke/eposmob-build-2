import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/supplier_voucher.dart';
import 'package:pos_machine/resources/app_url.dart';

class SupplierVoucherProvider extends ChangeNotifier {
  bool _isLoading = false;
  List<SupplierVoucher>? _allVouchers;
  List<SupplierVoucher>? voucherListDetails;

  // Pagination properties
  int _currentPage = 1;
  int _totalPages = 1;
  int _itemsPerPage = 20;

  // Filter properties
  int? _filterSupplierId;
  String? _filterVoucherNumber;
  String? _filterType;
  String? _filterStatus;

  // Getters
  bool get isLoading => _isLoading;
  List<SupplierVoucher>? get allVouchers => _allVouchers;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get itemsPerPage => _itemsPerPage;

  // Status options
  List<String> getStatusOptions() {
    return ['All Status', 'paid', 'pending', 'cancelled'];
  }

  // Type options
  List<String> getTypeOptions() {
    return ['All Types', 'order', 'other', 'refund', 'adjustment'];
  }

  // Pagination navigation
  void goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    applyFiltersLocally(
      filterSupplierId: _filterSupplierId,
      filterVoucherNumber: _filterVoucherNumber,
      filterType: _filterType,
      filterStatus: _filterStatus,
      page: page,
    );
  }

  // Apply filters
  void applyFilters({
    int? supplierId,
    String? voucherNumber,
    String? type,
    String? status,
    int page = 1,
  }) {
    _filterSupplierId = supplierId;
    _filterVoucherNumber = voucherNumber;
    _filterType = type;
    _filterStatus = status;
    _currentPage = page;

    applyFiltersLocally(
      filterSupplierId: supplierId,
      filterVoucherNumber: voucherNumber,
      filterType: type,
      filterStatus: status,
      page: page,
    );
  }

  // Reset filters
  void resetFilters() {
    _filterSupplierId = null;
    _filterVoucherNumber = null;
    _filterType = null;
    _filterStatus = null;
    _currentPage = 1;
    applyFiltersLocally(page: 1);
  }

  // Apply filters locally
  void applyFiltersLocally({
    int? filterSupplierId,
    String? filterVoucherNumber,
    String? filterType,
    String? filterStatus,
    int page = 1,
  }) {
    debugPrint(
        "applyFiltersLocally: filterSupplierId=$filterSupplierId, page=$page");
    debugPrint("_allVouchers: ${_allVouchers?.length ?? 0} vouchers");

    if (_allVouchers == null || _allVouchers!.isEmpty) {
      debugPrint("No vouchers available for filtering");
      voucherListDetails = [];
      _currentPage = 1;
      _totalPages = 1;
      notifyListeners();
      return;
    }

    // Filter vouchers
    List<SupplierVoucher> filteredVouchers = [..._allVouchers!];
    debugPrint("Starting with ${filteredVouchers.length} vouchers");

    // Filter by supplier id
    if (filterSupplierId != null && filterSupplierId > 0) {
      filteredVouchers = filteredVouchers.where((voucher) {
        return voucher.supplier.id == filterSupplierId;
      }).toList();
      debugPrint(
          "After supplier filter: ${filteredVouchers.length} vouchers match supplier $filterSupplierId");
    }

    // Filter by voucher number
    if (filterVoucherNumber != null && filterVoucherNumber.isNotEmpty) {
      filteredVouchers = filteredVouchers.where((voucher) {
        return voucher.voucherNumber
            .toLowerCase()
            .contains(filterVoucherNumber.toLowerCase());
      }).toList();
      debugPrint(
          "After voucher number filter: ${filteredVouchers.length} vouchers match '$filterVoucherNumber'");
    }

    // Filter by type
    if (filterType != null &&
        filterType.isNotEmpty &&
        filterType != 'All Types') {
      filteredVouchers = filteredVouchers.where((voucher) {
        return voucher.type.toLowerCase() == filterType.toLowerCase();
      }).toList();
      debugPrint(
          "After type filter: ${filteredVouchers.length} vouchers match '$filterType'");
    }

    // Filter by status
    if (filterStatus != null &&
        filterStatus.isNotEmpty &&
        filterStatus != 'All Status') {
      filteredVouchers = filteredVouchers.where((voucher) {
        return voucher.status.toLowerCase() == filterStatus.toLowerCase();
      }).toList();
      debugPrint(
          "After status filter: ${filteredVouchers.length} vouchers match '$filterStatus'");
    }

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

  // List all supplier vouchers
  Future<void> listAllSupplierVouchers({
    required String accessToken,
  }) async {
    debugPrint("listAllSupplierVouchers called");
    _isLoading = true;
    notifyListeners();

    final queryParams = {
      'page': '1',
      'per_page': '1000',
    };

    final uri = Uri.parse(APPUrl.listSupplierVouchers)
        .replace(queryParameters: queryParams);
    debugPrint("Fetching vouchers from: $uri");

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
      );

      debugPrint("Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        SupplierVoucherModel supplierVoucherModel =
            SupplierVoucherModel.fromJson(jsonData);

        _allVouchers = supplierVoucherModel.data;
        debugPrint("Loaded ${_allVouchers?.length ?? 0} vouchers");

        // Apply initial filters
        applyFiltersLocally(page: 1);
      } else {
        debugPrint("Error: ${response.statusCode} - ${response.body}");
        _allVouchers = [];
        voucherListDetails = [];
      }
    } catch (e) {
      debugPrint("Exception: $e");
      _allVouchers = [];
      voucherListDetails = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create voucher
  Future<Map<String, dynamic>> createVoucher({
    required int supplierId,
    required String type,
    required double amount,
    required String voucherDate,
    required String dueDate,
    required String status,
    required int? paymentMethodId,
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
        'supplier_id': supplierId,
        'type': type,
        'amount': amount,
        'voucher_date': voucherDate,
        'due_date': dueDate,
        'status': status,
        'payment_method_id': paymentMethodId,
        'voucher_items': voucherItems,
      };

      debugPrint("Creating voucher with body: $body");

      final response = await http.post(
        Uri.parse(APPUrl.createSupplierVoucher),
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
        await listAllSupplierVouchers(accessToken: accessToken);
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
}
