import 'dart:io';
import 'package:pos_machine/features/purchases/domain/models/purchase_order_model.dart';
import 'purchase_return_api.dart';
import '../domain/models/purchase_return.dart';

/// Request-local results; never caches a screen's active filters or rows.
class PurchaseReturnRepository {
  PurchaseReturnRepository({PurchaseReturnApi? api})
      : api = api ?? PurchaseReturnApi();
  final PurchaseReturnApi api;
  Future<void> requireTenant() async {
    if (await api.session.apiKey() == null) {
      throw const HttpException('API key not found. Please restart the app.');
    }
  }

  Future<ListPurchaseReturnData> fetchPage(
          {required String accessToken,
          int? page,
          String? supplierId,
          String? dateFrom,
          String? dateTo}) =>
      api.listPurchaseReturns(
          accessToken: accessToken,
          page: page,
          supplierId: supplierId,
          dateFrom: dateFrom,
          dateTo: dateTo);
  Future<PurchaseReturnData?> fetchDetails(
          {required String accessToken, required int returnId}) =>
      api.fetchPurchaseReturnDetails(
          accessToken: accessToken, returnId: returnId);
  Future<ReturnableItemsData?> fetchItems(
          {required String accessToken, required int purchaseVoucherId}) =>
      api.fetchReturnableItems(
          accessToken: accessToken, purchaseVoucherId: purchaseVoucherId);
  Future<Map<String, dynamic>> create(
          {required String accessToken,
          required int purchaseVoucherId,
          required String returnDate,
          required List<Map<String, dynamic>> items,
          bool hasPayment = false,
          double? paidAmount,
          String? paymentMethod}) =>
      api.createPurchaseReturn(
          accessToken: accessToken,
          purchaseVoucherId: purchaseVoucherId,
          returnDate: returnDate,
          items: items,
          hasPayment: hasPayment,
          paidAmount: paidAmount,
          paymentMethod: paymentMethod);
  Future<ListPurchaseOrderData> fetchVouchers(
          {required String accessToken, int page = 1}) =>
      api.fetchVouchers(accessToken: accessToken, page: page);
}
