import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/transaction_model.dart';
import '../resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TransactionProvider extends ChangeNotifier {
  /* ---------- STATE ---------- */
  // Transaction data management
  List<TransactionModel>? _allTransactions = [];
  List<TransactionModel>? _filteredTransactionsList = [];
  List<TransactionModel>? _listTransactionModelDataList = [];

  // Pagination properties
  int _transactionCurrentPage = 1;
  int _transactionTotalPages = 1;
  final int _transactionItemsPerPage = 20;

  // Filter properties
  String? _transactionFilterName;
  String? _transactionFilterType;
  String? _transactionFilterStatus;
  String? _transactionFilterPaymentMode;
  String? _transactionFilterSupplier;

  // Customer name for transaction details
  String _customerName = '';

  // Loading state
  bool _transactionIsLoading = false;
  static const Duration _requestTimeout = Duration(seconds: 30);

  // Store access token for batch fetch
  String? _accessToken;
  // Supplier name to id mapping (built from fetched data)
  final Map<String, int> _supplierNameToId = {};

  /* ---------- GETTERS ---------- */
  List<TransactionModel>? get listTransactionModelDataList =>
      _filteredTransactionsList ?? _listTransactionModelDataList;

  List<TransactionModel>? get allTransactions => _allTransactions;

  int get transactionCurrentPage => _transactionCurrentPage;
  int get transactionTotalPages => _transactionTotalPages;
  int get transactionItemsPerPage => _transactionItemsPerPage;
  String? get transactionFilterName => _transactionFilterName;
  String? get transactionFilterType => _transactionFilterType;
  String? get transactionFilterStatus => _transactionFilterStatus;
  String? get transactionFilterPaymentMode => _transactionFilterPaymentMode;
  String? get transactionFilterSupplier => _transactionFilterSupplier;
  bool get transactionIsLoading => _transactionIsLoading;
  int? lookupSupplierIdByName(String name) {
    if (name.isEmpty) return null;
    return _supplierNameToId[name];
  }

  // Getter for customer name
  String get customerName => _customerName;

  /* ---------- PUBLIC METHODS ---------- */
  Future<void> fetchTransactionsAPI({
    required String accessToken,
    String? filterName,
    int? page,
    bool loadAll = false,
  }) async {
    _transactionIsLoading = true;
    notifyListeners();

    try {
      String url = APPUrl.supplierTransactions;
      final queryParams = <String, String>{
        'page': (page ?? 1).toString(),
        if (loadAll) 'per_page': '1000',
      };

      if (filterName != null && filterName.isNotEmpty) {
        queryParams['filter_name'] = filterName;
      }

      // Get API key and active store from SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? activeStoreId = prefs.getInt('active_store_id');
      if (activeStoreId != null && !queryParams.containsKey('store_id')) {
        queryParams['store_id'] = activeStoreId.toString();
      }
      final uri = Uri.parse(url).replace(queryParameters: queryParams);

      // Get API key from SharedPreferences
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found. Please restart the app.");
      }
      final response = await _getWithRetry(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body);

        if (jsonMap['status'] == 'success' && jsonMap['data'] != null) {
          final data = jsonMap['data'];
          if (data['data'] != null && data['data'] is List) {
            final transactions = data['data'] as List<dynamic>;
            List<TransactionModel> transactionList = [];

            for (var i = 0; i < transactions.length; i++) {
              final tx = transactions[i];
              try {
                transactionList.add(_createTransactionFromJson(tx, i));
                // build supplier name->id map
                final supplierName = transactionList.last.supplier.user.name;
                final supplierId = transactionList.last.supplier.id;
                if (supplierName.isNotEmpty && supplierId != 0) {
                  _supplierNameToId[supplierName] = supplierId;
                }
              } catch (e) {
                debugPrint('Error parsing transaction: $e');
              }
            }

            if (loadAll) {
              _allTransactions = transactionList;
              applyTransactionFiltersLocally(page: 1);
            } else {
              _listTransactionModelDataList = transactionList;
              _filteredTransactionsList =
                  List.from(_listTransactionModelDataList!);
              _transactionCurrentPage = data['current_page'] ?? 1;
              _transactionTotalPages = data['last_page'] ?? 1;
            }
          }
        }
      } else {
        throw Exception('Failed to load transactions: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Error in fetchTransactionsAPI: $error');
      rethrow;
    } finally {
      _transactionIsLoading = false;
      notifyListeners();
    }
  }

  // New: Fetch using supplier-transactions V2 with server-side filters
  Future<void> fetchTransactionsFromServerV2({
    String? supplierId,
    String? transactionType, // Invoice | Voucher
    String? type, // Credit | Debit
    String? dateFrom, // yyyy-MM-dd
    String? dateTo, // yyyy-MM-dd
    int? perPage, // default 20
    int? page,
  }) async {
    if (_accessToken == null) throw Exception('Access token not set');
    _transactionIsLoading = true;
    notifyListeners();

    try {
      final queryParams = <String, String>{
        if (supplierId != null && supplierId.isNotEmpty) 'supplier_id': supplierId,
        if (transactionType != null && transactionType.isNotEmpty)
          'transaction_type': transactionType,
        if (type != null && type.isNotEmpty) 'type': type,
        if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
        'per_page': (perPage ?? _transactionItemsPerPage).toString(),
        'page': (page ?? 1).toString(),
      };

      // Get API key and active store from SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? activeStoreId = prefs.getInt('active_store_id');
      if (activeStoreId != null && !queryParams.containsKey('store_id')) {
        queryParams['store_id'] = activeStoreId.toString();
      }
      final uri = Uri.parse(APPUrl.supplierTransactionsV2)
          .replace(queryParameters: queryParams);

      // Get API key from SharedPreferences
      String? apiKey = prefs.getString('api_key');
      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found. Please restart the app.");
      }

      final response = await _getWithRetry(
        uri,
        headers: {
          'Authorization': 'Bearer ${_accessToken!}',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body);
        if (jsonMap['status'] == 'success' && jsonMap['data'] != null) {
          final data = jsonMap['data'];
          if (data['data'] != null && data['data'] is List) {
            final transactions = data['data'] as List<dynamic>;
            List<TransactionModel> transactionList = [];
            _supplierNameToId.clear();
            for (var i = 0; i < transactions.length; i++) {
              final tx = transactions[i];
              try {
                final model = _createTransactionFromJson(tx, i);
                transactionList.add(model);
                final name = model.supplier.user.name;
                final id = model.supplier.id;
                if (name.isNotEmpty && id != 0) {
                  _supplierNameToId[name] = id;
                }
              } catch (e) {
                debugPrint('Error parsing transaction (v2): $e');
              }
            }
            _listTransactionModelDataList = transactionList;
            _filteredTransactionsList = List.from(_listTransactionModelDataList!);
            _transactionCurrentPage = data['current_page'] ?? 1;
            _transactionTotalPages = data['last_page'] ?? 1;
          }
        }
      } else {
        throw Exception('Failed to load transactions v2: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error in fetchTransactionsFromServerV2: $e');
      rethrow;
    } finally {
      _transactionIsLoading = false;
      notifyListeners();
    }
  }

  void applyTransactionFiltersLocally({
    String? filterName,
    String? filterType,
    String? filterStatus,
    String? filterPaymentMode,
    String? filterSupplier,
    int? page,
  }) {
    if (_allTransactions == null || _allTransactions!.isEmpty) return;

    // Store filter values
    _transactionFilterName = filterName;
    _transactionFilterType = filterType;
    _transactionFilterStatus = filterStatus;
    _transactionFilterPaymentMode = filterPaymentMode;
    _transactionFilterSupplier = filterSupplier;

    // Apply filters
    List<TransactionModel> filtered = List.from(_allTransactions!);

    // Name filter (searches both reference and supplier name)
    if (filterName != null && filterName.isNotEmpty) {
      filtered = filtered
          .where((tx) =>
              tx.reference.toLowerCase().contains(filterName.toLowerCase()) ||
              tx.supplier.user.name
                  .toLowerCase()
                  .contains(filterName.toLowerCase()))
          .toList();
    }

    // Type filter
    if (filterType != null &&
        filterType.isNotEmpty &&
        filterType != "All Types") {
      filtered = filtered
          .where((tx) => tx.type.toLowerCase() == filterType.toLowerCase())
          .toList();
    }

    // Status filter
    if (filterStatus != null &&
        filterStatus.isNotEmpty &&
        filterStatus != "All Status") {
      filtered = filtered
          .where((tx) => tx.status.toLowerCase() == filterStatus.toLowerCase())
          .toList();
    }

    // Payment mode filter
    if (filterPaymentMode != null &&
        filterPaymentMode.isNotEmpty &&
        filterPaymentMode != "All Payment Modes") {
      filtered = filtered
          .where((tx) =>
              tx.paymentMode.toLowerCase() == filterPaymentMode.toLowerCase())
          .toList();
    }

    // Supplier filter - Changed to use contains instead of exact match
    if (filterSupplier != null && filterSupplier.isNotEmpty) {
      filtered = filtered
          .where((tx) => tx.supplier.user.name
              .toLowerCase()
              .contains(filterSupplier.toLowerCase()))
          .toList();
    }

    // Update pagination
    _updatePagination(filtered, page);
    notifyListeners();
  }

  void _updatePagination(List<TransactionModel> filtered, int? page) {
    _transactionTotalPages =
        (filtered.length / _transactionItemsPerPage).ceil();
    _transactionCurrentPage = page ?? 1;

    if (_transactionCurrentPage < 1) _transactionCurrentPage = 1;
    if (_transactionCurrentPage > _transactionTotalPages &&
        _transactionTotalPages > 0) {
      _transactionCurrentPage = _transactionTotalPages;
    }

    // Paginate results
    final startIndex = (_transactionCurrentPage - 1) * _transactionItemsPerPage;
    final endIndex = startIndex + _transactionItemsPerPage;

    if (filtered.isEmpty) {
      _filteredTransactionsList = [];
    } else if (endIndex >= filtered.length) {
      _filteredTransactionsList = filtered.sublist(startIndex, filtered.length);
    } else {
      _filteredTransactionsList = filtered.sublist(startIndex, endIndex);
    }
  }

  /* ---------- FILTER OPTIONS ---------- */
  List<String> getTypeOptions() {
    if (_allTransactions == null || _allTransactions!.isEmpty) {
      return ["All Types"];
    }

    final uniqueTypes = _allTransactions!
        .map((tx) => tx.type)
        .where((type) => type.isNotEmpty)
        .toSet()
        .toList();

    uniqueTypes.sort();
    return ["All Types", ...uniqueTypes];
  }

  List<String> getStatusOptions() {
    if (_allTransactions == null || _allTransactions!.isEmpty) {
      return ["All Status"];
    }

    final uniqueStatuses = _allTransactions!
        .map((tx) => tx.status)
        .where((status) => status.isNotEmpty)
        .toSet()
        .toList();

    uniqueStatuses.sort();
    return ["All Status", ...uniqueStatuses];
  }

  List<String> getPaymentModeOptions() {
    if (_allTransactions == null || _allTransactions!.isEmpty) {
      return ["All Payment Modes"];
    }

    final uniqueModes = _allTransactions!
        .map((tx) => tx.paymentMode)
        .where((mode) => mode.isNotEmpty)
        .toSet()
        .toList();

    uniqueModes.sort();
    return ["All Payment Modes", ...uniqueModes];
  }

  List<String> getSupplierOptions() {
    final source = (_allTransactions != null && _allTransactions!.isNotEmpty)
        ? _allTransactions!
        : (_listTransactionModelDataList ?? const <TransactionModel>[]);
    if (source.isEmpty) return ["All Suppliers"];

    final uniqueSuppliers = source
        .map((tx) => tx.supplier.user.name)
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    uniqueSuppliers.sort();
    return ["", ...uniqueSuppliers];
  }

  /* ---------- UTILITY METHODS ---------- */
  void setAccessToken(String token) {
    _accessToken = token;
  }

  // Method to set customer name
  void setCustomerName(String name) {
    _customerName = name;
    notifyListeners();
  }

  // Method to clear customer name
  void clearCustomerName() {
    _customerName = '';
    notifyListeners();
  }

  Future<void> fetchAllTransactionsBatch() async {
    if (_accessToken == null) throw Exception('Access token not set');

    _transactionIsLoading = true;
    notifyListeners();

    try {
      await fetchTransactionsAPI(
        accessToken: _accessToken!,
        loadAll: true,
      );
    } catch (error) {
      debugPrint('Error in fetchAllTransactionsBatch: $error');
      rethrow;
    } finally {
      _transactionIsLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAllTransactions() async {
    if (_accessToken == null) throw Exception('Access token not set');
    await fetchAllTransactionsBatch();
  }

  void resetTransactionFilters() {
    _transactionFilterName = null;
    _transactionFilterType = null;
    _transactionFilterStatus = null;
    _transactionFilterPaymentMode = null;
    _transactionFilterSupplier = null;
    _transactionCurrentPage = 1;

    if (_allTransactions != null && _allTransactions!.isNotEmpty) {
      applyTransactionFiltersLocally(page: 1);
    }
  }

  void goToTransactionPage(int page) {
    if (page < 1 || page > _transactionTotalPages) return;

    applyTransactionFiltersLocally(
      filterName: _transactionFilterName,
      filterType: _transactionFilterType,
      filterStatus: _transactionFilterStatus,
      filterPaymentMode: _transactionFilterPaymentMode,
      filterSupplier: _transactionFilterSupplier,
      page: page,
    );
  }

  void clearTransactionData() {
    _allTransactions = [];
    _filteredTransactionsList = [];
    _listTransactionModelDataList = [];
    _transactionCurrentPage = 1;
    _transactionTotalPages = 1;
    _transactionFilterName = null;
    _transactionFilterType = null;
    _transactionFilterStatus = null;
    _transactionFilterPaymentMode = null;
    _transactionFilterSupplier = null;
    _transactionIsLoading = false;
    _customerName = ''; // Clear customer name when clearing transaction data
    notifyListeners();
  }

  /* ---------- PRIVATE HELPERS ---------- */
  TransactionModel _createTransactionFromJson(
      Map<String, dynamic> json, int index) {
    String supplierName = 'Unknown';
    if (json['supplier'] != null && json['supplier'] is Map) {
      final supplier = json['supplier'] as Map<String, dynamic>;
      if (supplier['user'] != null && supplier['user'] is Map) {
        final user = supplier['user'] as Map<String, dynamic>;
        supplierName = user['name'] ?? 'Unknown';
      }
    }

    final supplier = Supplier(
      id: _safeParseInt(json['supplier']?['id']),
      userId: _safeParseInt(json['supplier']?['user_id']),
      balance: json['supplier']?['balance'] ?? '0.0',
      createdAt: json['supplier']?['created_at'] ?? '',
      updatedAt: json['supplier']?['updated_at'] ?? '',
      user: User(
        id: _safeParseInt(json['supplier']?['user']?['id']),
        name: supplierName,
        email: json['supplier']?['user']?['email'] ?? '',
        phone: json['supplier']?['user']?['phone'] ?? '',
        phoneVerified:
            _safeParseInt(json['supplier']?['user']?['phone_verified']),
        companyId: _safeParseInt(json['supplier']?['user']?['company_id']),
        createdAt: json['supplier']?['user']?['created_at'] ?? '',
        updatedAt: json['supplier']?['user']?['updated_at'] ?? '',
      ),
    );

    return TransactionModel(
      id: _safeParseInt(json['id']),
      supplierId: _safeParseInt(json['supplier_id']),
      supplierVoucherId: json['supplier_voucher_id'] != null
          ? _safeParseInt(json['supplier_voucher_id'])
          : null,
      date: json['date'] ?? '',
      type: json['type'] ?? '',
      referenceId: json['reference_id'] != null
          ? _safeParseInt(json['reference_id'])
          : null,
      transactionType: json['transaction_type'] ?? '',
      // API may use payment_mode or payment_method
      paymentMode: (json['payment_mode'] ?? json['payment_method'] ?? '').toString(),
      amount: json['amount'] ?? '0',
      taxAmount: json['tax_amount']?.toString(),
      currency: json['currency'] ?? 'INR',
      reference: json['reference'] ?? '',
      transactionComment: json['transaction_comment']?.toString(),
      status: json['status'] ?? '',
      userId: _safeParseInt(json['user_id']),
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      supplier: supplier,
      siNo: index + 1,
    );
  }

  int _safeParseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    try {
      if (value is int) return value;
      if (value is String) return int.parse(value);
      return defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  Future<http.Response> _getWithRetry(
    Uri uri, {
    required Map<String, String> headers,
    int retries = 2,
  }) async {
    int attempt = 0;
    late Object lastError;
    while (true) {
      try {
        return await http
            .get(uri, headers: headers)
            .timeout(_requestTimeout);
      } on SocketException catch (e) {
        lastError = e;
      } on HandshakeException catch (e) {
        lastError = e;
      } on TimeoutException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        lastError = e;
      } catch (e) {
        lastError = e;
      }

      if (attempt >= retries) {
        throw lastError;
      }
      // Exponential backoff: 600ms, 1200ms, ...
      final delayMs = 600 * (1 << attempt);
      await Future.delayed(Duration(milliseconds: delayMs));
      attempt++;
    }
  }
}
