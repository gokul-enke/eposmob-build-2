import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../resources/app_url.dart';
import '../models/expense.dart';
import '../models/master_data.dart';

class ExpenseProvider extends ChangeNotifier {
  final List<Expense> _allExpenses = [];
  List<Expense> _filteredExpenses = [];
  final Set<String> _selectedReferences = {};

  String _filterCategory = 'All';
  String _filterStatus = 'All';
  String _filterDebitAccount = 'All';
  String _filterReference = '';

  int _currentPage = 1;
  final int _itemsPerPage = 10;
  bool _isLoading = false;

  List<Map<String, dynamic>> categoryOptions = [];
  List<Map<String, dynamic>> debitAccountOptions = [];
  List<Map<String, dynamic>> creditAccountOptions = [];
  List<Map<String, dynamic>> paymentMethodOptions = [];

  ExpenseProvider() {
    _filteredExpenses = List.from(_allExpenses);
  }

  List<Expense> get expenses {
    final start = (_currentPage - 1) * _itemsPerPage;
    if (start >= _filteredExpenses.length) return [];
    final end = start + _itemsPerPage;
    return _filteredExpenses.sublist(
      start,
      end > _filteredExpenses.length ? _filteredExpenses.length : end,
    );
  }

  List<Expense> get allFiltered => _filteredExpenses;
  Set<String> get selectedReferences => _selectedReferences;
  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;
  int get totalItems => _filteredExpenses.length;
  int get totalPages =>
      (totalItems / _itemsPerPage).ceil() == 0 ? 1 : (totalItems / _itemsPerPage).ceil();
  bool get isLoading => _isLoading;
  List<String> get availableStatuses {
    final statuses = _allExpenses
        .map((exp) => exp.status.trim())
        .where((status) => status.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...statuses];
  }
  String get filterCategory => _filterCategory;
  String get filterStatus => _filterStatus;
  String get filterDebitAccount => _filterDebitAccount;
  String get filterReference => _filterReference;

  String resolveOptionLabel(
    List<Map<String, dynamic>> options,
    String? fallbackValue, {
    String? id,
  }) {
    final fallback = (fallbackValue ?? '').trim();
    final trimmedId = (id ?? '').trim();

    for (final option in options) {
      final optionId = option['id']?.toString().trim() ?? '';
      final optionName = option['name']?.toString().trim() ?? '';
      if (trimmedId.isNotEmpty && optionId == trimmedId && optionName.isNotEmpty) {
        return optionName;
      }
      if (fallback.isNotEmpty) {
        if (optionId == fallback && optionName.isNotEmpty) {
          return optionName;
        }
        if (optionName.toLowerCase() == fallback.toLowerCase()) {
          return optionName;
        }
      }
    }

    return fallback.isNotEmpty ? fallback : trimmedId;
  }


  void setCategoryOptionsFromMasterData(List<MasterDataValue> items) {
    final normalized = items
        .map(
          (item) => {
            'id': item.id.toString(),
            'name': item.description.trim().isNotEmpty
                ? item.description.trim()
                : item.value.trim(),
          },
        )
        .where(
          (item) =>
              (item['id']?.toString().isNotEmpty ?? false) &&
              (item['name']?.toString().isNotEmpty ?? false),
        )
        .toList();

    if (normalized.isEmpty) return;

    categoryOptions = normalized;
    debugPrint("📦 categoryOptions loaded: $categoryOptions");

    // Re-resolve category names for already-loaded expenses
    for (int i = 0; i < _allExpenses.length; i++) {
      final exp = _allExpenses[i];
      final resolved = resolveOptionLabel(
        categoryOptions,
        exp.category,
        id: exp.categoryId,
      );
      if (resolved != exp.category) {
        _allExpenses[i] = exp.copyWith(category: resolved);
      }
    }
    _applyFilters();
  }
  void setPaymentMethodOptionsFromMasterData(List<MasterDataValue> methods) {
    final normalized = methods
        .map(
          (method) => {
            'id': method.id.toString(),
            'name': method.description.trim().isNotEmpty
                ? method.description.trim()
                : method.value.trim(),
          },
        )
        .where(
          (item) =>
              (item['id']?.toString().isNotEmpty ?? false) &&
              (item['name']?.toString().isNotEmpty ?? false),
        )
        .toList();

    if (normalized.isEmpty) return;

    final merged = <String, Map<String, dynamic>>{};
    for (final item in paymentMethodOptions) {
      final id = item['id']?.toString();
      if (id != null && id.isNotEmpty) {
        merged[id] = {
          'id': id,
          'name': item['name']?.toString() ?? '',
        };
      }
    }
    for (final item in normalized) {
      merged[item['id']!] = item;
    }

    paymentMethodOptions = merged.values.toList();
    notifyListeners();
  }

