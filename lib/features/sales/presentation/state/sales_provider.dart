import 'package:flutter/material.dart';
import 'package:pos_machine/features/sales_returns/data/sales_return_repository.dart';
import 'package:pos_machine/features/sales_returns/presentation/state/sales_return_provider.dart';

import '../../data/sales_action_response.dart';
import '../../data/sales_actions_api.dart';
import '../../data/sales_http.dart';
import '../../data/sales_repository.dart';
import 'sales_daily_closing.dart';
import 'sales_filter_state.dart';
import 'sales_order_directory.dart';
import 'sales_return_bridge.dart';

export '../../domain/sales_action_error.dart';

typedef SalesPostRequest = SalesHttpPost;

class SalesProvider extends ChangeNotifier
    with
        SalesOrderDirectory,
        SalesFilterState,
        SalesDailyClosing,
        SalesReturnBridge {
  SalesProvider(
      {SalesPostRequest? postRequest,
      SalesRepository? repository,
      SalesReturnRepository? salesReturnRepository})
      : repository = repository ??
            SalesRepository(actions: SalesActionsApi(post: postRequest)),
        salesReturns = SalesReturnProvider(repository: salesReturnRepository) {
    salesReturns.addListener(_notifyReturnListeners);
  }
  @override
  final SalesRepository repository;
  @override
  final SalesReturnProvider salesReturns;
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  void _notifyReturnListeners() => notifyListeners();
  @override
  void dispose() {
    _disposed = true;
    salesReturns.removeListener(_notifyReturnListeners);
    salesReturns.dispose();
    super.dispose();
  }

  static void ensureSalesActionSucceeded(int statusCode, String responseBody,
          {required String fallback}) =>
      SalesActionResponse.ensureSalesActionSucceeded(statusCode, responseBody,
          fallback: fallback);
  static String apiErrorMessage(Object error, {required String fallback}) =>
      SalesActionResponse.apiErrorMessage(error, fallback: fallback);
  bool isOnlineSalesNavigation = false;
  String _orderNumber = "";
  String _orderId = "";

  String get getOrderNumber {
    return _orderNumber;
  }

  String get getOrderId {
    return _orderId;
  }

  int userId = 0;
  setUserId(int value) {
    userId = value;
    notifyListeners();
  }

  setOrderNumber(String value) {
    _orderNumber = value;
    notifyListeners();
  }

  setOrderId(String value) {
    _orderId = value;
    notifyListeners();
  }

  Future<dynamic> listOrderDetails(
          BuildContext context, String orderNumber, String accessToken) =>
      repository.orders.details(accessToken, orderNumber);
  Future<void> cancelOrder({
    required String accessToken,
    required String orderId,
    String? paymentMethod,
    String? refundAmount,
    bool? deliveryChargeRefundable,
  }) async {
    await repository.actions.cancelOrder(
        accessToken: accessToken,
        orderId: orderId,
        paymentMethod: paymentMethod,
        refundAmount: refundAmount,
        deliveryChargeRefundable: deliveryChargeRefundable);
    notifyListeners();
  }

  Future<void> changeOrderStatus({
    required String accessToken,
    required String orderId,
    required String status,
    double? refundAmount,
    String? paymentMethod,
    bool? deliveryChargeRefundable,
    String? deliveryLogistics,
  }) async {
    await repository.actions.changeOrderStatus(
        accessToken: accessToken,
        orderId: orderId,
        status: status,
        refundAmount: refundAmount,
        paymentMethod: paymentMethod,
        deliveryChargeRefundable: deliveryChargeRefundable,
        deliveryLogistics: deliveryLogistics);
    notifyListeners();
  }

  Future<void> changePaymentStatus({
    required String accessToken,
    required String orderId,
    required String status,
    required double amount,
  }) async {
    await repository.actions.changePaymentStatus(
        accessToken: accessToken,
        orderId: orderId,
        status: status,
        amount: amount);
    notifyListeners();
  }
}
