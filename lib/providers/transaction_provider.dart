import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/transaction_model.dart';
import '../resources/app_url.dart';

class TransactionProvider extends ChangeNotifier {
  /* ---------- STATE ---------- */
  // Transaction data management
  List<TransactionModel>? _allTransactions =
      []; // Store all transactions for local filtering
  List<TransactionModel>? _filteredTransactionsList = [];
  List<TransactionModel>? _listTransactionModelDataList = [];

  // Pagination properties
  int _transactionCurrentPage = 1;
  int _transactionTotalPages = 1;
  final int _transactionItemsPerPage = 20;

  // Filter properties
  String? _transactionFilterName;
  String? _transactionFilterStatus;
  String? _transactionFilterPaymentMode;

  // Loading state
  bool _transactionIsLoading = false;

  // Store access token for batch fetch
  String? _accessToken;

  /* ---------- GETTERS ---------- */
  List<TransactionModel>? get listTransactionModelDataList =>
      _filteredTransactionsList ?? _listTransactionModelDataList;

  List<TransactionModel>? get allTransactions => _allTransactions;

  int get transactionCurrentPage => _transactionCurrentPage;
  int get transactionTotalPages => _transactionTotalPages;
  int get transactionItemsPerPage => _transactionItemsPerPage;
  String? get transactionFilterName => _transactionFilterName;
  String? get transactionFilterStatus => _transactionFilterStatus;
  String? get transactionFilterPaymentMode => _transactionFilterPaymentMode;
  bool get transactionIsLoading => _transactionIsLoading;

  // Legacy getters for compatibility
  List<TransactionModel> get transactions => listTransactionModelDataList ?? [];
  bool get isLoading => _transactionIsLoading;
  int get currentPage => _transactionCurrentPage;
  int get totalPages => _transactionTotalPages;

  /// Search transactions locally by name
  void searchTransactions(String query) {
    if (_allTransactions == null || _allTransactions!.isEmpty) {
      return;
    }

    applyTransactionFiltersLocally(filterName: query, page: 1);
  }

  /// Extract unique statuses from loaded transactions
  List<String> getUniqueStatuses() {
    if (_allTransactions == null || _allTransactions!.isEmpty) {
      return ["All Status"];
    }

    final uniqueStatuses = _allTransactions!
        .map((transaction) => transaction.status)
        .where((status) => status.isNotEmpty)
        .toSet()
        .toList();

    uniqueStatuses.sort();
    return ["All Status", ...uniqueStatuses];
  }

  /// Extract unique payment modes from loaded transactions
  List<String> getUniquePaymentModes() {
    if (_allTransactions == null || _allTransactions!.isEmpty) {
      return ["All Payment Modes"];
    }

    final uniquePaymentModes = _allTransactions!
        .map((transaction) => transaction.paymentMode)
        .where((mode) => mode.isNotEmpty)
        .toSet()
        .toList();

    uniquePaymentModes.sort();
    return ["All Payment Modes", ...uniquePaymentModes];
  }

  /// Load all transactions for local filtering and pagination
  Future<void> loadAllTransactions(String accessToken) async {
    try {
      await fetchTransactionsAPI(
        accessToken: accessToken,
        loadAll: true,
      );
    } catch (error) {
      debugPrint('Error loading all transactions: $error');
      rethrow;
    }
  }