  String get nextReferenceNumber {
    int maxNum = 0;
    for (var exp in _allExpenses) {
      final match = RegExp(r'EXP(\d+)').firstMatch(exp.referenceNumber);
      if (match != null) {
        final num = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (num > maxNum) {
          maxNum = num;
        }
      }
    }
    final nextNum = maxNum + 1;
    return 'EXP${nextNum.toString().padLeft(5, '0')}';
  }

  void setCategory(String category) {
    _filterCategory = category;
    _currentPage = 1;
    _applyFilters();
  }

  void setStatus(String status) {
    _filterStatus = status;
    _currentPage = 1;
    _applyFilters();
  }

  void setDebitAccount(String debitAccount) {
    _filterDebitAccount = debitAccount;
    _currentPage = 1;
    _applyFilters();
  }

  void setReference(String ref) {
    _filterReference = ref;
    _currentPage = 1;
    _applyFilters();
  }

  void _applyFilters() {
    _filteredExpenses = _allExpenses.where((exp) {
      if (_filterReference.isNotEmpty) {
        final q = _filterReference.toLowerCase();
        if (!exp.referenceNumber.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (_filterCategory != 'All') {
        if (exp.category != _filterCategory) {
          return false;
        }
      }
      if (_filterDebitAccount != 'All') {
        if (exp.debitAccount != _filterDebitAccount) {
          return false;
        }
      }
      if (_filterStatus != 'All') {
        if (exp.status != _filterStatus) {
          return false;
        }
      }
      return true;
    }).toList();
    notifyListeners();
  }

  void resetFilters() {
    _filterCategory = 'All';
    _filterStatus = 'All';
    _filterDebitAccount = 'All';
    _filterReference = '';
    _currentPage = 1;
    _filteredExpenses = List.from(_allExpenses);
    _selectedReferences.clear();
    notifyListeners();
  }

  void addExpense(Expense expense) {
    _allExpenses.insert(0, expense);
    _applyFilters();
  }

  void deleteExpense(String refNo) {
    _allExpenses.removeWhere((exp) => exp.referenceNumber == refNo);
    _selectedReferences.remove(refNo);
    _applyFilters();
  }

  void deleteBulkExpenses() {
    _allExpenses.removeWhere((exp) => _selectedReferences.contains(exp.referenceNumber));
    _selectedReferences.clear();
    _applyFilters();
  }

  void toggleSelectItem(String refNo) {
    if (_selectedReferences.contains(refNo)) {
      _selectedReferences.remove(refNo);
    } else {
      _selectedReferences.add(refNo);
    }
    notifyListeners();
  }

  void selectAllItems(bool select) {
    _selectedReferences.clear();
    if (select) {
      for (var exp in expenses) {
        _selectedReferences.add(exp.referenceNumber);
      }
    }
    notifyListeners();
  }

  bool isAllSelected() {
    final currentVisible = expenses;
    if (currentVisible.isEmpty) return false;
    return currentVisible.every((exp) => _selectedReferences.contains(exp.referenceNumber));
  }

  void setPage(int page) {
    if (page >= 1 && page <= totalPages) {
      _currentPage = page;
      notifyListeners();
    }
  }

  Future<void> fetchGeneralPayments({
    required String accessToken,
    String type = "EXPENSE",
  }) async {
    _isLoading = true;
    notifyListeners();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    final queryParams = {
      'type': type,
    };
    if (activeStoreId != null) {
      queryParams['store_id'] = activeStoreId.toString();
    }

    final uri = Uri.parse(APPUrl.listGeneralPayments).replace(queryParameters: queryParams);
    debugPrint("Fetching general payments from: $uri");

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

        List<dynamic> rawList = [];
        if (jsonData['data'] is List) {
          rawList = jsonData['data'];
        } else if (jsonData['data'] is Map && jsonData['data']['data'] is List) {
          rawList = jsonData['data']['data'];
        }

        _allExpenses.clear();
        for (var item in rawList) {
          final expense = Expense.fromJson(item);
          final resolvedCategory = resolveOptionLabel(
            categoryOptions,
            expense.category,
            id: expense.categoryId,
          );
          _allExpenses.add(expense.copyWith(category: resolvedCategory));
           debugPrint("🏷️ category raw: ${expense.category}, id: ${expense.categoryId}, resolved: $resolvedCategory");
        }
        _applyFilters();
      } else {
        debugPrint("Error loading general payments: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("Exception loading general payments: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, double>> getExpenseBreakdownForDate({
    required String accessToken,
    required int storeId,
    required String businessDate,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      final queryParams = <String, String>{
        'type': 'EXPENSE',
        'store_id': storeId.toString(),
      };

      final uri = Uri.parse(APPUrl.listGeneralPayments)
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey ?? '',
      });

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        List<dynamic> rawList = [];
        if (jsonData['data'] is List) {
          rawList = jsonData['data'];
        } else if (jsonData['data'] is Map &&
            jsonData['data']['data'] is List) {
          rawList = jsonData['data']['data'];
        }

        double cash = 0.0;
        double bank = 0.0;

        for (var item in rawList) {
          final expense = Expense.fromJson(item);
          final expDate =
              '${expense.paymentDate.year}-${expense.paymentDate.month.toString().padLeft(2, '0')}-${expense.paymentDate.day.toString().padLeft(2, '0')}';
          if (expDate == businessDate) {
            final credit = expense.creditAccount.toLowerCase();
            if (credit.contains('cash')) {
              cash += expense.amount;
            } else if (credit.contains('bank')) {
              bank += expense.amount;
            }
          }
        }

        return {'cash': cash, 'bank': bank, 'total': cash + bank};
      }
    } catch (e) {
      debugPrint('Error fetching expense breakdown: $e');
    }
    return {'cash': 0.0, 'bank': 0.0, 'total': 0.0};
  }

  Future<void> fetchAccountOptions({
    required String accessToken,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) return;

    final uri = Uri.parse(APPUrl.generalPaymentAccountOptions);
    debugPrint("Fetching account options from: $uri");

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
      );

      debugPrint("Account options status: ${response.statusCode}");
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final data = jsonData['data'] ?? jsonData;

        debitAccountOptions = _normalizeOptionList(
          _extractOptionList(
            data,
            const [
              'expense_accounts',
              'expenseAccounts',
              'debit_accounts',
              'debitAccounts',
              'expense_account_options',
            ],
          ),
        );

        creditAccountOptions = _normalizeOptionList(
          _extractOptionList(
            data,
            const [
              'payment_accounts',
              'paymentAccounts',
              'credit_accounts',
              'creditAccounts',
              'payment_account_options',
            ],
          ),
        );

        // Category options are managed purely from master data to avoid mixing accounts.
        
        // Payment methods for expense create should come only from master data.
        // Do not populate this list from account-options, otherwise account names
        // and payment methods can get mixed in the same dropdown.
        paymentMethodOptions = paymentMethodOptions
            .where(
              (item) =>
                  (item['id']?.toString().isNotEmpty ?? false) &&
                  (item['name']?.toString().isNotEmpty ?? false),
            )
            .toList();

        notifyListeners();
      }
    } catch (e) {
      debugPrint("Exception loading account options: $e");
    }
  }

  Future<Map<String, dynamic>> createGeneralPayment({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      return {'status': 'error', 'message': 'API key not found'};
    }

    final body = Map<String, dynamic>.from(payload);
    if (activeStoreId != null) {
      body['store_id'] = activeStoreId;
    }

    final uri = Uri.parse(APPUrl.createGeneralPayment);
    debugPrint("Creating general payment at: $uri");
    debugPrint("Payload: ${json.encode(body)}");

    try {
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
        body: json.encode(body),
      );

      debugPrint("Create general payment response: ${response.statusCode} - ${response.body}");
      final responseData = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchGeneralPayments(accessToken: accessToken, type: payload['entry_type'] ?? 'EXPENSE');
        return {
          'status': 'success',
          'message': responseData['message'] ?? 'Created successfully',
          'data': responseData['data']
        };
      } else {
        // Extract the first field-level error message if available (e.g. from 422 responses)
        final errors = responseData['errors'];
        String errorMessage = responseData['message'] ?? 'Server error ${response.statusCode}';
        if (errors is Map && errors.isNotEmpty) {
          final firstFieldErrors = errors.values.first;
          if (firstFieldErrors is List && firstFieldErrors.isNotEmpty) {
            errorMessage = firstFieldErrors.first.toString();
          }
        }
        return {
          'status': 'error',
          'message': errorMessage,
          'errors': errors,
        };
      }
    } catch (e) {
      debugPrint("Exception creating general payment: $e");
      return {'status': 'error', 'message': e.toString()};
    }
  }
}

