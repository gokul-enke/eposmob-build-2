import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/helpers/api_response_helper.dart';
import 'package:pos_machine/models/daily_sales_close.dart';
import 'package:pos_machine/models/day_close_pending_status.dart';
import 'package:pos_machine/models/list_sales_return.dart';
import 'package:pos_machine/models/list_sales_return_items.dart';
import 'package:pos_machine/models/sales_return_refund_breakdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/list_sales_order.dart';
import '../resources/app_url.dart';

class SalesProvider with ChangeNotifier {
  bool isOnlineSalesNavigation = false;
  List<ListOrderModelData> _orders = [];
  List<SalesReturnOrder> _salesReturnOrders = [];
  List<SalesReturnCart> _salesReturnItems = [];
  SalesReturnOrderInfo? _currentReturnOrder;
  SalesReturnRefundBreakdown? _serverRefundBreakdown;
  List<DailySalesCloseData> dailySalesCloseList = [];
  Pagination? dailySalesClosePagination;
  int currentPage = 1;
  int totalPages = 1;
  int paginationFrom = 1;
  int salesReturnCurrentPage = 1;
  int salesReturnTotalPages = 1;
  List<ListOrderModelData> get orders => _orders;
  List<SalesReturnOrder> get salesReturnOrders => _salesReturnOrders;
  List<SalesReturnCart> get salesReturnItems => _salesReturnItems;
  SalesReturnOrderInfo? get currentReturnOrder => _currentReturnOrder;
  SalesReturnRefundBreakdown? get serverRefundBreakdown => _serverRefundBreakdown;

  void clearServerRefundBreakdown() {
    _serverRefundBreakdown = null;
    notifyListeners();
  }

  void _storeRefundBreakdownFromBody(String body) {
    final breakdown = SalesReturnRefundBreakdown.fromResponseBody(body);
    if (breakdown != null) {
      _serverRefundBreakdown = breakdown;
    }
  }

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

  // Filter visibility state
  bool _showFilters = false;
  bool get showFilters => _showFilters;

  void toggleFilters() {
    _showFilters = !_showFilters;
    notifyListeners();
  }

  void setFiltersVisibility(bool value) {
    _showFilters = value;
    notifyListeners();
  }

  // Filter parameters
  String? _filterOrderNumber;
  String? _filterCustomerName;
  String? _filterPhone;
  String? _filterPrice;
  String? _filterEmail;
  String? _filterStore;
  String? _filterStatus;
  DateTime? _filterDate;

  String? get filterOrderNumber => _filterOrderNumber;
  String? get filterCustomerName => _filterCustomerName;
  String? get filterPhone => _filterPhone;
  String? get filterPrice => _filterPrice;
  String? get filterEmail => _filterEmail;
  String? get filterStore => _filterStore;
  String? get filterStatus => _filterStatus;
  DateTime? get filterDate => _filterDate;

  void setFilterOrderNumber(String? value) {
    _filterOrderNumber = value;
    notifyListeners();
  }

  void setFilterCustomerName(String? value) {
    _filterCustomerName = value;
    notifyListeners();
  }

  void setFilterPhone(String? value) {
    _filterPhone = value;
    notifyListeners();
  }

  void setFilterPrice(String? value) {
    _filterPrice = value;
    notifyListeners();
  }

  void setFilterEmail(String? value) {
    _filterEmail = value;
    notifyListeners();
  }

  void setFilterStore(String? value) {
    _filterStore = value;
    notifyListeners();
  }

  void setFilterStatus(String? value) {
    _filterStatus = value;
    notifyListeners();
  }

  void setFilterDate(DateTime? value) {
    _filterDate = value;
    notifyListeners();
  }

  void clearAllFilters() {
    _filterOrderNumber = null;
    _filterCustomerName = null;
    _filterPhone = null;
    _filterPrice = null;
    _filterEmail = null;
    _filterStore = null;
    _filterStatus = null;
    _filterDate = null;
    notifyListeners();
  }

  bool get hasActiveFilters {
    return _filterOrderNumber != null ||
        _filterCustomerName != null ||
        _filterPhone != null ||
        _filterPrice != null ||
        _filterEmail != null ||
        _filterStore != null ||
        _filterStatus != null ||
        _filterDate != null;
  }