  /* ---------- PUBLIC API ---------- */
  Future<void> fetchTransactionsAPI({
    required String accessToken,
    String? filterName,
    int? page,
    bool loadAll = false,
  }) async {
    _transactionIsLoading = true;
    notifyListeners();

    try {
      // Build URL with query parameters
      String url = APPUrl.supplierTransactions;
      final queryParams = <String, String>{
        'page': (page ?? 1).toString(),
        if (loadAll) 'per_page': '1000', // Load all transactions
      };

      if (filterName != null && filterName.isNotEmpty) {
        queryParams['filter_name'] = filterName;
      }

      final uri = Uri.parse(url).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Transaction API Response: ${response.statusCode}');

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
                final model = _createTransactionFromJson(tx, i);
                transactionList.add(model);
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
                  List<TransactionModel>.from(_listTransactionModelDataList!);

              _transactionCurrentPage = data['current_page'] ?? 1;
              _transactionTotalPages = data['last_page'] ?? 1;
            }

            notifyListeners();
          }
        }
      } else {
        debugPrint('Failed to load transactions: ${response.statusCode}');
        throw Exception('Failed to load transactions');
      }
    } catch (error) {
      debugPrint('Error in fetchTransactionsAPI: $error');
      rethrow;
    } finally {
      _transactionIsLoading = false;
      notifyListeners();
    }
  }

  // Helper method to create a transaction model from JSON
  TransactionModel _createTransactionFromJson(
      Map<String, dynamic> json, int index) {
    // Extract supplier name safely
    String supplierName = 'Unknown';
    if (json['supplier'] != null && json['supplier'] is Map) {
      final supplier = json['supplier'] as Map<String, dynamic>;
      if (supplier['user'] != null && supplier['user'] is Map) {
        final user = supplier['user'] as Map<String, dynamic>;
        supplierName = user['name'] ?? 'Unknown';
      }
    }

    // Create a supplier object with safe defaults
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
      paymentMode: json['payment_mode'] ?? '',
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

  // Safe integer parsing with default value
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

  // Set access token for batch operations
  void setAccessToken(String token) {
    _accessToken = token;
  }

  // Get all transactions for local filtering
  List<TransactionModel> getAllTransactions() {
    return _allTransactions ?? [];
  }

  // Get unique transaction types
  List<String> getTypeOptions() {
    if (_allTransactions == null || _allTransactions!.isEmpty) {
      return ["All Types"];
    }

    final uniqueTypes = _allTransactions!
        .map((transaction) => transaction.type)
        .where((type) => type.isNotEmpty)
        .toSet()
        .toList();

    uniqueTypes.sort();
    return ["All Types", ...uniqueTypes];
  }

  // Apply filters locally to the transactions list
  void applyTransactionFiltersLocally({
    String? filterName,
    String? filterType,
    String? filterStatus,
    String? filterPaymentMode,
    int? page,
  }) {
    if (_allTransactions == null || _allTransactions!.isEmpty) {
      return;
    }

    // Store filter values
    _transactionFilterName = filterName;
    _transactionFilterStatus = filterStatus;
    _transactionFilterPaymentMode = filterPaymentMode;

    // Filter transactions
    List<TransactionModel> filtered = List.from(_allTransactions!);

    if (filterName != null && filterName.isNotEmpty) {
      filtered = filtered
          .where((tx) =>
              tx.reference.toLowerCase().contains(filterName.toLowerCase()))
          .toList();
    }

    if (filterType != null && filterType.isNotEmpty) {
      filtered = filtered.where((tx) => tx.type == filterType).toList();
    }

    if (filterStatus != null && filterStatus.isNotEmpty) {
      filtered = filtered.where((tx) => tx.status == filterStatus).toList();
    }

    if (filterPaymentMode != null && filterPaymentMode.isNotEmpty) {
      filtered =
          filtered.where((tx) => tx.paymentMode == filterPaymentMode).toList();
    }

    // Update pagination
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

    notifyListeners();
  }

  // Reset filters and show all transactions
  void resetTransactionFilters() {
    _transactionFilterName = null;
    _transactionFilterStatus = null;
    _transactionFilterPaymentMode = null;
    _transactionCurrentPage = 1;

    if (_allTransactions != null && _allTransactions!.isNotEmpty) {
      applyTransactionFiltersLocally(page: 1);
    }
  }

  // Fetch all transactions in batches for local filtering
  Future<void> fetchAllTransactionsBatch() async {
    if (_accessToken == null) {
      throw Exception('Access token not set');
    }

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

  // Refresh all transactions
  Future<void> refreshAllTransactions() async {
    if (_accessToken == null) {
      throw Exception('Access token not set');
    }

    try {
      await fetchAllTransactionsBatch();
    } catch (error) {
      debugPrint('Error in refreshAllTransactions: $error');
      rethrow;
    }
  }

  /// Change transaction page
  void goToTransactionPage(int page) {
    if (page < 1 || page > _transactionTotalPages) return;

    applyTransactionFiltersLocally(
        filterName: _transactionFilterName,
        filterType: _transactionFilterStatus,
        page: page);
  }

  // Legacy methods for compatibility
  void filterByStatus(String status) {
    applyTransactionFiltersLocally(
        filterName: _transactionFilterName, filterType: status, page: 1);
  }

  void filterByPaymentMode(String paymentMode) {
    applyTransactionFiltersLocally(
        filterName: _transactionFilterName,
        filterType: _transactionFilterStatus,
        page: 1);
  }

  void resetFilters() {
    resetTransactionFilters();
  }

  /// Clear all transaction data
  void clearTransactionData() {
    _allTransactions = [];
    _filteredTransactionsList = [];
    _listTransactionModelDataList = [];
    _transactionCurrentPage = 1;
    _transactionTotalPages = 1;
    _transactionFilterName = null;
    _transactionFilterStatus = null;
    _transactionFilterPaymentMode = null;
    _transactionIsLoading = false;
    notifyListeners();
  }
}

/* -------------------------------------------------
   Temporary hard-coded API JSON for offline testing
--------------------------------------------------*/
// const String _mockApiResponse = '''{
//   "status": "success",
//   "message": "Transaction listed successfully",
//   "data": {
//     "current_page": 1,
//     "last_page": 8,
//     "data": [
//       {
//         "id": 113,
//         "supplier_id": 1,
//         "date": "2025-06-27",
//         "type": "Credit",
//         "transaction_type": "Invoice",
//         "payment_mode": "cash",
//         "amount": "1293.000",
//         "reference": "767709",
//         "status": "SUCC",
//         "supplier": {
//           "id": 1,
//           "user": { "id": 8, "name": "Supplier" }
//         }
//       },
//       {
//         "id": 112,
//         "supplier_id": 1,
//         "date": "2025-06-27",
//         "type": "Credit",
//         "transaction_type": "Invoice",
//         "payment_mode": "cash",
//         "amount": "250.000",
//         "reference": "548095",
//         "status": "SUCC",
//         "supplier": {
//           "id": 1,
//           "user": { "id": 8, "name": "Supplier" }
//         }
//       }
//     ]
//   }
// }''';
