import 'dart:io';

import '../domain/models/list_purchase.dart';
import '../domain/models/list_purchase_voucher.dart';
import '../domain/models/purchase_order_model.dart';
import 'purchase_api.dart';

class PurchaseRepository {
  PurchaseRepository({PurchaseApi? api}) : api = api ?? PurchaseApi();
  final PurchaseApi api;
  Future<PurchaseRequest> prepareListAllStores(
          String accessToken, String? storeName) =>
      api.prepareListAllStores(accessToken, storeName);

  Future<PurchaseRequest> prepareListAllSuppliers(
          String accessToken, String? supplierName) =>
      api.prepareListAllSuppliers(accessToken, supplierName);

  Future<PurchaseRequest> prepareListAllUnits(
    String accessToken,
  ) =>
      api.prepareListAllUnits(accessToken);

  Future<PurchaseRequest> prepareListMasterDataValues(
    String accessToken,
    String code,
  ) =>
      api.prepareListMasterDataValues(accessToken, code);

  Future<PurchaseRequest> prepareListPurchase({
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
      api.prepareListPurchase(
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

  Future<PurchaseRequest> prepareListPurchaseVoucher({
    required String accessToken,
    String? filterAmount,
    String? filterStore,
    String? filterDate,
    int? page,
  }) =>
      api.prepareListPurchaseVoucher(
          accessToken: accessToken,
          filterAmount: filterAmount,
          filterStore: filterStore,
          filterDate: filterDate,
          page: page);

  Future<PurchaseRequest> prepareListAllPurchaseItems(
    String accessToken,
  ) =>
      api.prepareListAllPurchaseItems(accessToken);

  Future<PurchaseRequest> prepareListPurchaseOrders({
    required String accessToken,
    String? storeId,
    String? supplierId,
    String? dateFrom,
    String? dateTo,
    int? page,
  }) =>
      api.prepareListPurchaseOrders(
          accessToken: accessToken,
          storeId: storeId,
          supplierId: supplierId,
          dateFrom: dateFrom,
          dateTo: dateTo,
          page: page);

  Future<PurchaseRequest> prepareFetchPurchaseOrderDetails({
    required String accessToken,
    required String purchaseId,
  }) =>
      api.prepareFetchPurchaseOrderDetails(
          accessToken: accessToken, purchaseId: purchaseId);

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
      api.addPurchaseItem(
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
      api.addPurchaseProductStockAPI(
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
      api.addPurchase(purchaseId: purchaseId, accessToken: accessToken);

  Future<dynamic> removePurchaseItem({
    required String itemId,
    required String accessToken,
  }) =>
      api.removePurchaseItem(itemId: itemId, accessToken: accessToken);

  Future<dynamic> finishPurchaseOrder({
    required String accessToken,
    String? purchaseId,
    String? purchaseVoucherId,
    List<String>? paymentMethods,
    List<Map<String, dynamic>>? paidMethods,
  }) =>
      api.finishPurchaseOrder(
          accessToken: accessToken,
          purchaseId: purchaseId,
          purchaseVoucherId: purchaseVoucherId,
          paymentMethods: paymentMethods,
          paidMethods: paidMethods);

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
      api.createPurchaseOrder(
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
    required String timeoutMessage,
    required double discount,
    List<String>? paymentMethods,
    Map<String, dynamic>? paidAmounts,
  }) =>
      api.receivePurchaseOrder(
          accessToken: accessToken,
          purchaseId: purchaseId,
          items: items,
          invoiceRef: invoiceRef,
          timeoutMessage: timeoutMessage,
          discount: discount,
          paymentMethods: paymentMethods,
          paidAmounts: paidAmounts);

  Future<ListPurchaseOrderModel> fetchOrdersPage({
    required String accessToken,
    String? storeId,
    String? supplierId,
    String? dateFrom,
    String? dateTo,
    int? page,
  }) async {
    final request = await api.prepareListPurchaseOrders(
      accessToken: accessToken,
      storeId: storeId,
      supplierId: supplierId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      page: page,
    );
    final response = await request.send();
    if (response.statusCode != 200) {
      throw HttpException(
          'Failed to load purchase orders (${response.statusCode}).');
    }
    final decoded = response.json;
    if (decoded is! Map<String, dynamic> || decoded['status'] != 'success') {
      throw const HttpException('Failed to load purchase orders.');
    }
    return response.orders;
  }

  Future<ListPurchaseModel> fetchLegacyPurchasesPage(
      {required String accessToken,
      String? filterName,
      String? filterStore,
      int? page}) async {
    final request = await prepareListPurchase(
        accessToken: accessToken,
        filterName: filterName,
        filterStore: filterStore,
        page: page);
    final response = await request.send();
    if (response.statusCode != 200)
      throw HttpException('Failed to load purchases (${response.statusCode}).');
    final decoded = response.json;
    if (decoded is! Map<String, dynamic> || decoded['status'] == 'failed')
      throw const HttpException('Failed to load purchases.');
    return response.purchases;
  }

  Future<ListVoucherModel> fetchLegacyVouchersPage(
      {required String accessToken,
      String? filterAmount,
      String? filterStore,
      int? page}) async {
    final request = await prepareListPurchaseVoucher(
        accessToken: accessToken,
        filterAmount: filterAmount,
        filterStore: filterStore,
        page: page);
    final response = await request.send();
    if (response.statusCode != 200)
      throw HttpException(
          'Failed to load purchase vouchers (${response.statusCode}).');
    final decoded = response.json;
    if (decoded is! Map<String, dynamic> || decoded['status'] == 'failed')
      throw const HttpException('Failed to load purchase vouchers.');
    return response.vouchers;
  }
}
