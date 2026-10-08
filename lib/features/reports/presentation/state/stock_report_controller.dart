import 'package:flutter/foundation.dart';
import '../../data/stock_report_snapshot.dart';
import '../../domain/models/stock_report.dart';
import '../../domain/stock_report_query.dart';

typedef StockReportFetch = Future<GetStockReportResponse> Function(
    StockReportQuery query, int page, int? perPage);

/// Local inputs and request state. Shared ReportsProvider rows are never replaced.
class StockReportController extends ChangeNotifier {
  StockReportController({required this.fetch, required this.readScope});
  final StockReportFetch fetch;
  final Future<StockReportScope> Function() readScope;
  StockReportOption? store, category, product;
  StockLevel stockLevel = StockLevel.all;
  StockExpiry expiry = StockExpiry.all;
  DateTime? snapshot, from, until;
  GetStockReportResponse? report;
  String? errorKey;
  bool loading = false, showFilters = true, _worker = false, _disposed = false;
  int resetRevision = 0, _generation = 0, _requestedPage = 1;
  ({StockReportQuery query, int page, int generation})? _pending;
  StockReportQuery? _loaded;
  StockReportScope? _scope;
  int get page => report?.pagination?.currentPage ?? 1;
  int get totalPages => report?.pagination?.lastPage ?? 1;
  int get perPage => report?.pagination?.perPage ?? 20;
  StockReportQuery get query => StockReportQuery(
      storeId: int.tryParse(store?.id ?? ''),
      categoryId: int.tryParse(category?.id ?? ''),
      product: product?.id,
      stockLevel: stockLevel,
      expiry: expiry,
      snapshot: snapshot,
      from: from,
      until: until);
  bool get canExport =>
      !_disposed &&
      !loading &&
      errorKey == null &&
      (report?.data.isNotEmpty ?? false) &&
      _loaded?.matches(query) == true;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setFilters(bool value) {
    if (_disposed) return;
    showFilters = value;
    _notify();
  }

  Future<void> setStore(StockReportOption? value) {
    if (_disposed) return Future.value();
    store = value;
    return load();
  }

  Future<void> setCategory(StockReportOption? value) {
    if (_disposed) return Future.value();
    category = value;
    return load();
  }

  Future<void> setProduct(StockReportOption? value) {
    if (_disposed) return Future.value();
    product = value;
    return load();
  }

  Future<void> setLevel(StockLevel value) {
    if (_disposed) return Future.value();
    stockLevel = value;
    return load();
  }

  Future<void> setExpiry(StockExpiry value) {
    if (_disposed) return Future.value();
    expiry = value;
    return load();
  }

  Future<void> setDate(DateTime? value, String field) {
    if (_disposed) return Future.value();
    switch (field) {
      case 'snapshot':
        snapshot = value;
      case 'from':
        from = value;
      case 'until':
        until = value;
    }
    return load();
  }

  Future<void> reset() {
    if (_disposed) return Future.value();
    resetRevision++;
    store = category = product = null;
    snapshot = from = until = null;
    stockLevel = StockLevel.all;
    expiry = StockExpiry.all;
    return load();
  }

  Future<void> retry() => load(requestedPage: _requestedPage);
  // After a failed page load the visible pagination still describes the current
  // filters, so paging stays available; after a failed filter change it doesn't.
  Future<void> goToPage(int value) => !loading &&
          (errorKey == null || _loaded?.matches(query) == true) &&
          value >= 1 &&
          value <= totalPages
      ? load(requestedPage: value)
      : Future.value();

  Future<void> load({int requestedPage = 1}) async {
    if (_disposed) return;
    _requestedPage = requestedPage;
    final q = query, generation = ++_generation;
    errorKey = null;
    if (!q.valid) {
      _pending = null;
      loading = false;
      errorKey = 'stock_report.invalid_date_range';
      _notify();
      return;
    }
    _pending = (query: q, page: requestedPage, generation: generation);
    loading = true;
    _notify();
    if (_worker) return;
    _worker = true;
    try {
      while (!_disposed && _pending != null) {
        final request = _pending!;
        _pending = null;
        try {
          final scope = await readScope();
          if (_disposed || request.generation != _generation) continue;
          final response = await fetch(request.query, request.page, null);
          if (_disposed || request.generation != _generation) continue;
          if (scope != await readScope()) {
            throw StateError('Stock report session changed');
          }
          if (_disposed || request.generation != _generation) continue;
          final pagination = response.pagination;
          final lastPage = pagination?.lastPage;
          // The result set shrank below the requested page (e.g. a refresh
          // after restocking): show its new last page instead of an error.
          if (response.status.toLowerCase() == 'success' &&
              lastPage != null &&
              lastPage >= 1 &&
              request.page > lastPage) {
            _requestedPage = lastPage;
            _pending ??= (
              query: request.query,
              page: lastPage,
              generation: request.generation
            );
            continue;
          }
          if (response.status.toLowerCase() != 'success' ||
              (pagination != null &&
                  (pagination.currentPage != request.page ||
                      (pagination.lastPage ?? 0) < request.page ||
                      (pagination.perPage ?? 0) < 1))) {
            throw StateError('Invalid stock report page');
          }
          report = response;
          _loaded = request.query;
          _scope = scope;
        } catch (_) {
          if (!_disposed && request.generation == _generation) {
            errorKey = 'stock_report.unavailable';
          }
        }
      }
    } finally {
      _worker = false;
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  Future<T> export<T>(
      {required Future<T> Function(List<StockReportData>) build,
      required bool Function() permissionUnchanged,
      void Function(int page, int total)? progress}) async {
    if (!canExport) throw StateError('Stock export unavailable');
    final q = query, generation = _generation, scope = _scope;
    Future<void> check() async {
      if (_disposed ||
          generation != _generation ||
          !q.matches(query) ||
          !permissionUnchanged()) {
        throw StateError('Stock export inputs or permissions changed');
      }
      final current = await readScope();
      if (_disposed ||
          generation != _generation ||
          scope != current ||
          !permissionUnchanged()) {
        throw StateError('Stock export session changed');
      }
    }

    final rows = await stockReportSnapshot((page) async {
      await check();
      final result = await fetch(q, page, 250);
      await check();
      return result;
    }, progress: progress);
    await check();
    final output = await build(rows);
    await check();
    return output;
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _pending = null;
    super.dispose();
  }
}
