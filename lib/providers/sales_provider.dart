import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/list_sales_return.dart';
import 'package:pos_machine/models/list_sales_return_items.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/list_sales_order.dart';
import '../resources/app_url.dart';

class SalesProvider with ChangeNotifier {
  List<ListOrderModelData> _orders = [];
  List<SalesReturnOrder> _salesReturnOrders = [];
  List<SalesReturnCart> _salesReturnItems = [];
  int currentPage = 1;
  int totalPages = 1;
  int salesReturnCurrentPage = 1;
  int salesReturnTotalPages = 1;
  List<ListOrderModelData> get orders => _orders;
  List<SalesReturnOrder> get salesReturnOrders => _salesReturnOrders;
  List<SalesReturnCart> get salesReturnItems => _salesReturnItems;

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

    final uri = Uri.parse(APPUrl.getListOrder).replace(queryParameters: queryParameters);

    // DEBUG: Print request details
    debugPrint('=== SALES API REQUEST DEBUG ===');
    debugPrint('Base URL: ${APPUrl.getListOrder}');
    debugPrint('Query Parameters: $queryParameters');
    debugPrint('Final URL with Query: $uri');
    debugPrint('Access Token: ${accessToken.isNotEmpty ? "Present" : "Missing"}');

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
          debugPrint('JSON Keys: ${jsonData is Map ? jsonData.keys.toList() : "Not a Map"}');
          
