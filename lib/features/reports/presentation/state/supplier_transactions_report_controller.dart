import 'package:flutter/material.dart';
import '../../data/supplier_report_snapshot.dart';
import '../../domain/supplier_report.dart';

typedef SupplierReportFetch = Future<Map<String, dynamic>> Function(
    SupplierReportQuery query, int page);

/// Export stopped on purpose because the filters, page, store or session
/// changed while it ran. Extends [StateError] so existing handlers still match.
class SupplierReportExportCancelled extends StateError {
  SupplierReportExportCancelled(super.message);
}

/// Owns report inputs, directory snapshot, pagination and request generations.
class SupplierTransactionsReportController extends ChangeNotifier {
  SupplierTransactionsReportController(
      {required this.fetchDirectory,
      required this.fetch,
      required this.readScope});
  final Future<List<SupplierReportOption>> Function() fetchDirectory;
  final SupplierReportFetch fetch;
  final Future<SupplierReportScope> Function() readScope;
  final supplierInput = TextEditingController();
  final fromInput = TextEditingController();
  final toInput = TextEditingController();
  List<SupplierReportOption> suppliers = const [];
  Map<String, SupplierTransactionSummary> rows = const {};
  String? selectedSupplierId;
  int page = 1,
      pages = 1,
      perPage = 20,
      _requestedPage = 1,
      _request = 0,
      _directoryRequest = 0;
  SupplierReportQuery? _loaded;
  SupplierReportScope? _loadedScope;
  Object? directoryError;
  bool initializing = false,
      loading = false,
      showFilters = true,
      _disposed = false;
  String? errorKey;
  Object? error;
  int errorRevision = 0;
  int get loadRevision => _request;
  static const dateRangeErrorKey =
      'supplier_transaction_report.from_date_after_to_date';

  /// A From-after-To input error: retrying cannot help until a date changes.
  bool get hasValidationError => errorKey == dateRangeErrorKey;
  bool get canExport =>
      !_disposed &&
      !loading &&
      errorKey == null &&
      rows.isNotEmpty &&
      _loaded?.matches(query) == true;
  bool get canPaginate =>
      !_disposed &&
      !loading &&
      errorKey == null &&
      _loaded?.matches(query) == true;
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
    // Directory options are optional: their failure or latency must not block
    // the independent transactions endpoint or the report's usable rows.
    await Future.wait([reloadDirectory(), load()]);
  }

  Future<void> reloadDirectory() async {
    if (_disposed) return;
    final directoryRequest = ++_directoryRequest;
    initializing = true;
    directoryError = null;
    _notify();
    try {
      final result = await fetchDirectory();
      if (_disposed || directoryRequest != _directoryRequest) return;
      suppliers = List.unmodifiable(result);
    } catch (e) {
      if (!_disposed && directoryRequest == _directoryRequest) {
        directoryError = e;
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
    final target = requestedPage ??
        (_loaded?.matches(snapshot) == true ? _requestedPage : 1);
    _requestedPage = target;
    if (!snapshot.isDateRangeValid) {
      loading = false;
      error = null;
      errorKey = dateRangeErrorKey;
      ++errorRevision;
      _notify();
      return;
    }
    loading = true;
    error = null;
    errorKey = null;
    _notify();
    try {
      final scope = await readScope();
      if (_disposed || request != _request) return;
      final response = await fetch(snapshot, target);
      if (_disposed || request != _request) return;
      final currentScope = await readScope();
      if (_disposed || request != _request) return;
      if (scope != currentScope) {
        throw StateError('Supplier report session changed during loading.');
      }
      final result = SupplierReportPage.parse(response);
      rows = result.rows;
      page = result.page;
      pages = result.pages;
      perPage = result.perPage;
      _loaded = snapshot;
      _loadedScope = scope;
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

  Future<void> retry() async {
    if (_disposed) return;
    await Future.wait([
      if (directoryError != null) reloadDirectory(),
      load(requestedPage: _requestedPage),
    ]);
  }

  Future<List<SupplierTransactionSummary>> exportRows({
    void Function(int page, int total)? progress,
  }) =>
      export(build: (rows) async => rows, progress: progress);

  /// Keep the same scope through fetching AND workbook creation, so callers
  /// never receive a file for delivery after the active store/session changes.
  Future<T> export<T>({
    required Future<T> Function(List<SupplierTransactionSummary> rows) build,
    void Function(int page, int total)? progress,
  }) async {
    if (!canExport) throw StateError('Supplier report is unavailable.');
    final snapshot = _loaded!, scope = _loadedScope, request = _request;
    void checkLocal() {
      if (_disposed || request != _request || !snapshot.matches(query)) {
        throw SupplierReportExportCancelled(
            'Supplier report filters changed during export.');
      }
    }

    Future<void> check() async {
      checkLocal();
      final currentScope = await readScope();
      checkLocal();
      if (scope == null || scope != currentScope) {
        throw SupplierReportExportCancelled(
            'Supplier report session changed during export.');
      }
    }

    final result = await fetchSupplierReportSnapshot((page) async {
      await check();
      final result = await fetch(snapshot, page);
      await check();
      return result;
    }, progress: progress);
    await check();
    final output = await build(result);
    await check();
    return output;
  }

  Future<void> reset() {
    if (_disposed) return Future<void>.value();
    ++_request;
    selectedSupplierId = null;
    supplierInput.clear();
    fromInput.clear();
    toInput.clear();
    page = 1;
    _requestedPage = 1;
    pages = 1;
    rows = const {};
    loading = false;
    return initialize();
  }

  Future<void> goToPage(int value) async {
    if (canPaginate && value >= 1 && value <= pages) {
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
