import 'package:flutter/foundation.dart';

import '../../data/sales_return_repository.dart';
import '../../domain/models/list_sales_return.dart';
import '../../domain/models/list_sales_return_items.dart';
import '../../domain/models/sales_return_refund_breakdown.dart';

class SalesReturnProvider extends ChangeNotifier {
  SalesReturnProvider({SalesReturnRepository? repository})
      : repository = repository ?? SalesReturnRepository();
  final SalesReturnRepository repository;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<SalesReturnOrder> orders = [];
  List<SalesReturnCart> items = [];
  SalesReturnOrderInfo? currentOrder;
  SalesReturnRefundBreakdown? breakdown;
  int currentPage = 1;
  int totalPages = 1;

  void clearBreakdown() {
    breakdown = null;
    _notify();
  }

  Future<void> fetchSalesReturn(
      {required String accessToken, int? page}) async {
    final request =
        await repository.api.prepare(accessToken, includeStore: true);
    try {
      final response = await repository.api.list(request, page: page);
      orders = response.data.data;
      currentPage = response.data.currentPage;
      totalPages = response.data.lastPage;
      _notify();
    } catch (_) {
      orders = [];
      rethrow;
    }
  }

  Future<void> fetchSalesReturnItems(
      {required String accessToken, required String orderId, int? page}) async {
    final response =
        await repository.fetchItems(accessToken, orderId: orderId, page: page);
    items = response.data;
    currentOrder = response.order;
    _notify();
  }

  Future<int> submitSalesReturn(
      {required String accessToken,
      required int orderId,
      required double price,
      required num quantity,
      required int cartItemId,
      required String reason,
      bool isDeliveryRefundable = false}) async {
    final result = await repository.api.submit(
        accessToken: accessToken,
        orderId: orderId,
        price: price,
        quantity: quantity,
        cartItemId: cartItemId,
        reason: reason,
        isDeliveryRefundable: isDeliveryRefundable);
    if (result.breakdown != null) breakdown = result.breakdown;
    _notify();
    return result.id;
  }

  Future<void> completeSalesReturn(
      {required String accessToken,
      required int returnOrderId,
      String? paymentMethod,
      double? paidAmount,
      bool? hasPayment,
      bool isDeliveryRefundable = false}) async {
    final result = await repository.api.complete(
        accessToken: accessToken,
        returnOrderId: returnOrderId,
        paymentMethod: paymentMethod,
        paidAmount: paidAmount,
        hasPayment: hasPayment,
        isDeliveryRefundable: isDeliveryRefundable);
    if (result != null) breakdown = result;
    _notify();
  }
}
