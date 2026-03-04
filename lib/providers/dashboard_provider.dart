import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../resources/app_url.dart';
import '../models/dashboard_api.dart';

class DashboardProvider {
  //                 *********************** DASHBOARD API ***************************************************

  Future<dynamic> dashbaord(String accessToken, BuildContext context) async {
    // debugPrint("dashbaord");
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
    final url = Uri.parse(APPUrl.dashBoardUrl).replace(queryParameters: queryParameters);
    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      });

      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(json.decode(response.body).toString());
        return json.decode(response.body);
      } else if (response.statusCode > 400) {
        throw const HttpException("Data Not Found.Try Again!");
      } else {
        throw const HttpException('Failed to load data ,Try Again Later!');
      }
    } catch (error) {
      rethrow;
    } finally {}
  }

  Future<List<GraphData>> fetchGraphData(String accessToken) async {
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    final Map<String, String> queryParameters = {};
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse(APPUrl.dashBoardGraphUrl).replace(queryParameters: queryParameters); // Replace with actual endpoint

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    debugPrint('Fetching graph data from: $url');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      );

      debugPrint('Graph data response status: ${response.statusCode}');
      // debugPrint('Graph data response body: ${response.body}');

      if (response.statusCode == 200) {
        // Check if response is JSON
        final contentType = response.headers['content-type'];
        if (contentType != null && contentType.contains('application/json')) {
          final Map<String, dynamic> responseData = json.decode(response.body);

          if (responseData['status'] == 'success') {
            final dynamic data = responseData['data'];
            if (data is List) {
              return data.map((item) => GraphData.fromJson(item)).toList();
            } else {
              throw const FormatException('Expected data to be a list');
            }
          } else {
            throw HttpException(
                responseData['message'] ?? 'Failed to load graph data');
          }
        } else {
          // HTML response or other non-JSON content
          debugPrint('Graph data endpoint returned non-JSON content');
          return [];
        }
      } else if (response.statusCode == 404) {
        // Handle 404 by returning empty list instead of throwing error
        debugPrint('Graph data endpoint not found (404), returning empty list');
        return [];
      } else {
        throw HttpException(
            'Failed to load graph data. Status code: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Error fetching graph data: $error');
      // Return empty list instead of rethrowing to prevent app crash
      return [];
    }
  }

  // New API methods for dashboard data
  Future<DashboardOverview> fetchDashboardOverview(
      String accessToken, String startDate, String endDate) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    final Map<String, String> queryParameters = {
      'start_date': startDate,
      'end_date': endDate,
    };
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse(APPUrl.companyOverview).replace(queryParameters: queryParameters);

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    debugPrint('Fetching dashboard overview from: $url');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      },
    );

    debugPrint('Dashboard overview response status: ${response.statusCode}');
    debugPrint('Dashboard overview response body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);

      // Check if response has the expected structure
      if (responseData['status'] == 'success' && responseData['data'] != null) {
        final data = responseData['data'];
        debugPrint('Dashboard overview data: $data');
        return DashboardOverview.fromJson(data as Map<String, dynamic>);
      } else {
        throw HttpException(
            'Invalid response format: ${responseData['message'] ?? 'Unknown error'}');
      }
    } else {
      throw HttpException(
          'Failed to load dashboard overview. Status code: ${response.statusCode}');
    }
  }

  Future<OrdersPerMonth> fetchOrdersPerMonth(
      String accessToken, int year) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    final Map<String, String> queryParameters = {'year': year.toString()};
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse(APPUrl.ordersGraph).replace(queryParameters: queryParameters);

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    debugPrint('Fetching orders per month from: $url');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Orders per month response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          return OrdersPerMonth.fromJson(
              responseData['data'] as Map<String, dynamic>);
        } else {
          debugPrint('Invalid Orders per month format: ${response.body}');
          throw HttpException(
              'Invalid format: ${responseData['message'] ?? 'Unknown error'}');
        }
      } else {
        debugPrint(
            'Orders per month Error ${response.statusCode}: ${response.body}');
        throw HttpException(
            'Load failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Exception in fetchOrdersPerMonth: $e');
      rethrow;
    }
  }

  Future<CustomersPerMonth> fetchCustomersPerMonth(
      String accessToken, int year) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    final Map<String, String> queryParameters = {'year': year.toString()};
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse(APPUrl.customersGraph).replace(queryParameters: queryParameters);

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    debugPrint('Fetching customers per month from: $url');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Customers per month response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          return CustomersPerMonth.fromJson(
              responseData['data'] as Map<String, dynamic>);
        } else {
          debugPrint('Invalid Customers per month format: ${response.body}');
          throw HttpException(
              'Invalid format: ${responseData['message'] ?? 'Unknown error'}');
        }
      } else {
        debugPrint(
            'Customers per month Error ${response.statusCode}: ${response.body}');
        throw HttpException(
            'Load failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Exception in fetchCustomersPerMonth: $e');
      rethrow;
    }
  }

  Future<ExecutivesOverview> fetchExecutivesOverview(
      String accessToken, String startDate, String endDate) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    final Map<String, String> queryParameters = {
      'start_date': startDate,
      'end_date': endDate,
    };
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse(APPUrl.executivesOverview).replace(queryParameters: queryParameters);

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    debugPrint('Fetching executives overview from: $url');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Executives overview response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          return ExecutivesOverview.fromJson(
              responseData['data'] as Map<String, dynamic>);
        } else {
          debugPrint('Invalid Executives Overview format: ${response.body}');
          throw HttpException(
              'Invalid format: ${responseData['message'] ?? 'Unknown error'}');
        }
      } else {
        debugPrint(
            'Executives Overview Error ${response.statusCode}: ${response.body}');
        throw HttpException(
            'Load failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Exception in fetchExecutivesOverview: $e');
      rethrow;
    }
  }

  Future<SalesGraph> fetchExecutiveSalesGraph(String accessToken, String period,
      String startDate, String endDate) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    final Map<String, String> queryParameters = {'period': period};
    if (period != 'today' && period != 'week') {
      queryParameters['start_date'] = startDate;
      queryParameters['end_date'] = endDate;
    }
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse(APPUrl.salesGraph).replace(queryParameters: queryParameters);

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    debugPrint('Fetching executive sales graph from: $url');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint(
          'Executive sales graph response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          return SalesGraph.fromJson(
              responseData['data'] as Map<String, dynamic>);
        } else {
          debugPrint('Invalid Executive sales graph format: ${response.body}');
          throw HttpException(
              'Invalid format: ${responseData['message'] ?? 'Unknown error'}');
        }
      } else {
        debugPrint(
            'Executive sales graph Error ${response.statusCode}: ${response.body}');
        throw HttpException(
            'Load failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Exception in fetchExecutiveSalesGraph: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> listCartItnes(BuildContext context) async {
    // debugPrint("dashbaord");

    final baseUri = Uri.parse(
        "https://safai.enke.ae/api/carts/list-cart-items?customer_id=5");
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    final Map<String, String> queryParams =
        Map<String, String>.from(baseUri.queryParameters);
    final int? activeStoreId = prefs.getInt('active_store_id');
    if (activeStoreId != null) {
      queryParams['store_id'] = activeStoreId.toString();
    }
    final url = baseUri.replace(queryParameters: queryParams);
    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer 8|bTQHp0upEnGCgNEwbYo0bdhLLEg3CKBSvU6QPJe5',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      });

      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(json.decode(response.body).toString());
        return json.decode(response.body);
      } else if (response.statusCode > 400) {
        throw const HttpException("Data Not Found.Try Again!");
      } else {
        throw const HttpException('Failed to load data ,Try Again Later!');
      }
    } catch (error) {
      rethrow;
    } finally {}
  }

  // Supplier Dashboard API Methods

  Future<SuppliersOverview> fetchSuppliersOverview(String accessToken,
      String period, String startDate, String endDate) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    final Map<String, String> queryParameters = {
      'period': period,
      'start_date': startDate,
      'end_date': endDate,
    };
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse(APPUrl.suppliersOverview).replace(queryParameters: queryParameters);

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    debugPrint('Fetching suppliers overview from: $url');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Suppliers overview response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          return SuppliersOverview.fromJson(
              responseData['data'] as Map<String, dynamic>);
        } else {
          debugPrint('Invalid Suppliers Overview format: ${response.body}');
          throw HttpException(
              'Invalid format: ${responseData['message'] ?? 'Unknown error'}');
        }
      } else {
        debugPrint(
            'Suppliers Overview Error ${response.statusCode}: ${response.body}');
        throw HttpException(
            'Load failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Exception in fetchSuppliersOverview: $e');
      rethrow;
    }
  }

  Future<SuppliersPurchaseGraph> fetchSuppliersPurchaseGraph(String accessToken,
      String period, String startDate, String endDate) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    final Map<String, String> queryParameters = {
      'period': period,
      'start_date': startDate,
      'end_date': endDate,
    };
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse(APPUrl.suppliersPurchaseGraph).replace(queryParameters: queryParameters);

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    debugPrint('Fetching suppliers purchase graph from: $url');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint(
          'Suppliers purchase graph response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          return SuppliersPurchaseGraph.fromJson(
              responseData['data'] as Map<String, dynamic>);
        } else {
          debugPrint(
              'Invalid Suppliers Purchase Graph format: ${response.body}');
          throw HttpException(
              'Invalid format: ${responseData['message'] ?? 'Unknown error'}');
        }
      } else {
        debugPrint(
            'Suppliers Purchase Graph Error ${response.statusCode}: ${response.body}');
        throw HttpException(
            'Load failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Exception in fetchSuppliersPurchaseGraph: $e');
      rethrow;
    }
  }

  Future<SupplierTransactionsGraph> fetchSupplierTransactionsGraph(
      String accessToken,
      String period,
      String startDate,
      String endDate) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    final Map<String, String> queryParameters = {
      'period': period,
      'start_date': startDate,
      'end_date': endDate,
    };
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse(APPUrl.supplierTransactionsGraph).replace(queryParameters: queryParameters);

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    debugPrint('Fetching supplier transactions graph from: $url');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint(
          'Supplier transactions graph response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          return SupplierTransactionsGraph.fromJson(
              responseData['data'] as Map<String, dynamic>);
        } else {
          debugPrint(
              'Invalid Supplier Transactions Graph format: ${response.body}');
          throw HttpException(
              'Invalid format: ${responseData['message'] ?? 'Unknown error'}');
        }
      } else {
        debugPrint(
            'Supplier Transactions Graph Error ${response.statusCode}: ${response.body}');
        throw HttpException(
            'Load failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Exception in fetchSupplierTransactionsGraph: $e');
      rethrow;
    }
  }

  Future<SupplierCreditBalanceGraph> fetchSupplierCreditBalance(
      String accessToken, String startDate, String endDate) async {
    final baseUri = Uri.parse(
        '${APPUrl.supplierCreditBalance}?start_date=$startDate&end_date=$endDate');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    // Preserve existing params and add store_id when available
    final queryParams = Map<String, String>.from(baseUri.queryParameters);
    if (activeStoreId != null) {
      queryParams['store_id'] = activeStoreId.toString();
    }
    final url = baseUri.replace(queryParameters: queryParams);

    debugPrint('Fetching supplier credit balance from: $url');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint(
          'Supplier credit balance response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          return SupplierCreditBalanceGraph.fromJson(
              responseData['data'] as Map<String, dynamic>);
        } else {
          debugPrint(
              'Invalid Supplier Credit Balance format: ${response.body}');
          throw HttpException(
              'Invalid format: ${responseData['message'] ?? 'Unknown error'}');
        }
      } else {
        debugPrint(
            'Supplier Credit Balance Error ${response.statusCode}: ${response.body}');
        throw HttpException(
            'Load failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Exception in fetchSupplierCreditBalance: $e');
      rethrow;
    }
  }

  Future<SalesStats> fetchSalesStats(String accessToken) async {
    final url = Uri.parse(APPUrl.salesStatsUrl);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    debugPrint('Fetching sales stats from: $url');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Sales stats response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          return SalesStats.fromJson(responseData);
        } else {
          debugPrint('Invalid Sales Stats format: ${response.body}');
          throw HttpException(
              'Invalid format: ${responseData['status'] ?? 'Unknown error'}');
        }
      } else {
        debugPrint(
            'Sales Stats Error ${response.statusCode}: ${response.body}');
        throw HttpException(
            'Load failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Exception in fetchSalesStats: $e');
      rethrow;
    }
  }

  Future<CustomerStats> fetchCustomerStats(String accessToken, String period,
      String startDate, String endDate) async {
    final url = Uri.parse(
        '${APPUrl.customerStats}?period=$period&start_date=$startDate&end_date=$endDate');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    debugPrint('Fetching customer stats from: $url');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Customer stats response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          return CustomerStats.fromJson(responseData);
        } else {
          debugPrint('Invalid Customer Stats format: ${response.body}');
          throw HttpException(
              'Invalid format: ${responseData['message'] ?? 'Unknown error'}');
        }
      } else {
        debugPrint(
            'Customer Stats Error ${response.statusCode}: ${response.body}');
        throw HttpException(
            'Load failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Exception in fetchCustomerStats: $e');
      rethrow;
    }
  }

  Future<ProductStats> fetchProductStats(String accessToken) async {
    final url = Uri.parse(APPUrl.productsStats);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    debugPrint('Fetching product stats from: $url');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Product stats response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          return ProductStats.fromJson(responseData);
        } else {
          debugPrint('Invalid Product Stats format: ${response.body}');
          throw HttpException(
              'Invalid format: ${responseData['message'] ?? 'Unknown error'}');
        }
      } else {
        debugPrint(
            'Product Stats Error ${response.statusCode}: ${response.body}');
        throw HttpException(
            'Load failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Exception in fetchProductStats: $e');
      rethrow;
    }
  }
}

class GraphData {
  final DateTime date;
  final int count;

  GraphData({required this.date, required this.count});

  factory GraphData.fromJson(Map<String, dynamic> json) {
    return GraphData(
      date: DateTime.parse(json['date']),
      count: json['count'],
    );
  }
}
