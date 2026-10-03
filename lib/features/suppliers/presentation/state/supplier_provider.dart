import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pos_machine/core/filters/balance_filter.dart';
import 'package:pos_machine/core/pagination/page_slice.dart';

import '../../data/supplier_api.dart';
import '../../data/supplier_repository.dart';
import '../../domain/models/supplier.dart';
import '../../domain/supplier_filter.dart';

/// App-wide supplier directory state: every supplier (kept for local search
/// and offline use), the filtered page shown on the suppliers list, and the
/// selected supplier.
///
/// Data access lives in [SupplierRepository]; filtering rules in
/// [SupplierFilter].
class SupplierProvider with ChangeNotifier {
  SupplierProvider({SupplierRepository? repository})
      : repository = repository ?? SupplierRepository();

  final SupplierRepository repository;

  static const int defaultItemsPerPage = 20;

  List<Supplier>? _supplierList = [];
  List<Supplier>? _allSuppliers = [];
  List<Supplier> _filteredSuppliers = [];
  bool _isLoading = false;
  Supplier? _selectedSupplier;
  String? _selectedSupplierName;
  String? _selectedSupplierId;

  int _currentPage = 1;
  int _totalPages = 1;
  final int _itemsPerPage = defaultItemsPerPage;
  SupplierFilter _filter = SupplierFilter.none;

  /// Suppliers on the current page of the filtered list.
  List<Supplier>? get supplierList => _supplierList;
  List<Supplier>? get allSuppliers => _allSuppliers;

  /// Every supplier matching [filter], across all pages (for export).
  List<Supplier> get filteredSuppliers =>
      List<Supplier>.unmodifiable(_filteredSuppliers);
  bool get hasFilteredSuppliers => _filteredSuppliers.isNotEmpty;
  bool get isLoading => _isLoading;
  Supplier? get selectedSupplier => _selectedSupplier;

  /// Supplier transaction report bindings.
  String? get selectedSupplierName => _selectedSupplierName;
  String? get selectedSupplierId => _selectedSupplierId;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get itemsPerPage => _itemsPerPage;

  /// The filter applied to the suppliers list.
  SupplierFilter get filter => _filter;

  // -------------------------------------------------------------- selection

  void selectSupplier(Supplier supplier) {
    _selectedSupplier = supplier;
    notifyListeners();
  }

  void clearSelectedSupplier() {
    _selectedSupplier = null;
    notifyListeners();
  }

  void setSelectedSupplierName(String supplierName) {
    _selectedSupplierName = supplierName;
    notifyListeners();
  }

  void clearSelectedSupplierName() {
    _selectedSupplierName = null;
    notifyListeners();
  }

  void setSelectedSupplierId(String? supplierId) {
    _selectedSupplierId = supplierId;
    notifyListeners();
  }

  void clearSelectedSupplierId() {
    _selectedSupplierId = null;
    notifyListeners();
  }

  // ------------------------------------------------------ filtering + pages

  /// Applies [filter] to every supplier and shows [page] of the result.
  void applyFilter(SupplierFilter filter, {int page = 1}) {
    final all = _allSuppliers;
    if (all == null || all.isEmpty) {
      _supplierList = [];
      _filteredSuppliers = [];
      _currentPage = 1;
      _totalPages = 1;
      notifyListeners();
      return;
    }

    _filter = filter;
    _filteredSuppliers = filter.apply(all);
    final slice =
        PageSlice.of(_filteredSuppliers, page: page, perPage: _itemsPerPage);
    _supplierList = slice.items;
    _currentPage = slice.currentPage;
    _totalPages = slice.totalPages;
    notifyListeners();
  }

  /// Legacy string-based form of [applyFilter].
  void applyFiltersLocally({
    String? supplierName,
    String? supplierEmail,
    String? supplierPhone,
    String? filterBalance,
    int page = 1,
  }) {
    applyFilter(
      SupplierFilter(
        name: supplierName ?? '',
        email: supplierEmail ?? '',
        phone: supplierPhone ?? '',
        balance: BalanceFilter.fromLegacy(filterBalance),
      ),
      page: page,
    );
  }

