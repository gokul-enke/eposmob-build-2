import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show TextEditingController;
import 'package:pos_machine/core/utils/search_debouncer.dart';
import '../../data/discount_sale_report_snapshot.dart';
import '../../domain/discount_sale_report_query.dart';
import '../../domain/models/discount_sale_report.dart';
import '../../domain/report_date_range.dart';
import '../../domain/report_period.dart';

typedef DiscountSaleReportFetch = Future<DiscountSaleReportResponse> Function(
    Map<String, String> parameters, int page, int perPage);

typedef DiscountSaleReportOptionsLoader = Future<List<DiscountSaleReportOption>>
    Function();

/// Filters, server paging and export of the Discount Sale Report: Discount
/// Type, Order / Offline Receipt Number, single-choice Executive, Customer
/// and Store, and the Date Range.
///
/// A newer request always wins; a failed reload keeps the previous rows,
/// shows an error with Retry and disables Export and paging until it
/// recovers.
class DiscountSaleReportController extends ChangeNotifier {
  DiscountSaleReportController(
      {required this.fetch,
      required this.readScope,
      this.loaders = const {},
      this.locked = const {},
      DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    _search = SearchDebouncer(() => load());
    orderNumber.addListener(_orderNumberChanged);
    _applyLocked();
  }

  static const pageSize = 25;

  /// The API accepts at most 100 rows per page.
  static const exportPageSize = 100;

  /// Reads of a snapshot whose rows moved before the export fails.
  static const exportAttempts = 3;
  static const defaultPeriod = ReportPeriod.thisMonth;
  static const missingDates = 'discount_sale_report.missing_dates';
  static const invertedDates = 'discount_sale_report.inverted_dates';
  static const unavailable = 'discount_sale_report.unavailable';

  final DiscountSaleReportFetch fetch;
  final Future<DiscountSaleReportScope> Function() readScope;
  final Map<DiscountSaleReportFilter, DiscountSaleReportOptionsLoader> loaders;

  /// Filters fixed for this user (a sales executive sees only their own
  /// discounts in the store they are logged into): selected from the start,
  /// unchangeable, kept by Reset and not counted as active filters.
  final Map<DiscountSaleReportFilter, DiscountSaleReportOption> locked;
  final DateTime Function() _clock;
  late final SearchDebouncer _search;

  ReportPeriod period = defaultPeriod;

  /// Whole days of the Custom range; either may be open.
  DateTime? customFrom, customTo;

  DiscountType discountType = DiscountType.all;

  /// Order number or offline receipt number, partial. Edits reload after a
  /// short pause.
  final orderNumber = TextEditingController();

  /// Picked id per picker; a missing entry means All.
  final selected = <DiscountSaleReportFilter, String>{};
  final options = <DiscountSaleReportFilter, List<DiscountSaleReportOption>>{};

  List<DiscountSaleReportRow> rows = const [];
  bool loading = false;
  String? errorKey;
  int page = 1, totalPages = 1, resetRevision = 0;
  int? total;

  /// Totals of the loaded filters over every page.
  Map<String, double> summary = const {};

  bool _disposed = false, _resetting = false;
  int _generation = 0, _requestedPage = 1, _optionsGeneration = 0;
  String _lastOrderNumber = '';
  Map<String, String>? _loaded;
  DiscountSaleReportScope? _scope;

  /// Executives seen in loaded rows (id → name), which the directory API may
  /// not list.
  final _seenExecutives = <String, String>{};

  /// Date Range options, in display order.
  List<ReportPeriod> get periods => DiscountSaleReportParams.periods;

  ReportDateRange get customRange =>
      ReportDateRange(from: customFrom, to: customTo);

  /// The API request for the current filters (without paging).
  Map<String, String> get parameters {
    final number = orderNumber.text.trim();
    final custom = period == ReportPeriod.custom;
    return {
      DiscountSaleReportParams.dateRange:
          DiscountSaleReportParams.periodCode(period),
      for (final entry in selected.entries) entry.key.parameter: entry.value,
      if (discountType != DiscountType.all)
        DiscountSaleReportParams.discountType: discountType.code,
      if (number.isNotEmpty) DiscountSaleReportParams.orderNumber: number,
      if (custom && customFrom != null)
        DiscountSaleReportParams.from: reportApiDate(customFrom!),
      if (custom && customTo != null)
        DiscountSaleReportParams.to: reportApiDate(customTo!),
    };
  }

  bool get hasActiveFilters =>
      period != defaultPeriod ||
      selected.keys.any((filter) => !locked.containsKey(filter)) ||
      discountType != DiscountType.all ||
      orderNumber.text.trim().isNotEmpty;

  bool isLocked(DiscountSaleReportFilter filter) => locked.containsKey(filter);

  /// Selects the locked options; a known name is shown without loading.
  void _applyLocked() {
    for (final MapEntry(key: filter, value: option) in locked.entries) {
      selected[filter] = option.id;
      if (option.label.trim().isNotEmpty) options[filter] = [option];
    }
  }

  bool get canExport =>
      !_disposed &&
      !_search.isPending &&
      !loading &&
      errorKey == null &&
      rows.isNotEmpty &&
      _loaded != null &&
      mapEquals(_loaded, parameters);

  bool get canPage => !loading && !_search.isPending && errorKey == null;

  /// Wrong dates are fixed in the filters, not by retrying.
  bool get canRetry => errorKey != missingDates && errorKey != invertedDates;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _orderNumberChanged() {
    // Compared as sent: spaces around the number change nothing.
    final number = orderNumber.text.trim();
    if (_disposed || _resetting || number == _lastOrderNumber) return;
    _lastOrderNumber = number;
    // Invalidate the shown result at once; the request waits for typing.
    _generation++;
    _requestedPage = 1;
    loading = false;
    _search.schedule();
    _notify();
  }

  Future<void> initialize() => Future.wait([load(), loadOptions()]);

  /// Sets the picked id of [filter]; null or empty means All. A locked
  /// filter keeps its value.
  Future<void> select(DiscountSaleReportFilter filter, String? id) {
    if (isLocked(filter)) return Future.value();
    final clean = id?.trim() ?? '';
    if (clean == (selected[filter] ?? '')) return Future.value();
    if (clean.isEmpty) {
      selected.remove(filter);
    } else {
      selected[filter] = clean;
    }
    return load();
  }

  Future<void> setDiscountType(DiscountType? value) {
    if (value == null || value == discountType) return Future.value();
    discountType = value;
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

  Future<void> reset() {
    if (_disposed) return Future.value();
    _resetting = true;
    orderNumber.clear();
    _lastOrderNumber = '';
    _resetting = false;
    period = defaultPeriod;
    customFrom = customTo = null;
    discountType = DiscountType.all;
    selected.clear();
    _applyLocked();
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
    _search.cancel();
    _requestedPage = requestedPage;
    final generation = ++_generation;
    // Custom needs both dates (the API's custom range is untested
    // open-ended).
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
        throw StateError('Discount report session changed');
      }
      if (_disposed || generation != _generation) return;
      if (requestedPage > response.lastPage) {
        // The result shrank below this page (e.g. a refresh after the day or
        // month rolled over): show its new last page instead of an error.
        return load(requestedPage: response.lastPage);
      }
      if (response.currentPage != requestedPage ||
          response.rows.length > response.perPage) {
        throw StateError('Invalid discount report page');
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
  bool optionsLoading(DiscountSaleReportFilter filter) =>
      _optionsPending.contains(filter);

  /// Some picker's options could not be loaded (shown with Retry).
  bool get optionsFailed => _optionsFailed.isNotEmpty;

  final _optionsPending = <DiscountSaleReportFilter>{};
  final _optionsFailed = <DiscountSaleReportFilter>{};

  /// The newest request per picker; an older answer is ignored.
  final _optionsRequest = <DiscountSaleReportFilter, int>{};

  /// Loads [only] these pickers' options (default: all). Each is
  /// independent: one failing does not block the report or the others, its
  /// picker is ready as soon as its own list arrives, and a failure shows at
  /// once.
  Future<void> loadOptions({Iterable<DiscountSaleReportFilter>? only}) async {
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
    Future<void> loadOne(DiscountSaleReportFilter filter) async {
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

  /// Reloads only the pickers whose options failed.
  Future<void> retryOptions() => loadOptions(only: _optionsFailed.toList());

  /// Options of one picker as id → label: the loaded list plus, for the
  /// Executive, anyone only seen in report rows.
  Map<String, String> optionMap(DiscountSaleReportFilter filter) {
    final loaded = options[filter] ?? const <DiscountSaleReportOption>[];
    return {
      for (final option in loaded)
        if (option.id.isNotEmpty) option.id: option.label,
      if (filter == DiscountSaleReportFilter.salesExecutive)
        for (final entry in _seenExecutives.entries)
          if (!loaded.any((o) => o.id == entry.key)) entry.key: entry.value,
    };
  }

  /// What the current filters are, as (label key, value) pairs with picker
  /// names instead of ids; [translate] marks values that are keys too (never
  /// user data such as names or the typed number). Used for the export.
  List<(String, String, {bool translate})> get appliedFilters {
    final number = orderNumber.text.trim();
    return [
      ('discount_sale_report.date_range', period.labelKey, translate: true),
      if (period == ReportPeriod.custom && customFrom != null)
        (
          'discount_sale_report.from_date',
          reportApiDate(customFrom!),
          translate: false
        ),
      if (period == ReportPeriod.custom && customTo != null)
        (
          'discount_sale_report.to_date',
          reportApiDate(customTo!),
          translate: false
        ),
      for (final filter in DiscountSaleReportFilter.values)
        if (selected[filter] case final String id)
          (filter.labelKey, optionMap(filter)[id] ?? id, translate: false),
      if (discountType != DiscountType.all)
        (
          'discount_sale_report.filter_discount_type',
          discountType.labelKey,
          translate: true
        ),
      if (number.isNotEmpty)
        ('discount_sale_report.filter_order_number', number, translate: false),
    ];
  }

  /// Rereads every page of the loaded filters and builds the file. Stops when
  /// filters, session or permission change while it runs; paging or
  /// refreshing the table meanwhile does not.
  Future<T> export<T>(
      {required Future<T> Function(List<DiscountSaleReportRow> rows) build,
      required bool Function() permissionUnchanged,
      void Function(int page, int total)? progress}) async {
    if (!canExport) throw StateError('Discount report export unavailable');
    final params = parameters, scope = _scope;
    Future<void> check() async {
      if (_disposed ||
          !mapEquals(params, parameters) ||
          !permissionUnchanged()) {
        throw StateError('Discount report export changed');
      }
      final current = await readScope();
      if (_disposed ||
          !mapEquals(params, parameters) ||
          current != scope ||
          !permissionUnchanged()) {
        throw StateError('Discount report export session changed');
      }
    }

    Future<List<DiscountSaleReportRow>> snapshot() =>
        discountSaleReportSnapshot((page) async {
          await check();
          final response = await fetch(params, page, exportPageSize);
          await check();
          return response;
        }, progress: progress);

    // Live sales can move rows between page reads; reread a few times before
    // failing. Filter, session and permission changes still stop at once.
    List<DiscountSaleReportRow>? all;
    for (var attempt = 1; all == null; attempt++) {
      try {
        all = await snapshot();
      } on DiscountSaleReportSnapshotChanged {
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
    _search.dispose();
    orderNumber.removeListener(_orderNumberChanged);
    orderNumber.dispose();
    super.dispose();
  }
}
