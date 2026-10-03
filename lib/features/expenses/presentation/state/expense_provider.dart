import 'package:flutter/foundation.dart';
import 'package:pos_machine/models/master_data.dart';
import '../../domain/models/expense.dart';
import '../../domain/expense_options.dart';
import '../../data/expense_repository.dart';

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
  Object? _loadError;
  int _loadGeneration = 0;
  Object? get loadError => _loadError;

  List<Map<String, dynamic>> categoryOptions = [];
  List<Map<String, dynamic>> debitAccountOptions = [];
  List<Map<String, dynamic>> creditAccountOptions = [];
  List<Map<String, dynamic>> paymentMethodOptions = [];

  final ExpenseRepository repository;

  ExpenseProvider({ExpenseRepository? repository}) : repository = repository ?? ExpenseRepository() {
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
    _currentPage = _currentPage.clamp(1, totalPages);
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
    final generation = ++_loadGeneration;
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final staged = await repository.fetchGeneralPayments(accessToken: accessToken, type: type, isCurrent: () => generation == _loadGeneration);
      if (staged == null || generation != _loadGeneration) return;
      final resolved = staged
          .map((expense) => expense.copyWith(
                category: resolveOptionLabel(categoryOptions, expense.category,
                    id: expense.categoryId),
              ))
          .toList();
      _allExpenses
        ..clear()
        ..addAll(resolved);
      _applyFilters();
    } catch (error) {
      if (generation == _loadGeneration) _loadError = error;
    } finally {
      if (generation == _loadGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<Map<String, double>> getExpenseBreakdownForDate({required String accessToken, required int storeId, required String businessDate}) => repository.getExpenseBreakdownForDate(accessToken: accessToken, storeId: storeId, businessDate: businessDate);

  Future<void> fetchAccountOptions({required String accessToken}) async {
    try {
      final data = await repository.fetchAccountOptions(accessToken: accessToken);
      if (data == null) return;
        debitAccountOptions = normalizeExpenseOptionList(
          extractExpenseOptionList(
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

        creditAccountOptions = normalizeExpenseOptionList(
          extractExpenseOptionList(
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
    } catch (e) { debugPrint("Exception loading account options: $e"); }
  }
  Future<Map<String, dynamic>> createGeneralPayment({required String accessToken, required Map<String, dynamic> payload}) async {
    final result = await repository.createGeneralPayment(accessToken: accessToken, payload: payload);
    if (result['status'] == 'success') {
      await fetchGeneralPayments(accessToken: accessToken, type: payload['entry_type'] ?? 'EXPENSE');
    }
    return result;
  }
}
