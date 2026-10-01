import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/customer_list.dart';

/// Credit/debit filter of the transactions tab.
enum TransactionDirection {
  credit('credit', 'customer_profile.type_credit'),
  debit('debit', 'customer_profile.type_debit');

  const TransactionDirection(this.apiValue, this.translationKey);

  /// Value of the API's `type` query parameter.
  final String apiValue;
  final String translationKey;
}

/// One request to the customer transactions endpoint.
@immutable
class CustomerTransactionsQuery {
  const CustomerTransactionsQuery({
    required this.accessToken,
    required this.customerId,
    required this.page,
    required this.perPage,
    this.dateFrom,
    this.dateTo,
    this.type,
  });

  final String accessToken;
  final String customerId;
  final int page;
  final int perPage;

  /// `yyyy-MM-dd`.
  final String? dateFrom;
  final String? dateTo;

  /// `credit` or `debit`.
  final String? type;
}

/// Calls the API and returns its raw JSON (`{data: {data: [...],
/// current_page, last_page}}`), e.g. `InvoiceProvider.listCustomerTransactions`.
typedef CustomerTransactionsFetcher = Future<dynamic> Function(
  CustomerTransactionsQuery query,
);

/// Filters applied to the transactions list.
@immutable
class CustomerTransactionFilter {
  const CustomerTransactionFilter({this.reference, this.range, this.type});

  /// Client-side "reference contains" filter on the loaded page.
  final String? reference;
  final DateTimeRange? range;
  final TransactionDirection? type;

  static const empty = CustomerTransactionFilter();
}

/// Totals of the visible transactions.
@immutable
class TransactionTotals {
  const TransactionTotals({required this.credit, required this.debit});

  final double credit;
  final double debit;
  double get net => credit - debit;
}

/// Loads and pages a customer's transactions, keeps the filter draft and the
/// applied filter, and computes the visible rows and totals.
class CustomerTransactionsController extends ChangeNotifier {
  CustomerTransactionsController({
    required CustomerTransactionsFetcher fetch,
    required String? Function() readToken,
    required String? customerId,
    List<CustomerTransaction> initial = const [],
    this.perPage = 20,
  })  : _fetch = fetch,
        _readToken = readToken,
        _customerId = customerId,
        _transactions = List.of(initial) {
    _visible = _applyLocal(_transactions);
  }

  static final _apiDate = DateFormat('yyyy-MM-dd');

  final CustomerTransactionsFetcher _fetch;
  final String? Function() _readToken;
  final int perPage;

  String? _customerId;
  List<CustomerTransaction> _transactions;
  List<CustomerTransaction> _visible = const [];
  bool _isLoading = false;
  bool _hasError = false;
  int _currentPage = 1;
  int _lastPage = 1;
  int _requestSeq = 0;
  bool _disposed = false;

  CustomerTransactionFilter _filter = CustomerTransactionFilter.empty;
  bool _filtersVisible = false;

  /// Draft values edited in the filter panel; committed by [applyFilters].
  final referenceController = TextEditingController();
  DateTimeRange? _draftRange;
  TransactionDirection? _draftType;

  List<CustomerTransaction> get transactions => _visible;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  int get currentPage => _currentPage;
  int get lastPage => _lastPage;
  CustomerTransactionFilter get filter => _filter;
  bool get filtersVisible => _filtersVisible;
  DateTimeRange? get draftRange => _draftRange;
  TransactionDirection? get draftType => _draftType;

  TransactionTotals get totals {
    var credit = 0.0;
    var debit = 0.0;
    for (final transaction in _visible) {
      final amount = absoluteAmount(transaction);
      if (isCredit(transaction)) {
        credit += amount;
      } else {
        debit += amount;
      }
    }
    return TransactionTotals(credit: credit, debit: debit);
  }

  /// Credit when the type says so or the amount carries a `+`.
  static bool isCredit(CustomerTransaction transaction) {
    return transaction.type?.toLowerCase() == 'credit' ||
        (transaction.amount?.contains('+') ?? false);
  }

