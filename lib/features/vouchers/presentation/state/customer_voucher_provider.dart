import 'package:flutter/foundation.dart';
import '../../data/customer_voucher_repository.dart';
import '../../data/voucher_payloads.dart';
import '../../domain/models/customer_voucher.dart';
import '../../domain/voucher_filter.dart';

class CustomerVoucherProvider extends ChangeNotifier {
  CustomerVoucherProvider({CustomerVoucherRepository? repository})
      : repository = repository ?? CustomerVoucherRepository();
  final CustomerVoucherRepository repository;
  bool _isLoading = false;
  Object? loadError;
  int _loadGeneration = 0;
  List<CustomerVoucher>? _allVouchers;
  List<CustomerVoucher>? voucherListDetails;

  // Pagination properties
  int _currentPage = 1;
  int _totalPages = 1;
  int _itemsPerPage = 20;

  // Filter properties
  String? _filterCustomerName;
  String? _filterVoucherNumber;
  String? _filterType;
  String? _filterStatus;
  String? _filterDateFrom;
  String? _filterDateTo;
  String? _lastAccessToken;

  // Getters
  bool get isLoading => _isLoading;
  List<CustomerVoucher>? get allVouchers => _allVouchers;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get itemsPerPage => _itemsPerPage;

  // Status options
  List<String> getStatusOptions() {
    return ['All Status', 'paid', 'pending', 'cancelled'];
  }

  // Type options
  List<String> getTypeOptions() {
    return [
      'All Types',
      ...{
        'other',
        'refund',
        'adjustment',
        for (final v in _allVouchers ?? <CustomerVoucher>[])
          if (v.type.isNotEmpty) v.type
      }
    ];
  }

  // Pagination navigation
  void goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    applyFiltersLocally(
      filterCustomerName: _filterCustomerName,
      filterVoucherNumber: _filterVoucherNumber,
      filterType: _filterType,
      filterStatus: _filterStatus,
      page: page,
    );
  }

  // Apply filters
  void applyFilters({
    String? customerName,
    String? voucherNumber,
    String? type,
    String? status,
    String? dateFrom,
    String? dateTo,
    int page = 1,
  }) {
    final datesChanged = dateFrom != _filterDateFrom || dateTo != _filterDateTo;
    _filterCustomerName = customerName;
    _filterVoucherNumber = voucherNumber;
    _filterType = type;
    _filterStatus = status;
    _filterDateFrom = dateFrom;
    _filterDateTo = dateTo;
    _currentPage = page;

    if (datesChanged && _lastAccessToken != null) {
      listAllCustomerVouchers(accessToken: _lastAccessToken!);
    } else {
      applyFiltersLocally(
        filterCustomerName: customerName,
        filterVoucherNumber: voucherNumber,
        filterType: type,
        filterStatus: status,
        page: page,
      );
    }
  }

  // Reset filters
  void resetFilters() {
    _filterCustomerName = null;
    _filterVoucherNumber = null;
    _filterType = null;
    _filterStatus = null;
    _filterDateFrom = null;
    _filterDateTo = null;
    _currentPage = 1;
    if (_lastAccessToken != null) {
      listAllCustomerVouchers(accessToken: _lastAccessToken!);
    } else {
      applyFiltersLocally(page: 1);
    }
  }

  // Apply filters locally
  void applyFiltersLocally({
    String? filterCustomerName,
    String? filterVoucherNumber,
    String? filterType,
    String? filterStatus,
    int page = 1,
  }) {
    if (_allVouchers == null || _allVouchers!.isEmpty) {
      voucherListDetails = [];
      _currentPage = 1;
      _totalPages = 1;
      notifyListeners();
      return;
    }

    final filteredVouchers = filterForExport(
        customerName: filterCustomerName,
        voucherNumber: filterVoucherNumber,
        type: filterType,
        status: filterStatus);

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

  List<CustomerVoucher> filterForExport(
          {String? customerName,
          String? voucherNumber,
          String? type,
          String? status}) =>
      filterCustomerVouchers(_allVouchers ?? [],
          customerName: customerName,
          voucherNumber: voucherNumber,
          type: type,
          status: status);
  Future<void> listAllCustomerVouchers({required String accessToken}) async {
    final generation = ++_loadGeneration;
    loadError = null;
    _lastAccessToken = accessToken;
    _isLoading = true;
    notifyListeners();
    try {
      final rows = await repository.fetch(accessToken,
          dateFrom: _filterDateFrom, dateTo: _filterDateTo);
      if (generation != _loadGeneration) return;
      _allVouchers = rows;
      applyFiltersLocally(
          filterCustomerName: _filterCustomerName,
          filterVoucherNumber: _filterVoucherNumber,
          filterType: _filterType,
          filterStatus: _filterStatus,
          page: 1);
    } catch (e) {
      if (generation == _loadGeneration) loadError = e;
    } finally {
      if (generation == _loadGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<Map<String, dynamic>> createVoucher({
    required String type,
    required double amount,
    required String voucherDate,
    required String dueDate,
    required String status,
    required int? paymentMethodId,
    required int customerId,
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
          customerVoucherPayload(
              type: type,
              amount: amount,
              voucherDate: voucherDate,
              dueDate: dueDate,
              status: status,
              paymentMethodId: paymentMethodId,
              voucherItems: voucherItems,
              customerId: customerId));
      if (result['success'] == true) {
        await listAllCustomerVouchers(accessToken: accessToken);
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': 'Error creating voucher: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<dynamic> zatcaPhase2VoucherPrint(
          {required int id, required String accessToken}) =>
      repository.zatcaPrint(id, accessToken);
  Future<dynamic> zatcaPhase2VoucherResync(
          {required int id, required String accessToken}) =>
      repository.zatcaResync(id, accessToken);
}
