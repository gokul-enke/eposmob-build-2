import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/order_details.dart';

import '../../data/sales_action_response.dart';

class SalesOrderDetailController extends ChangeNotifier {
  SalesOrderDetailController({required this.fetch});
  final Future<dynamic> Function() fetch;
  bool loading = false;
  bool _disposed = false;
  int _generation = 0;
  String orderNumber = '';
  String? tokenNumber;
  OrderDetailsModelData? data;
  OrderDetailsModelDataCustomerDetails? get customer => data?.customerDetails;
  OrderDetailsModelDataCart? get cart => data?.cart;
  List<OrderDetailsModelDataCartItem>? get items => cart?.cartItems ?? [];
  OrderDetailsModelDataPriceSummary? get priceSummary =>
      data?.priceSummary ?? cart?.priceSummary;
  Future<void> load() async {
    if (_disposed) return;
    final generation = ++_generation;
    loading = true;
    notifyListeners();
    try {
      final response = await fetch();
      if (_disposed || generation != _generation) return;
      if (response['status'] == 'success') {
        try {
          final parsed = OrderDetailsModel.fromJson(response);
          if (parsed.data != null) {
            data = parsed.data;
            orderNumber = data?.customerReceiptNumber ?? '';
            tokenNumber = data?.tokenNumber;
          } else {
            orderNumber = 'sales_order_details.err_order_data_null'.tr;
          }
        } catch (_) {
          orderNumber = 'sales_order_details.err_parsing_order_data'.tr;
        }
      } else {
        orderNumber = response['message']?.toString().trim().isNotEmpty == true
            ? response['message'].toString().trim()
            : 'sales_order_details.err_order_not_found'.tr;
      }
    } catch (error) {
      if (!_disposed && generation == _generation)
        orderNumber = SalesActionResponse.apiErrorMessage(error,
            fallback: 'sales_order_details.err_order_not_found'.tr);
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
