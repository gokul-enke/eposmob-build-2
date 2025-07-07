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
    if (value is int) return value;
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        return defaultValue;
      }
    }
    return defaultValue;
  }

  /// Batch-based fetch for all transactions (like product fetch)
  Future<void> fetchAllTransactionsBatch({String? filterName, String? filterType}) async {
    List<TransactionModel> allTransactions = [];
    int currentPage = 1;
    _transactionIsLoading = true;
    notifyListeners();
    try {
      while (true) {
        final queryParams = <String, String>{
          'page': currentPage.toString(),
        };
        if (filterName != null && filterName.isNotEmpty) {
          queryParams['filter_name'] = filterName;
        }
        if (filterType != null && filterType.isNotEmpty && filterType != 'All Types') {
          queryParams['type'] = filterType.toLowerCase();
        }
        final url = Uri.parse(APPUrl.supplierTransactions).replace(queryParameters: queryParams);
        final response = await http.get(url, headers: {
          'Authorization': 'Bearer ${_accessToken ?? ''}',
          'Content-Type': 'application/json',
        });
        if (response.statusCode == 200) {
          final jsonMap = jsonDecode(response.body);
          if (jsonMap['status'] == 'success' && jsonMap['data'] != null) {
            final data = jsonMap['data'];
            if (data['data'] != null && data['data'] is List) {
              final transactions = data['data'] as List<dynamic>;
              if (transactions.isEmpty) break;
              for (var i = 0; i < transactions.length; i++) {
                final tx = transactions[i];
                try {
                  final model = _createTransactionFromJson(tx, allTransactions.length + i);
                  allTransactions.add(model);
                } catch (e) {
                  debugPrint('Error parsing transaction: $e');
                }
              }
              currentPage++;
              if (currentPage > (data['last_page'] ?? currentPage)) break;
            } else {
              break;
            }
          } else {
            break;
          }
        } else {
          break;
        }
      }
      _allTransactions = allTransactions;
      applyTransactionFiltersLocally(page: 1);
    } catch (e) {
      debugPrint('Error fetching all transactions: $e');
    } finally {
      _transactionIsLoading = false;
      notifyListeners();
    }
  }

  /// For pull-to-refresh
  Future<void> refreshAllTransactions() async {
    await fetchAllTransactionsBatch();
  }

  /// Apply local pagination and filtering for transactions
  void applyTransactionFiltersLocally({
    String? filterName,
    String? filterType,
    int page = 1,
  }) {
    if (_allTransactions == null || _allTransactions!.isEmpty) {
      _listTransactionModelDataList = [];
      _filteredTransactionsList = [];
      _transactionCurrentPage = 1;
      _transactionTotalPages = 1;
      notifyListeners();
      return;
    }

    _transactionFilterName = filterName;
    _transactionFilterStatus = null; // Remove status filter
    _transactionFilterPaymentMode = null; // Remove payment mode filter
    _transactionCurrentPage = page;
    String? typeFilter = filterType;

    List<TransactionModel> filteredList = [..._allTransactions!];
    if (filterName != null && filterName.isNotEmpty) {
      filteredList = filteredList.where((transaction) {
        String supplierName = '';
        try {
          supplierName = transaction.supplier.user.name.toLowerCase();
        } catch (_) {}
        return supplierName.contains(filterName.toLowerCase()) ||
            transaction.reference.toLowerCase().contains(filterName.toLowerCase()) ||
            transaction.transactionType.toLowerCase().contains(filterName.toLowerCase());
      }).toList();
    }
    if (typeFilter != null && typeFilter.isNotEmpty && typeFilter != 'All Types') {
      filteredList = filteredList.where((transaction) =>
        transaction.type.toLowerCase() == typeFilter.toLowerCase()
      ).toList();
    }
    _transactionTotalPages = (filteredList.length / _transactionItemsPerPage).ceil();
    _transactionTotalPages = _transactionTotalPages == 0 ? 1 : _transactionTotalPages;
    if (_transactionCurrentPage > _transactionTotalPages) {
      _transactionCurrentPage = _transactionTotalPages;
    }
    int startIndex = (_transactionCurrentPage - 1) * _transactionItemsPerPage;
    int endIndex = startIndex + _transactionItemsPerPage;
    if (startIndex >= filteredList.length) {
      _listTransactionModelDataList = [];
      _filteredTransactionsList = [];
    } else {
      endIndex = endIndex > filteredList.length ? filteredList.length : endIndex;
      _listTransactionModelDataList = filteredList.sublist(startIndex, endIndex);
      _filteredTransactionsList = List<TransactionModel>.from(_listTransactionModelDataList!);
    }
    notifyListeners();
  }

  /// For UI filter dropdown
  List<String> getTypeOptions() {
    return ['All Types', 'Credit', 'Debit'];
  }

  /// Reset transaction filters and pagination
  void resetTransactionFilters() {
    _transactionFilterName = null;
    _transactionFilterStatus = null;
    _transactionFilterPaymentMode = null;
    _transactionCurrentPage = 1;

    if (_allTransactions != null && _allTransactions!.isNotEmpty) {
      applyTransactionFiltersLocally(page: 1);
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
        filterName: _transactionFilterName,
        filterType: status,
        page: 1);
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

  // Store access token for batch fetch
  void setAccessToken(String? token) {
    _accessToken = token;
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
