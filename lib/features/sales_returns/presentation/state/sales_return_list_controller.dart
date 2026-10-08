import 'package:flutter/foundation.dart';
import '../../domain/sales_return_list.dart';

class SalesReturnListController extends ChangeNotifier {
  SalesReturnListController(this.readSource);
  final Future<SalesReturnListSource> Function() readSource;
  SalesReturnListData? data;
  Object? error;
  bool loading = false;
  int requestedPage = 1;
  int _generation = 0;
  bool _disposed = false;
  SalesReturnListScope? _scope;
  bool get canExport =>
      !loading && error == null && data?.rows.isNotEmpty == true;
  bool matchesScope(SalesReturnListScope scope) =>
      _scope?.sameAs(scope) == true;

  void invalidate() {
    if (_disposed) return;
    _generation++;
    data = null;
    _scope = null;
    error = null;
    loading = false;
    requestedPage = 1;
    notifyListeners();
  }

  Future<void> load({int? page}) async {
    if (_disposed) return;
    final generation = ++_generation;
    requestedPage = page ?? requestedPage;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final source = await readSource();
      if (_disposed || generation != _generation) return;
      if (_scope != null && !_scope!.sameAs(source.scope)) {
        data = null;
        requestedPage = 1;
        notifyListeners();
      }
      _scope = source.scope;
      var result = await source.fetch(requestedPage);
      // A refresh can shrink the catalogue beyond the previously loaded page.
      if (result.page > result.pages) result = await source.fetch(result.pages);
      final current = await readSource();
      if (_disposed || generation != _generation) return;
      if (!source.scope.sameAs(current.scope)) {
        invalidate();
        await load(page: 1);
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

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