List<dynamic> _extractOptionList(dynamic data, List<String> candidateKeys) {
  if (data is! Map<String, dynamic>) return const [];

  for (final key in candidateKeys) {
    final value = data[key];
    if (value is List) {
      return value;
    }
    if (value is Map<String, dynamic>) {
      final nestedList = _extractFirstList(value);
      if (nestedList.isNotEmpty) {
        return nestedList;
      }
    }
  }

  if (candidateKeys.isNotEmpty) return const [];
  return _extractFirstList(data);
}

List<dynamic> _extractFirstList(Map<String, dynamic> map) {
  for (final value in map.values) {
    if (value is List) {
      return value;
    }
  }
  return const [];
}

List<Map<String, dynamic>> _normalizeOptionList(List<dynamic> rawList) {
  final seen = <String>{};
  final normalized = <Map<String, dynamic>>[];

  for (final item in rawList) {
    final option = _normalizeOption(item);
    if (option == null) continue;
    final id = option['id']?.toString().trim() ?? '';
    final name = option['name']?.toString().trim() ?? '';
    if (id.isEmpty || name.isEmpty) continue;
    if (seen.add(id)) {
      normalized.add({
        'id': id,
        'name': name,
      });
    }
  }

  return normalized;
}

Map<String, dynamic>? _normalizeOption(dynamic raw) {
  if (raw is String || raw is num) {
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return {'id': text, 'name': text};
  }

  if (raw is! Map) return null;

  String? id;
  for (final key in const [
    'id',
    'value',
    'code',
    'category_id',
    'payment_method_id',
    'account_id',
  ]) {
    final value = raw[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      id = value.toString().trim();
      break;
    }
  }

  String? name;
  for (final key in const [
    'name',
    'description',
    'label',
    'title',
    'value',
    'category_name',
    'payment_method_name',
    'account_name',
  ]) {
    final value = raw[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      name = value.toString().trim();
      break;
    }
  }

  if ((id == null || id.isEmpty) && (name == null || name.isEmpty)) {
    return null;
  }

  return {
    'id': id ?? name!,
    'name': name ?? id!,
  };
}




