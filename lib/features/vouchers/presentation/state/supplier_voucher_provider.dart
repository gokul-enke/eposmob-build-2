import 'package:flutter/foundation.dart';
import '../../data/supplier_voucher_repository.dart';
import '../../data/voucher_payloads.dart';
import '../../domain/models/supplier_voucher.dart';
import '../../domain/voucher_filter.dart';

class SupplierVoucherProvider extends ChangeNotifier {
  SupplierVoucherProvider({SupplierVoucherRepository? repository})
      : repository = repository ?? SupplierVoucherRepository();
  final SupplierVoucherRepository repository;
  bool _isLoading = false;
  Future<void>? _voucherLoad;
  Object? _loadError;
  Object? get loadError => _loadError;
  List<SupplierVoucher>? _allVouchers;
  List<SupplierVoucher> _filteredVouchers = [];
  List<SupplierVoucher> get filteredVouchers =>
      List.unmodifiable(_filteredVouchers);
  List<SupplierVoucher>? voucherListDetails;

  // Pagination properties
  int _currentPage = 1;
  int _totalPages = 1;
  final int _itemsPerPage = 20;

  // Filter properties
  int? _filterSupplierId;
  String? _filterVoucherNumber;
  String? _filterType;
  String? _filterStatus;

  // Getters
  bool get isLoading => _isLoading;
  List<SupplierVoucher>? get allVouchers => _allVouchers;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get itemsPerPage => _itemsPerPage;

  // Status options
  List<String> getStatusOptions() {
    return ['All Status', 'paid', 'pending', 'cancelled'];
  }

  // Type options
  List<String> getTypeOptions() {
    return ['All Types', 'order', 'other', 'refund', 'adjustment'];
  }

  // Pagination navigation
  void goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    applyFiltersLocally(
      filterSupplierId: _filterSupplierId,
      filterVoucherNumber: _filterVoucherNumber,
      filterType: _filterType,
      filterStatus: _filterStatus,
      page: page,
    );
  }

  // Apply filters
  void applyFilters({
    int? supplierId,
    String? voucherNumber,
    String? type,
    String? status,
    int page = 1,
  }) {
    _filterSupplierId = supplierId;
    _filterVoucherNumber = voucherNumber;
    _filterType = type;
    _filterStatus = status;
    _currentPage = page;

    applyFiltersLocally(
      filterSupplierId: supplierId,
      filterVoucherNumber: voucherNumber,
      filterType: type,
      filterStatus: status,
      page: page,
    );
  }

  // Reset filters
  void resetFilters() {
    _filterSupplierId = null;
    _filterVoucherNumber = null;
    _filterType = null;
    _filterStatus = null;
    _currentPage = 1;
    applyFiltersLocally(page: 1);
  }

  // Apply filters locally
  void applyFiltersLocally({
    int? filterSupplierId,
    String? filterVoucherNumber,
    String? filterType,
    String? filterStatus,
    int page = 1,
  }) {
    if (_allVouchers == null || _allVouchers!.isEmpty) {
      voucherListDetails = [];
      _filteredVouchers = [];
      _currentPage = 1;
      _totalPages = 1;
      notifyListeners();
      return;
    }

    final filteredVouchers = filterSupplierVouchers(_allVouchers!,
        filterSupplierId: filterSupplierId,
        filterVoucherNumber: filterVoucherNumber,
        filterType: filterType,
        filterStatus: filterStatus);
    _filteredVouchers = List.of(filteredVouchers);

    // Update total pages
    _totalPages = (filteredVouchers.length / _itemsPerPage).ceil();
    _totalPages = _totalPages == 0 ? 1 : _totalPages;

    // Adjust current page if it's out of bounds
    if (page > _totalPages) {
      _currentPage = _totalPages;
    } else {
      _currentPage = page;
    }

    // Paginate
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;

    if (startIndex >= filteredVouchers.length) {
      voucherListDetails = [];
    } else {
      endIndex = endIndex > filteredVouchers.length
          ? filteredVouchers.length
          : endIndex;
      voucherListDetails = filteredVouchers.sublist(startIndex, endIndex);
    }

    notifyListeners();
  }

  // Refresh clicks share one load; only that load owns the loading flag.
  Future<void> listAllSupplierVouchers({required String accessToken}) =>
      _voucherLoad ??= _loadSupplierVouchers(accessToken: accessToken)
          .whenComplete(() => _voucherLoad = null);

  Future<void> _loadSupplierVouchers({required String accessToken}) async {
    _loadError = null;
    _isLoading = true;
    notifyListeners();
    try {
      _allVouchers = await repository.fetch(accessToken);
      applyFiltersLocally(
          filterSupplierId: _filterSupplierId,
          filterVoucherNumber: _filterVoucherNumber,
          filterType: _filterType,
          filterStatus: _filterStatus,
          page: 1);
    } catch (e) {
      _allVouchers = [];
      _filteredVouchers = [];
      voucherListDetails = [];
      _currentPage = 1;
      _totalPages = 1;
      _loadError = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createVoucher({
    required int supplierId,
    required String type,
    required double amount,
    required String voucherDate,
    required String dueDate,
    required String status,
    required int? paymentMethodId,
    required List<Map<String, dynamic>> voucherItems,
    required String accessToken,
  }) async {
    _isLoading = true;
    notifyListeners();
    final tenant = await repository.requireTenant();
    try {
      final result = await repository.create(
          accessToken,
          tenant,
          supplierVoucherPayload(
              type: type,
              amount: amount,
              voucherDate: voucherDate,
              dueDate: dueDate,
              status: status,
              paymentMethodId: paymentMethodId,
              voucherItems: voucherItems,
              supplierId: supplierId));
      if (result['success'] == true) {
        await _voucherLoad;
        await listAllSupplierVouchers(accessToken: accessToken);
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': 'Error creating voucher: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
