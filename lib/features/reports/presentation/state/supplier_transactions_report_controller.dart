import 'package:flutter/material.dart';
import '../../domain/supplier_report.dart';

typedef SupplierReportFetch = Future<Map<String, dynamic>> Function(
    SupplierReportQuery query, int page);

/// Owns report inputs, directory snapshot, pagination and request generations.
class SupplierTransactionsReportController extends ChangeNotifier {
  SupplierTransactionsReportController(
      {required this.fetchDirectory, required this.fetch});
  final Future<List<SupplierReportOption>> Function() fetchDirectory;
  final SupplierReportFetch fetch;
  final supplierInput = TextEditingController();
  final fromInput = TextEditingController();
  final toInput = TextEditingController();
  List<SupplierReportOption> suppliers = const [];
  Map<String, SupplierTransactionSummary> rows = const {};
  String? selectedSupplierId;
  int page = 1, pages = 1, _request = 0, _directoryRequest = 0;
  bool initializing = false,
      loading = false,
      showFilters = true,
      _disposed = false;
  String? errorKey;
  Object? error;
  int errorRevision = 0;
  bool get hasActiveFilters =>
      supplierInput.text.isNotEmpty ||
      fromInput.text.isNotEmpty ||
      toInput.text.isNotEmpty ||
      selectedSupplierId != null;
  SupplierReportQuery get query => SupplierReportQuery(
      supplierId: selectedSupplierId,
      fromDate: fromInput.text.isEmpty ? null : fromInput.text,
      toDate: toInput.text.isEmpty ? null : toInput.text);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setFiltersVisible(bool value) {
    if (_disposed) return;
    showFilters = value;
    _notify();
  }

  Future<void> initialize() async {
    if (_disposed) return;
    final directoryRequest = ++_directoryRequest;
    initializing = true;
    errorKey = null;
    error = null;
    _notify();
    try {
      final result = await fetchDirectory();
      if (_disposed || directoryRequest != _directoryRequest) return;
      suppliers = List.unmodifiable(result);
      _notify();
      await load();
    } catch (e) {
      if (!_disposed && directoryRequest == _directoryRequest) {
        error = e;
        errorKey = 'supplier_transaction_report.err_loading_supplier_data';
        ++errorRevision;
      }
    } finally {
      if (!_disposed && directoryRequest == _directoryRequest) {
        initializing = false;
        _notify();
      }
    }
  }

  Future<void> load({int? requestedPage}) async {
    if (_disposed) return;
    final request = ++_request;
    final snapshot = query;
    if (!snapshot.isDateRangeValid) {
      loading = false;
      error = null;
      errorKey = 'supplier_transaction_report.from_date_after_to_date';
      ++errorRevision;
      _notify();
      return;
    }
    final target = requestedPage ?? page;
    loading = true;
    error = null;
    errorKey = null;
    _notify();
    try {
      final response = await fetch(snapshot, target);
      if (_disposed || request != _request) return;
      final result = SupplierReportPage.parse(response);
      rows = result.rows;
      page = result.page;
      pages = result.pages;
    } catch (e) {
      if (!_disposed && request == _request) {
        error = e;
        errorKey = 'supplier_transaction_report.err_loading_supplier_data';
        ++errorRevision;
      }
    } finally {
      if (!_disposed && request == _request) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> selectSupplier(SupplierReportOption? supplier) {
    if (_disposed) return Future<void>.value();
    selectedSupplierId = supplier?.id;
    supplierInput.text = supplier?.name ?? '';
    return load(requestedPage: 1);
  }

  Future<void> selectDate(DateTime value, bool isFrom) {
    if (_disposed) return Future<void>.value();
    final text =
        '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    (isFrom ? fromInput : toInput).text = text;
    return load(requestedPage: 1);
  }

  Future<void> reset() {
    if (_disposed) return Future<void>.value();
    ++_request;
    selectedSupplierId = null;
    supplierInput.clear();
    fromInput.clear();
    toInput.clear();
    page = 1;
    pages = 1;
    rows = const {};
    loading = false;
    return initialize();
  }

  Future<void> goToPage(int value) async {
    if (!loading && !initializing && value >= 1 && value <= pages) {
      await load(requestedPage: value);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_request;
    ++_directoryRequest;
    supplierInput.dispose();
    fromInput.dispose();
    toInput.dispose();
    super.dispose();
  }
}
