import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pos_machine/core/pagination/page_slice.dart';

import '../../data/customer_api.dart';
import '../../data/customer_repository.dart';
import 'package:pos_machine/core/filters/balance_filter.dart';
import '../../domain/customer_filter.dart';
import '../../domain/models/customer_list.dart';

export '../../data/customer_api.dart' show CustomerHttpGet;

/// App-wide customer directory state: the full customer list (kept for
/// local search and offline use), the filtered page shown on the customers
/// list, and the selected customer.
///
/// Data access lives in [CustomerRepository]; filtering rules in
/// [CustomerFilter]. Screens that only need a one-off lookup should use the
/// repository directly instead of creating a provider.
class CustomerProvider extends ChangeNotifier {
  CustomerProvider({
    CustomerHttpGet? httpGet,
    CustomerRepository? repository,
  }) : repository = repository ??
            CustomerRepository(api: CustomerApi(httpGet: httpGet));

  final CustomerRepository repository;

  static const int defaultItemsPerPage = 20;

  /// Customers on the current page of the filtered list.
  List<CustomerListModelData>? customerList = [];
  List<CustomerListModelData>? _allCustomers = [];
  CustomerListModelData? selectedCustomer;

  /// Report dropdown bindings.
  String? selectedCustomerId;
  String? selectedCustomerName;

  int _currentPage = 1;
  int _totalPages = 1;
  final int _itemsPerPage = defaultItemsPerPage;
  CustomerFilter _filter = CustomerFilter.none;
  bool _isLoading = false;

  List<CustomerListModelData>? get getCustomerList => customerList;
  List<CustomerListModelData>? get allCustomers => _allCustomers;
  CustomerListModelData? get getSelectedCustomer => selectedCustomer;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get itemsPerPage => _itemsPerPage;
  bool get isLoading => _isLoading;

  /// The filter applied to the customers list.
  CustomerFilter get filter => _filter;

  /// Every customer matching [filter], across all pages (for export).
  List<CustomerListModelData> get filteredCustomers =>
      _filter.apply(_allCustomers ?? const []);

  // -------------------------------------------------------------- selection

  void selectCustomer(CustomerListModelData customer) {
    selectedCustomer = customer;
    selectedCustomerId = customer.id?.toString();
    selectedCustomerName = customer.name;
    notifyListeners();
  }

  void setSelectedCustomerId(String? id) {
    selectedCustomerId = id;
    notifyListeners();
  }

  void setSelectedCustomerName(String? name) {
    selectedCustomerName = name;
    notifyListeners();
  }

  void _clearSelection() {
    selectedCustomer = null;
    selectedCustomerId = null;
    selectedCustomerName = null;
  }

  // ------------------------------------------------------ filtering + pages

  /// Applies [filter] to the full directory and shows [page] of the result.
  void applyFilter(CustomerFilter filter, {int page = 1}) {
    final all = _allCustomers;
    if (all == null || all.isEmpty) {
      customerList = [];
      _currentPage = 1;
      _totalPages = 1;
      notifyListeners();
      return;
    }

    _filter = filter;
    final slice = PageSlice.of(
      filter.apply(all),
      page: page,
      perPage: _itemsPerPage,
    );
    customerList = slice.items;
    _currentPage = slice.currentPage;
    _totalPages = slice.totalPages;
    notifyListeners();
  }

  /// Legacy string-based form of [applyFilter].
  void applyFiltersLocally({
    String? filterName,
    String? filterEmail,
    String? filterPhone,
    String? filterBalance,
    int page = 1,
  }) {
    applyFilter(
      CustomerFilter(
        name: filterName ?? '',
        email: filterEmail ?? '',
        phone: filterPhone ?? '',
        balance: BalanceFilter.fromLegacy(filterBalance),
      ),
      page: page,
    );
  }

  void _reapplyFilter({String? name, String? email, String? phone}) {
    applyFilter(
      _filter.copyWith(name: name, email: email, phone: phone),
      page: _currentPage,
    );
  }

  void resetFilters() {
    _filter = CustomerFilter.none;
    _currentPage = 1;
    if (_allCustomers != null && _allCustomers!.isNotEmpty) {
      applyFilter(CustomerFilter.none);
    }
  }

