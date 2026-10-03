import 'package:flutter/widgets.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/utils/search_debouncer.dart';

/// Page-owned inputs and debounce. Shared expense state remains in the provider.
class ExpenseListController extends ChangeNotifier {
  ExpenseListController(
      {required String reference,
      required this.applyReference,
      required this.resetFilters,
      required this.fetch,
      ExportController? export})
      : referenceController = TextEditingController(text: reference),
        export = export ?? ExportController(),
        _ownsExport = export == null {
    _search = SearchDebouncer(search);
    referenceController.addListener(notifyListeners);
    this.export.addListener(notifyListeners);
  }
  final TextEditingController referenceController;
  final ScrollController tableController = ScrollController();
  final ExportController export;
  final bool _ownsExport;
  final void Function(String) applyReference;
  final VoidCallback resetFilters;
  final Future<void> Function() fetch;
  late final SearchDebouncer _search;
  bool filtersVisible = true;
  bool _disposed = false;
  void scheduleSearch() => _search.schedule();
  void search() {
    if (!_disposed) applyReference(referenceController.text);
  }

  void flushSearch() => _search.flush();
  void prepareExport(String appliedReference) {
    _search.cancel();
    if (appliedReference != referenceController.text) search();
  }

  void toggleFilters() {
    filtersVisible = !filtersVisible;
    notifyListeners();
  }

  void reset() {
    _search.cancel();
    referenceController.clear();
    resetFilters();
  }

  Future<void> refresh() => fetch();
  @override
  void dispose() {
    _disposed = true;
    _search.dispose();
    referenceController.removeListener(notifyListeners);
    export.removeListener(notifyListeners);
    if (_ownsExport) export.dispose();
    referenceController.dispose();
    tableController.dispose();
    super.dispose();
  }
}
