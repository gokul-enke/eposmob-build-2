import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/barcode_list_source.dart';
import '../../domain/barcode_list_query.dart';
import '../models/barcode_row.dart';
import '../models/barcode_rows.dart';

/// Owns input, expanded-row pagination and cross-page print selection.
class BarcodeListController extends ChangeNotifier {
  BarcodeListController(this.source) {
    source.addListener(_catalogueChanged);
  }
  final BarcodeListSource source;
  final name = TextEditingController();
  final barcode = TextEditingController();
  List<BarcodeCategory> categories = const [];
  int? categoryId;
  BarcodeListQuery applied = const BarcodeListQuery();
  List<BarcodeRow> rows = const [];
  final selected = <String, BarcodeRow>{};
  static const pageSize = 20;
  int page = 1;
  int _version = -1;
  bool loading = true;
  Object? error;
  bool _disposed = false;
  Future<void>? _initializing;
  Timer? _debounce;

  int get totalPages => (rows.length / pageSize).ceil().clamp(1, 999999);
  List<BarcodeRow> get pageRows {
    final start = (page - 1) * pageSize;
    return rows.sublist(start, (start + pageSize).clamp(start, rows.length));
  }

  bool get pageSelected => pageRows.isNotEmpty && pageRows.every(isSelected);
  bool isSelected(BarcodeRow row) => selected.containsKey(row.selectionKey);
  BarcodeListQuery get draft => BarcodeListQuery(
      name: name.text, barcode: barcode.text, categoryId: categoryId);

  Future<void> initialize() =>
      _initializing ??= _initialize().whenComplete(() => _initializing = null);
  Future<void> _initialize() async {
    loading = true;
    error = null;
    _notify();
    try {
      final options = await source.categories();
      if (_disposed) return;
      categories = options;
      refresh();
    } catch (e) {
      if (!_disposed) error = e;
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  void scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), flushSearch);
  }

  /// Returns true when pending edits changed the active filter.
  bool flushSearch() {
    _debounce?.cancel();
    if (_disposed || draft.sameFiltersAs(applied)) return false;
    _apply(draft);
    return true;
  }

  void selectCategory(int? value) {
    categoryId = value;
    flushSearch();
  }

  void refresh() {
    _debounce?.cancel();
    if (!_disposed) _apply(draft);
  }

  void _apply(BarcodeListQuery query) {
    applied = query; // synchronous provider notifications must see this filter
    source.apply(query);
    _catalogueChanged();
  }

  void _catalogueChanged() {
    if (_disposed) return;
    final version = source.version;
    if (version == _version) {
      // Keep quantity getters current when an existing stock list is mutated,
      // while retaining the expanded rows and page for unrelated notifications.
      _notify();
      return;
    }
    _version = version;
    rows = List.unmodifiable(
        expandProductsToBarcodeRows(source.products, barcode: applied.barcode));
    page = 1;
    _notify();
  }

  void goToPage(int target) {
    if (flushSearch()) return; // new filters begin on page 1
    page = target.clamp(1, totalPages);
    _notify();
  }

  void setSelected(BarcodeRow row, bool value) {
    if (value) {
      selected[row.selectionKey] = row;
    } else {
      selected.remove(row.selectionKey);
    }
    _notify();
  }

  void selectPage(bool value) {
    for (final row in pageRows) {
      if (value) {
        selected[row.selectionKey] = row;
      } else {
        selected.remove(row.selectionKey);
      }
    }
    _notify();
  }

  void clearSelection() {
    selected.clear();
    _notify();
  }

  void reset() {
    name.clear();
    barcode.clear();
    categoryId = null;
    selected.clear();
    refresh(); // also resets when filter values already match
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    source.removeListener(_catalogueChanged);
    name.dispose();
    barcode.dispose();
    super.dispose();
  }
}