  DailySalesCloseData? _selectedDailySalesCloseData;
  DailySalesCloseData? get selectedDailySalesCloseData =>
      _selectedDailySalesCloseData;

  void setSelectedDailySalesCloseData(DailySalesCloseData? data) {
    _selectedDailySalesCloseData = data;
    notifyListeners();
  }

  int _returnIndex = 78; // Default to user list
  int get returnIndex => _returnIndex;
  void setReturnIndex(int index) {
    _returnIndex = index;
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
    bool? filterOnlineSales,
  }) async {
    final queryParameters = <String, String>{};

    // Add store_id from parameter or from SharedPreferences
    if (storeId != null) {
      queryParameters['store_id'] = storeId.toString();
    } else {
      final prefs = await SharedPreferences.getInstance();
      final int? activeStoreId = prefs.getInt('active_store_id');
      if (activeStoreId != null) {
        queryParameters['store_id'] = activeStoreId.toString();
      }
    }

    if (orderNumber != null) queryParameters['number'] = orderNumber;
    if (filterName != null) queryParameters['filter_name'] = filterName;
    if (date != null) queryParameters['order_date'] = date;
    if (customerId != null) {
      queryParameters['customer_id'] = customerId.toString();
    }
    if (productId != null) queryParameters['product_id'] = productId.toString();
    if (filterStatus != null) queryParameters['filter_status'] = filterStatus;
    if (filterPrice != null) queryParameters['filter_price'] = filterPrice;
    if (filterEmail != null) queryParameters['filter_email'] = filterEmail;
    if (filterPhone != null) queryParameters['filter_phone'] = filterPhone;
    if (filterStore != null) queryParameters['filter_store'] = filterStore;
    if (filterCreatedBy != null) {
      queryParameters['filter_created_by'] = filterCreatedBy;
    }
    if (page != null) queryParameters['page'] = page.toString();
    if (filterOnlineSales != null) {
      queryParameters['filter_online_sales'] = filterOnlineSales.toString();
    }

    final uri = Uri.parse(APPUrl.getListOrder)
        .replace(queryParameters: queryParameters);

    // DEBUG: Print request details
    debugPrint('=== SALES API REQUEST DEBUG ===');
    debugPrint('Base URL: ${APPUrl.getListOrder}');
    debugPrint('Query Parameters: $queryParameters');
    debugPrint('Final URL with Query: $uri');
    debugPrint(
        'Access Token: ${accessToken.isNotEmpty ? "Present" : "Missing"}');

    try {
      // Get API key from SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found. Please restart the app.");
      }
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('=== SALES API RESPONSE DEBUG ===');
      debugPrint('Response Status Code: ${response.statusCode}');
      debugPrint('Response Headers: ${response.headers}');
      debugPrint('Response Body Length: ${response.body.length}');

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          debugPrint('=== RAW RESPONSE BODY ===');
          debugPrint('Raw Response: ${response.body}');

          final jsonData = json.decode(response.body);
          debugPrint('=== PARSED JSON STRUCTURE ===');
          debugPrint('JSON Type: ${jsonData.runtimeType}');
          debugPrint(
              'JSON Keys: ${jsonData is Map ? jsonData.keys.toList() : "Not a Map"}');

          if (jsonData is Map) {
            debugPrint('Status: ${jsonData["status"]}');
            debugPrint('Message: ${jsonData["message"]}');
            debugPrint('Data Type: ${jsonData["data"]?.runtimeType}');

            if (jsonData["data"] != null) {
              debugPrint(
                  'Data Keys: ${jsonData["data"] is Map ? jsonData["data"].keys.toList() : "Data is not a Map"}');

              if (jsonData["data"] is Map && jsonData["data"]["data"] != null) {
                debugPrint(
                    'Orders Array Type: ${jsonData["data"]["data"].runtimeType}');
                debugPrint(
                    'Orders Array Length: ${jsonData["data"]["data"] is List ? jsonData["data"]["data"].length : "Not a List"}');

                if (jsonData["data"]["data"] is List &&
                    jsonData["data"]["data"].isNotEmpty) {
                  debugPrint('=== FIRST ORDER SAMPLE ===');
                  var firstOrder = jsonData["data"]["data"][0];
                  debugPrint('First Order Type: ${firstOrder.runtimeType}');
                  debugPrint(
                      'First Order Keys: ${firstOrder is Map ? firstOrder.keys.toList() : "Not a Map"}');
                  if (firstOrder is Map) {
                    firstOrder.forEach((key, value) {
                      debugPrint('  $key: ${value?.runtimeType} = $value');
                    });
                  }
                }
              }
            }
          }

          try {
            debugPrint('=== ATTEMPTING MODEL PARSING ===');
            ListSalesOrderModel listSalesOrderModel =
                ListSalesOrderModel.fromJson(jsonData);

            debugPrint('Model Status: ${listSalesOrderModel.status}');
            debugPrint('Model Message: ${listSalesOrderModel.message}');
            debugPrint(
                'Model Data Length: ${listSalesOrderModel.data?.length ?? 0}');
            debugPrint(
                'Model Pagination: ${listSalesOrderModel.pagination != null ? "Present" : "Null"}');

            if (listSalesOrderModel.pagination != null) {
              int newCurrentPage =
                  listSalesOrderModel.pagination?.currentPage ?? 1;
              int newTotalPages =
                  listSalesOrderModel.pagination?.totalPages ?? 1;
              int newPaginationFrom = listSalesOrderModel.pagination?.from ?? 1;
              int newPaginationTo = listSalesOrderModel.pagination?.to ?? 1;

              debugPrint('=== PAGINATION UPDATE ===');
              debugPrint('Previous Current Page: $currentPage');
              debugPrint('Previous Total Pages: $totalPages');
              debugPrint('New Current Page: $newCurrentPage');
              debugPrint('New Total Pages: $newTotalPages');
              debugPrint('Total Orders in Response: ${_orders.length}');
              debugPrint('From: ${listSalesOrderModel.pagination?.from}');
              debugPrint('To: ${listSalesOrderModel.pagination?.to}');
              debugPrint(
                  'Next Page URL: ${listSalesOrderModel.pagination?.nextPageUrl}');
              debugPrint(
                  'Prev Page URL: ${listSalesOrderModel.pagination?.prevPageUrl}');

              // If from value is invalid (0 or null), calculate it
              if (newPaginationFrom <= 0) {
                // Calculate based on current page and response items count
                int itemsPerPage = _orders.length > 0 ? _orders.length : 1;
                newPaginationFrom = ((newCurrentPage - 1) * itemsPerPage) + 1;
                debugPrint(
                    'Calculated From using itemsPerPage=$itemsPerPage: $newPaginationFrom');
              }

              currentPage = newCurrentPage;
              totalPages = newTotalPages;
              paginationFrom = newPaginationFrom;

              debugPrint('Updated Current Page: $currentPage');
              debugPrint('Updated Total Pages: $totalPages');
              debugPrint('Updated Pagination From: $paginationFrom');
              debugPrint('Updated Pagination To: $newPaginationTo');
            } else {
              debugPrint('=== NO PAGINATION DATA ===');
              debugPrint('Setting default pagination values');
              currentPage = 1;
              totalPages = 1;
              paginationFrom = 1;
            }

            _orders = listSalesOrderModel.data ?? [];
            debugPrint('Orders Set Successfully: ${_orders.length} orders');

            // DEBUG: Print each order details
            if (_orders.isNotEmpty) {
              debugPrint('=== ORDERS DETAILS ===');
              for (int i = 0; i < _orders.length && i < 3; i++) {
                var order = _orders[i];
                debugPrint('Order $i:');
                debugPrint('  ID: ${order.id}');
                debugPrint('  Order Number: ${order.orderNumber}');
                debugPrint('  Grant Total: ${order.grantTotal}');
                debugPrint('  Status: ${order.status}');
                debugPrint('  Customer Name: ${order.customerName}');
                debugPrint(
                    '  Cart Items Count: ${order.cartItems?.length ?? 0}');
                debugPrint('  Order Date: ${order.orderDate}');
              }
            }

            notifyListeners();
            debugPrint('=== MODEL PARSING SUCCESS ===');
          } catch (e, stackTrace) {
            debugPrint('=== MODEL PARSING ERROR ===');
            debugPrint('Error Type: ${e.runtimeType}');
            debugPrint('Error Message: $e');
            debugPrint('Stack Trace: $stackTrace');

            // Try to identify specific parsing issues
            if (e.toString().contains('type')) {
              debugPrint('=== TYPE MISMATCH ANALYSIS ===');
              // Additional type analysis could be added here
            }

            throw Exception('Failed to parse order list data: $e');
          }
        } else {
          debugPrint('=== EMPTY RESPONSE ERROR ===');
          throw Exception('Received empty response');
        }
      } else {
        debugPrint('=== HTTP ERROR ===');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
        throw Exception('Failed to load orders: HTTP ${response.statusCode}');
      }
    } catch (error, stackTrace) {
      debugPrint('=== FETCH ORDERS EXCEPTION ===');
      debugPrint('Error Type: ${error.runtimeType}');
      debugPrint('Error Message: $error');
      debugPrint('Stack Trace: $stackTrace');
      _orders = [];
      rethrow;
    }
  }

  //          *********************** LIST ORDER DETAILS API ***************************************************
  Future<dynamic> listOrderDetails(
      BuildContext context, String orderNumber, String accessToken) async {
    // debugPrint(" API listOrderDetails $_orderId   passed one$orderNumber");
    final url = Uri.parse("${APPUrl.getListOrderDetails}/$orderNumber");

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    final Map<String, String> queryParameters = {};
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final finalUrl = url.replace(queryParameters: queryParameters);
    debugPrint('🌐 ORDER DETAILS API URL: ${finalUrl.toString()}');
    debugPrint('📤 ORDER DETAILS request body: {}');

    try {
      final response = await http.get(finalUrl, headers: {
        'Authorization': 'Bearer $accessToken',
        'content-type': 'application/json',
        'X-Tenant': apiKey,
      });
      debugPrint('📥 ORDER DETAILS response status: ${response.statusCode}');
      debugPrint('📥 ORDER DETAILS response body: ${response.body}');
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
    int? page,
  }) async {
    final queryParameters = <String, String>{};
    if (page != null) queryParameters['page'] = page.toString();

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }

    final uri = Uri.parse(APPUrl.listSalesReturn)
        .replace(queryParameters: queryParameters);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint(
          'fetch Sales Return list response status code: ${response.statusCode}');
      debugPrint('response.body ${response.body}');

      ApiResponseHelper.ensureSuccess(
        response.statusCode,
        response.body,
        fallback: 'Failed to load sales returns',
      );

      final jsonData = json.decode(response.body);
      final salesReturnResponse = SalesReturnResponse.fromJson(jsonData);
      _salesReturnOrders = salesReturnResponse.data.data;

      salesReturnCurrentPage = salesReturnResponse.data.currentPage;
      salesReturnTotalPages = salesReturnResponse.data.lastPage;

      notifyListeners();
    } catch (error) {
      _salesReturnOrders = [];
      rethrow;
    }
  }

  Future<void> fetchSalesReturnItems({
    required String accessToken,
    required String orderId,
    int? page,
  }) async {
    debugPrint("orderId $orderId");
    final queryParameters = <String, String>{
      'order_number': orderId.toString(),
      if (page != null) 'page': page.toString(),
    };

    debugPrint(queryParameters.toString());

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }

    final uri = Uri.parse(APPUrl.listSalesReturnItems)
        .replace(queryParameters: queryParameters);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint(
          'fetch Sales Return list response status code: ${response.statusCode}');
      debugPrint('response.body ${response.body}');

      ApiResponseHelper.ensureSuccess(
        response.statusCode,
        response.body,
        fallback: 'Failed to load return items',
      );

      final jsonData = json.decode(response.body);
      final salesReturnResponse = SalesReturnItemsResponse.fromJson(jsonData);
      _salesReturnItems = salesReturnResponse.data;
      _currentReturnOrder = salesReturnResponse.order;
      notifyListeners();
    } catch (error) {
      debugPrint('Error in fetchSalesReturnItems: $error');
      rethrow;
    }
  }

  Future<void> submitSalesReturn({
    required String accessToken,
    required int orderId,
    required double price,
    required num quantity,
    required int cartItemId,
    required String reason,
    bool isDeliveryRefundable = false,
  }) async {
    final url =
        Uri.parse(APPUrl.salesReturn); // Update with your server base URL

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      },
      body: jsonEncode({
        'order_id': orderId,
        'price': price,
        'quantity': quantity,
        'cart_item_id': cartItemId,
        'reason': reason,
        'is_delivery_refundable': isDeliveryRefundable,
      }),
    );

    debugPrint("accessToken $accessToken");
    debugPrint("orderId $orderId");
    debugPrint("price $price");
    debugPrint("quantity $quantity");
    debugPrint("cartItemId $cartItemId");
    debugPrint("reason $reason");
    debugPrint("response.statusCode ${response.statusCode}");
    debugPrint("response.body ${response.body}");

    ApiResponseHelper.ensureSuccess(
      response.statusCode,
      response.body,
      fallback: 'Failed to submit sales return',
    );
    _storeRefundBreakdownFromBody(response.body);
    notifyListeners();
  }

  Future<void> completeSalesReturn({
    required String accessToken,
    required int returnOrderId,
    String? paymentMethod,
    double? paidAmount,
    bool? hasPayment,
    bool isDeliveryRefundable = false,
  }) async {
    final url = Uri.parse(
        APPUrl.completeSalesReturn); // Update with your server base URL

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    // Debug print the request body
    final requestBody = jsonEncode({
      'return_order_id': returnOrderId,
      'is_delivery_refundable': isDeliveryRefundable,
      if (hasPayment == true) ...{
        'payment_method': paymentMethod,
        'paid_amount': paidAmount,
        'has_payment': hasPayment,
      } else ...{
        'has_payment': false,
      }
    });
    debugPrint('=== COMPLETE SALES RETURN REQUEST BODY ===');
    debugPrint(requestBody);
    debugPrint('=== END REQUEST BODY ===');

    debugPrint("accessToken $accessToken");
    debugPrint("returnOrderId $returnOrderId");
    debugPrint("hasPayment $hasPayment");
    debugPrint("paymentMethod $paymentMethod");
    debugPrint("paidAmount $paidAmount");
    debugPrint("isDeliveryRefundable $isDeliveryRefundable");

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      },
      body: requestBody,
    );

    ApiResponseHelper.ensureSuccess(
      response.statusCode,
      response.body,
      fallback: 'Failed to complete sales return',
    );
    _storeRefundBreakdownFromBody(response.body);
    debugPrint('Sales return completed successfully: ${response.body}');
    notifyListeners();
  }

  Future<void> cancelOrder({
    required String accessToken,
    required String orderId,
    required String paymentMethod,
    required String refundAmount,
    required bool deliveryChargeRefundable,
  }) async {
    final url = Uri.parse(APPUrl.cancelOrderUrl);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    final requestBody = {
      'order_id': orderId,
      'refund_method': paymentMethod,
      'refund_amount': refundAmount,
      'delivery_charge_refundable': deliveryChargeRefundable,
    };

    debugPrint("🔴 CANCEL ORDER API REQUEST BODY: ${jsonEncode(requestBody)}");

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      },
      body: jsonEncode(requestBody),
    );

    debugPrint("accessToken $accessToken");
    debugPrint("orderId $orderId");
    debugPrint("paymentMethod $paymentMethod");
    debugPrint("refundAmount $refundAmount");
    debugPrint("deliveryChargeRefundable $deliveryChargeRefundable");
    debugPrint("response.statusCode ${response.statusCode}");
    debugPrint("response.body ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      notifyListeners();
    } else {
      throw Exception('Failed to cancel order');
    }
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
    final url = Uri.parse(APPUrl.orderChangeStatusUrl);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    final requestBody = {
      'order_id': orderId,
      'status': status,
      if (refundAmount != null) 'refund_amount': refundAmount,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (deliveryChargeRefundable != null)
        'delivery_charge_refundable': deliveryChargeRefundable,
      if (deliveryLogistics != null) 'delivery_logistics': deliveryLogistics,
    };

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      notifyListeners();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to change order status');
    }
  }

  Future<void> changePaymentStatus({
    required String accessToken,
    required String orderId,
    required String status,
    required double amount,
  }) async {
    final url = Uri.parse(APPUrl.orderChangePaymentStatusUrl);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    final requestBody = {
      'order_id': orderId,
      'status': status,
      'amount': amount,
    };

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      notifyListeners();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to change payment status');
    }
  }

  Future<void> fetchDailySalesClose({
    required String accessToken,
    String? startDate,
    String? endDate,
    int page = 1,
    int? userId,
    required int storeId,
  }) async {
    final queryParameters = <String, String>{
      'store_id[]': storeId.toString(),
      'page': page.toString(),
    };
    if (startDate != null) queryParameters['start_date'] = startDate;
    if (endDate != null) queryParameters['end_date'] = endDate;
    if (userId != null && userId != 0) {
      queryParameters['user_id[]'] = userId.toString();
    }

    final uri = Uri.parse(APPUrl.listDailySalesClose)
        .replace(queryParameters: queryParameters);

    // DEBUG: Print request details
    debugPrint('=== DEBUG: fetchDailySalesClose START ===');
    debugPrint('Full URL: $uri');
    debugPrint('Query Parameters: $queryParameters');
    debugPrint('User ID: $userId');
    debugPrint('Store ID: $storeId');
    debugPrint('Start Date: $startDate');
    debugPrint('End Date: $endDate');
    debugPrint('Page: $page');

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found.");
      }

      final headers = {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      };

      // DEBUG: Print headers (masking sensitive data)
      debugPrint('=== DEBUG: Request Headers ===');
      debugPrint(
          'Authorization: Bearer ${accessToken.length > 10 ? accessToken.substring(0, 10) + '...' : accessToken}');
      debugPrint('Content-Type: ${headers['Content-Type']}');
      debugPrint(
          'X-Tenant: ${apiKey.length > 8 ? apiKey.substring(0, 8) + '...' : apiKey}');

      final response = await http
          .get(
            uri,
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      // DEBUG: Print response details
      debugPrint('=== DEBUG: Response Details ===');
      debugPrint('Response Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final model = DailySalesCloseModel.fromJson(jsonData);
        dailySalesCloseList = model.data ?? [];
        dailySalesClosePagination = model.pagination;
        notifyListeners();
        debugPrint('=== DEBUG: fetchDailySalesClose SUCCESS ===');
      } else {
        dailySalesCloseList = [];
        notifyListeners();
        debugPrint(
            '=== DEBUG: fetchDailySalesClose FAILED (Non-200 Status) ===');
      }
    } catch (error, stackTrace) {
      debugPrint('=== DEBUG: fetchDailySalesClose ERROR ===');
      debugPrint('Error: $error');
      debugPrint('Stack Trace: $stackTrace');
      dailySalesCloseList = [];
      notifyListeners();
      rethrow;
    }
  }

  Future<DailySalesCloseData?> fetchDailySalesCloseDetail({
    required String accessToken,
    required int id,
  }) async {
    final uri = Uri.parse(APPUrl.viewDailySalesClose(id.toString()));

    debugPrint('=== DEBUG: fetchDailySalesCloseDetail START ===');
    debugPrint('Full URL: $uri');

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found.");
      }

      final headers = {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      };

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      debugPrint(
          '=== DEBUG: Detail Response Status Code: ${response.statusCode} ===');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['data'] != null) {
          final detailData = DailySalesCloseData.fromJson(jsonData['data']);
          return detailData;
        }
      }
      return null;
    } catch (error, stackTrace) {
      debugPrint('=== DEBUG: fetchDailySalesCloseDetail ERROR ===');
      debugPrint('Error: $error');
      debugPrint('Stack Trace: $stackTrace');
      rethrow;
    }
  }

  Future<DailySalesCloseSummary?> fetchDailySalesCloseSummary({
    required String accessToken,
    required int storeId,
    String? businessDate,
  }) async {
    final queryParameters = <String, String>{
      'store_id': storeId.toString(),
    };
    if (businessDate != null && businessDate.isNotEmpty) {
      queryParameters['business_date'] = businessDate;
    }

    final uri = Uri.parse(APPUrl.dailySalesCloseSummary)
        .replace(queryParameters: queryParameters);

    debugPrint('=== DEBUG: fetchDailySalesCloseSummary START ===');
    debugPrint('Full URL: $uri');

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found.");
      }

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('=== DEBUG: Response Status Code: ${response.statusCode} ===');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final model = DailySalesCloseSummaryResponse.fromJson(jsonData);
        return model.data;
      } else {
        throw HttpException('Failed to fetch summary: ${response.statusCode}');
      }
    } catch (error, stackTrace) {
      debugPrint('=== DEBUG: fetchDailySalesCloseSummary ERROR ===');
      debugPrint('Error: $error');
      debugPrint('Stack Trace: $stackTrace');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createDailySalesClose({
    required String accessToken,
    required int storeId,
    String? shiftName,
    String? businessDate,
    String? openingDate,
    String? openingTime,
    String? closingDate,
    String? closingTime,
    num? cashRefunds,
    num? cashExpenses,
    num? cashDropAmount,
    num? openingCashInHand,
    List<dynamic>? openingCashBreakdown,
    num? closingCashInHand,
    List<dynamic>? closingCashBreakdown,
    String? notes,
    int? openingTransactionId,
    int? closingTransactionId,
  }) async {
    final queryParameters = <String, String>{
      'store_id': storeId.toString(),
    };

    final uri = Uri.parse(APPUrl.dailySalesCloseCreate)
        .replace(queryParameters: queryParameters);

    debugPrint('=== DEBUG: createDailySalesClose START ===');
    debugPrint('Full URL: $uri');
    debugPrint('Query Parameters: $queryParameters');

    final Map<String, dynamic> requestBody = {
      'shift_name': shiftName,
      'business_date': businessDate,
      'opening_date': openingDate,
      'opening_time': openingTime,
      'closing_date': closingDate,
      'closing_time': closingTime,
      'cash_refunds': cashRefunds,
      'cash_expenses': cashExpenses,
      'cash_drop_amount': cashDropAmount,
      'opening_cash_in_hand': openingCashInHand,
      'opening_cash_breakdown': openingCashBreakdown,
      'closing_cash_in_hand': closingCashInHand,
      'closing_cash_breakdown': closingCashBreakdown,
      'notes': notes,
    };
    if (openingTransactionId != null) {
      requestBody['opening_transaction_id'] = openingTransactionId;
    }
    if (closingTransactionId != null) {
      requestBody['closing_transaction_id'] = closingTransactionId;
    }
    final requestBodyJson = jsonEncode(requestBody);
    debugPrint('Submitting daily sales close for store $storeId.');

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found.");
      }

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
        body: requestBodyJson,
      ).timeout(const Duration(seconds: 15));

      debugPrint('=== DEBUG: Response Status Code: ${response.statusCode} ===');

      final jsonData = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': jsonData['success'] ?? true,
          'message': jsonData['message'] ?? 'Day close created successfully',
        };
      } else {
        return {
          'success': false,
          'message': jsonData['message'] ?? 'Failed to create day close',
        };
      }
    } catch (error, stackTrace) {
      debugPrint('=== DEBUG: createDailySalesClose ERROR ===');
      debugPrint('Error: $error');
      debugPrint('Stack Trace: $stackTrace');
      return {
        'success': false,
        'message': error.toString(),
      };
    }
  }

  Future<bool> openShiftApi({
    required String accessToken,
    required int storeId,
    required String shiftName,
    required String businessDate,
    required String openingDate,
    required String openingTime,
    required double openingCashInHand,
    required List<Map<String, dynamic>> openingCashBreakdown,
    String notes = '',
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');
      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found.");
      }

      final url = Uri.parse(APPUrl.openShift);
      final body = jsonEncode({
        'store_id': storeId,
        'shift_name': shiftName,
        'business_date': businessDate,
        'opening_date': openingDate,
        'opening_time': openingTime,
        'opening_cash_in_hand': openingCashInHand,
        'opening_cash_breakdown': openingCashBreakdown,
        'notes': notes,
      });

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        debugPrint('openShiftApi failed with status ${response.statusCode}.');
        return false;
      }
    } catch (e) {
      debugPrint('openShiftApi exception: $e');
      return false;
    }
  }

  Future<DayClosePendingStatus?> fetchDayClosePendingStatus({
    required String accessToken,
    required int storeId,
    required int userId,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found.");
      }

      final uri = Uri.parse(
        '${APPUrl.dailySalesClosePendingStatus}'
        '?store_id=$storeId&user_id=$userId'
      );
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      );
      debugPrint(
        'Day close pending-status response: ${response.statusCode}.',
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        return DayClosePendingStatus.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching day close pending status: $e');
      return null;
    }
  }
}
