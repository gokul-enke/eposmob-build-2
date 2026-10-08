import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/category_list_source.dart';
import '../../domain/category_list_entry.dart';

/// Inputs, debounce, paging and filtered snapshots belong to this page only.
class CategoryListController extends ChangeNotifier {
  CategoryListController(this.source) {
    source.addListener(_directoryChanged);
  }
  final CategoryListSource source;
  final search = TextEditingController();
  static const pageSize = 20;
  List<CategoryListEntry> _directory = const [], rows = const [];
  String applied = '';
  int page = 1;
  Object? error;
  bool _fetching = true, _disposed = false;
  Future<void>? _inFlight;
  Timer? _debounce;
  bool get loading => _fetching || source.isBusy();
  int get totalPages =>
      ((rows.length + pageSize - 1) ~/ pageSize).clamp(1, 999999);
  List<CategoryListEntry> get pageRows {
    final start = (page - 1) * pageSize;
    return rows.sublist(start, (start + pageSize).clamp(start, rows.length));
  }

  Future<void> load() =>
      _inFlight ??= _load().whenComplete(() => _inFlight = null);
  Future<void> _load() async {
    _fetching = true;
    error = null;
    _notify();
    try {
      await source.ensureLoaded();
    } catch (e) {
      if (!_disposed) error = e;
    } finally {
      if (!_disposed) {
        _fetching = false;
        _directoryChanged();
      }
    }
  }

  void _directoryChanged() {
    if (_disposed) return;
    if (!source.isBusy()) {
      final entries = source.readEntries();
      final changed = entries.length != _directory.length ||
          Iterable<int>.generate(entries.length)
              .any((i) => !entries[i].sameValues(_directory[i]));
      if (changed) {
        _directory = List.unmodifiable(entries);
        rows = filterCategoryEntries(_directory, applied);
        page = page.clamp(1, totalPages);
      }
    }
    _notify();
  }

  void scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), flushSearch);
  }

  bool flushSearch() {
    _debounce?.cancel();
    if (_disposed || applied.toLowerCase() == search.text.toLowerCase()) {
      return false;
    }
    applied = search.text;
    rows = filterCategoryEntries(_directory, applied);
    page = 1;
    _notify();
    return true;
  }

  void reset() {
    _debounce?.cancel();
    search.clear();
    applied = '';
    rows = filterCategoryEntries(_directory, applied);
    page = 1;
    _notify();
  }

  void goToPage(int target) {
    if (_disposed || loading || flushSearch()) return;
    page = target.clamp(1, totalPages);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    source.removeListener(_directoryChanged);
    search.dispose();
    super.dispose();
  }
}
