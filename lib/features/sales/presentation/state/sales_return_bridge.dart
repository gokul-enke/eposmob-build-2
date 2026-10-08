import 'package:flutter/foundation.dart';
import 'package:pos_machine/features/sales_returns/domain/models/list_sales_return.dart';
import 'package:pos_machine/features/sales_returns/domain/models/list_sales_return_items.dart';
import 'package:pos_machine/features/sales_returns/domain/models/sales_return_refund_breakdown.dart';
import 'package:pos_machine/features/sales_returns/presentation/state/sales_return_provider.dart';

mixin SalesReturnBridge on ChangeNotifier {
  SalesReturnProvider get salesReturns;
  int get salesReturnCurrentPage => salesReturns.currentPage;
  set salesReturnCurrentPage(int value) => salesReturns.currentPage = value;
  int get salesReturnTotalPages => salesReturns.totalPages;
  set salesReturnTotalPages(int value) => salesReturns.totalPages = value;
  List<SalesReturnOrder> get salesReturnOrders => salesReturns.orders;
  List<SalesReturnCart> get salesReturnItems => salesReturns.items;
  SalesReturnOrderInfo? get currentReturnOrder => salesReturns.currentOrder;
  SalesReturnRefundBreakdown? get serverRefundBreakdown =>
      salesReturns.breakdown;
  void clearServerRefundBreakdown() => salesReturns.clearBreakdown();

  Future<void> fetchSalesReturn({required String accessToken, int? page}) =>
      salesReturns.fetchSalesReturn(accessToken: accessToken, page: page);

  Future<void> fetchSalesReturnItems(
          {required String accessToken, required String orderId, int? page}) =>
      salesReturns.fetchSalesReturnItems(
          accessToken: accessToken, orderId: orderId, page: page);

  Future<int> submitSalesReturn(
          {required String accessToken,
          required int orderId,
          required double price,
          required num quantity,
          required int cartItemId,
          required String reason,
          bool isDeliveryRefundable = false}) =>
      salesReturns.submitSalesReturn(
          accessToken: accessToken,
          orderId: orderId,
          price: price,
          quantity: quantity,
          cartItemId: cartItemId,
          reason: reason,
          isDeliveryRefundable: isDeliveryRefundable);

  Future<void> completeSalesReturn(
          {required String accessToken,
          required int returnOrderId,
          String? paymentMethod,
          double? paidAmount,
          bool? hasPayment,
          bool isDeliveryRefundable = false}) =>
      salesReturns.completeSalesReturn(
          accessToken: accessToken,
          returnOrderId: returnOrderId,
          paymentMethod: paymentMethod,
          paidAmount: paidAmount,
          hasPayment: hasPayment,
          isDeliveryRefundable: isDeliveryRefundable);
}
