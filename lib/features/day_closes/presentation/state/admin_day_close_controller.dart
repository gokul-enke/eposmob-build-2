import 'package:flutter/foundation.dart';
import '../../domain/admin_day_close_list.dart';
import '../../domain/day_close_list.dart';

class AdminDayCloseController extends ChangeNotifier {
  AdminDayCloseController(this.readSource);
  final Future<AdminDayCloseSource> Function() readSource;
  DayCloseListData? data;
  List<AdminExecutiveOption> executives = const [];
  AdminDayCloseQuery query = const AdminDayCloseQuery();
  Object? error, executivesError;
  bool loading = false, executivesLoading = false;
  int requestedPage = 1, _generation = 0, _executiveGeneration = 0;
  bool _disposed = false;
  AdminDayCloseScope? _scope;
  int get revision => _generation;
  bool get canExport =>
      !loading && error == null && data?.rows.isNotEmpty == true;
  bool matches(AdminDayCloseScope scope, AdminDayCloseQuery captured,
          int revision) =>
      !_disposed &&
      _scope?.sameAs(scope) == true &&
      captured.sameAs(query) &&
      revision == _generation;

  void invalidate() {
    if (_disposed) return;
    _generation++;
    _executiveGeneration++;
    _scope = null;
    data = null;
    executives = const [];
    query = AdminDayCloseQuery(date: query.date);
    error = null;
    executivesError = null;
    loading = false;
    executivesLoading = false;
    requestedPage = 1;
    notifyListeners();
  }

  Future<void> setQuery(AdminDayCloseQuery value) {
    if (_disposed || value.sameAs(query)) return Future.value();
    query = value;
    data = null;
    return load(page: 1);
  }

  Future<void> reset() {
    if (_disposed) return Future.value();
    query = const AdminDayCloseQuery();
    data = null;
    return load(page: 1);
  }

  Future<void> refresh({bool firstPage = false}) async {
    await Future.wait([load(page: firstPage ? 1 : null), loadExecutives()]);
  }

  Future<void> load({int? page}) async {
    if (_disposed) return;
    final generation = ++_generation;
    requestedPage = page ?? requestedPage;
    final targetPage = requestedPage, captured = query;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final source = await readSource();
      if (_disposed || generation != _generation) return;
      if (_scope != null && !_scope!.sameAs(source.scope)) {
        invalidate();
        await refresh(firstPage: true);
        return;
      }
      _scope = source.scope;
      var result = await source.fetch(targetPage, captured);
      if (_disposed || generation != _generation) return;
      if (result.page > result.pages) {
        result = await source.fetch(result.pages, captured);
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

  Future<void> loadExecutives() async {
    if (_disposed) return;
    final generation = ++_executiveGeneration;
    executivesError = null;
    executivesLoading = true;
    notifyListeners();
    try {
      final source = await readSource();
      if (_disposed || generation != _executiveGeneration) return;
      final result = await source.fetchExecutives();
      final current = await readSource();
      if (_disposed || generation != _executiveGeneration) return;
      if (!source.scope.sameAs(current.scope)) {
        invalidate();
        await refresh(firstPage: true);
        return;
      }
      // A disappearing lookup entry must not hide the filter still applied to
      // the API. Preserve its label until the user selects All or resets.
      final selected =
          executives.where((e) => e.id == query.executiveId).firstOrNull;
      executives = List.unmodifiable([
        ...result,
        if (selected != null && !result.any((e) => e.id == selected.id))
          selected,
      ]);
    } catch (cause) {
      if (!_disposed && generation == _executiveGeneration) {
        executivesError = cause;
      }
    } finally {
      if (!_disposed && generation == _executiveGeneration) {
        executivesLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _executiveGeneration++;
    super.dispose();
  }
}
