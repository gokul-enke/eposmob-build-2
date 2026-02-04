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

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    final url = Uri.parse(APPUrl.dashBoardUrl);
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
    final url =
        Uri.parse(APPUrl.dashBoardGraphUrl); // Replace with actual endpoint
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

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
    final url = Uri.parse(
        '${APPUrl.companyOverview}?start_date=$startDate&end_date=$endDate');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

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
    final url = Uri.parse('${APPUrl.ordersGraph}?year=$year');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    debugPrint('Fetching orders per month from: $url');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      },
    );

    debugPrint('Orders per month response status: ${response.statusCode}');
    debugPrint('Orders per month response body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);

      // Check if response has the expected structure
      if (responseData['status'] == 'success' && responseData['data'] != null) {
        final data = responseData['data'];
        debugPrint('Orders per month data: $data');
        return OrdersPerMonth.fromJson(data as Map<String, dynamic>);
      } else {
        throw HttpException(
            'Invalid response format: ${responseData['message'] ?? 'Unknown error'}');
      }
    } else {
      throw HttpException(
          'Failed to load orders per month. Status code: ${response.statusCode}');
    }
  }

  Future<CustomersPerMonth> fetchCustomersPerMonth(
      String accessToken, int year) async {
    final url = Uri.parse('${APPUrl.customersGraph}?year=$year');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    debugPrint('Fetching customers per month from: $url');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      },
    );

    debugPrint('Customers per month response status: ${response.statusCode}');
    debugPrint('Customers per month response body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);

      // Check if response has the expected structure
      if (responseData['status'] == 'success' && responseData['data'] != null) {
        final data = responseData['data'];
        debugPrint('Customers per month data: $data');
        return CustomersPerMonth.fromJson(data as Map<String, dynamic>);
      } else {
        throw HttpException(
            'Invalid response format: ${responseData['message'] ?? 'Unknown error'}');
      }
    } else {
      throw HttpException(
          'Failed to load customers per month. Status code: ${response.statusCode}');
    }
  }

  Future<ExecutivesOverview> fetchExecutivesOverview(
      String accessToken, String startDate, String endDate) async {
    final url = Uri.parse(
        '${APPUrl.executivesOverview}?start_date=$startDate&end_date=$endDate');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    debugPrint('Fetching executives overview from: $url');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      },
    );

    debugPrint('Executives overview response status: ${response.statusCode}');
    debugPrint('Executives overview response body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);

      // Check if response has the expected structure
      if (responseData['status'] == 'success' && responseData['data'] != null) {
        final data = responseData['data'];
        debugPrint('Executives overview data: $data');
        return ExecutivesOverview.fromJson(data as Map<String, dynamic>);
      } else {
        throw HttpException(
            'Invalid response format: ${responseData['message'] ?? 'Unknown error'}');
      }
    } else {
      throw HttpException(
          'Failed to load executives overview. Status code: ${response.statusCode}');
    }
  }

  Future<SalesGraph> fetchExecutiveSalesGraph(String accessToken, String period,
      String startDate, String endDate) async {
    String urlStr;
    if (period == 'today' || period == 'week') {
      urlStr = '${APPUrl.salesGraph}?period=$period';
    } else {
      urlStr =
          '${APPUrl.salesGraph}?period=$period&start_date=$startDate&end_date=$endDate';
    }

    final url = Uri.parse(urlStr);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    debugPrint('Fetching executive sales graph from: $url');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      },
    );

    debugPrint('Executive sales graph response status: ${response.statusCode}');
    debugPrint('Executive sales graph response body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);

      // Check if response has the expected structure
      if (responseData['status'] == 'success' && responseData['data'] != null) {
        final data = responseData['data'];
        debugPrint('Executive sales graph data: $data');
        return SalesGraph.fromJson(data as Map<String, dynamic>);
      } else {
        throw HttpException(
            'Invalid response format: ${responseData['message'] ?? 'Unknown error'}');
      }
    } else {
      throw HttpException(
          'Failed to load executive sales graph. Status code: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> listCartItnes(BuildContext context) async {
    // debugPrint("dashbaord");

    final url = Uri.parse(
        "https://safai.enke.ae/api/carts/list-cart-items?customer_id=5");
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
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

  Future<SuppliersOverview> fetchSuppliersOverview(
      String accessToken, String startDate, String endDate) async {
    final url = Uri.parse(
        '${APPUrl.suppliersOverview}?start_date=$startDate&end_date=$endDate');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    debugPrint('Fetching suppliers overview from: $url');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      },
    );

    debugPrint('Suppliers overview response status: ${response.statusCode}');
    debugPrint('Suppliers overview response body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);

      // Check if response has the expected structure
      if (responseData['status'] == 'success' && responseData['data'] != null) {
        final data = responseData['data'];
        debugPrint('Suppliers overview data: $data');
        return SuppliersOverview.fromJson(data as Map<String, dynamic>);
      } else {
        throw HttpException(
            'Invalid response format: ${responseData['message'] ?? 'Unknown error'}');
      }
    } else {
      throw HttpException(
          'Failed to load suppliers overview. Status code: ${response.statusCode}');
    }
  }

  Future<SuppliersPurchaseGraph> fetchSuppliersPurchaseGraph(
      String accessToken, String startDate, String endDate) async {
    final url = Uri.parse(
        '${APPUrl.suppliersPurchaseGraph}?start_date=$startDate&end_date=$endDate');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    debugPrint('Fetching suppliers purchase graph from: $url');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      },
    );

    debugPrint(
        'Suppliers purchase graph response status: ${response.statusCode}');
    debugPrint('Suppliers purchase graph response body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);

      // Check if response has the expected structure
      if (responseData['status'] == 'success' && responseData['data'] != null) {
        final data = responseData['data'];
        debugPrint('Suppliers purchase graph data: $data');
        return SuppliersPurchaseGraph.fromJson(data as Map<String, dynamic>);
      } else {
        throw HttpException(
            'Invalid response format: ${responseData['message'] ?? 'Unknown error'}');
      }
    } else {
      throw HttpException(
          'Failed to load suppliers purchase graph. Status code: ${response.statusCode}');
    }
  }

  Future<SupplierTransactionsGraph> fetchSupplierTransactionsGraph(
      String accessToken, String startDate, String endDate) async {
    final url = Uri.parse(
        '${APPUrl.supplierTransactionsGraph}?start_date=$startDate&end_date=$endDate');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    debugPrint('Fetching supplier transactions graph from: $url');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      },
    );

    debugPrint(
        'Supplier transactions graph response status: ${response.statusCode}');
    debugPrint('Supplier transactions graph response body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);

      // Check if response has the expected structure
      if (responseData['status'] == 'success' && responseData['data'] != null) {
        final data = responseData['data'];
        debugPrint('Supplier transactions graph data: $data');
        return SupplierTransactionsGraph.fromJson(data as Map<String, dynamic>);
      } else {
        throw HttpException(
            'Invalid response format: ${responseData['message'] ?? 'Unknown error'}');
      }
    } else {
      throw HttpException(
          'Failed to load supplier transactions graph. Status code: ${response.statusCode}');
    }
  }

  Future<SupplierCreditBalanceGraph> fetchSupplierCreditBalance(
      String accessToken, String startDate, String endDate) async {
    final url = Uri.parse(
        '${APPUrl.supplierCreditBalance}?start_date=$startDate&end_date=$endDate');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    debugPrint('Fetching supplier credit balance from: $url');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      },
    );

    debugPrint(
        'Supplier credit balance response status: ${response.statusCode}');
    debugPrint('Supplier credit balance response body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);

      // Check if response has the expected structure
      if (responseData['status'] == 'success' && responseData['data'] != null) {
        final data = responseData['data'];
        debugPrint('Supplier credit balance data: $data');
        return SupplierCreditBalanceGraph.fromJson(
            data as Map<String, dynamic>);
      } else {
        throw HttpException(
            'Invalid response format: ${responseData['message'] ?? 'Unknown error'}');
      }
    } else {
      throw HttpException(
          'Failed to load supplier credit balance. Status code: ${response.statusCode}');
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
