import 'package:flutter/foundation.dart';

import '../../data/customer_report_snapshot.dart';
import '../../domain/customer_report.dart';
import '../../domain/report_date_range.dart';
import 'report_load_error.dart';

/// Filters of one Customer Transactions Report request.
@immutable
class CustomerReportQuery {
  const CustomerReportQuery(
      {this.customerId, this.range = ReportDateRange.empty});

  final String? customerId;
  final ReportDateRange range;

  @override
  bool operator ==(Object other) =>
      other is CustomerReportQuery &&
      other.customerId == customerId &&
      other.range == range;

  @override
  int get hashCode => Object.hash(customerId, range);
}

/// Calls the report API for [query] and [page] and returns its raw JSON,
/// e.g. `InvoiceProvider.listAllTransaction(updateState: false)`.
typedef CustomerReportFetch = Future<dynamic> Function(
    CustomerReportQuery query, int page);

/// State of the Customer Transactions Report: filters, the page on screen,
/// and the all-pages export. A newer request always wins over an older one
/// that finishes later, and a failed reload keeps the rows already shown.
class CustomerTransactionsReportController extends ChangeNotifier {
  CustomerTransactionsReportController({
    required CustomerReportFetch fetch,
    String? customerId,
  })  : _fetch = fetch,
        _query = CustomerReportQuery(customerId: customerId);

  final CustomerReportFetch _fetch;
  CustomerReportQuery _query;
  CustomerReportQuery? _loaded;
  List<CustomerReportRow> _rows = const [];
  int _page = 1, _pages = 1, _perPage = 20, _requestedPage = 1, _request = 0;
  bool _loading = false, _disposed = false;
  ReportLoadError? _error;

  CustomerReportQuery get query => _query;
  String? get customerId => _query.customerId;
  ReportDateRange get range => _query.range;
  List<CustomerReportRow> get rows => _rows;
  int get page => _page;
  int get pages => _pages;
  int get perPage => _perPage;
  bool get loading => _loading;
  ReportLoadError? get error => _error;

  bool get hasActiveFilters =>
      _query.customerId != null || !_query.range.isEmpty;

  /// The rows on screen match the current filters and can be exported.
  bool get canExport =>
      !_loading && _error == null && _rows.isNotEmpty && _loaded == _query;

  void setCustomer(String? id) {
    _query = CustomerReportQuery(customerId: id, range: _query.range);
    load();
  }

  void setFrom(DateTime? value) =>
      _setRange(_query.range.copyWith(from: () => value));

  void setTo(DateTime? value) =>
      _setRange(_query.range.copyWith(to: () => value));

  void _setRange(ReportDateRange range) {
    _query = CustomerReportQuery(customerId: _query.customerId, range: range);
    load();
  }

  /// Clears every filter and loads the first page.
  Future<void> reset() {
    _query = const CustomerReportQuery();
    return load();
  }

  /// Loads the page that failed last (or the first page).
  Future<void> retry() => load(_requestedPage);

  Future<void> load([int page = 1]) async {
    final query = _query, request = ++_request;
    _requestedPage = page;
    if (query.range.isInverted) {
      _loading = false;
      _error = ReportLoadError.invertedRange;
      _notify();
      return;
    }
    _loading = true;
    _error = null;
    _notify();
    try {
      final result = CustomerReportPage.parse(await _fetch(query, page), page);
      if (_disposed || request != _request) return;
      _rows = result.rows;
      _page = result.current;
      _pages = result.last;
      _perPage = result.perPage;
      _loaded = query;
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

  /// Every page of the loaded report, for the export.
  Future<List<CustomerReportRow>> exportRows(
      {void Function(int page, int total)? progress}) {
    if (!canExport) throw StateError('Customer report is unavailable.');
    final query = _loaded!;
    return fetchCustomerReportSnapshot((page) => _fetch(query, page),
        progress: progress);
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