  static double absoluteAmount(CustomerTransaction transaction) {
    final raw = transaction.amount?.replaceAll('+', '').replaceAll('-', '');
    return double.tryParse(raw ?? '') ?? 0.0;
  }

  static String formatApiDate(DateTime date) => _apiDate.format(date);

  /// Switches to another customer and reloads from page 1.
  Future<void> setCustomer(String? customerId) {
    _customerId = customerId;
    return load(page: 1);
  }

  Future<void> load({required int page}) async {
    final token = _readToken();
    final customerId = _customerId;
    if (token == null ||
        token.isEmpty ||
        customerId == null ||
        customerId.isEmpty) {
      return;
    }

    final request = ++_requestSeq;
    _isLoading = true;
    _hasError = false;
    _notify();

    final range = _filter.range;
    try {
      final response = await _fetch(
        CustomerTransactionsQuery(
          accessToken: token,
          customerId: customerId,
          dateFrom: range == null ? null : formatApiDate(range.start),
          dateTo: range == null ? null : formatApiDate(range.end),
          type: _filter.type?.apiValue,
          perPage: perPage,
          page: page,
        ),
      );
      if (request != _requestSeq || _disposed) return;

      final data = response is Map ? response['data'] : null;
      final rows = (data is Map && data['data'] is List)
          ? data['data'] as List
          : const [];
      _transactions = rows
          .whereType<Map>()
          .map((row) =>
              CustomerTransaction.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      _currentPage = (data is Map && data['current_page'] is num)
          ? (data['current_page'] as num).toInt()
          : page;
      _lastPage = (data is Map && data['last_page'] is num)
          ? (data['last_page'] as num).toInt()
          : 1;
      _visible = _applyLocal(_transactions);
    } catch (error) {
      if (request != _requestSeq || _disposed) return;
      debugPrint('Failed to load customer transactions: $error');
      _hasError = true;
    }
    _isLoading = false;
    _notify();
  }

  Future<void> retry() => load(page: _currentPage);

  void goToPage(int page) {
    if (page < 1 || page > _lastPage || page == _currentPage) return;
    load(page: page);
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

  void setDraftType(TransactionDirection? type) {
    _draftType = type;
    _notify();
  }

  /// Commits the draft, closes the panel and reloads page 1.
  Future<void> applyFilters() {
    final reference = referenceController.text.trim();
    _filter = CustomerTransactionFilter(
      reference: reference.isEmpty ? null : reference,
      range: _draftRange,
      type: _draftType,
    );
    _filtersVisible = false;
    return load(page: 1);
  }

  /// Clears every filter, closes the panel and reloads page 1.
  Future<void> resetFilters() {
    referenceController.clear();
    _draftRange = null;
    _draftType = null;
    _filter = CustomerTransactionFilter.empty;
    _filtersVisible = false;
    return load(page: 1);
  }

  List<CustomerTransaction> _applyLocal(List<CustomerTransaction> source) {
    final reference = _filter.reference?.toLowerCase();
    final range = _filter.range;
    final type = _filter.type;
    return source.where((transaction) {
      if (reference != null && reference.isNotEmpty) {
        final value = transaction.reference?.toLowerCase();
        if (value == null || !value.contains(reference)) return false;
      }
      if (range != null) {
        final date = _parseDay(transaction.date);
        if (date == null) return false;
        final start = DateUtils.dateOnly(range.start);
        final end = DateUtils.dateOnly(range.end);
        if (date.isBefore(start) || date.isAfter(end)) return false;
      }
      if (type != null) {
        final credit = isCredit(transaction);
        if (type == TransactionDirection.credit && !credit) return false;
        if (type == TransactionDirection.debit && credit) return false;
      }
      return true;
    }).toList();
  }

  /// The calendar day of [value] (`yyyy-MM-dd`, ISO date-time, or
  /// `dd-MM-yyyy ...`).
  static DateTime? _parseDay(String? value) {
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
