import 'package:flutter/foundation.dart';
import 'package:pos_machine/core/pagination/page_slice.dart';

import '../../domain/models/supplier.dart';

/// Loads every purchase order of a supplier, e.g. the ones embedded in the
/// selected [Supplier].
typedef SupplierPurchasesFetcher = Future<List<SupplierPurchase>> Function();

/// Loads a supplier's purchase orders and shows them [perPage] at a time.
class SupplierOrdersController extends ChangeNotifier {
  SupplierOrdersController({
    required SupplierPurchasesFetcher fetch,
    this.perPage = 20,
  }) : _fetch = fetch;

  final SupplierPurchasesFetcher _fetch;
  final int perPage;

  List<SupplierPurchase> _all = const [];
  bool _isLoading = false;
  bool _hasError = false;
  int _page = 1;
  int _requestSeq = 0;
  bool _disposed = false;

  PageSlice<SupplierPurchase> get _slice =>
      PageSlice.of(_all, page: _page, perPage: perPage);

  /// Every loaded purchase order.
  List<SupplierPurchase> get allPurchases => _all;

  /// Purchase orders on the current page.
  List<SupplierPurchase> get purchases => _slice.items;
  int get currentPage => _slice.currentPage;
  int get totalPages => _slice.totalPages;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;

  bool get showPagination =>
      !_isLoading && !_hasError && _all.isNotEmpty && totalPages > 1;

  /// Loads every purchase order and shows page 1.
  Future<void> load() async {
    final request = ++_requestSeq;
    _isLoading = true;
    _hasError = false;
    _notify();
    try {
      final result = await _fetch();
      if (request != _requestSeq || _disposed) return;
      _all = List<SupplierPurchase>.unmodifiable(result);
      _page = 1;
    } catch (error) {
      if (request != _requestSeq || _disposed) return;
      debugPrint('Failed to load supplier purchases: $error');
      _all = const [];
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
