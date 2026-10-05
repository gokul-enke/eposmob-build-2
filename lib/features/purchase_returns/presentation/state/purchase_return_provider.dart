import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/purchase_return_repository.dart';
import '../../domain/models/purchase_return.dart';

/// Legacy observable return state. Pages use request-local fetchPage/fetchItems.
class PurchaseReturnProvider extends ChangeNotifier {
  PurchaseReturnProvider({PurchaseReturnRepository? repository})
      : repository = repository ?? PurchaseReturnRepository();
  final PurchaseReturnRepository repository;
  List<PurchaseReturnData> purchaseReturnsList = [];
  int purchaseReturnCurrentPage = 1;
  int purchaseReturnTotalPages = 1;
  List<ReturnableItem> returnableItemsList = [];
  ReturnableItemsData? activeReturnableItemsData;
  Future<void> listPurchaseReturns({
    required String accessToken,
    int? page,
    String? supplierId,
    String? dateFrom,
    String? dateTo,
  }) async {
    await repository.requireTenant();
    try {
      final data = await repository.fetchPage(
          accessToken: accessToken,
          page: page,
          supplierId: supplierId,
          dateFrom: dateFrom,
          dateTo: dateTo);
      final model = ListPurchaseReturnModel(data: data);
      purchaseReturnCurrentPage = model.data?.currentPage ?? 1;
      purchaseReturnTotalPages = model.data?.lastPage ?? 1;
      purchaseReturnsList = model.data?.data ?? [];
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching purchase returns: $e");
      purchaseReturnsList = [];
      purchaseReturnCurrentPage = 1;
      purchaseReturnTotalPages = 1;
      notifyListeners();
      if (e is HttpException) rethrow;
      throw const HttpException(
          'Unable to load purchase returns. Please try again.');
    }
  }

  Future<PurchaseReturnData?> fetchPurchaseReturnDetails(
          {required String accessToken, required int returnId}) =>
      repository.fetchDetails(accessToken: accessToken, returnId: returnId);

  Future<void> fetchReturnableItems({
    required String accessToken,
    required int purchaseVoucherId,
  }) async {
    await repository.requireTenant();
    try {
      final data = await repository.fetchItems(
          accessToken: accessToken, purchaseVoucherId: purchaseVoucherId);
      final parsed = ReturnableItemsResponse(data: data);
      activeReturnableItemsData = parsed.data;
      returnableItemsList = parsed.data?.items ?? [];
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching returnable items: $e");
      returnableItemsList = [];
      activeReturnableItemsData = null;
      notifyListeners();
      if (e is HttpException) rethrow;
      throw const HttpException(
        'Unable to load returnable items. Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>> createPurchaseReturn(
          {required String accessToken,
          required int purchaseVoucherId,
          required String returnDate,
          required List<Map<String, dynamic>> items,
          bool hasPayment = false,
          double? paidAmount,
          String? paymentMethod}) =>
      repository.create(
          accessToken: accessToken,
          purchaseVoucherId: purchaseVoucherId,
          returnDate: returnDate,
          items: items,
          hasPayment: hasPayment,
          paidAmount: paidAmount,
          paymentMethod: paymentMethod);

  Future<ListPurchaseReturnData> fetchPage(
          {required String accessToken,
          int? page,
          String? supplierId,
          String? dateFrom,
          String? dateTo}) =>
      repository.fetchPage(
          accessToken: accessToken,
          page: page,
          supplierId: supplierId,
          dateFrom: dateFrom,
          dateTo: dateTo);
  Future<ReturnableItemsData?> fetchItems(
          {required String accessToken, required int purchaseVoucherId}) =>
      repository.fetchItems(
          accessToken: accessToken, purchaseVoucherId: purchaseVoucherId);
}
