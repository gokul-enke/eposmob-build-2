import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/core/pagination/page_slice.dart';

import '../../domain/models/supplier.dart';

/// Loads every transaction of a supplier, e.g. the ones embedded in the
/// selected [Supplier].
typedef SupplierTransactionsFetcher = Future<List<SupplierTransaction>>
    Function();

/// Credit/debit filter of the transactions tab.
enum SupplierTransactionDirection {
  credit('supplier_profile.trans_type_credit'),
  debit('supplier_profile.trans_type_debit');

  const SupplierTransactionDirection(this.translationKey);

  final String translationKey;
}

/// Filters applied to the transactions list.
@immutable
class SupplierTransactionFilter {
  const SupplierTransactionFilter({this.reference, this.range, this.type});

  /// "Reference contains" (case-insensitive).
  final String? reference;
  final DateTimeRange? range;
  final SupplierTransactionDirection? type;

  bool get isEmpty =>
      (reference == null || reference!.isEmpty) &&
      range == null &&
      type == null;

  static const empty = SupplierTransactionFilter();
}

/// Loads a supplier's transactions, filters them locally and shows them
/// [perPage] at a time. Keeps the filter-panel draft and the applied filter.
class SupplierTransactionsController extends ChangeNotifier {
  SupplierTransactionsController({
    required SupplierTransactionsFetcher fetch,
    this.perPage = 20,
  }) : _fetch = fetch;

  static final _apiDate = DateFormat('yyyy-MM-dd');

  final SupplierTransactionsFetcher _fetch;
  final int perPage;

  List<SupplierTransaction> _all = const [];
  List<SupplierTransaction> _filtered = const [];
  bool _isLoading = false;
  bool _hasError = false;
  int _page = 1;
  int _requestSeq = 0;
  bool _disposed = false;

  SupplierTransactionFilter _filter = SupplierTransactionFilter.empty;
  bool _filtersVisible = false;

  /// Draft values edited in the filter panel; committed by [applyFilters].
  final referenceController = TextEditingController();
  DateTimeRange? _draftRange;
  SupplierTransactionDirection? _draftType;

  /// Every loaded transaction, unfiltered (what the report prints).
  List<SupplierTransaction> get allTransactions => _all;

  /// Every transaction matching [filter], across pages.
  List<SupplierTransaction> get filteredTransactions => _filtered;

  PageSlice<SupplierTransaction> get _slice =>
      PageSlice.of(_filtered, page: _page, perPage: perPage);

  /// Transactions on the current page.
  List<SupplierTransaction> get transactions => _slice.items;
  int get currentPage => _slice.currentPage;
  int get totalPages => _slice.totalPages;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  SupplierTransactionFilter get filter => _filter;
  bool get filtersVisible => _filtersVisible;
  DateTimeRange? get draftRange => _draftRange;
  SupplierTransactionDirection? get draftType => _draftType;

  bool get showPagination =>
      !_isLoading && !_hasError && _filtered.isNotEmpty && totalPages > 1;

  static bool isCredit(SupplierTransaction transaction) =>
      transaction.type.trim().toLowerCase() == 'credit';

  static String formatApiDate(DateTime date) => _apiDate.format(date);

  /// Loads every transaction and shows page 1.
  Future<void> load() async {
    final request = ++_requestSeq;
    _isLoading = true;
    _hasError = false;
    _notify();
    try {
      final result = await _fetch();
      if (request != _requestSeq || _disposed) return;
      _all = List<SupplierTransaction>.unmodifiable(result);
      _filtered = _applyLocal(_all);
      _page = 1;
    } catch (error) {
      if (request != _requestSeq || _disposed) return;
      debugPrint('Failed to load supplier transactions: $error');
      _all = const [];
      _filtered = const [];
      _hasError = true;
    }
    _isLoading = false;
    _notify();
  }

  Future<void> retry() => load();

  void goToPage(int page) {
    if (page < 1 || page > totalPages || page == currentPage) return;
    _page = page;
    _notify();
  }

  void toggleFilters() {
    _filtersVisible = !_filtersVisible;
    if (_filtersVisible) {
      referenceController.text = _filter.reference ?? '';
      _draftRange = _filter.range;
      _draftType = _filter.type;
    }
    _notify();
  }

  void setDraftRange(DateTimeRange? range) {
    _draftRange = range;
    _notify();
  }

  void setDraftType(SupplierTransactionDirection? type) {
    _draftType = type;
    _notify();
  }

  /// Commits the draft, closes the panel and shows page 1.
  void applyFilters() {
    final reference = referenceController.text.trim();
    _filter = SupplierTransactionFilter(
      reference: reference.isEmpty ? null : reference,
      range: _draftRange,
      type: _draftType,
    );
    _filtersVisible = false;
    _refilter();
  }

  /// Clears every filter, closes the panel and shows page 1.
  void resetFilters() {
    referenceController.clear();
    _draftRange = null;
    _draftType = null;
    _filter = SupplierTransactionFilter.empty;
    _filtersVisible = false;
    _refilter();
  }

  void _refilter() {
    _filtered = _applyLocal(_all);
    _page = 1;
    _notify();
  }

  List<SupplierTransaction> _applyLocal(List<SupplierTransaction> source) {
    final reference = _filter.reference?.toLowerCase();
    final range = _filter.range;
    final type = _filter.type;
    return source.where((transaction) {
      if (reference != null && reference.isNotEmpty) {
        if (!transaction.reference.toLowerCase().contains(reference)) {
          return false;
        }
      }
      if (range != null) {
        final date = parseDay(transaction.date);
        if (date == null) return false;
        final start = DateUtils.dateOnly(range.start);
        final end = DateUtils.dateOnly(range.end);
        if (date.isBefore(start) || date.isAfter(end)) return false;
      }
      if (type != null) {
        final credit = isCredit(transaction);
        if (type == SupplierTransactionDirection.credit && !credit) {
          return false;
        }
        if (type == SupplierTransactionDirection.debit && credit) return false;
      }
      return true;
    }).toList(growable: false);
  }

  /// The calendar day of [value] (`yyyy-MM-dd`, ISO date-time, or
  /// `dd-MM-yyyy ...`); `null` when it cannot be read.
  static DateTime? parseDay(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();
    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return DateUtils.dateOnly(iso);
    final first = trimmed.split(' ').first;
    for (final pattern in const ['yyyy-MM-dd', 'dd-MM-yyyy']) {
      try {
        return DateUtils.dateOnly(DateFormat(pattern).parseStrict(first));
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    referenceController.dispose();
    super.dispose();
  }
}