  void resetFilters() {
    _filter = SupplierFilter.none;
    applyFilter(SupplierFilter.none);
  }

  void goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    applyFilter(_filter, page: page);
  }

  // ---------------------------------------------------------------- loading

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Loads every supplier and re-applies the current filter (a
  /// [supplierName] replaces the name filter). Returns the visible page;
  /// an empty list when loading failed. Throws when no API key is stored.
  Future<List<Supplier>?> fetchSuppliers({
    required String accessToken,
    String? supplierName,
  }) async {
    _setLoading(true);
    try {
      final suppliers =
          await repository.fetchAll(accessToken, name: supplierName);
      if (suppliers == null) return [];
      _allSuppliers = suppliers;
      applyFilter(
        supplierName == null ? _filter : _filter.copyWith(name: supplierName),
        page: _currentPage,
      );
      debugPrint('Fetched ${_allSuppliers?.length ?? 0} suppliers');
      return _supplierList;
    } on HttpException catch (error) {
      // A missing API key is a setup problem the caller must surface.
      if (error.message == SupplierApi.missingApiKeyMessage) rethrow;
      debugPrint('Exception in fetchSuppliers: $error');
      return [];
    } catch (error) {
      debugPrint('Exception in fetchSuppliers: $error');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Supplier transactions for a report or a profile tab. Does not touch
  /// the list's loading state.
  Future<Map<String, dynamic>> fetchSupplierTransactions({
    required String accessToken,
    String? supplierName,
    String? supplierId,
    String? transactionType,
    String? fromDate,
    String? toDate,
    bool listAll = true,
    int? page,
  }) =>
      repository.fetchTransactions(
        accessToken,
        supplierName: supplierName,
        supplierId: supplierId,
        transactionType: transactionType,
        fromDate: fromDate,
        toDate: toDate,
        listAll: listAll,
        page: page,
      );

  // -------------------------------------------------------------- mutations

  /// Creates a supplier and reloads the directory on success.
  Future<Map<String, dynamic>> addSupplier({
    required String name,
    required String email,
    required String phone,
    required String accessToken,
    required String balance,
    required String paymentStatus,
    required String address,
    required String altPhone,
    List<int> productCategories = const [],
    String? taxNumber,
    List<SupplierKyc> kyc = const [],
  }) async {
    final response = await repository.create(
      accessToken,
      name: name,
      email: email,
      phone: phone,
      balance: balance,
      paymentStatus: paymentStatus,
      address: address,
      altPhone: altPhone,
      taxNumber: taxNumber,
      kyc: kyc,
    );
    if (response['status'] != 'error') {
      await fetchSuppliers(accessToken: accessToken);
    }
    return response;
  }

  /// Updates a supplier and reloads the directory on success.
  Future<Map<String, dynamic>> updateSupplier({
    required int id,
    required String name,
    required String phone,
    required String accessToken,
    required double balance,
    String? email,
    String? address,
    String? altPhone,
    String? paymentStatus,
    String? taxNumber,
    List<SupplierKyc>? kyc,
  }) async {
    final response = await repository.update(
      accessToken,
      id: id,
      name: name,
      phone: phone,
      balance: balance,
      email: email,
      address: address,
      altPhone: altPhone,
      paymentStatus: paymentStatus,
      taxNumber: taxNumber,
      kyc: kyc,
    );
    if (response['status'] != 'error') {
      await fetchSuppliers(accessToken: accessToken);
    }
    return response;
  }

  /// Clears the in-memory directory (offline data management).
  void clearCachedSuppliers() {
    _supplierList = [];
    _allSuppliers = [];
    _filteredSuppliers = [];
    _currentPage = 1;
    _totalPages = 1;
    _filter = SupplierFilter.none;
    notifyListeners();
    debugPrint('Cleared cached suppliers');
  }
}
