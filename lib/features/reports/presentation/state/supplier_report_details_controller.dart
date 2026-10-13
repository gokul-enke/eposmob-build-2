import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/features/suppliers/domain/models/supplier.dart';

import '../../data/supplier_report_details_snapshot.dart';
import '../../domain/supplier_report.dart';
import '../../domain/supplier_report_details_query.dart';

class SupplierReportDetailsExportCancelled implements Exception {}

/// View-owned rows and filters. No directory paging, selection or API mutation.
class SupplierReportDetailsController extends ChangeNotifier {
  SupplierReportDetailsController({
    required this.selection,
    required this.readScope,
    required this.fetch,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _defaultDates();
  }

  final SupplierReportDetailsSelection Function() selection;
  final Future<SupplierReportScope> Function() readScope;
  final Future<Map<String, dynamic>> Function(
      SupplierReportDetailsQuery query, int? page) fetch;
  final DateTime Function() _now;
  final fromInput = TextEditingController(), toInput = TextEditingController();
  final searchInput = TextEditingController();
  String type = 'All', payment = 'All';
  bool loading = false, showFilters = true;
  Object? error;
  String? errorKey;
  int errorRevision = 0;
  static const dateRangeErrorKey =
      'supplier_transaction_report.from_date_after_to_date';
  bool get hasValidationError => errorKey == dateRangeErrorKey;
  List<SupplierTransaction> _allRows = const [], rows = const [];
  SupplierReportScope? _loadedScope;
  SupplierReportDetailsSelection? _loadedSupplier;
  String _displayName = '';
  bool _ready = false, _disposed = false;
  int _generation = 0, _revision = 0;
  String get supplierName =>
      _displayName.isNotEmpty ? _displayName : selection().name;
  SupplierReportDetailsQuery get query => SupplierReportDetailsQuery(
      supplier: selection(),
      from: fromInput.text,
      to: toInput.text,
      type: type,
      payment: payment,
      search: searchInput.text);
  bool get canExport =>
      _ready &&
      !loading &&
      error == null &&
      errorKey == null &&
      rows.isNotEmpty &&
      _loadedSupplier == selection() &&
      query.hasSupplier &&
      query.isDateRangeValid;
  bool get hasActiveFilters =>
      type != 'All' ||
      payment != 'All' ||
      searchInput.text.isNotEmpty ||
      fromInput.text.isNotEmpty ||
      toInput.text.isNotEmpty;

  void _defaultDates() {
    final today = _now();
    final format = DateFormat('yyyy-MM-dd');
    fromInput.text =
        format.format(DateTime(today.year, today.month - 1, today.day));
    toInput.text = format.format(today);
  }

  void setFiltersVisible(bool value) {
    showFilters = value;
    _notify();
  }

  void filterChanged() {
    _revision++;
    rows = query.apply(_allRows);
    _notify();
  }

  void selectType(String? value) {
    type = value ?? 'All';
    filterChanged();
  }

  void selectPayment(String? value) {
    payment = value ?? 'All';
    filterChanged();
  }

  Future<void> selectDate(DateTime date, bool from) async {
    (from ? fromInput : toInput).text = DateFormat('yyyy-MM-dd').format(date);
    filterChanged();
    // Rows were fetched with server date bounds. Widening a bound needs a new
    // snapshot; filtering that old subset alone cannot recover older rows.
    await load();
  }

  Future<void> reset() async {
    searchInput.clear();
    type = 'All';
    payment = 'All';
    _defaultDates();
    await load();
  }

  Future<void> load() async {
    if (_disposed) return;
    final generation = ++_generation;
    _revision++;
    final requested = query;
    _ready = false;
    if (!requested.isDateRangeValid) {
      loading = false;
      error = null;
      errorKey = dateRangeErrorKey;
      errorRevision++;
      _notify();
      return;
    }
    loading = true;
    error = null;
    errorKey = null;
    _notify();
    try {
      if (!requested.hasSupplier) throw StateError('No supplier selected.');
      final scope = await readScope();
      if (!_current(generation, requested.supplier)) return;
      final response = await fetch(requested, null);
      if (!_current(generation, requested.supplier)) return;
      final currentScope = await readScope();
      if (!_current(generation, requested.supplier)) return;
      if (scope != currentScope) {
        throw StateError('Supplier report session changed.');
      }
      final parsed = parseSupplierReportDetails(response, requested.supplier);
      _allRows = parsed;
      _loadedSupplier = requested.supplier;
      _displayName = requested.supplier.name.isEmpty
          ? supplierReportDetailsName(response, requested.supplier)
          : requested.supplier.name;
      _loadedScope = scope;
      // Filters edited during a refresh apply to the newly fetched snapshot.
      rows = query.apply(_allRows);
      _ready = true;
    } catch (failure) {
      if (_current(generation, requested.supplier)) {
        error = failure;
        errorRevision++;
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  bool _current(int generation, SupplierReportDetailsSelection supplier) =>
      !_disposed && generation == _generation && supplier == selection();

  Future<T> export<T>({
    required Future<T> Function(
            List<SupplierTransaction>, SupplierReportDetailsQuery)
        build,
    void Function(int page, int total)? progress,
  }) async {
    if (!canExport) throw SupplierReportDetailsExportCancelled();
    final requested = query, revision = _revision;
    final scope = _loadedScope;
    Future<void> check() async {
      if (_disposed ||
          revision != _revision ||
          !canExport ||
          requested != query ||
          scope == null ||
          scope.token.isEmpty ||
          (scope.tenant?.isEmpty ?? true)) {
        throw SupplierReportDetailsExportCancelled();
      }
      final current = await readScope();
      if (_disposed ||
          revision != _revision ||
          !canExport ||
          requested != query ||
          scope != current) {
        throw SupplierReportDetailsExportCancelled();
      }
    }

    await check();
    final snapshot = await fetchSupplierReportDetailsSnapshot((page) async {
      await check();
      final response = await fetch(requested, page);
      await check();
      return response;
    }, requested, progress: progress);
    await check();
    final result = await build(
        snapshot,
        SupplierReportDetailsQuery(
          supplier: (id: requested.supplier.id, name: supplierName),
          from: requested.from,
          to: requested.to,
          type: requested.type,
          payment: requested.payment,
          search: requested.search,
        ));
    await check();
    return result;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _revision++;
    fromInput.dispose();
    toInput.dispose();
    searchInput.dispose();
    super.dispose();
  }
}
