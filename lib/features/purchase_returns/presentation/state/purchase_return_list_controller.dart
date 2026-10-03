import 'package:flutter/material.dart';
import 'package:pos_machine/models/get_suppliers.dart';
import '../../domain/models/purchase_return.dart';
import '../../domain/purchase_return_filter.dart';

typedef FetchReturnPage = Future<ListPurchaseReturnData> Function(
    PurchaseReturnFilter filter, int page);

class PurchaseReturnListController extends ChangeNotifier {
  PurchaseReturnListController(
      {required this.fetch,
      required this.fetchSuppliers,
      required this.fallbackError,
      required this.onError});
  final FetchReturnPage fetch;
  final Future<List<GetSuppliersModelData>> Function() fetchSuppliers;
  final String fallbackError;
  final void Function(String) onError;
  final supplierController = TextEditingController(text: 'All');
  final supplierSearchController = TextEditingController();
  final fromDateController = TextEditingController();
  final toDateController = TextEditingController();
  List<GetSuppliersModelData> _supplierData = [];
  List<String> suppliers = ['All'];
  List<PurchaseReturnData> purchaseReturnsList = [];
  int purchaseReturnCurrentPage = 1;
  int purchaseReturnTotalPages = 1;
  int currentPage = 1;
  bool isLoading = true;
  bool showFilters = false;
  String? loadError;
  bool _disposed = false;
  int _request = 0;

  void update(VoidCallback mutation) {
    if (_disposed) return;
    mutation();
    notifyListeners();
  }

  bool hasActiveFilters() =>
      supplierController.text != 'All' ||
      fromDateController.text.isNotEmpty ||
      toDateController.text.isNotEmpty;
  PurchaseReturnFilter get filter {
    String? id;
    if (supplierController.text != 'All') {
      for (final supplier in _supplierData) {
        if ((supplier.user?.name ?? supplier.name ?? '') ==
            supplierController.text) {
          if ((supplier.id ?? 0) > 0) id = supplier.id.toString();
          break;
        }
      }
    }
    return PurchaseReturnFilter(
        supplierId: id,
        dateFrom: PurchaseReturnFilter.optional(fromDateController.text),
        dateTo: PurchaseReturnFilter.optional(toDateController.text));
  }

  Future<void> initialize({bool canLoad = true}) async {
    if (!canLoad) {
      update(() => isLoading = false);
      return;
    }
    final request = ++_request;
    update(() => isLoading = true);
    try {
      final suppliers = await fetchSuppliers();
      if (_disposed || request != _request) return;
      update(() {
        _supplierData = suppliers;
        this.suppliers = [
          'All',
          ...suppliers.map((e) => e.user?.name ?? e.name ?? '')
        ];
      });
      await fetchReturns(page: 1);
    } catch (error) {
      if (!_disposed && request == _request) _fail(error);
    }
  }

  Future<void> fetchReturns({int? page}) async {
    if (_disposed) return;
    final request = ++_request;
    final requestedPage = page ?? currentPage;
    final query = filter;
    update(() {
      isLoading = true;
      loadError = null;
    });
    try {
      final result = await fetch(query, requestedPage);
      if (_disposed || request != _request) return;
      update(() {
        purchaseReturnsList = result.data ?? [];
        purchaseReturnCurrentPage = result.currentPage ?? 1;
        purchaseReturnTotalPages = result.lastPage ?? 1;
        if (page != null) currentPage = page;
        isLoading = false;
      });
    } catch (error) {
      if (_disposed || request != _request) return;
      update(() {
        purchaseReturnsList = [];
        purchaseReturnCurrentPage = 1;
        purchaseReturnTotalPages = 1;
      });
      _fail(error);
    }
  }

  void _fail(Object error) {
    update(() {
      isLoading = false;
      loadError = error is Exception
          ? error.toString().replaceFirst('Exception: ', '')
          : fallbackError;
    });
    onError(loadError!);
  }

  Future<void> resetFilters() async {
    update(() {
      supplierController.text = 'All';
      fromDateController.clear();
      toDateController.clear();
      currentPage = 1;
    });
    await fetchReturns(page: 1);
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    supplierController.dispose();
    supplierSearchController.dispose();
    fromDateController.dispose();
    toDateController.dispose();
    super.dispose();
  }
}
