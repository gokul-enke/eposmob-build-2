import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import '../../data/sales_list_repository.dart';
import '../../domain/sales_list_query.dart';

/// Listing inputs and request generations are independent of detail/mutation state.
class SalesListController extends ChangeNotifier {
  SalesListController(this.source, this.readToken,
      {this.isOnlineSales = false});
  final SalesListSource source;
  final String Function() readToken;
  final number = TextEditingController();
  final customer = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final price = TextEditingController();
  DateTime? from, until, businessDate;
  int? storeId;
  bool isOnlineSales;
  String status = 'all';
  bool loading = false, showFilters = true, _disposed = false;
  Object? error;
  int _generation = 0, requestedPage = 1;
  Timer? _timer;
  SalesListPageData? data;
  SalesListQuery? applied;
  SalesListQuery? _inFlight;
  SalesListQuery get query => SalesListQuery(
      number: number.text,
      customer: customer.text,
      phone: phone.text,
      email: email.text,
      price: price.text,
      status: status,
      from: from,
      until: until,
      businessDate: businessDate,
      storeId: storeId,
      isOnlineSales: isOnlineSales);
  List<ListOrderModelData> get rows => data?.rows ?? const [];
  int get current => data?.current ?? 1;
  int get last => data?.last ?? 1;
  bool get matchesInputs => applied?.sameAs(query) ?? false;
  bool get canExport =>
      !loading && error == null && rows.isNotEmpty && matchesInputs;
  void notify() {
    if (!_disposed) notifyListeners();
  }

  void toggleFilters() {
    showFilters = !showFilters;
    notify();
  }

  void scheduleSearch() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), () {
      _timer = null;
      // Keep a refresh for the same query alive when input is abandoned.
      // Replace an in-flight search for different inputs even when the user
      // has returned to the previously applied query.
      if (!matchesInputs || (_inFlight != null && !_inFlight!.sameAs(query))) {
        search();
      }
    });
    notify();
  }

  Future<void> search() => load(1);
  Future<void> refresh() => load(requestedPage);
  Future<void> load(int page) async {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    final target = applied != null && !matchesInputs ? 1 : page;
    return _fetch(query, target);
  }

  /// Realtime refresh: re-runs the query on screen (or in flight) without
  /// consuming filter text that is still being typed.
  Future<void> refreshShown() {
    if (_disposed) return Future.value();
    final shown = _inFlight ?? applied;
    if (shown != null) return _fetch(shown, requestedPage);
    return _timer == null ? load(requestedPage) : Future.value();
  }

  Future<void> _fetch(SalesListQuery requested, int target) async {
    requestedPage = target;
    final generation = ++_generation;
    _inFlight = requested;
    loading = true;
    error = null;
    notify();
    try {
      final result = await source.fetch(readToken(), requested, target);
      if (_disposed || generation != _generation) return;
      data = result;
      applied = requested;
    } catch (failure) {
      if (_disposed || generation != _generation) return;
      error = failure;
    } finally {
      if (!_disposed && generation == _generation) {
        _inFlight = null;
        loading = false;
        notify();
      }
    }
  }

  Future<void> prepareExport() async {
    _timer?.cancel();
    _timer = null;
    if (!matchesInputs) await search();
  }

  void invalidateSession(int? activeStore) {
    _generation++;
    _timer?.cancel();
    _timer = null;
    data = null;
    _inFlight = null;
    applied = null;
    error = null;
    loading = false;
    storeId = activeStore;
    requestedPage = 1;
    notify();
  }

  void clearFilters() {
    for (final field in [number, customer, phone, email, price]) {
      field.clear();
    }
    status = 'all';
    from = null;
    until = null;
    businessDate = null;
  }

  Future<void> reset() {
    if (_disposed) return Future.value();
    clearFilters();
    return search();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    for (final field in [number, customer, phone, email, price]) {
      field.dispose();
    }
    super.dispose();
  }
}
