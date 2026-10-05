import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';

import '../../domain/models/list_purchase.dart';

class LegacyPurchaseFormController extends ChangeNotifier {
  LegacyPurchaseFormController(
      {required this.readStores,
      required this.readSuppliers,
      required this.readItems,
      required this.fetchItems,
      required this.addItem,
      required this.removeItem,
      required this.finishPurchase,
      required this.onMessage,
      required this.onBusy,
      required this.onBack});
  final List<GetStoreModelData>? Function() readStores;
  final List<GetSuppliersModelData>? Function() readSuppliers;
  final List<PurchaseItem> Function() readItems;
  final Future<dynamic> Function() fetchItems;
  final Future<dynamic> Function(
      {required String categoryId,
      required String productId,
      required String quantity,
      required String unit,
      required String supplierId,
      required String storeId,
      required String batchNumber}) addItem;
  final Future<dynamic> Function(String) removeItem;
  final Future<dynamic> Function(String) finishPurchase;
  final void Function(String) onMessage;
  final void Function(bool) onBusy;
  final VoidCallback onBack;
  bool _disposed = false;
  bool initLoading = false;
  bool apiLoading = false;
  bool commandBusy = false;
  int quantity = 0;
  int batchNumber = 0;
  int? purchaseId;
  String? selectedProperty;
  String? selectedSupplier;
  GetProduct? selectedValue;
  Category? selectedValueCategory;
  String? selected;
  GetSuppliersModelData? supplier;
  GetStoreModelData? storeSelected;
  List<GetStoreModelData>? storeList;
  List<GetSuppliersModelData>? supplierList;
  List<PurchaseItem>? purchaseItemList = [];
  List<GetProduct>? productList;
  final supplierIdController = TextEditingController();
  final storeController = TextEditingController();
  final quantityController = TextEditingController();
  final unitController = TextEditingController();
  final categoryIDController = TextEditingController(text: '0');
  final productIDController = TextEditingController(text: '0');
  final textEditingController = TextEditingController();
  void change(VoidCallback update) {
    if (_disposed) return;
    update();
    notifyListeners();
  }

  Future<void> loadData() async {
    if (_disposed) return;
    change(() {
      initLoading = true;
      storeList = readStores() ?? [];
      supplierList = readSuppliers() ?? [];
    });
    try {
      await fetchItems();
      if (_disposed) return;
      _updateItems();
    } catch (error) {
      if (!_disposed) onMessage(error.toString());
    } finally {
      change(() {
        initLoading = false;
      });
    }
  }

  void _updateItems() {
    change(() {
      purchaseItemList = List.of(readItems());
      for (final item in purchaseItemList!) {
        purchaseId = item.purchaseId;
      }
    });
  }

  Future<void> getPurchaseItems() async {
    if (_disposed) return;
    change(() {
      apiLoading = true;
    });
    try {
      await fetchItems();
      if (_disposed) return;
      _updateItems();
    } catch (error) {
      if (!_disposed) onMessage(error.toString());
    } finally {
      change(() {
        apiLoading = false;
      });
    }
  }

  Future<void> submitItem() async {
    if (_disposed || commandBusy) return;
    if (selectedValue == null ||
        selectedValueCategory == null ||
        selectedProperty == null ||
        supplierIdController.text.isEmpty ||
        storeController.text.isEmpty) {
      onMessage('add_purchase.fill_required'.tr);
      return;
    }
    await _run(
        () => addItem(
            categoryId: categoryIDController.text,
            productId: productIDController.text,
            quantity: '$quantity',
            unit: selectedProperty ?? '',
            supplierId: supplierIdController.text,
            storeId: storeController.text,
            batchNumber: '$batchNumber'),
        backOnFailure: true);
  }

  Future<void> deleteItem(String id) => _run(() => removeItem(id));
  Future<void> finish() async {
    if (_disposed || commandBusy) return;
    if (purchaseId == null) {
      onMessage('add_purchase.failed'.tr);
      onBack();
      return;
    }
    await _run(() => finishPurchase('$purchaseId'), backAlways: true);
  }

  Future<void> _run(Future<dynamic> Function() action,
      {bool backOnFailure = false, bool backAlways = false}) async {
    if (_disposed || commandBusy) return;
    commandBusy = true;
    onBusy(true);
    try {
      final result = await action();
      if (_disposed) return;
      final success = result is Map && result['status'] == 'success';
      onMessage(
          result is Map ? '${result['message']}' : 'add_purchase.failed'.tr);
      if (success && !backAlways) await getPurchaseItems();
      if (_disposed) return;
      if (backAlways || (!success && backOnFailure)) onBack();
    } catch (error) {
      if (!_disposed) onMessage(error.toString());
    } finally {
      commandBusy = false;
      if (!_disposed) onBusy(false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final field in [
      supplierIdController,
      storeController,
      quantityController,
      unitController,
      categoryIDController,
      productIDController,
      textEditingController
    ]) {
      field.dispose();
    }
    super.dispose();
  }
}
