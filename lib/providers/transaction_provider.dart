import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/transaction_model.dart';
import '../resources/app_url.dart';

class TransactionProvider extends ChangeNotifier {
  /* ---------- STATE ---------- */
  final List<TransactionModel> _allTransactions = [];
  final List<TransactionModel> _filteredTransactions = [];

  bool _isLoading = false;
  int _currentPage = 1;
  int _totalPages = 1;
  String? _nextPageUrl;

  // Filters
  String _searchQuery = '';
  String? _statusFilter;
  String? _paymentModeFilter;

  /* ---------- GETTERS ---------- */
  List<TransactionModel> get transactions => _filteredTransactions;
  bool get isLoading => _isLoading;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get hasNextPage => _nextPageUrl != null;

  /* ---------- PUBLIC API ---------- */
  Future<void> fetchTransactions({int page = 1}) async {
    _setLoading(true);

    try {
      final url = Uri.parse(
        'https://stagingepos.enke.ae/api/v1/suppliers/list-transactions?page=$page',
      );

      final res = await http.get(url);

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final jsonMap = jsonDecode(res.body);

      // Manual parsing to avoid type errors
      if (jsonMap['status'] == 'success' && jsonMap['data'] != null) {
        final data = jsonMap['data'];

        // Always clear transactions when fetching a specific page
        _allTransactions.clear();

        if (data['data'] != null && data['data'] is List) {
          final transactions = data['data'] as List<dynamic>;

          int startIndex = _allTransactions.length;
          for (var i = 0; i < transactions.length; i++) {
            final tx = transactions[i];
            try {
              final model = _createTransactionFromJson(tx, startIndex + i);
              _allTransactions.add(model);
            } catch (e) {
              debugPrint('Error parsing transaction: $e');
            }
          }

          _currentPage = data['current_page'] ?? 1;
          _totalPages = data['last_page'] ?? 1;
          _nextPageUrl = data['next_page_url'];

          _applyFilters();
        }
      }
    } catch (e) {
      debugPrint('Transaction fetch error: $e');
    } finally {
      _setLoading(false);
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

  // This method is only used for infinite scrolling, not with pagination controls
  Future<void> loadNextPage() async {
    if (_nextPageUrl != null && !_isLoading) {
      _setLoading(true);

      try {
        // Instead of loading next page and appending, go to the next page directly
        int nextPage = _currentPage + 1;
        if (nextPage <= _totalPages) {
          await goToTransactionPage(nextPage);
        }
      } catch (e) {
        debugPrint('Next page load error: $e');
        _setLoading(false);
      }
    }
  }

  // Go to a specific page (similar to stock.dart)
  Future<void> goToTransactionPage(int page) async {
    if (page < 1 || page > _totalPages || page == _currentPage) return;

    _setLoading(true);
    _currentPage = page;

    // Clear transactions before fetching new page
    _allTransactions.clear();
    _filteredTransactions.clear();
    notifyListeners();

    await fetchTransactions(page: page);
  }

  void searchTransactions(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilters();
  }

  void filterByStatus(String status) {
    _statusFilter = status.toLowerCase();
    _applyFilters();
  }

  void filterByPaymentMode(String paymentMode) {
    _paymentModeFilter = paymentMode.toLowerCase();
    _applyFilters();
  }

  void resetFilters() {
    _searchQuery = '';
    _statusFilter = null;
    _paymentModeFilter = null;
    _applyFilters();
  }

  // Apply all active filters to the transaction list
  void _applyFilters() {
    _filteredTransactions.clear();

    // Start with all transactions
    List<TransactionModel> filtered = List.from(_allTransactions);

    // Apply search query if present
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((tx) {
        String supplierName = '';
        try {
          supplierName = tx.supplier.user.name.toLowerCase();
        } catch (_) {}

        return supplierName.contains(_searchQuery) ||
            tx.reference.toLowerCase().contains(_searchQuery) ||
            tx.transactionType.toLowerCase().contains(_searchQuery) ||
            tx.paymentMode.toLowerCase().contains(_searchQuery) ||
            tx.status.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // Apply status filter if present
    if (_statusFilter != null && _statusFilter!.isNotEmpty) {
      filtered = filtered
          .where((tx) => tx.status.toLowerCase() == _statusFilter)
          .toList();
    }

    // Apply payment mode filter if present
    if (_paymentModeFilter != null && _paymentModeFilter!.isNotEmpty) {
      filtered = filtered
          .where((tx) => tx.paymentMode.toLowerCase() == _paymentModeFilter)
          .toList();
    }

    _filteredTransactions.addAll(filtered);
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
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
