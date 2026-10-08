import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show TextEditingController;
import 'package:pos_machine/core/utils/search_debouncer.dart';
import '../../data/non_stock_report_snapshot.dart';
import '../../domain/models/non_stock_report.dart';
import '../../domain/non_stock_report_query.dart';

typedef NonStockReportFetch = Future<GetNonStockReportResponse> Function(
    NonStockReportQuery query, int page);

/// Owns listing inputs and rows. Retries use the requested page, while retained
/// rows keep their original page number. Late responses cannot replace them.
class NonStockReportController extends ChangeNotifier {
  NonStockReportController({required this.fetch, required this.readScope}) {
    _search = SearchDebouncer(() => load());
    barcode.addListener(_barcodeChanged);
  }
  static const exportAttempts = 3;
  final NonStockReportFetch fetch;
  final Future<NonStockReportScope> Function() readScope;
  final barcode = TextEditingController();
  late final SearchDebouncer _search;
  String? store, category, product;
  String _lastBarcode = '';
  GetNonStockReportResponse? report;
  bool loading = false, _disposed = false, _resetting = false;
  String? errorKey;
  int resetRevision = 0,
      _generation = 0,
      _requestedPage = 1,
      _displayedPage = 1;
  NonStockReportQuery? _loaded;
  NonStockReportScope? _scope;
  int get page => report?.pagination?.currentPage ?? _displayedPage;
  int get totalPages => report?.pagination?.lastPage ?? page;
  int get perPage => report?.pagination?.perPage ?? 20;
  NonStockReportQuery get query => NonStockReportQuery(
      store: store,
      category: category,
      product: product,
      barcode: barcode.text);
  bool get hasActiveFilters => !query.isEmpty;
  bool get canExport =>
      !_disposed &&
      !_search.isPending &&
      !loading &&
      errorKey == null &&
      (report?.data.isNotEmpty ?? false) &&
      _loaded?.matches(query) == true;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _barcodeChanged() {
    if (_disposed || _resetting || barcode.text == _lastBarcode) return;
    _lastBarcode = barcode.text;
    // Invalidate pending table/export work immediately, before the debounce.
    _generation++;
    _requestedPage = 1;
    loading = false;
    _search.schedule();
    _notify();
  }

  Future<void> setStore(String? value) {
    store = value;
    return load();
  }

  Future<void> setCategory(String? value) {
    category = value;
    return load();
  }

  Future<void> setProduct(String? value) {
    product = value;
    return load();
  }

  Future<void> reset() {
    if (_disposed) return Future.value();
    _resetting = true;
    barcode.clear();
    _lastBarcode = '';
    _resetting = false;
    store = category = product = null;
    resetRevision++;
    return load();
  }

  Future<void> submit() => load();
  Future<void> retry() => load(requestedPage: _requestedPage);
  Future<void> goToPage(int value) => !loading &&
          !_search.isPending &&
          errorKey == null &&
          value >= 1 &&
          value <= totalPages
      ? load(requestedPage: value)
      : Future.value();
  Future<void> load({int requestedPage = 1}) async {
    if (_disposed) return;
    _search.cancel();
    _requestedPage = requestedPage;
    final q = query, generation = ++_generation;
    loading = true;
    errorKey = null;
    _notify();
    try {
      final scope = await readScope();
      if (_disposed || generation != _generation) return;
      final response = await fetch(q, requestedPage);
      if (_disposed || generation != _generation) return;
      if (scope != await readScope()) {
        throw StateError('Non-stock session changed');
      }
      if (_disposed || generation != _generation) return;
      final meta = response.pagination;
      if (response.status.toLowerCase() != 'success' ||
          (meta == null && requestedPage != 1) ||
          (meta != null &&
              ((meta.currentPage != null &&
                      meta.currentPage != requestedPage) ||
                  (meta.lastPage != null && meta.lastPage! < requestedPage) ||
                  (meta.perPage != null &&
                      (meta.perPage! < 1 ||
                          response.data.length > meta.perPage!))))) {
        throw StateError('Invalid non-stock report page');
      }
      report = response;
      _displayedPage = requestedPage;
      _loaded = q;
      _scope = scope;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        errorKey = 'non_stock_report.unavailable';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<T> export<T>(
      {required Future<T> Function(List<NonStockReportData>) build,
      required bool Function() permissionUnchanged,
      void Function(int page, int total)? progress}) async {
    if (!canExport) throw StateError('Non-stock export unavailable');
    final q = query, generation = _generation, scope = _scope;
    Future<void> check() async {
      if (_disposed ||
          generation != _generation ||
          !q.matches(query) ||
          !permissionUnchanged()) {
        throw StateError('Non-stock export changed');
      }
      final current = await readScope();
      if (_disposed ||
          generation != _generation ||
          current != scope ||
          !permissionUnchanged()) {
        throw StateError('Non-stock export session changed');
      }
    }

    Future<List<NonStockReportData>> snapshot() =>
        nonStockReportSnapshot((page) async {
          await check();
          final response = await fetch(q, page);
          await check();
          return response;
        }, progress: progress);

    // Live sales can move rows between page reads; reread a few times before
    // failing. Filter, session and permission changes still stop at once.
    List<NonStockReportData>? rows;
    for (var attempt = 1; rows == null; attempt++) {
      try {
        rows = await snapshot();
      } on NonStockReportSnapshotChanged {
        if (attempt >= exportAttempts) rethrow;
      }
    }
    await check();
    final result = await build(rows);
    await check();
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _search.dispose();
    barcode.dispose();
    super.dispose();
  }
}
