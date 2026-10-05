import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/purchase_returns/data/purchase_return_repository.dart';
import 'package:pos_machine/features/purchase_returns/domain/models/purchase_return.dart';
import 'package:pos_machine/features/purchase_returns/presentation/state/purchase_return_provider.dart';
import 'package:pos_machine/features/purchases/domain/models/list_purchase.dart';
import 'package:pos_machine/features/purchases/domain/models/list_purchase_voucher.dart';
import 'package:pos_machine/features/purchases/domain/models/purchase_order_model.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';
import 'package:pos_machine/models/list_unit.dart';

import '../../data/purchase_repository.dart';

part 'purchase_provider_operations_1.dart';
part 'purchase_provider_operations_2.dart';

part 'purchase_state.dart';

class PurchaseProvider extends _PurchaseState {
  PurchaseProvider({super.repository, super.purchaseReturnRepository});
  void _notifyPurchaseListeners() => notifyListeners();

  Future<dynamic> listAllPurchaseItems(
    String accessToken,
  ) =>
      _listAllPurchaseItemsOperation(accessToken);

  Future<dynamic> addPurchaseItem({
    required String categoryId,
    required String productId,
    required String quantity,
    required String unit,
    required String supplierId,
    required String storeId,
    required String batchNumber,
    required String accessToken,
  }) =>
      _addPurchaseItemOperation(
          categoryId: categoryId,
          productId: productId,
          quantity: quantity,
          unit: unit,
          supplierId: supplierId,
          storeId: storeId,
          batchNumber: batchNumber,
          accessToken: accessToken);

  Future<dynamic> addPurchaseProductStockAPI({
    required String accessToken,
    required String purchaseItemId,
    required String quantity,
    required String purchaseRate,
    required String retailPrice,
    required String wholesalePrice,
    required String wholesaleMinUnit,
    required String expiryDate,
    required String batchNumber,
    required String unit,
  }) =>
      _addPurchaseProductStockAPIOperation(
          accessToken: accessToken,
          purchaseItemId: purchaseItemId,
          quantity: quantity,
          purchaseRate: purchaseRate,
          retailPrice: retailPrice,
          wholesalePrice: wholesalePrice,
          wholesaleMinUnit: wholesaleMinUnit,
          expiryDate: expiryDate,
          batchNumber: batchNumber,
          unit: unit);

  Future<dynamic> addPurchase({
    required String purchaseId,
    required String accessToken,
  }) =>
      _addPurchaseOperation(purchaseId: purchaseId, accessToken: accessToken);

  Future<dynamic> removePurchaseItem({
    required String itemId,
    required String accessToken,
  }) =>
      _removePurchaseItemOperation(itemId: itemId, accessToken: accessToken);

  Future<dynamic> finishPurchaseOrder({
    required String accessToken,
    String? purchaseId,
    String? purchaseVoucherId,
    List<String>? paymentMethods,
    List<Map<String, dynamic>>? paidMethods,
  }) =>
      _finishPurchaseOrderOperation(
          accessToken: accessToken,
          purchaseId: purchaseId,
          purchaseVoucherId: purchaseVoucherId,
          paymentMethods: paymentMethods,
          paidMethods: paidMethods);

  Future<void> listPurchaseOrders({
    required String accessToken,
    String? storeId,
    String? supplierId,
    String? dateFrom,
    String? dateTo,
    int? page,
  }) =>
      _listPurchaseOrdersOperation(
          accessToken: accessToken,
          storeId: storeId,
          supplierId: supplierId,
          dateFrom: dateFrom,
          dateTo: dateTo,
          page: page);

  Future<void> fetchPurchaseOrderDetails({
    required String accessToken,
    required String purchaseId,
  }) =>
      _fetchPurchaseOrderDetailsOperation(
          accessToken: accessToken, purchaseId: purchaseId);

