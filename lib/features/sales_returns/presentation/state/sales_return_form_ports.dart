import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';

import '../../data/sales_return_api.dart';
import '../../domain/models/list_sales_return_items.dart';
import '../../domain/models/sales_return_refund_breakdown.dart';

typedef ReturnFetchOrders = Future<void> Function(
    {required String accessToken,
    int? storeId,
    String? orderNumber,
    int? customerId,
    String? date,
    int? page});
typedef ReturnSubmit = Future<SalesReturnSubmission> Function(
    {required String accessToken,
    required int orderId,
    required double price,
    required num quantity,
    required int cartItemId,
    required String reason,
    bool isDeliveryRefundable});
typedef ReturnComplete = Future<SalesReturnRefundBreakdown?> Function(
    {required String accessToken,
    required int returnOrderId,
    String? paymentMethod,
    double? paidAmount,
    bool? hasPayment,
    bool isDeliveryRefundable});

class SalesReturnFormPorts {
  const SalesReturnFormPorts(
      {required this.token,
      required this.storeId,
      required this.passedNumber,
      required this.passedId,
      required this.clearNavigation,
      required this.fetchOrders,
      required this.orders,
      required this.currentPage,
      required this.totalPages,
      required this.items,
      required this.details,
      required this.submit,
      required this.complete,
      required this.error});
  final String Function() token, passedNumber, passedId;
  final Future<int?> Function() storeId;
  final void Function() clearNavigation;
  final ReturnFetchOrders fetchOrders;
  final List<ListOrderModelData> Function() orders;
  final int Function() currentPage, totalPages;
  final Future<SalesReturnItemsResponse> Function(String number) items;
  final Future<dynamic> Function(String number) details;
  final ReturnSubmit submit;
  final ReturnComplete complete;
  final void Function(String message) error;
}
