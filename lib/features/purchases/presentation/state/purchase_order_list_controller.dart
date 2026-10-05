import 'package:flutter/widgets.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';

import '../../domain/models/purchase_order_model.dart';
import '../../domain/purchase_order_filter.dart';

typedef FetchPurchaseOrders = Future<ListPurchaseOrderModel> Function(
    PurchaseOrderFilter filter, int page);

class PurchaseOrderListController extends ChangeNotifier {
  PurchaseOrderListController(
      {required this.fetch,
      required this.fetchStores,
      required this.fetchSuppliers}) {
    supplierController.text = 'All';
    storeController.text = 'All';
  }
  final FetchPurchaseOrders fetch;
  final Future<List<GetStoreModelData>> Function() fetchStores;
  final Future<List<GetSuppliersModelData>> Function() fetchSuppliers;
  final supplierController = TextEditingController();
  final supplierSearchController = TextEditingController();
  final storeController = TextEditingController();
  final storeSearchController = TextEditingController();
  final fromDateController = TextEditingController();
  final toDateController = TextEditingController();
  bool initLoading = false;
  bool showFilters = false;
  List<String> suppliers = ['All'];
  List<String> stores = ['All'];
  List<GetStoreModelData> _stores = [];
  List<GetSuppliersModelData> _suppliers = [];
  List<PurchaseOrderData> purchaseOrdersList = [];
  int listPurchaseOrderCurrentPage = 1;
  int listPurchaseOrderTotalPages = 1;
  bool _disposed = false;
  int _request = 0;
  int _directoryRequest = 0;
  void update(VoidCallback action) {
    if (_disposed) return;
    action();
    notifyListeners();
  }

  Future<void> initialize({required bool canLoad}) async {
    if (!canLoad || _disposed) return;
    final request = _request;
    final directoryRequest = ++_directoryRequest;
    update(() => initLoading = true);
    try {
      final stores = await fetchStores();
      if (_disposed || directoryRequest != _directoryRequest) return;
      _stores = stores;
      final suppliers = await fetchSuppliers();
      if (_disposed || directoryRequest != _directoryRequest) return;
      _suppliers = suppliers;
      this.stores = ['All', ...stores.map((s) => s.name ?? '')];
      this.suppliers = [
        'All',
        ...suppliers.map((s) => s.user?.name ?? s.name ?? '')
      ];
      update(() {});
      if (request == _request) await fetchPurchases();
    } catch (error) {
      debugPrint('Error loading initial purchases: $error');
    } finally {
      if (!_disposed && request == _request) {
        update(() => initLoading = false);
      }
    }
  }

  PurchaseOrderFilter get filter {
    String? supplierId;
    final supplier = supplierController.text;
    if (supplier.isNotEmpty && supplier != 'All') {
      for (final item in _suppliers) {
        if ((item.user?.name ?? item.name) == supplier) {
          if (item.id != null && item.id! > 0) supplierId = item.id.toString();
          break;
        }
      }
    }
    var storeId = 'all';
    if (storeController.text != 'All') {
      for (final item in _stores) {
        if (item.name == storeController.text) {
          if (item.id != null && item.id! > 0) storeId = item.id.toString();
          break;
        }
      }
    }
    return PurchaseOrderFilter(
        storeId: storeId,
        supplierId: supplierId,
        dateFrom: fromDateController.text.trim().isEmpty
            ? null
            : fromDateController.text.trim(),
        dateTo: toDateController.text.trim().isEmpty
            ? null
            : toDateController.text.trim());
  }

  Future<void> fetchPurchases({int? page}) async {
    if (_disposed) return;
    final request = ++_request;
    update(() => initLoading = true);
    try {
      final model = await fetch(filter, page ?? 1);
      if (_disposed || request != _request) return;
      update(() {
        purchaseOrdersList = model.data?.data ?? [];
        listPurchaseOrderCurrentPage = model.data?.currentPage ?? 1;
        listPurchaseOrderTotalPages = model.data?.lastPage ?? 1;
      });
    } catch (error) {
      if (_disposed || request != _request) return;
      debugPrint('Error fetching purchases: $error');
      update(() => purchaseOrdersList = []);
    } finally {
      if (!_disposed && request == _request) update(() => initLoading = false);
    }
  }

  Future<void> resetSearch() async {
    if (_disposed) return;
    supplierController.text = 'All';
    supplierSearchController.clear();
    storeController.text = 'All';
    storeSearchController.clear();
    fromDateController.clear();
    toDateController.clear();
    await fetchPurchases();
  }

  Future<void> refreshData() => resetSearch();
  bool get hasActiveFilters =>
      supplierController.text != 'All' ||
      storeController.text != 'All' ||
      fromDateController.text.isNotEmpty ||
      toDateController.text.isNotEmpty;
  @override
  void dispose() {
    _disposed = true;
    _request++;
    for (final input in [
      supplierController,
      supplierSearchController,
      storeController,
      storeSearchController,
      fromDateController,
      toDateController
    ]) {
      input.dispose();
    }
    super.dispose();
  }
}
