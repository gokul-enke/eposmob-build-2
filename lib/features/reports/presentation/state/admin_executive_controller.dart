import 'package:flutter/foundation.dart';
import 'package:pos_machine/models/sales_executive_report.dart';
import '../../domain/admin_executive_report.dart';
import '../../domain/report_date_range.dart';
import 'report_load_error.dart';

class AdminExecutiveController extends ChangeNotifier {
  AdminExecutiveController(this.readSource, {DateTime Function()? now})
      : _now = now ?? DateTime.now;
  final Future<AdminExecutiveSource> Function() readSource;
  final DateTime Function() _now;
  ReportDateRange range = ReportDateRange.empty;
  ReportDateRange? loadedRange;
  DateTime? loadedAt;
  AdminExecutiveScope? _scope;
  List<SalesExecutiveReportData> _rows = const [];
  String name = '';
  bool loading = false, _disposed = false;
  ReportLoadError? error;
  int _generation = 0;
  int get revision => _generation;
  List<SalesExecutiveReportData> get rows => filterAdminExecutives(_rows, name);
  bool get canExport =>
      !loading &&
      error == null &&
      loadedRange == range &&
      rows.isNotEmpty &&
      rows.every(completeAdminExecutiveRow);
  bool matches(AdminExecutiveScope scope, int revision) =>
      !_disposed && revision == _generation && _scope?.sameAs(scope) == true;

  void setName(String value) {
    if (_disposed || name == value) return;
    name = value;
    // Name filtering is local; do not cancel an in-flight date request.
    notifyListeners();
  }

  Future<void> setRange(ReportDateRange value) {
    if (_disposed || value == range) return Future.value();
    range = value;
    _rows = const [];
    loadedRange = null;
    loadedAt = null;
    return load();
  }

  Future<void> reset() {
    if (_disposed) return Future.value();
    name = '';
    range = ReportDateRange.empty;
    _rows = const [];
    loadedRange = null;
    loadedAt = null;
    return load();
  }

  void invalidate() {
    if (_disposed) return;
    _generation++;
    _scope = null;
    _rows = const [];
    loadedAt = null;
    loadedRange = null;
    loading = false;
    error = null;
    notifyListeners();
  }

  Future<void> load() async {
    if (_disposed) return;
    final generation = ++_generation, captured = range;
    if (captured.isInverted) {
      loading = false;
      error = ReportLoadError.invertedRange;
      notifyListeners();
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final source = await readSource();
      if (_disposed || generation != _generation) return;
      if (_scope != null && !_scope!.sameAs(source.scope)) {
        invalidate();
        await load();
        return;
      }
      _scope = source.scope;
      final startedAt = _now(), result = await source.fetch(captured);
      final current = await readSource();
      if (_disposed || generation != _generation) return;
      if (!source.scope.sameAs(current.scope)) {
        invalidate();
        await load();
        return;
      }
      _rows = List.unmodifiable(result);
      loadedAt = startedAt;
      loadedRange = captured;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        error = ReportLoadError.failed;
      }
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
