import 'package:flutter/foundation.dart';
import '../../data/sales_report_snapshot.dart';
import '../../domain/models/sales_report.dart';
import '../../domain/report_date_range.dart';
import '../../domain/report_period.dart';
import '../../domain/sales_report_query.dart';

typedef SalesReportFetch = Future<SalesReportResponse> Function(
    Map<String, String> parameters, int page, int perPage);

typedef SalesReportOptionsLoader = Future<List<SalesReportOption>> Function();

/// Filters, server paging and export of the Sales Report: Stores, Sales
/// Executives, Payment Methods, Delivery Modes, Categories, Products and
/// Customers (options from [loaders]; the screen picks one of each, the API
/// takes id lists), the Date Range and the order-date sort.
///
/// A newer request always wins; a failed reload keeps the previous rows,
/// shows an error with Retry and disables Export and paging until it
/// recovers.
class SalesReportController extends ChangeNotifier {
  SalesReportController(
      {required this.fetch,
      required this.readScope,
      this.loaders = const {},
      this.locked = const {},
      DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    _applyLocked();
  }

  static const pageSize = 25;

  /// The API accepts at most 100 rows per page.
  static const exportPageSize = 100;

  /// Reads of a snapshot whose rows moved before the export fails.
  static const exportAttempts = 3;
  static const defaultPeriod = ReportPeriod.thisMonth;
  static const missingDates = 'order_sales_report.missing_dates';
  static const invertedDates = 'order_sales_report.inverted_dates';
  static const unavailable = 'order_sales_report.unavailable';

  final SalesReportFetch fetch;
  final Future<SalesReportScope> Function() readScope;
  final Map<SalesReportFilter, SalesReportOptionsLoader> loaders;

  /// Filters fixed for this user (a sales executive sees only their own
  /// sales in the store they are logged into): selected from the start,
  /// unchangeable, kept by Reset and not counted as active filters.
  final Map<SalesReportFilter, SalesReportOption> locked;
  final DateTime Function() _clock;

  ReportPeriod period = defaultPeriod;

  /// Whole days of the Custom range; either may be open.
  DateTime? customFrom, customTo;

  /// Newest orders first (the API default) unless switched.
  bool oldestFirst = false;

  /// Selected ids per filter; a missing entry means All.
  final selected = <SalesReportFilter, Set<String>>{};
  final options = <SalesReportFilter, List<SalesReportOption>>{};

  List<SalesReportRow> rows = const [];
  bool loading = false;
  String? errorKey;
  int page = 1, totalPages = 1, resetRevision = 0;
  int? total;

  /// Totals of the loaded filters over every page.
  Map<String, double> summary = const {};

  bool _disposed = false;
  int _generation = 0, _requestedPage = 1, _optionsGeneration = 0;
  Map<String, String>? _loaded;
  SalesReportScope? _scope;

  /// Executives seen in loaded rows (id → name), e.g. ones the directory
  /// API does not list; merged into their picker.
  final _seenExecutives = <String, String>{};

  /// Date Range options, in display order.
  List<ReportPeriod> get periods => SalesReportParams.periods;

  ReportDateRange get customRange =>
      ReportDateRange(from: customFrom, to: customTo);

  /// Selected ids of [filter], sorted so equal selections compare equal.
  List<String> ids(SalesReportFilter filter) => [...?selected[filter]]..sort();

  /// The API request for the current filters (without paging). Only Custom
  /// sends dates; the presets send their code.
  Map<String, String> get parameters => {
        SalesReportParams.period: SalesReportParams.periodCode(period),
        for (final filter in SalesReportFilter.values)
          if (ids(filter) case final picked when picked.isNotEmpty)
            filter.parameter: picked.join(','),
        if (oldestFirst) SalesReportParams.sortDirection: 'asc',
        if (period == ReportPeriod.custom && customFrom != null)
          SalesReportParams.from: reportApiDate(customFrom!),
        if (period == ReportPeriod.custom && customTo != null)
          SalesReportParams.to: reportApiDate(customTo!),
      };

  bool get hasActiveFilters =>
      period != defaultPeriod ||
      selected.keys.any((filter) => !locked.containsKey(filter)) ||
      oldestFirst;

  bool isLocked(SalesReportFilter filter) => locked.containsKey(filter);

  /// Selects the locked options; a known name is shown without loading.
  void _applyLocked() {
    for (final MapEntry(key: filter, value: option) in locked.entries) {
      selected[filter] = {option.id};
      if (option.label.trim().isNotEmpty) options[filter] = [option];
    }
  }

  bool get canExport =>
      !_disposed &&
      !loading &&
      errorKey == null &&
      rows.isNotEmpty &&
      _loaded != null &&
      mapEquals(_loaded, parameters);

  bool get canPage => !loading && errorKey == null;

  /// Wrong dates are fixed in the filters, not by retrying.
  bool get canRetry => errorKey != missingDates && errorKey != invertedDates;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() => Future.wait([load(), loadOptions()]);

  /// Sets the selection of [filter]; an empty set means All. A locked
  /// filter keeps its value.
  Future<void> select(SalesReportFilter filter, Set<String> ids) {
    if (isLocked(filter)) return Future.value();
    final clean = {
      for (final id in ids)
        if (id.trim().isNotEmpty) id.trim()
    };
    if (setEquals(clean, selected[filter] ?? const <String>{})) {
      return Future.value();
    }
    if (clean.isEmpty) {
      selected.remove(filter);
    } else {
      selected[filter] = clean;
    }
    return load();
  }

  Future<void> setPeriod(ReportPeriod? value) {
    if (value == null || value == period || !periods.contains(value)) {
      return Future.value();
    }
    // Custom starts from the range on screen, so it never silently widens
    // to every order; a preset replaces the custom dates.
    final shown = period.approximateRange(_clock());
    customFrom = value == ReportPeriod.custom ? shown.from : null;
    customTo = value == ReportPeriod.custom ? shown.to : null;
    period = value;
    return load();
  }

  Future<void> setCustomDate(DateTime? value, {required bool from}) {
    final day =
        value == null ? null : DateTime(value.year, value.month, value.day);
    period = ReportPeriod.custom;
    if (from) {
      customFrom = day;
    } else {
      customTo = day;
    }
    return load();
  }

  Future<void> setOldestFirst(bool? value) {
    if (value == null || value == oldestFirst) return Future.value();
    oldestFirst = value;
    return load();
  }

  Future<void> reset() {
    if (_disposed) return Future.value();
    period = defaultPeriod;
    customFrom = customTo = null;
    selected.clear();
    _applyLocked();
    oldestFirst = false;
    resetRevision++;
    return load();
  }

  Future<void> submit() => load();
  Future<void> retry() => load(requestedPage: _requestedPage);
  Future<void> goToPage(int value) =>
      canPage && value >= 1 && value <= totalPages && value != page
          ? load(requestedPage: value)
          : Future.value();

  Future<void> load({int requestedPage = 1}) async {
    if (_disposed) return;
    _requestedPage = requestedPage;
    final generation = ++_generation;
    // Custom needs both dates (the API's custom range is untested open-ended).
    final dateError = period != ReportPeriod.custom
        ? null
        : customFrom == null || customTo == null
            ? missingDates
            : customRange.isInverted
                ? invertedDates
                : null;
    if (dateError != null) {
      loading = false;
      errorKey = dateError;
      _notify();
      return;
    }
    final params = parameters;
    loading = true;
    errorKey = null;
    _notify();
    try {
      final scope = await readScope();
      if (_disposed || generation != _generation) return;
      final response = await fetch(params, requestedPage, pageSize);
      if (_disposed || generation != _generation) return;
      if (scope != await readScope()) {
        throw StateError('Sales report session changed');
      }
      if (_disposed || generation != _generation) return;
      if (requestedPage > response.lastPage) {
        // The result shrank below this page (e.g. a refresh after the month
        // rolled over): show its new last page instead of an error.
        return load(requestedPage: response.lastPage);
      }
      if (response.currentPage != requestedPage ||
          response.rows.length > response.perPage) {
        throw StateError('Invalid sales report page');
      }
      rows = List.unmodifiable(response.rows);
      page = requestedPage;
      totalPages = response.lastPage;
      total = response.total;
      summary = Map.unmodifiable(response.summary);
      for (final row in rows) {
        final id = row.salesExecutiveId, name = row.salesExecutive;
        if (id != null && name != null && name.trim().isNotEmpty) {
          _seenExecutives['$id'] = name;
        }
      }
      _loaded = params;
      _scope = scope;
    } catch (_) {
      if (!_disposed && generation == _generation) errorKey = unavailable;
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  /// Whether [filter]'s options are still on their way (its picker shows a
  /// spinner instead of an empty list).
  bool optionsLoading(SalesReportFilter filter) =>
      _optionsPending.contains(filter);

  /// Some filter's options could not be loaded (shown with Retry).
  bool get optionsFailed => _optionsFailed.isNotEmpty;

  final _optionsPending = <SalesReportFilter>{};
  final _optionsFailed = <SalesReportFilter>{};

  /// The newest request per filter; an older answer is ignored.
  final _optionsRequest = <SalesReportFilter, int>{};

  /// Loads the options of [only] these filters (default: all). Each is
  /// independent: one failing does not block the report or the others, its
  /// picker is ready as soon as its own list arrives, and a failure shows at
  /// once.
  Future<void> loadOptions({Iterable<SalesReportFilter>? only}) async {
    if (_disposed) return;
    final targets = [
      for (final filter in only ?? loaders.keys)
        if (loaders.containsKey(filter)) filter
    ];
    if (targets.isEmpty) return;
    for (final filter in targets) {
      _optionsRequest[filter] = ++_optionsGeneration;
      _optionsPending.add(filter);
      _optionsFailed.remove(filter);
    }
    _notify();
    Future<void> loadOne(SalesReportFilter filter) async {
      final request = _optionsRequest[filter];
      bool current() => !_disposed && _optionsRequest[filter] == request;
      try {
        final list = await loaders[filter]!();
        if (current()) options[filter] = List.unmodifiable(list);
      } catch (_) {
        if (current()) _optionsFailed.add(filter);
      } finally {
        if (current()) {
          _optionsPending.remove(filter);
          _notify();
        }
      }
    }

    await Future.wait([for (final filter in targets) loadOne(filter)]);
  }

  /// Reloads only the filters whose options failed.
  Future<void> retryOptions() => loadOptions(only: _optionsFailed.toList());

  /// Options of one filter as id → label (for the pickers): the loaded list
  /// plus executives only seen in report rows.
  Map<String, String> optionMap(SalesReportFilter filter) {
    final loaded = options[filter] ?? const <SalesReportOption>[];
    return {
      for (final option in loaded)
        if (option.id.isNotEmpty) option.id: option.label,
      if (filter == SalesReportFilter.salesExecutive)
        for (final entry in _seenExecutives.entries)
          if (!loaded.any((o) => o.id == entry.key)) entry.key: entry.value,
    };
  }

  /// What the current filters are, as (label key, value) pairs with picker
  /// names instead of ids; [translate] marks values that are keys too (never
  /// user data such as names). Used for the export.
  List<(String, String, {bool translate})> get appliedFilters => [
        ('order_sales_report.date_range', period.labelKey, translate: true),
        if (period == ReportPeriod.custom && customFrom != null)
          (
            'order_sales_report.from_date',
            reportApiDate(customFrom!),
            translate: false
          ),
        if (period == ReportPeriod.custom && customTo != null)
          (
            'order_sales_report.to_date',
            reportApiDate(customTo!),
            translate: false
          ),
        for (final filter in SalesReportFilter.values)
          if (ids(filter) case final picked when picked.isNotEmpty)
            (filter.labelKey, _names(filter, picked), translate: false),
      ];

  String _names(SalesReportFilter filter, List<String> picked) {
    final names = optionMap(filter);
    return [for (final id in picked) names[id] ?? id].join(', ');
  }

  /// Rereads every page of the loaded filters and builds the file. Stops when
  /// filters, session or permission change while it runs; paging or
  /// refreshing the table meanwhile does not.
  Future<T> export<T>(
      {required Future<T> Function(List<SalesReportRow> rows) build,
      required bool Function() permissionUnchanged,
      void Function(int page, int total)? progress}) async {
    if (!canExport) throw StateError('Sales report export unavailable');
    final params = parameters, scope = _scope;
    Future<void> check() async {
      if (_disposed ||
          !mapEquals(params, parameters) ||
          !permissionUnchanged()) {
        throw StateError('Sales report export changed');
      }
      final current = await readScope();
      if (_disposed ||
          !mapEquals(params, parameters) ||
          current != scope ||
          !permissionUnchanged()) {
        throw StateError('Sales report export session changed');
      }
    }

    Future<List<SalesReportRow>> snapshot() =>
        salesReportSnapshot((page) async {
          await check();
          final response = await fetch(params, page, exportPageSize);
          await check();
          return response;
        }, progress: progress);

    // Live sales can move rows between page reads; reread a few times before
    // failing. Filter, session and permission changes still stop at once.
    List<SalesReportRow>? all;
    for (var attempt = 1; all == null; attempt++) {
      try {
        all = await snapshot();
      } on SalesReportSnapshotChanged {
        if (attempt >= exportAttempts) rethrow;
      }
    }
    await check();
    final result = await build(all);
    await check();
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
