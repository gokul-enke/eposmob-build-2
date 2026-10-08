import 'package:flutter/foundation.dart';
import '../../data/consumed_stocks_report_snapshot.dart';
import '../../domain/models/consumed_stocks_report.dart';
import '../../domain/consumed_stocks_report_query.dart';

typedef ConsumedStocksFetch = Future<GetConsumedStocksReportResponse> Function(
    ConsumedStocksReportQuery query, int page);

class ConsumedStocksExportCancelled extends StateError {
  ConsumedStocksExportCancelled()
      : super('Consumed stock export cancelled: filters or access changed');
}

/// One owner for filters, retry target, rows and cached store options.
class ConsumedStocksReportController extends ChangeNotifier {
  ConsumedStocksReportController(
      {required this.fetch, required this.readScope, required this.loadStores});
  final ConsumedStocksFetch fetch;
  final Future<ConsumedStocksReportScope> Function() readScope;
  final Future<Map<String, String>> Function() loadStores;
  String? productId, storeId;
  DateTime? from, until;
  Map<String, String> stores = {};
  GetConsumedStocksReportResponse? report;
  bool loading = false, _disposed = false;
  String? errorKey;
  int resetRevision = 0,
      _request = 0,
      _filterRevision = 0,
      _requestedPage = 1,
      _displayedPage = 1;
  Future<void>? _directoryRequest;
  ConsumedStocksReportQuery? _loaded;
  ConsumedStocksReportScope? _scope;
  ConsumedStocksReportQuery get query => ConsumedStocksReportQuery(
      productId: productId, storeId: storeId, from: from, until: until);
  int get page => report?.data?.pagination?.currentPage ?? _displayedPage;
  int get totalPages => report?.data?.pagination?.lastPage ?? page;
  int get perPage => report?.data?.pagination?.perPage ?? 25;
  bool get canExport =>
      !_disposed &&
      !loading &&
      errorKey == null &&
      (report?.data?.data?.isNotEmpty ?? false) &&
      _loaded?.matches(query) == true;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async => Future.wait([refreshStores(), load()]);
  Future<void> refreshStores() => _directoryRequest ??= _readStores();
  Future<void> _readStores() async {
    try {
      final options = await loadStores();
      if (!_disposed) stores = options;
    } catch (_) {
      /* Directory errors leave table loading independent. */
    } finally {
      _directoryRequest = null;
      _notify();
    }
  }

  Future<void> setProduct(String? id) {
    productId = id;
    return _filterChanged();
  }

  Future<void> setStore(String? id) {
    storeId = id;
    return _filterChanged();
  }

  Future<void> setFrom(DateTime? date) {
    from = date;
    return _filterChanged();
  }

  Future<void> setUntil(DateTime? date) {
    until = date;
    return _filterChanged();
  }

  Future<void> _filterChanged() {
    _filterRevision++;
    return load();
  }

  Future<void> reset() {
    productId = storeId = null;
    from = until = null;
    resetRevision++;
    return _filterChanged();
  }

  Future<void> retry() => load(requestedPage: _requestedPage);
  Future<void> goToPage(int value) =>
      !loading && errorKey == null && value >= 1 && value <= totalPages
          ? load(requestedPage: value)
          : Future.value();
  Future<void> load({int requestedPage = 1}) async {
    if (_disposed) return;
    final q = query, request = ++_request;
    _requestedPage = requestedPage;
    errorKey = null;
    if (q.isInverted) {
      loading = false;
      errorKey = 'consumed_stocks_report.invalid_dates';
      _notify();
      return;
    }
    loading = true;
    _notify();
    try {
      final scope = await readScope();
      if (_disposed || request != _request) return;
      final response = await fetch(q, requestedPage);
      if (_disposed || request != _request) return;
      if (scope != await readScope()) {
        throw StateError('Consumed stock session changed');
      }
      if (_disposed || request != _request) return;
      final meta = response.data?.pagination;
      if (response.status != 'success' ||
          response.data?.data == null ||
          (meta == null && requestedPage != 1) ||
          (meta != null &&
              ((meta.currentPage != null &&
                      meta.currentPage != requestedPage) ||
                  (meta.lastPage != null && meta.lastPage! < requestedPage) ||
                  (meta.perPage != null &&
                      (meta.perPage! < 1 ||
                          response.data!.data!.length > meta.perPage!))))) {
        throw StateError('Invalid consumed stock page');
      }
      report = response;
      _displayedPage = requestedPage;
      _loaded = q;
      _scope = scope;
    } catch (_) {
      if (!_disposed && request == _request) {
        errorKey = 'consumed_stocks_report.unavailable';
      }
    } finally {
      if (!_disposed && request == _request) {
        loading = false;
        _notify();
      }
    }
  }

  Future<T> export<T>(
      {required Future<T> Function(List<ConsumedStockData>) build,
      required bool Function() permissionUnchanged,
      void Function(int page, int total)? progress}) async {
    if (!canExport) throw StateError('Consumed stock export unavailable');
    final q = query, revision = _filterRevision, scope = _scope;
    Future<void> check() async {
      if (_disposed ||
          revision != _filterRevision ||
          !q.matches(query) ||
          !permissionUnchanged()) {
        throw ConsumedStocksExportCancelled();
      }
      final current = await readScope();
      if (_disposed ||
          revision != _filterRevision ||
          current != scope ||
          !permissionUnchanged()) {
        throw ConsumedStocksExportCancelled();
      }
    }

    // Page/refresh requests have their own generation and do not invalidate this
    // captured export; filter/reset/session/permission changes still stop it.
    final rows = await consumedStocksReportSnapshot((page) async {
      await check();
      final response = await fetch(q, page);
      await check();
      return response;
    }, progress: progress);
    await check();
    final result = await build(rows);
    await check();
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    _filterRevision++;
    super.dispose();
  }
}
