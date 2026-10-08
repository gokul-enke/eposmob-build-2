import 'package:flutter/foundation.dart';
import 'package:pos_machine/models/day_close_pending_status.dart';
import '../../domain/day_close_list.dart';

class DayCloseListController extends ChangeNotifier {
  DayCloseListController(this.readSource);
  final Future<DayCloseListSource> Function() readSource;
  DayCloseListData? data;
  DayClosePendingStatus? pending;
  Object? error, pendingError;
  String? date;
  bool loading = false, pendingLoading = false;
  int requestedPage = 1, _generation = 0, _pendingGeneration = 0;
  bool _disposed = false;
  DayCloseListScope? _scope;
  int get revision => _generation;
  bool get canExport =>
      !loading && error == null && data?.rows.isNotEmpty == true;
  bool matches(DayCloseListScope scope, String? query, int revision) =>
      !_disposed &&
      _scope?.sameAs(scope) == true &&
      query == date &&
      revision == _generation;

  void invalidate() {
    if (_disposed) return;
    _generation++;
    _pendingGeneration++;
    data = null;
    pending = null;
    _scope = null;
    error = null;
    pendingError = null;
    loading = false;
    pendingLoading = false;
    requestedPage = 1;
    notifyListeners();
  }

  Future<void> setDate(String? value) {
    if (value == date) return Future.value();
    date = value;
    data = null;
    return load(page: 1);
  }

  Future<void> reset() {
    date = null;
    data = null;
    return load(page: 1);
  }

  Future<void> refresh({bool firstPage = false}) async {
    await Future.wait([load(page: firstPage ? 1 : null), loadPending()]);
  }

  Future<void> load({int? page}) async {
    if (_disposed) return;
    final generation = ++_generation;
    final query = date;
    requestedPage = page ?? requestedPage;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final source = await readSource();
      if (_disposed || generation != _generation) return;
      if (_scope != null && !_scope!.sameAs(source.scope)) {
        data = null;
        pending = null;
        requestedPage = 1;
      }
      _scope = source.scope;
      var result = await source.fetch(requestedPage, date: query);
      if (result.page > result.pages) {
        result = await source.fetch(result.pages, date: query);
      }
      final current = await readSource();
      if (_disposed || generation != _generation) return;
      if (!source.scope.sameAs(current.scope)) {
        invalidate();
        await refresh(firstPage: true);
        return;
      }
      data = result;
      requestedPage = result.page;
    } catch (cause) {
      if (!_disposed && generation == _generation) error = cause;
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadPending() async {
    if (_disposed) return;
    final generation = ++_pendingGeneration;
    pending = null;
    pendingError = null;
    pendingLoading = true;
    notifyListeners();
    try {
      final source = await readSource();
      if (_disposed || generation != _pendingGeneration) return;
      final result = await source.fetchPending();
      final current = await readSource();
      if (_disposed || generation != _pendingGeneration) return;
      if (!source.scope.sameAs(current.scope)) {
        await loadPending();
        return;
      }
      pending = result;
    } catch (cause) {
      if (!_disposed && generation == _pendingGeneration) pendingError = cause;
    } finally {
      if (!_disposed && generation == _pendingGeneration) {
        pendingLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _pendingGeneration++;
    super.dispose();
  }
}
