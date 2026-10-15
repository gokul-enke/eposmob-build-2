import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pos_machine/core/utils/search_debouncer.dart';
import 'package:pos_machine/models/transaction_model.dart';
import '../../data/supplier_ledger_repository.dart';
import '../../domain/supplier_ledger_query.dart';

class SupplierLedgerListController extends ChangeNotifier {
  SupplierLedgerListController(this.repository, {this.onError});
  static const pageSize = 50;
  final SupplierLedgerRepository repository;
  final ValueChanged<Object>? onError;
  final searchController = TextEditingController();
  final supplierSearchController = TextEditingController();
  final typeController = TextEditingController(text: 'All Types');
  final transactionTypeController = TextEditingController(text: 'All');
  final statusController = TextEditingController(text: 'All Status');
  final supplierFocus = FocusNode();
  late final search = SearchDebouncer(searchTransactions);
  List<TransactionModel> _items = [], _statusSource = [];
  List<TransactionModel>? _localItems;
  Future<List<TransactionModel>>? _localSource;
  (String?, String?, String?)? _localSourceKey;
  // The legacy provider publishes page responses. Serialize its page calls so
  // the response copied by the repository belongs to that call.
  Future<void> _pageTail = Future.value();
  int _revision = 0, currentPage = 1, totalPages = 1;
  bool loading = true, hasLoadError = false, _disposed = false;
  List<TransactionModel> get items => List.unmodifiable(_items);
  List<String> get supplierOptions => repository.supplierOptions;
  SupplierLedgerQuery get query => SupplierLedgerQuery(
        supplierId: repository.supplierId(supplierSearchController.text),
        supplierName: supplierSearchController.text,
        search: searchController.text,
        type: typeController.text == 'All Types' ? null : typeController.text,
        transactionType: transactionTypeController.text == 'All'
            ? null
            : transactionTypeController.text,
        status: statusController.text == 'All Status'
            ? null
            : statusController.text,
      );
  bool get hasActiveFilters => query.hasActiveFilters;
  List<String> get statuses => <String>{
        'All Status',
        statusController.text,
        ..._statusSource.map((tx) => tx.status),
        ...?_localItems?.map((tx) => tx.status)
      }.where((value) => value.isNotEmpty).toList();
  void _publish() {
    if (!_disposed) notifyListeners();
  }

  Future<void> fetchPage(int page) async {
    if (_disposed) return;
    final request = query;
    final revision = ++_revision;
    loading = true;
    hasLoadError = false;
    if (request.usesLocalFilters && _localItems == null) _items = [];
    _publish();
    try {
      if (request.usesLocalFilters) {
        if (_localSourceKey != request.sourceKey) {
          _localSource = null;
          _localSourceKey = request.sourceKey;
          _localItems = null;
        }
        if (_localItems == null) {
          final result = await (_localSource ??= repository.snapshot(request));
          if (_disposed || revision != _revision) return;
          _localItems = repository.filter(result, request);
        }
        final all = _localItems!;
        totalPages =
            ((all.length + pageSize - 1) ~/ pageSize).clamp(1, 1 << 30);
        currentPage = page.clamp(1, totalPages);
        _items = all.skip((currentPage - 1) * pageSize).take(pageSize).toList();
      } else {
        _localItems = null;
        final previous = _pageTail;
        final completer = Completer<void>();
        _pageTail = completer.future;
        try {
          await previous;
          if (_disposed || revision != _revision) return;
          final result = await repository.fetchPage(request, page, pageSize);
          if (_disposed || revision != _revision) return;
          _items = result.items;
          _statusSource = result.items;
          currentPage = result.currentPage;
          totalPages = result.totalPages;
        } finally {
          completer.complete();
        }
      }
    } catch (error) {
      if (_disposed || revision != _revision) return;
      _localSource = null;
      hasLoadError = true;
      onError?.call(error);
    } finally {
      if (!_disposed && revision == _revision) {
        loading = false;
        _publish();
      }
    }
  }

  void searchTransactions() {
    if (_disposed) return;
    _localItems = null;
    unawaited(fetchPage(1));
  }

  Future<void> refresh() {
    if (_disposed) return Future.value();
    _localItems = null;
    _localSource = null;
    return fetchPage(currentPage);
  }

  void resetSearch() {
    if (_disposed) return;
    search.cancel();
    searchController.clear();
    supplierSearchController.clear();
    typeController.text = 'All Types';
    transactionTypeController.text = 'All';
    statusController.text = 'All Status';
    searchTransactions();
  }

  Future<List<TransactionModel>> exportRows(
      {void Function(int, int)? onProgress}) {
    if (_disposed) throw StateError('List disposed');
    return repository.snapshot(query,
        applyLocalFilters: true, onProgress: onProgress);
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    search.dispose();
    searchController.dispose();
    supplierSearchController.dispose();
    typeController.dispose();
    transactionTypeController.dispose();
    statusController.dispose();
    supplierFocus.dispose();
    super.dispose();
  }
}
