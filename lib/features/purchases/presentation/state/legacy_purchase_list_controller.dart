import 'package:flutter/widgets.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';

import '../../domain/models/list_purchase.dart';
import '../../domain/models/list_purchase_voucher.dart';

class LegacyPurchaseListController extends ChangeNotifier {
  LegacyPurchaseListController({this.fetchPurchases, this.fetchVouchers});
  final Future<ListPurchaseModel> Function(
      {String? filterName, String? filterStore, int? page})? fetchPurchases;
  final Future<ListVoucherModel> Function(
      {String? filterAmount, String? filterStore, int? page})? fetchVouchers;
  final searchTextController = TextEditingController();
  final purchaserNameController = TextEditingController();
  final productNameController = TextEditingController();
  final supplierIdController = TextEditingController();
  final storeController = TextEditingController();
  final dateController = TextEditingController();
  final amountController = TextEditingController();
  DateTime? selectedDate;
  GetStoreModelData? storeSelected;
  GetSuppliersModelData? supplier;
  String? selectedSupplierId;
  bool initLoading = false;
  bool _disposed = false;
  int _generation = 0;
  int currentPage = 1;
  int totalPages = 1;
  List<PurchaseItem> purchaseDetailsList = [];
  List<VoucherModelData> voucherModelListData = [];
  void change(VoidCallback update) {
    if (_disposed) return;
    update();
    notifyListeners();
  }

  Future<void> load([int page = 1, bool reset = false]) async {
    if (_disposed) return;
    if (reset) {
      for (final field in fields) {
        field.clear();
      }
      selectedDate = null;
      selectedSupplierId = null;
    }
    final generation = ++_generation;
    change(() {
      initLoading = true;
    });
    try {
      if (fetchPurchases != null) {
        final result = await fetchPurchases!(
            filterName: reset ? null : purchaserNameController.text,
            filterStore: reset ? null : storeController.text,
            page: page);
        if (_disposed || generation != _generation) return;
        change(() {
          purchaseDetailsList = [
            for (final row in result.data ?? <ListPurchaseModelData>[])
              ...?row.purchaseItems
          ];
          currentPage = result.pagination?.currentPage ?? 1;
          totalPages = result.pagination?.lastPage ?? 1;
        });
      } else {
        final result = await fetchVouchers!(
            filterAmount: reset ? null : amountController.text,
            filterStore: reset ? null : storeController.text,
            page: page);
        if (_disposed || generation != _generation) return;
        change(() {
          voucherModelListData = result.data ?? [];
          currentPage = result.pagination?.currentPage ?? 1;
          totalPages = result.pagination?.lastPage ?? 1;
        });
      }
    } catch (error) {
      // Preserve the previous successful page on failed refresh.
      debugPrint('Failed to load legacy purchase list: $error');
    } finally {
      if (!_disposed && generation == _generation)
        change(() {
          initLoading = false;
        });
    }
  }

  List<TextEditingController> get fields => [
        searchTextController,
        purchaserNameController,
        productNameController,
        supplierIdController,
        storeController,
        dateController,
        amountController
      ];
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }
}
