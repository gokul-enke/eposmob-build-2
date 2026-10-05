import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/features/purchases/domain/models/purchase_order_model.dart';
import '../../domain/models/purchase_return.dart';
import '../../domain/models/return_line_item.dart';
import '../../domain/purchase_return_pricing.dart';

typedef CreateReturn = Future<Map<String, dynamic>> Function(
    {required int purchaseVoucherId,
    required String returnDate,
    required List<Map<String, dynamic>> items,
    required bool hasPayment,
    double? paidAmount,
    String? paymentMethod});

class CreatePurchaseReturnController extends ChangeNotifier {
  CreatePurchaseReturnController(
      {required this.fetchVouchers,
      required this.fetchItems,
      required this.fetchPaymentMethods,
      required this.create});
  final Future<ListPurchaseOrderData> Function(int) fetchVouchers;
  final Future<ReturnableItemsData?> Function(int) fetchItems;
  final Future<List<MasterDataValue>> Function() fetchPaymentMethods;
  final CreateReturn create;
  bool voucherSelected = false;
  PurchaseOrderData? selectedVoucher;
  bool isLoadingVouchers = true;
  bool isLoadingItems = false;
  bool isSubmitting = false;
  String? itemsLoadError;
  final List<ReturnLineItem> returnItems = [];
  List<ReturnableItem> returnableItemsList = [];
  List<PurchaseOrderData> purchaseOrdersList = [];
  int listPurchaseOrderCurrentPage = 1;
  int listPurchaseOrderTotalPages = 1;
  DateTime returnDate = DateTime.now();
  MasterDataValue? selectedPaymentMethod;
  final paidAmountController = TextEditingController();
  bool paidAmountManuallyEdited = false;
  List<MasterDataValue> paymentMethods = [];
  bool isLoadingPaymentMethods = false;
  bool _disposed = false;
  int _voucherRequest = 0;
  int _itemsRequest = 0;
  void update(VoidCallback mutation) {
    if (_disposed) return;
    mutation();
    notifyListeners();
  }

  Future<void> loadPaymentMethods() async {
    update(() => isLoadingPaymentMethods = true);
    try {
      final methods = await fetchPaymentMethods();
      update(() => paymentMethods = methods);
    } catch (_) {
      // The original form keeps its cached values when loading fails.
    } finally {
      update(() => isLoadingPaymentMethods = false);
    }
  }

  Future<void> loadVouchers({int page = 1}) async {
    if (_disposed) return;
    final request = ++_voucherRequest;
    update(() => isLoadingVouchers = true);
    try {
      final result = await fetchVouchers(page);
      if (_disposed || request != _voucherRequest) return;
      update(() {
        purchaseOrdersList = result.data ?? [];
        listPurchaseOrderCurrentPage =
            result.currentPage ?? listPurchaseOrderCurrentPage;
        listPurchaseOrderTotalPages =
            result.lastPage ?? listPurchaseOrderTotalPages;
      });
    } catch (_) {
    } finally {
      if (request == _voucherRequest) update(() => isLoadingVouchers = false);
    }
  }

  Future<void> onVoucherSelected(PurchaseOrderData voucher) async {
    if (_disposed || voucher.id == null) return;
    update(() {
      selectedVoucher = voucher;
      voucherSelected = true;
      returnItems.clear();
    });
    await _loadItems(voucher.id!);
  }

  Future<void> retryLoadReturnableItems() async {
    final id = selectedVoucher?.id;
    if (id == null || isLoadingItems || _disposed) return;
    await _loadItems(id);
  }

  Future<void> _loadItems(int id) async {
    final request = ++_itemsRequest;
    update(() {
      isLoadingItems = true;
      itemsLoadError = null;
    });
    try {
      final result = await fetchItems(id);
      if (_disposed || request != _itemsRequest) return;
      update(() => returnableItemsList = result?.items ?? []);
    } catch (error) {
      if (_disposed || request != _itemsRequest) return;
      update(() {
        returnableItemsList = [];
        itemsLoadError = error
            .toString()
            .replaceFirst('HttpException: ', '')
            .replaceFirst('Exception: ', '');
      });
    } finally {
      if (request == _itemsRequest) update(() => isLoadingItems = false);
    }
  }

  double returnUnitPrice(ReturnableItem item) =>
      PurchaseReturnPricing.unitPrice(item: item, voucher: selectedVoucher);
  double get totalReturnAmount =>
      returnItems.fold(0.0, (sum, e) => sum + e.amount);
  double get totalReturnQty =>
      returnItems.fold(0.0, (sum, e) => sum + e.quantity);
  void updatePaidAmount() {
    if (!paidAmountManuallyEdited)
      paidAmountController.text = totalReturnAmount.toStringAsFixed(2);
  }

  void addItem(ReturnableItem item, double quantity, String reason) {
    update(() {
      final existing = returnItems
          .indexWhere((e) => e.source.purchaseItemId == item.purchaseItemId);
      if (existing >= 0) {
        returnItems[existing].quantity = quantity;
        returnItems[existing].reason = reason;
      } else {
        returnItems.add(ReturnLineItem(
            source: item,
            unitPrice: returnUnitPrice(item),
            quantity: quantity,
            reason: reason));
      }
      updatePaidAmount();
    });
  }

  void removeReturnItem(int index) => update(() {
        returnItems.removeAt(index);
        updatePaidAmount();
      });
  bool get hasValidPayment {
    if (selectedPaymentMethod == null) return true;
    final amount = double.tryParse(paidAmountController.text.trim()) ?? 0;
    return amount > 0 && amount <= totalReturnAmount;
  }

  Future<Map<String, dynamic>?> submitReturn() async {
    if (_disposed ||
        isSubmitting ||
        returnItems.isEmpty ||
        selectedVoucher?.id == null ||
        !hasValidPayment) return null;
    final id = selectedVoucher!.id!;
    final items = returnItems.map((e) => e.toPayload()).toList();
    final date = DateFormat('yyyy-MM-dd').format(returnDate);
    final method = selectedPaymentMethod;
    final paid = method != null
        ? double.tryParse(paidAmountController.text.trim())
        : null;
    update(() => isSubmitting = true);
    try {
      return await create(
          purchaseVoucherId: id,
          returnDate: date,
          items: items,
          hasPayment: method != null,
          paidAmount: paid,
          paymentMethod: method?.id.toString());
    } finally {
      update(() => isSubmitting = false);
    }
  }

  void backToVouchers() {
    _itemsRequest++;
    update(() {
      voucherSelected = false;
      selectedVoucher = null;
      returnItems.clear();
      selectedPaymentMethod = null;
      paidAmountController.clear();
      paidAmountManuallyEdited = false;
      isLoadingItems = false;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _voucherRequest++;
    _itemsRequest++;
    paidAmountController.dispose();
    super.dispose();
  }
}
