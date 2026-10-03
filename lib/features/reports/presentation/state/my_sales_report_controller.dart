import 'package:flutter/foundation.dart';
import 'package:pos_machine/models/sales_executive_report.dart';

import '../../domain/my_sales_report.dart';
import '../../domain/report_date_range.dart';
import 'report_load_error.dart';

/// Calls the My Sales Report API and returns its raw JSON, e.g.
/// `SalesExecutiveProvider.getSalesExecutiveReport(updateState: false)`.
/// Both ends empty means today.
typedef MySalesReportFetch = Future<dynamic> Function(
    {String? from, String? to});

/// State of My Sales Report. The API returns every row at once, so pages
/// are cut locally and the export reuses the loaded rows.
class MySalesReportController extends ChangeNotifier {
  MySalesReportController(
      {required MySalesReportFetch fetch, DateTime Function()? now})
      : _fetch = fetch,
        _now = now ?? DateTime.now;

  static const pageSize = 20;

  final MySalesReportFetch _fetch;
  final DateTime Function() _now;
  ReportDateRange _range = ReportDateRange.empty;
  ReportDateRange? _loadedRange;
  DateTime? _loadedAt;
  List<SalesExecutiveReportData> _rows = const [];
  int _page = 1, _request = 0;
  bool _loading = false, _disposed = false;
  ReportLoadError? _error;

  ReportDateRange get range => _range;
  bool get loading => _loading;
  ReportLoadError? get error => _error;
  bool get hasActiveFilters => !_range.isEmpty;

  /// Every loaded row (the export).
  List<SalesExecutiveReportData> get rows => _rows;

  /// The filters of the rows on screen (null before the first load).
  ReportDateRange? get loadedRange => _loadedRange;

  /// When the rows on screen were loaded; with no dates they are that day's.
  DateTime? get loadedAt => _loadedAt;

  int get page => _page;
  int get pages =>
      ((_rows.length + pageSize - 1) ~/ pageSize).clamp(1, 1 << 30);
  List<SalesExecutiveReportData> get pageRows =>
      _rows.skip((_page - 1) * pageSize).take(pageSize).toList();

  bool get canExport =>
      !_loading && _error == null && _loadedRange == _range && _rows.isNotEmpty;

  void setFrom(DateTime? value) {
    _range = _range.copyWith(from: () => value);
    load();
  }

  void setTo(DateTime? value) {
    _range = _range.copyWith(to: () => value);
    load();
  }

  Future<void> reset() {
    _range = ReportDateRange.empty;
    return load();
  }

  void setPage(int page) {
    if (_loading) return;
    _page = page.clamp(1, pages);
    _notify();
  }

  Future<void> load() async {
    final range = _range, request = ++_request;
    if (range.isInverted) {
      _loading = false;
      _error = ReportLoadError.invertedRange;
      _notify();
      return;
    }
    final startedAt = _now();
    _loading = true;
    _error = null;
    _notify();
    try {
      final rows = parseMySalesReport(
          await _fetch(from: range.apiFrom, to: range.apiTo));
      if (_disposed || request != _request) return;
      _rows = rows;
      _loadedRange = range;
      _loadedAt = startedAt;
      _page = 1;
    } catch (_) {
      if (_disposed || request != _request) return;
      _error = ReportLoadError.failed;
    } finally {
      if (!_disposed && request == _request) {
        _loading = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    super.dispose();
  }
}
