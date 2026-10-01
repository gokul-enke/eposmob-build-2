import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/filters/balance_filter.dart';
import 'package:pos_machine/core/utils/search_debouncer.dart';

import '../../domain/supplier_filter.dart';
import '../export/supplier_excel_export.dart';
import 'supplier_provider.dart';

/// Screen-scoped state of the suppliers list: the search inputs (typing is
/// debounced), whether the filter panel is shown, and the export.
///
/// The applied filter lives in [SupplierProvider]; this controller starts
/// from it so coming back to the page shows the same inputs.
class SupplierListController extends ChangeNotifier {
  SupplierListController(
    this._provider, {
    required bool filtersVisible,
    Duration debounce = const Duration(milliseconds: 300),
    ExportController? export,
  })  : _filtersVisible = filtersVisible,
        export = export ?? ExportController(),
        nameController = TextEditingController(text: _provider.filter.name),
        emailController = TextEditingController(text: _provider.filter.email),
        phoneController = TextEditingController(text: _provider.filter.phone),
        _balance = _provider.filter.balance {
    _search = SearchDebouncer(search, delay: debounce);
    for (final input in [nameController, emailController, phoneController]) {
      input.addListener(notifyListeners);
    }
  }

  final SupplierProvider _provider;
  final ExportController export;
  late final SearchDebouncer _search;

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  BalanceFilter _balance;
  bool _filtersVisible;

  BalanceFilter get balance => _balance;
  bool get filtersVisible => _filtersVisible;

  /// Something is typed or selected (shown as a dot while hidden).
  bool get hasActiveFilter => !currentFilter.isEmpty;

  SupplierFilter get currentFilter => SupplierFilter(
        name: nameController.text,
        email: emailController.text,
        phone: phoneController.text,
        balance: _balance,
      );

  bool get canExport =>
      !export.busy && !_provider.isLoading && _hasMatchesForExport;

  bool get _hasMatchesForExport =>
      currentFilter.apply(_provider.allSuppliers ?? const []).isNotEmpty;

  /// Applies the inputs after the debounce (call on every keystroke).
  void scheduleSearch() => _search.schedule();

  /// Applies the inputs now, back on page 1.
  void search() {
    _search.cancel();
    _provider.applyFilter(currentFilter);
  }

  void setBalance(BalanceFilter? value) {
    _balance = value ?? BalanceFilter.all;
    notifyListeners();
    search();
  }

  void toggleFilters() {
    _filtersVisible = !_filtersVisible;
    notifyListeners();
  }

  void reset() {
    _search.cancel();
    nameController.clear();
    emailController.clear();
    phoneController.clear();
    _balance = BalanceFilter.all;
    notifyListeners();
    _provider.resetFilters();
  }

  /// Reloads every supplier and re-applies the visible inputs (including
  /// a search still waiting on the debounce) on the current page.
  Future<void> refresh(String accessToken) async {
    _search.cancel();
    await _provider.fetchSuppliers(accessToken: accessToken);
    _provider.applyFilter(currentFilter, page: _provider.currentPage);
  }

  /// Applies the visible inputs without leaving the current page, so an
  /// export sees exactly what is typed.
  void applyInputsInPlace() {
    _search.cancel();
    _provider.applyFilter(currentFilter, page: _provider.currentPage);
  }

  /// Creates the Excel file of every matching supplier (all pages).
  Future<File> createExportFile() {
    applyInputsInPlace();
    return SupplierExcelExport.createFile(_provider.filteredSuppliers);
  }

  @override
  void dispose() {
    _search.dispose();
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    export.dispose();
    super.dispose();
  }
}
