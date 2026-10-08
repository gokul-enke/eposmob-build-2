import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pos_machine/models/quotation_model.dart';
import '../../data/quotation_list_repository.dart';
import '../../domain/quotation_list_query.dart';

class QuotationListController extends ChangeNotifier {
  QuotationListController(this.source, this.readToken);
  final QuotationListSource source;
  final String Function() readToken;
  final number = TextEditingController();
  String? customerId;
  int? storeId;
  String status = 'All';
  DateTime? quotationDate, expiryDate;
  bool loading = false, showFilters = true, _disposed = false;
  Object? error;
  int _generation = 0;
  int requestedPage = 1;
  Timer? _timer;
  QuotationListPageData? data;
  QuotationListQuery? applied;
  QuotationListQuery get query => QuotationListQuery(
      number: number.text,
      customerId: customerId,
      storeId: storeId,
      status: status,
      quotationDate: quotationDate,
      expiryDate: expiryDate);
  List<Quotation> get rows => data?.rows ?? const [];
  int get current => data?.current ?? 1;
  int get last => data?.last ?? 1;
  bool get canExport =>
      !loading &&
      error == null &&
      rows.isNotEmpty &&
      applied != null &&
      applied!.sameAs(query);
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
    // An earlier request must not publish rows for inputs the user has edited.
    _generation++;
    loading = false;
    _timer = Timer(const Duration(milliseconds: 300), () {
      _timer = null;
      if (!(applied?.sameAs(query) ?? false)) search();
    });
    notify();
  }

  Future<void> search() {
    _timer?.cancel();
    _timer = null;
    return load(1);
  }

  Future<void> load(int page) async {
    if (_disposed) return;
    final pending = !(applied?.sameAs(query) ?? true);
    _timer?.cancel();
    _timer = null;
    final target = pending ? 1 : page;
    requestedPage = target;
    final requested = query;
    final generation = ++_generation;
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
        loading = false;
        notify();
      }
    }
  }

  Future<void> prepareExport() async {
    _timer?.cancel();
    _timer = null;
    if (!(applied?.sameAs(query) ?? false)) await search();
  }

  void invalidateSession() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    data = null;
    applied = null;
    error = null;
    loading = false;
    storeId = null;
    requestedPage = 1;
    notify();
  }

  Future<void> reset() {
    if (_disposed) return Future.value();
    number.clear();
    customerId = null;
    storeId = null;
    status = 'All';
    quotationDate = null;
    expiryDate = null;
    return search();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    number.dispose();
    super.dispose();
  }
}
