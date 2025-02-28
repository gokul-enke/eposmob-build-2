import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/list_sales_return.dart';

import '../models/list_sales_order.dart';
import '../resources/app_url.dart';

class SalesProvider with ChangeNotifier {
  List<ListOrderModelData> _orders = [];
  List<SalesReturnOrder> _salesReturnOrders = [];
  int currentPage = 1;
  int totalPages = 1;
  List<ListOrderModelData> get orders => _orders;
  List<SalesReturnOrder> get salesReturnOrders => _salesReturnOrders;

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

  Future<void> fetchOrders({
    required String accessToken,
    int? storeId,
    String? orderNumber,
    String? filterName,
    String? date,
    int? customerId,
    int? productId,
    String? filterStatus,
    String? filterPrice,
    String? filterEmail,
    String? filterPhone,
    String? filterStore,
    String? filterCreatedBy,
    int? page,
  }) async {
    final queryParameters = <String, String>{
      // 'store_id': storeId.toString(),
    };

    if (orderNumber != null) queryParameters['number'] = orderNumber;
    // if (filterName != null) queryParameters['filter_name'] = filterName;
    if (date != null) queryParameters['order_date'] = date;
    if (customerId != null) {
      queryParameters['customer_id'] = customerId.toString();
    }
    if (productId != null) queryParameters['product_id'] = productId.toString();
    // if (filterStatus != null) queryParameters['filter_status'] = filterStatus;
    // if (filterPrice != null) queryParameters['filter_price'] = filterPrice;
    // if (filterEmail != null) queryParameters['filter_email'] = filterEmail;
    // if (filterPhone != null) queryParameters['filter_phone'] = filterPhone;
    // if (filterStore != null) queryParameters['filter_store'] = filterStore;
    if (filterCreatedBy != null) {
      queryParameters['filter_created_by'] = filterCreatedBy;
    }
    if (page != null) queryParameters['page'] = page.toString();

    final uri = Uri.parse(APPUrl.getListOrder)
        .replace(queryParameters: queryParameters);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      // debugPrint('fetchOrders response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final jsonData = json.decode(response.body);
          // debugPrint('Received JSON data: ${jsonData.toString()}');
          try {
            ListSalesOrderModel listSalesOrderModel =
                ListSalesOrderModel.fromJson(jsonData);
            currentPage = listSalesOrderModel.pagination?.currentPage ?? 1;
            totalPages = listSalesOrderModel.pagination?.totalPages ?? 1;
            // debugPrint(listSalesOrderModel.pagination!.currentPage.toString());
            // debugPrint(listSalesOrderModel.pagination!.totalPages.toString());
            _orders = listSalesOrderModel.data ?? [];
            notifyListeners();
          } catch (e) {
            // debugPrint('Error parsing JSON data: $e');
            // debugPrint('JSON structure: ${jsonData.runtimeType}');
            throw Exception('Failed to parse order list data: $e');
          }
        } else {
          // debugPrint('Empty response body');
          throw Exception('Received empty response');
        }
      } else {
        debugPrint(
            'Failed to load orders: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load orders');
      }
    } catch (error) {
      // debugPrint('Error in fetchOrders: $error');
      _orders = [];
      rethrow;
    }
  }

  //          *********************** LIST ORDER DETAILS API ***************************************************
  Future<dynamic> listOrderDetails(
      BuildContext context, String orderNumber, String accessToken) async {
    // debugPrint(" API listOrderDetails $_orderId   passed one$orderNumber");
    final url = Uri.parse("${APPUrl.getListOrderDetails}/$orderNumber");

    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'content-type': 'application/json'
      });
      // if (response.statusCode == 200) {
      debugPrint('List listOrderDetails  inside');

      debugPrint(json.decode(response.body).toString());
      final jsonData = json.decode(response.body);

      debugPrint("status ${jsonData["status"]}");

      return json.decode(response.body);
      // }
    } catch (error) {
      debugPrint(error.toString());
      rethrow;
    } finally {}
  }

  Future<void> fetchSalesReturn({
    required String accessToken,
    required int customerId,
    int? page,
  }) async {
    final queryParameters = <String, String>{
      'customer_id': "1",
    };
    if (page != null) queryParameters['page'] = page.toString();

    final uri = Uri.parse(APPUrl.listSalesReturn)
        .replace(queryParameters: queryParameters);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint(
          'fetch Sales Return list response status code: ${response.statusCode}');
      debugPrint('response.body ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        try {
          final salesReturnResponse = SalesReturnResponse.fromJson(jsonData);
          debugPrint(
              'fetch Sales Return list response data: ${salesReturnResponse.data}');
          _salesReturnOrders = salesReturnResponse.data; // Store fetched data
          notifyListeners(); // Notify listeners to update UI
        } catch (e) {
          debugPrint('Error parsing JSON data: $e');
        }
      } else {
        debugPrint(
            'Failed to load orders: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load orders');
      }
    } catch (error) {
      // debugPrint('Error in fetchOrders: $error');
      _salesReturnOrders = [];
      rethrow;
    }
  }

  Future<void> submitSalesReturn({
    required String accessToken,
    required int orderId,
    required double price,
    required int quantity,
    required int cartItemId,
    required String reason,
  }) async {
    final url =
        Uri.parse(APPUrl.salesReturn); // Update with your server base URL

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'order_id': orderId,
        'price': price,
        'quantity': quantity,
        'cart_item_id': cartItemId,
        'reason': reason,
      }),
    );

    // debugPrint("accessToken $accessToken");
    // debugPrint("orderId $orderId");
    // debugPrint("price $price");
    // debugPrint("quantity $quantity");
    // debugPrint("cartItemId $cartItemId");
    // debugPrint("reason $reason");
    // debugPrint("response.statusCode ${response.statusCode}");
    // debugPrint("response.body ${response.body}");

    if (response.statusCode == 200) {
      // debugPrint('Sales return submitted successfully: ${response.body}');
      notifyListeners();
    } else {
      debugPrint(
          'Failed to submit sales return: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to submit sales return');
    }
  }

  Future<void> completeSalesReturn({
    required String accessToken,
    required int returnOrderId,
  }) async {
    final url = Uri.parse(
        APPUrl.completeSalesReturn); // Update with your server base URL

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'return_order_id': returnOrderId,
      }),
    );

    if (response.statusCode == 200) {
      debugPrint('Sales return submitted successfully: ${response.body}');
      notifyListeners();
    } else {
      debugPrint(
          'Failed to submit sales return: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to submit sales return');
    }
  }
}