          if (jsonData is Map) {
            debugPrint('Status: ${jsonData["status"]}');
            debugPrint('Message: ${jsonData["message"]}');
            debugPrint('Data Type: ${jsonData["data"]?.runtimeType}');
            
            if (jsonData["data"] != null) {
              debugPrint('Data Keys: ${jsonData["data"] is Map ? jsonData["data"].keys.toList() : "Data is not a Map"}');
              
              if (jsonData["data"] is Map && jsonData["data"]["data"] != null) {
                debugPrint('Orders Array Type: ${jsonData["data"]["data"].runtimeType}');
                debugPrint('Orders Array Length: ${jsonData["data"]["data"] is List ? jsonData["data"]["data"].length : "Not a List"}');
                
                if (jsonData["data"]["data"] is List && jsonData["data"]["data"].isNotEmpty) {
                  debugPrint('=== FIRST ORDER SAMPLE ===');
                  var firstOrder = jsonData["data"]["data"][0];
                  debugPrint('First Order Type: ${firstOrder.runtimeType}');
                  debugPrint('First Order Keys: ${firstOrder is Map ? firstOrder.keys.toList() : "Not a Map"}');
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
            debugPrint('Model Data Length: ${listSalesOrderModel.data?.length ?? 0}');
            debugPrint('Model Pagination: ${listSalesOrderModel.pagination != null ? "Present" : "Null"}');
            
            if (listSalesOrderModel.pagination != null) {
              int newCurrentPage = listSalesOrderModel.pagination?.currentPage ?? 1;
              int newTotalPages = listSalesOrderModel.pagination?.totalPages ?? 1;
              
              debugPrint('=== PAGINATION UPDATE ===');
              debugPrint('Previous Current Page: $currentPage');
              debugPrint('Previous Total Pages: $totalPages');
              debugPrint('New Current Page: $newCurrentPage');
              debugPrint('New Total Pages: $newTotalPages');
              debugPrint('Total Orders in Response: ${_orders.length}');
              debugPrint('From: ${listSalesOrderModel.pagination?.from}');
              debugPrint('To: ${listSalesOrderModel.pagination?.to}');
              debugPrint('Next Page URL: ${listSalesOrderModel.pagination?.nextPageUrl}');
              debugPrint('Prev Page URL: ${listSalesOrderModel.pagination?.prevPageUrl}');
              
              currentPage = newCurrentPage;
              totalPages = newTotalPages;
              
              debugPrint('Updated Current Page: $currentPage');
              debugPrint('Updated Total Pages: $totalPages');
            } else {
              debugPrint('=== NO PAGINATION DATA ===');
              debugPrint('Setting default pagination values');
              currentPage = 1;
              totalPages = 1;
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
                debugPrint('  Cart Items Count: ${order.cartItems?.length ?? 0}');
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

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'content-type': 'application/json',
        'X-Tenant': apiKey,
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
    int? page,
  }) async {
    final queryParameters = <String, String>{};
    if (page != null) queryParameters['page'] = page.toString();

    final uri = Uri.parse(APPUrl.listSalesReturn)
        .replace(queryParameters: queryParameters);

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

      debugPrint(
          'fetch Sales Return list response status code: ${response.statusCode}');
      debugPrint('response.body ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        try {
          debugPrint('=== SALES RETURN JSON PARSING DEBUG ===');
          debugPrint('About to parse SalesReturnResponse.fromJson...');
          debugPrint('JSON Data Keys: ${jsonData.keys}');
          debugPrint('Data section: ${jsonData['data']}');
          final salesReturnResponse = SalesReturnResponse.fromJson(jsonData);
          debugPrint(
              'fetch Sales Return list response data: ${salesReturnResponse.data.data}');
          _salesReturnOrders = salesReturnResponse.data.data; // Store fetched data from nested structure
          
          // Update pagination for sales return
          salesReturnCurrentPage = salesReturnResponse.data.currentPage;
          salesReturnTotalPages = salesReturnResponse.data.lastPage;
          debugPrint('Sales Return Pagination - Current: $salesReturnCurrentPage, Total: $salesReturnTotalPages');
          
          notifyListeners(); // Notify listeners to update UI
        } catch (e, stackTrace) {
          debugPrint('=== JSON PARSING ERROR ===');
          debugPrint('Error parsing JSON data: $e');
          debugPrint('Stack Trace: $stackTrace');
          debugPrint('JSON that failed to parse: ${jsonData.toString()}');
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

    final uri = Uri.parse(APPUrl.listSalesReturnItems)
        .replace(queryParameters: queryParameters);

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

      debugPrint(
          'fetch Sales Return list response status code: ${response.statusCode}');
      debugPrint('response.body ${response.body}');

      final jsonData = json.decode(response.body);
      try {
        debugPrint('=== SALES RETURN ITEMS JSON PARSING DEBUG ===');
        debugPrint('About to parse SalesReturnItemsResponse.fromJson...');
        debugPrint('JSON Data Keys: ${jsonData.keys}');
        debugPrint('Data section: ${jsonData['data']}');
        final salesReturnResponse = SalesReturnItemsResponse.fromJson(jsonData);
        _salesReturnItems = salesReturnResponse.data;
        notifyListeners();
      } catch (e, stackTrace) {
        debugPrint('=== SALES RETURN ITEMS JSON PARSING ERROR ===');
        debugPrint('Error parsing JSON data: $e');
        debugPrint('Stack Trace: $stackTrace');
        debugPrint('JSON that failed to parse: ${jsonData.toString()}');
      }
    } catch (error) {
      debugPrint('Error in fetchOrders: $error');
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
    String? paymentMethod,
    double? paidAmount,
    bool? hasPayment,
  }) async {
    final url = Uri.parse(
        APPUrl.completeSalesReturn); // Update with your server base URL

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
        'return_order_id': returnOrderId,
        if (hasPayment == true) ...{
          'payment_method': paymentMethod,
          'paid_amount': paidAmount,
          'has_payment': hasPayment,
        } else ...{
          'has_payment': false,
        }
      }),
    );

    debugPrint("accessToken $accessToken");
    debugPrint("returnOrderId $returnOrderId");
    debugPrint("hasPayment $hasPayment");
    debugPrint("paymentMethod $paymentMethod");
    debugPrint("paidAmount $paidAmount");

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