  void goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    applyFilter(_filter, page: page);
  }

  // ---------------------------------------------------------------- loading

  /// Loads one server page, or with [loadAll] the full directory (which is
  /// then filtered and paged locally). Returns the legacy response map.
  Future<dynamic> listCustomer({
    required String accessToken,
    String? filterName,
    String? filterEmail,
    String? filterPhone,
    String? filterAgeRange,
    bool sortAscending = false,
    int page = 1,
    bool loadAll = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    final result = await repository.list(
      accessToken,
      CustomerQuery(
        name: filterName,
        email: filterEmail,
        phone: filterPhone,
        ageRange: filterAgeRange,
        sortAscending: sortAscending,
        page: page,
        loadAll: loadAll,
      ),
    );

    switch (result) {
      case CustomerDirectoryLoaded(:final customers):
        _allCustomers = customers;
        _reapplyFilter(
            name: filterName, email: filterEmail, phone: filterPhone);
      case CustomerPageLoaded(:final customers):
        customerList = customers;
      case CustomerListFailed():
        break;
    }

    _isLoading = false;
    notifyListeners();
    return result.legacyResponse;
  }

  /// Loads the full directory for local filtering.
  Future<void> loadAllCustomers(String accessToken) async {
    await listCustomer(accessToken: accessToken, loadAll: true);
  }

  /// Lightweight load for dropdowns.
  Future<void> fetchCustomers({
    required String accessToken,
    String? customerName,
    bool listAll = true,
  }) async {
    await listCustomer(
      accessToken: accessToken,
      filterName: customerName,
      page: 1,
      loadAll: listAll,
    );
    notifyListeners();
  }

  /// A complete, sorted customer snapshot for a screen that keeps its own
  /// list. Does not change this provider's state or notify listeners.
  Future<List<CustomerListModelData>> fetchAllCustomersSnapshot({
    required String accessToken,
  }) =>
      repository.snapshot(accessToken);

  /// Refreshes the shared directory after a customer was created or
  /// updated, so search, billing and quotation selectors see it at once.
  Future<void> refreshAfterMutation(String accessToken) async {
    if (accessToken.trim().isEmpty) return;
    await loadAllCustomers(accessToken);
  }

  /// [refreshAfterMutation] without delaying the caller.
  void refreshAfterMutationInBackground(String accessToken) {
    final normalizedToken = accessToken.trim();
    if (normalizedToken.isEmpty) return;

    unawaited(Future<void>(() async {
      try {
        await refreshAfterMutation(normalizedToken);
      } catch (error) {
        debugPrint(
          '[CustomerProvider] Background refresh after mutation failed: $error',
        );
      }
    }));
  }

  /// Re-fetches [customerId] and makes it the selected customer.
  Future<dynamic> reloadSelectedCustomer(
    String accessToken,
    int customerId,
  ) async {
    final result = await repository.fetchById(accessToken, customerId);
    final customer = result.customer;
    if (customer != null) {
      selectedCustomer = customer;
      notifyListeners();
    }
    return result.response;
  }

  // --------------------------------------------------------- cache / sync

  /// Clears the cached and in-memory directory. Login stays intact.
  Future<void> clearCachedCustomers() async {
    await repository.clearCache();
    customerList = [];
    _allCustomers = [];
    _clearSelection();
    _currentPage = 1;
    _totalPages = 1;
    _filter = CustomerFilter.none;
    notifyListeners();
    debugPrint('Cleared cached customers');
  }

  /// Replaces the directory with [customers] from realtime sync, keeping
  /// the current filter, page and (when it still exists) selection.
  Future<void> applyRealtimeCustomers(
    List<CustomerListModelData> customers, {
    required int? storeId,
  }) async {
    _allCustomers = List<CustomerListModelData>.from(customers);

    final selectedId = selectedCustomer?.id;
    if (selectedId != null) {
      final match =
          _allCustomers!.where((customer) => customer.id == selectedId);
      if (match.isEmpty) {
        _clearSelection();
      } else {
        selectedCustomer = match.first;
        selectedCustomerId = match.first.id?.toString();
        selectedCustomerName = match.first.name;
      }
    }

    applyFilter(_filter, page: _currentPage);
    await repository.saveToCache(storeId, _allCustomers!);
    notifyListeners();
  }

  /// Upserts [changedCustomers] and removes [deletedCustomerIds].
  Future<void> mergeRealtimeCustomers(
    List<CustomerListModelData> changedCustomers, {
    required int? storeId,
    required Set<int> deletedCustomerIds,
  }) async {
    final merged = List<CustomerListModelData>.from(_allCustomers ?? const []);
    final indexById = <int, int>{};
    for (var i = 0; i < merged.length; i++) {
      final id = merged[i].id;
      if (id != null) indexById[id] = i;
    }
    for (final customer in changedCustomers) {
      final id = customer.id;
      final index = id == null ? null : indexById[id];
      if (index == null) {
        merged.add(customer);
        if (id != null) indexById[id] = merged.length - 1;
      } else {
        merged[index] = customer;
      }
    }
    if (deletedCustomerIds.isNotEmpty) {
      merged.removeWhere(
        (customer) =>
            customer.id != null && deletedCustomerIds.contains(customer.id),
      );
    }
    await applyRealtimeCustomers(merged, storeId: storeId);
  }
}
