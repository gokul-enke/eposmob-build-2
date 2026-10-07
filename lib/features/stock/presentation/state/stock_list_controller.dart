import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/stock_list_query.dart';

/// Owns only the list page's inputs and initialization; shared stock mutations
/// and filtering retain the existing provider implementation.
class StockListController extends ChangeNotifier {
  StockListController(
      {required this.ensureCategories,
      required this.fetchStocks,
      required this.fetchStores,
      required this.readCategoryNames,
      required this.readStoreNames,
      required this.applyFilters,
      required this.resetFilters,
      required this.readVariantEnabled});
  final Future<void> Function() ensureCategories;
  final Future<void> Function(String) fetchStocks, fetchStores;
  final Iterable<String> Function() readCategoryNames, readStoreNames;
  final void Function(StockListQuery) applyFilters;
  final VoidCallback resetFilters;
  final bool Function() readVariantEnabled;
  final stockNameController = TextEditingController();
  final categoryController = TextEditingController(text: 'All Categories');
  final barcodeController = TextEditingController();
  final rackController = TextEditingController();
  final storeController = TextEditingController(text: 'All Stores');
  final stockStatusController = TextEditingController(text: 'All Statuses');
  bool loading = false, initialized = false, showFilters = false;
  bool _disposed = false;
  Timer? _searchTimer;
  Object? loadError;
  StockListQuery? appliedQuery;
  List<String> categories = ['All Categories'];
  List<String> stores = ['All Stores'];

  bool get hasActiveFilters =>
      stockNameController.text.isNotEmpty ||
      categoryController.text != 'All Categories' ||
      barcodeController.text.isNotEmpty ||
      rackController.text.isNotEmpty ||
      storeController.text != 'All Stores' ||
      stockStatusController.text != 'All Statuses';
  StockListQuery get query => StockListQuery(
      name: stockNameController.text,
      category: categoryController.text == 'All Categories'
          ? null
          : categoryController.text,
      barcode: barcodeController.text.isEmpty ? null : barcodeController.text,
      rack: rackController.text.isEmpty ? null : rackController.text,
      store: storeController.text == 'All Stores' ? null : storeController.text,
      status: stockStatusController.text == 'All Statuses'
          ? null
          : stockStatusController.text,
      includeVariants: readVariantEnabled());

  Future<void> load(String token) async {
    if (_disposed || loading) return;
    if (token.isEmpty) throw StateError('stock.auth_token_missing');
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      await ensureCategories();
      if (_disposed) return;
      await fetchStocks(token);
      if (_disposed) return;
      // The stock loader replaces the visible page with unfiltered rows.
      // Restore the inputs before another request can fail or keep us waiting.
      search();
      await fetchStores(token);
      if (_disposed) return;
      final categoryNames =
          readCategoryNames().where((name) => name.isNotEmpty).toList()..sort();
      final storeNames = readStoreNames()
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      categories = ['All Categories', ...categoryNames];
      stores = ['All Stores', ...storeNames];
      initialized = true;
      search();
    } catch (error) {
      if (!_disposed) loadError = error;
      rethrow;
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void search() {
    _searchTimer?.cancel();
    _searchTimer = null;
    if (_disposed) return;
    appliedQuery = query;
    applyFilters(appliedQuery!);
    notifyListeners();
  }

  void scheduleSearch() {
    if (_disposed) return;
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), search);
    notifyListeners();
  }

  bool flushSearch() {
    if (_searchTimer == null) return false;
    search();
    return true;
  }

  void reset() {
    if (_disposed) return;
    _searchTimer?.cancel();
    _searchTimer = null;
    stockNameController.clear();
    categoryController.text = 'All Categories';
    barcodeController.clear();
    rackController.clear();
    storeController.text = 'All Stores';
    stockStatusController.text = 'All Statuses';
    appliedQuery = query;
    resetFilters();
    notifyListeners();
  }

  void mutate(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  void setFiltersVisible(bool value) => mutate(() => showFilters = value);
  @override
  void dispose() {
    _disposed = true;
    _searchTimer?.cancel();
    for (final input in [
      stockNameController,
      categoryController,
      barcodeController,
      rackController,
      storeController,
      stockStatusController,
    ]) {
      input.dispose();
    }
    super.dispose();
  }
}
