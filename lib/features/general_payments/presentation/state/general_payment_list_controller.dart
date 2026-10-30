import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show TextEditingController;
import 'package:pos_machine/core/pagination/page_slice.dart';
import '../../../reports/domain/report_period.dart';
import '../../domain/general_payment_entry.dart';
import '../../domain/general_payment_filter.dart';
import '../../domain/general_payment_totals.dart';
import '../../domain/general_payment_type.dart';
import '../../domain/models/general_payment.dart';

/// Loads the store's general payments; null when [isCurrent] turned false.
typedef GeneralPaymentFetch = Future<List<GeneralPayment>?> Function(
    bool Function() isCurrent);

/// The General Payments list: every entry is loaded once, then filtered,
/// totalled and paged in memory, so filters apply at once.
///
/// A newer load always wins; a failed reload keeps the entries on screen
/// with an error and Retry, and disables Export until it recovers.
class GeneralPaymentListController extends ChangeNotifier {
  GeneralPaymentListController(
      {required this.fetch, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    reference.addListener(_referenceChanged);
  }

  static const pageSize = 25;
  static const loadError = 'general_payments.load_error';
  static const invertedDates = 'general_payments.inverted_dates';

  /// Date Range options after All dates, in display order.
  static const periods = [
    ReportPeriod.today,
    ReportPeriod.thisWeek,
    ReportPeriod.thisMonth,
    ReportPeriod.lastMonth,
    ReportPeriod.last3Months,
    ReportPeriod.custom,
  ];

  final GeneralPaymentFetch fetch;
  final DateTime Function() _clock;

  /// Reference number, partial; filters as it is typed.
  final reference = TextEditingController();

  GeneralPaymentFilter _filter = GeneralPaymentFilter.none;
  List<GeneralPayment> _all = const [];
  List<GeneralPayment> _filtered = const [];
  PageSlice<GeneralPayment> _slice =
      const PageSlice(items: [], currentPage: 1, totalPages: 1, totalItems: 0);
  GeneralPaymentTotals _totals = GeneralPaymentTotals.zero;
  bool _loading = false, _loaded = false, _disposed = false;
  String? _errorKey;
  int _generation = 0;

  GeneralPaymentFilter get filter => _filter;
  bool get loading => _loading;

  /// Entries arrived at least once (the totals are meaningful).
  bool get loaded => _loaded;

  /// Why the entries on screen may be stale; null when they are fresh.
  String? get errorKey => _errorKey;

  /// Why the filters match nothing; fixed in the filters, not by Retry.
  String? get filterErrorKey => _filter.isInverted ? invertedDates : null;

  int get totalCount => _all.length;
  int get matchCount => _filtered.length;
  List<GeneralPayment> get filteredRows => _filtered;
  List<GeneralPayment> get pageRows => _slice.items;
  int get page => _slice.currentPage;
  int get totalPages => _slice.totalPages;
  GeneralPaymentTotals get totals => _totals;
  bool get hasActiveFilters => _filter.isActive;

  /// Each reference series' expected next number (EXP → EXP00121, LRP →
  /// LRP00002) among every loaded entry, for New Entry to show; empty until
  /// entries arrive.
  Map<String, String> get nextReferences => {
        if (_loaded)
          for (final prefix in generalPaymentReferencePrefixes)
            if (nextGeneralPaymentReference(
                    prefix, _all.map((row) => row.referenceNumber))
                case final next?)
              prefix: next,
      };

  bool get canExport =>
      !_disposed && !_loading && _errorKey == null && _filtered.isNotEmpty;

  /// Category id → name among the loaded entries of the chosen type (every
  /// type under All), sorted by name.
  Map<String, String> get categoryOptions =>
      _options((row) => (row.categoryId, row.category));
  Map<String, String> get debitAccountOptions =>
      _options((row) => (row.debitAccountId, row.debitAccount));
  Map<String, String> get creditAccountOptions =>
      _options((row) => (row.creditAccountId, row.creditAccount));

  Map<String, String> _options(
      (String?, String) Function(GeneralPayment row) pick) {
    final found = <String, String>{};
    for (final row in _all) {
      if (_filter.type != null && row.type != _filter.type) continue;
      final (id, label) = pick(row);
      if (id != null) found.putIfAbsent(id, () => label.isEmpty ? id : label);
    }
    final sorted = found.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return Map.fromEntries(sorted);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Refilters after a filter change; the list goes back to its first page
  /// unless [keepPage] (a reload of the same filters).
  void _apply({bool keepPage = false}) {
    final now = _clock();
    _filtered =
        List.unmodifiable(_all.where((row) => _filter.matches(row, now)));
    _totals = GeneralPaymentTotals.of(_filtered);
    _slice = PageSlice.of(_filtered,
        page: keepPage ? _slice.currentPage : 1, perPage: pageSize);
  }

  void _setFilter(GeneralPaymentFilter next) {
    if (_disposed || next == _filter) return;
    _filter = next;
    _apply();
    _notify();
  }

  void _referenceChanged() =>
      _setFilter(_filter.copyWith(reference: reference.text));

  /// Choosing a type keeps only the category and accounts that type uses.
  void setType(GeneralPaymentType? value) {
    if (_disposed || value == _filter.type) return;
    _filter = _filter.copyWith(type: () => value);
    _dropUnusedChoices();
    _apply();
    _notify();
  }

  /// Clears a chosen category or account no loaded entry (of the chosen type)
  /// uses any more, e.g. after a type change, a reload or a store switch.
  /// Its dropdown would show All while it still hid every entry.
  void _dropUnusedChoices() {
    final categories = categoryOptions,
        debits = debitAccountOptions,
        credits = creditAccountOptions;
    _filter = _filter.copyWith(
        categoryId: () => categories.containsKey(_filter.categoryId)
            ? _filter.categoryId
            : null,
        debitAccountId: () => debits.containsKey(_filter.debitAccountId)
            ? _filter.debitAccountId
            : null,
        creditAccountId: () => credits.containsKey(_filter.creditAccountId)
            ? _filter.creditAccountId
            : null);
  }

  void setCategory(String? id) =>
      _setFilter(_filter.copyWith(categoryId: () => id));

  void setDebitAccount(String? id) =>
      _setFilter(_filter.copyWith(debitAccountId: () => id));

  void setCreditAccount(String? id) =>
      _setFilter(_filter.copyWith(creditAccountId: () => id));

  /// Null is All dates. Custom starts from the range on screen, so switching
  /// to it never silently widens the list; a preset drops the custom dates.
  void setPeriod(ReportPeriod? value) {
    if (value == _filter.period) return;
    final shown = _filter.dateRange(_clock());
    final custom = value == ReportPeriod.custom;
    _setFilter(_filter.copyWith(
        period: () => value,
        customFrom: () => custom ? shown.from : null,
        customTo: () => custom ? shown.to : null));
  }

  void setCustomDate(DateTime? value, {required bool from}) {
    final day =
        value == null ? null : DateTime(value.year, value.month, value.day);
    _setFilter(_filter.copyWith(
        period: () => ReportPeriod.custom,
        customFrom: from ? () => day : null,
        customTo: from ? null : () => day));
  }

  void reset() {
    if (_disposed) return;
    reference.removeListener(_referenceChanged);
    reference.clear();
    reference.addListener(_referenceChanged);
    _filter = GeneralPaymentFilter.none;
    _apply();
    _notify();
  }

  void goToPage(int value) {
    if (_disposed || _loading || value == page) return;
    _slice = PageSlice.of(_filtered, page: value, perPage: pageSize);
    _notify();
  }

  /// What the list is filtered by, as (label key, value) pairs with names
  /// instead of ids; [translate] marks values that are keys too (never user
  /// data such as names or the typed reference). Used for the export.
  List<(String, String, {bool translate})> get appliedFilters {
    final f = _filter, text = f.reference.trim();
    String day(DateTime value) => reportApiDate(value);
    return [
      if (text.isNotEmpty)
        ('general_payments.filter_reference', text, translate: false),
      if (f.type case final type?)
        ('general_payments.filter_entry_type', type.labelKey, translate: true),
      if (f.categoryId case final id?)
        (
          'general_payments.filter_category',
          categoryOptions[id] ?? id,
          translate: false
        ),
      if (f.debitAccountId case final id?)
        (
          'general_payments.filter_debit_account',
          debitAccountOptions[id] ?? id,
          translate: false
        ),
      if (f.creditAccountId case final id?)
        (
          'general_payments.filter_credit_account',
          creditAccountOptions[id] ?? id,
          translate: false
        ),
      if (f.period case final period?)
        (
          'general_payments.filter_date_range',
          period.labelKey,
          translate: true
        ),
      if (f.period == ReportPeriod.custom && f.customFrom != null)
        ('general_payments.from_date', day(f.customFrom!), translate: false),
      if (f.period == ReportPeriod.custom && f.customTo != null)
        ('general_payments.to_date', day(f.customTo!), translate: false),
    ];
  }

  /// Loads every entry again. [clear] first empties the list, for a session
  /// change where the old entries belong to someone or somewhere else.
  Future<void> load({bool clear = false}) async {
    if (_disposed) return;
    final generation = ++_generation;
    bool current() => !_disposed && generation == _generation;
    if (clear) {
      _all = const [];
      _loaded = false;
      _apply();
    }
    _loading = true;
    _errorKey = null;
    _notify();
    try {
      final rows = await fetch(current);
      if (!current() || rows == null) return;
      _all = List.unmodifiable(rows);
      _loaded = true;
      final before = _filter;
      _dropUnusedChoices();
      _apply(keepPage: _filter == before);
    } catch (_) {
      if (current()) _errorKey = loadError;
    } finally {
      if (current()) {
        _loading = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    reference.removeListener(_referenceChanged);
    reference.dispose();
    super.dispose();
  }
}
