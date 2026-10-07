import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:pos_machine/models/get_product.dart';
import '../../data/product_list_source.dart';
import '../../domain/product_list_query.dart';

/// Owns only the catalog listing's inputs, results and pagination.
class ProductListController extends ChangeNotifier {
  ProductListController(
      {required this.source,
      required this.ensureCategories,
      this.itemsPerPage = 20})
      : assert(itemsPerPage > 0);
  final ProductListSource source;
  final Future<void> Function() ensureCategories;
  final int itemsPerPage;
  final name = TextEditingController();
  final price = TextEditingController();
  final barcode = TextEditingController();
  final hsn = TextEditingController();
  final itemCode = TextEditingController();
  int? categoryId;
  String? property;
  int page = 1;
  bool filtersVisible = true, loading = false, deleting = false;
  bool _disposed = false;
  int _loadGeneration = 0;
  Object? error;
  Timer? _debounce;
  List<GetProduct> _all = [];
  List<GetProduct> get all => _all;
  int get totalPages => (_all.length / itemsPerPage).ceil().clamp(1, 1 << 30);
  List<GetProduct> get rows {
    final start = (page - 1) * itemsPerPage;
    return _all.skip(start).take(itemsPerPage).toList();
  }

  ProductListQuery get query => ProductListQuery(
      name: name.text,
      price: price.text,
      barcode: barcode.text,
      hsn: hsn.text,
      itemCode: itemCode.text,
      categoryId: categoryId,
      property: property);
  bool get hasFilters => !query.isEmpty;
  bool get canExport =>
      !loading && !deleting && error == null && _all.isNotEmpty;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (_disposed) return;
    final generation = ++_loadGeneration;
    loading = true;
    error = null;
    _notify();
    // A category directory failure must not hide an available local catalog.
    Object? failure;
    try {
      await ensureCategories();
    } catch (e) {
      failure = e;
    }
    if (_disposed || generation != _loadGeneration) return;
    error = failure;
    loading = false;
    search();
  }

  void scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), search);
  }

  void search() {
    if (_disposed) return;
    _debounce?.cancel();
    page = 1;
    reloadCatalog();
  }

  void reloadCatalog() {
    if (_disposed) return;
    _all = source.select(query);
    page = page.clamp(1, totalPages);
    _notify();
  }

  void selectCategory(int? id) {
    categoryId = id;
    search();
  }

  void selectProperty(String? value) {
    property = value;
    search();
  }

  void goToPage(int value) {
    // Apply pending text before pagination, rather than skipping its first page.
    if (_debounce?.isActive ?? false) {
      search();
      return;
    }
    if (loading || deleting || value < 1 || value > totalPages) return;
    page = value;
    _notify();
  }

  void toggleFilters() {
    filtersVisible = !filtersVisible;
    _notify();
  }

  void setFiltersVisible(bool visible) {
    filtersVisible = visible;
    _notify();
  }

  void reset() {
    _debounce?.cancel();
    for (final input in [name, price, barcode, hsn, itemCode]) {
      input.clear();
    }
    categoryId = null;
    property = null;
    search();
  }

  Future<void> refresh() async {
    reset(); // Preserve the previous Refresh behavior: clear every filter.
    await initialize();
  }

  List<GetProduct> exportSnapshot() {
    // Flush pending text, but preserve the displayed page for an unchanged list.
    if (_debounce?.isActive ?? false) search();
    if (!canExport) throw StateError('Product list is unavailable');
    return List.unmodifiable(_all);
  }

  Future<bool> delete(int id) async {
    if (deleting || _disposed) return false;
    deleting = true;
    _notify();
    try {
      final result = await source.deleteProduct(id);
      if (!_disposed && result) reloadCatalog();
      return result;
    } finally {
      deleting = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    for (final input in [name, price, barcode, hsn, itemCode]) {
      input.dispose();
    }
    super.dispose();
  }
}
