import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/balance_filter.dart';
import '../../domain/customer_filter.dart';
import '../../domain/models/customer_list.dart';
import '../export/customer_excel_export.dart';
import 'customer_provider.dart';

/// Exports a list of customers (writes and shares a file).
typedef CustomerExporter = Future<void> Function(
  List<CustomerListModelData> customers,
);

/// Screen-scoped state of the customers list: the search inputs, whether
/// the filter panel is shown, and the export in progress.
///
/// The applied filter itself lives in [CustomerProvider] (it outlives the
/// screen); this controller starts from it, so coming back to the page shows
/// the same inputs as the filtered list. Typing is debounced before the
/// filter is applied; Enter and dropdown changes apply at once.
class CustomerListController extends ChangeNotifier {
  CustomerListController(
    this._provider, {
    this.debounce = const Duration(milliseconds: 300),
    CustomerExporter? exporter,
  })  : _exporter = exporter ?? CustomerExcelExport.exportAndShare,
        nameController = TextEditingController(text: _provider.filter.name),
        emailController = TextEditingController(text: _provider.filter.email),
        phoneController = TextEditingController(text: _provider.filter.phone),
        _balance = _provider.filter.balance;

  final CustomerProvider _provider;
  final Duration debounce;
  final CustomerExporter _exporter;

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  BalanceFilter _balance;
  Timer? _debounceTimer;

  BalanceFilter get balance => _balance;

  bool _filtersVisible = true;
  bool _isExporting = false;

  /// Whether the filter panel is shown. Hiding it keeps the filter applied.
  bool get filtersVisible => _filtersVisible;

  /// A filter is applied to the list (shown as a dot while the panel is
  /// hidden).
  bool get hasActiveFilter => !_provider.filter.isEmpty;

  bool get isExporting => _isExporting;

  /// Export needs at least one matching customer and no export running.
  bool get canExport => !_isExporting && _provider.filteredCustomers.isNotEmpty;

  void toggleFilters() {
    _filtersVisible = !_filtersVisible;
    notifyListeners();
  }

  /// Exports every customer matching the current filter (all pages).
  /// Returns false when nothing was exported because it failed.
  Future<bool> export() async {
    if (!canExport) return true;
    _isExporting = true;
    notifyListeners();
    try {
      await _exporter(_provider.filteredCustomers);
      return true;
    } catch (error) {
      debugPrint('Customer export failed: $error');
      return false;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  CustomerFilter get currentFilter => CustomerFilter(
        name: nameController.text,
        email: emailController.text,
        phone: phoneController.text,
        balance: _balance,
      );

  /// Applies the inputs after [debounce] (call on every keystroke).
  void scheduleSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, search);
  }

  /// Applies the inputs now, back on page 1.
  void search() {
    _debounceTimer?.cancel();
    _provider.applyFilter(currentFilter);
  }

  void setBalance(BalanceFilter? value) {
    _balance = value ?? BalanceFilter.all;
    notifyListeners();
    search();
  }

  void reset() {
    _debounceTimer?.cancel();
    nameController.clear();
    emailController.clear();
    phoneController.clear();
    _balance = BalanceFilter.all;
    notifyListeners();
    _provider.resetFilters();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }
}