  Future<dynamic> createPurchaseOrder({
    required String accessToken,
    required String purchaseDate,
    required String supplierId,
    required String storeId,
    String? voucherNumber,
    String? invoiceRef,
    required double discount,
    List<String>? paymentMethods,
    Map<String, dynamic>? paidAmounts,
    required List<Map<String, dynamic>> items,
  }) =>
      _createPurchaseOrderOperation(
          accessToken: accessToken,
          purchaseDate: purchaseDate,
          supplierId: supplierId,
          storeId: storeId,
          voucherNumber: voucherNumber,
          invoiceRef: invoiceRef,
          discount: discount,
          paymentMethods: paymentMethods,
          paidAmounts: paidAmounts,
          items: items);

  Future<dynamic> receivePurchaseOrder({
    required String accessToken,
    required String purchaseId,
    required List<Map<String, dynamic>> items,
    String? invoiceRef, // NEW!
    required double discount,
    List<String>? paymentMethods,
    Map<String, dynamic>? paidAmounts,
  }) =>
      _receivePurchaseOrderOperation(
          accessToken: accessToken,
          purchaseId: purchaseId,
          items: items,
          invoiceRef: invoiceRef,
          discount: discount,
          paymentMethods: paymentMethods,
          paidAmounts: paidAmounts);

  Future<void> listPurchaseReturns(
          {required String accessToken,
          int? page,
          String? supplierId,
          String? dateFrom,
          String? dateTo}) =>
      _listPurchaseReturnsOperation(
          accessToken: accessToken,
          page: page,
          supplierId: supplierId,
          dateFrom: dateFrom,
          dateTo: dateTo);

  Future<PurchaseReturnData?> fetchPurchaseReturnDetails(
          {required String accessToken, required int returnId}) =>
      _fetchPurchaseReturnDetailsOperation(
          accessToken: accessToken, returnId: returnId);

  Future<void> fetchReturnableItems(
          {required String accessToken, required int purchaseVoucherId}) =>
      _fetchReturnableItemsOperation(
          accessToken: accessToken, purchaseVoucherId: purchaseVoucherId);

  Future<Map<String, dynamic>> createPurchaseReturn(
          {required String accessToken,
          required int purchaseVoucherId,
          required String returnDate,
          required List<Map<String, dynamic>> items,
          bool hasPayment = false,
          double? paidAmount,
          String? paymentMethod}) =>
      _createPurchaseReturnOperation(
          accessToken: accessToken,
          purchaseVoucherId: purchaseVoucherId,
          returnDate: returnDate,
          items: items,
          paidAmount: paidAmount,
          paymentMethod: paymentMethod);

  Future<void> listAllStores(String accessToken, String? storeName) =>
      _listAllStoresOperation(accessToken, storeName);

  Future<void> listAllSuppliers(String accessToken, String? supplierName) =>
      _listAllSuppliersOperation(accessToken, supplierName);

  Future<void> listAllUnits(
    String accessToken,
  ) =>
      _listAllUnitsOperation(accessToken);

  Future<void> listMasterDataValues(
    String accessToken,
    String code,
  ) =>
      _listMasterDataValuesOperation(accessToken, code);

  Future<void> listPurchase({
    required String accessToken,
    String? storeId,
    String? supplierId,
    String? filterName,
    String? filterProduct,
    String? filterStore,
    String? filterSupplier,
    String? filterDate,
    String? createdBy,
    int? page,
  }) =>
      _listPurchaseOperation(
          accessToken: accessToken,
          storeId: storeId,
          supplierId: supplierId,
          filterName: filterName,
          filterProduct: filterProduct,
          filterStore: filterStore,
          filterSupplier: filterSupplier,
          filterDate: filterDate,
          createdBy: createdBy,
          page: page);

  Future<void> listPurchaseVoucher({
    required String accessToken,
    String? filterAmount,
    String? filterStore,
    String? filterDate,
    int? page,
  }) =>
      _listPurchaseVoucherOperation(
          accessToken: accessToken,
          filterAmount: filterAmount,
          filterStore: filterStore,
          filterDate: filterDate,
          page: page);
}
