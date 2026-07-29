import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/models/get_product_sales_report_model.dart';
import 'package:pos_machine/models/get_sales_report_model.dart';
import 'package:pos_machine/models/get_supplier_sales_report_model.dart';
import 'package:pos_machine/models/get_non_stock_report_model.dart';
import 'package:pos_machine/models/get_consumed_stocks_report_model.dart';
import 'package:pos_machine/models/get_stock_report_model.dart';

import '../models/get_customer_account_book_model.dart';
import '../resources/app_url.dart';

class ReportsProvider with ChangeNotifier {
  GetCustomerAccountBookResponse? _customerAccountBook;
  GetProductSalesReportResponse? _productSalesReport;
  GetSalesReportResponse? _salesReport;
  GetSupplierSalesReportResponse? _supplierSalesReport;
  GetNonStockReportResponse? _nonStockReport;
  GetConsumedStocksReportResponse? _consumedStocksReport;
  GetStockReportResponse? _stockReport;

  GetCustomerAccountBookResponse? get customerAccountBook =>
      _customerAccountBook;
  GetProductSalesReportResponse? get productSalesReport => _productSalesReport;
  GetSalesReportResponse? get salesReport => _salesReport;
  GetSupplierSalesReportResponse? get supplierSalesReport =>
      _supplierSalesReport;
  GetNonStockReportResponse? get nonStockReport => _nonStockReport;
  GetConsumedStocksReportResponse? get consumedStocksReport =>
      _consumedStocksReport;
  GetStockReportResponse? get stockReport => _stockReport;

  Future<void> fetchCustomerAccountBook({
    required String accessToken,
    String? customerName,
    String? fromDate,
    String? toDate,
    String? amount,
  }) async {
    final queryParameters = <String, String>{};
    if (customerName != null && customerName.isNotEmpty) {
      queryParameters['customer_name'] = customerName;
    }
    if (fromDate != null && fromDate.isNotEmpty) {
      queryParameters['from_date'] = fromDate;
    }
    if (toDate != null && toDate.isNotEmpty) {
      queryParameters['to_date'] = toDate;
    }
    if (amount != null && amount.isNotEmpty) {
      queryParameters['amount'] = amount;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }

    final uri = Uri.parse(APPUrl.customerAccountBook)
        .replace(queryParameters: queryParameters);
    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        _customerAccountBook =
            GetCustomerAccountBookResponse.fromJson(jsonData);
        notifyListeners();
      } else {
        throw Exception('Failed to load customer account book');
      }
    } catch (error) {
      rethrow;
    }
  }

  Future<void> fetchProductSalesReport({
    required String accessToken,
    String? categoryId,
    String? productId,
    String? startDate,
    String? endDate,
    String? amount,
  }) async {
    final queryParameters = <String, String>{};

    if (categoryId != null) {
      queryParameters['category_id'] = categoryId.toString();
    }
    if (productId != null) {
      queryParameters['product_id'] = productId.toString();
    }
    if (startDate != null && startDate.isNotEmpty) {
      queryParameters['from_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      queryParameters['to_date'] = endDate;
    }
    if (amount != null && amount.isNotEmpty) {
      queryParameters['amount'] = amount;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }

    final uri = Uri.parse(APPUrl.productSalesReport)
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

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final jsonData = json.decode(response.body);
          _productSalesReport =
              GetProductSalesReportResponse.fromJson(jsonData);
          notifyListeners();
        } else {
          throw Exception('Received empty response');
        }
      } else {
        debugPrint(
            'Failed to load product sales report: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load product sales report');
      }
    } catch (error) {
      rethrow;
    }
  }

  Future<void> fetchSalesReport({
    required String accessToken,
    String? customerName,
    String? createdBy,
    String? startDate,
    String? endDate,
  }) async {
    final queryParameters = <String, String>{};

    if (customerName != null && customerName.isNotEmpty) {
      queryParameters['customer_name'] = customerName;
    }
    if (createdBy != null && createdBy.isNotEmpty) {
      queryParameters['created_by'] = createdBy;
    }
    if (startDate != null && startDate.isNotEmpty) {
      queryParameters['from_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      queryParameters['to_date'] = endDate;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }

    final uri =
        Uri.parse(APPUrl.salesReport).replace(queryParameters: queryParameters);
    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final jsonData = json.decode(response.body);
          _salesReport = GetSalesReportResponse.fromJson(jsonData);
          notifyListeners();
        } else {
          throw Exception('Received empty response');
        }
      } else {
        debugPrint(
            'Failed to load sales report: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load sales report');
      }
    } catch (error) {
      rethrow;
    }
  }

  Future<void> fetchSupplierSalesReport({
    required String accessToken,
    String? supplierName,
    String? startDate,
    String? endDate,
    String? amount,
  }) async {
    final queryParameters = <String, String>{};

    if (supplierName != null && supplierName.isNotEmpty) {
      queryParameters['supplier_name'] = supplierName;
    }
    if (startDate != null && startDate.isNotEmpty) {
      queryParameters['from_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      queryParameters['to_date'] = endDate;
    }
    if (amount != null && amount.isNotEmpty) {
      queryParameters['amount'] = amount;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }

    final uri = Uri.parse(APPUrl.supplierSalesReport)
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

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final jsonData = json.decode(response.body);
          _supplierSalesReport =
              GetSupplierSalesReportResponse.fromJson(jsonData);
          notifyListeners();
        } else {
          throw Exception('Received empty response');
        }
      } else {
        debugPrint(
            'Failed to load supplier sales report: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load supplier sales report');
      }
    } catch (error) {
      rethrow;
    }
  }

  Future<void> fetchNonStockReport({
    required String accessToken,
    String? store,
    String? category,
    String? product,
    String? barcode,
    int? page,
  }) async {
    final queryParameters = <String, String>{};

    if (store != null && store.isNotEmpty) {
      queryParameters['store'] = store;
    }
    if (category != null && category.isNotEmpty) {
      queryParameters['category'] = category;
    }
    if (product != null && product.isNotEmpty) {
      queryParameters['product'] = product;
    }
    if (barcode != null && barcode.isNotEmpty) {
      queryParameters['barcode'] = barcode;
    }
    if (page != null) {
      queryParameters['page'] = page.toString();
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }

    final uri = Uri.parse(APPUrl.nonStockReportUrl)
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

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final jsonData = json.decode(response.body);
          _nonStockReport = GetNonStockReportResponse.fromJson(jsonData);
          notifyListeners();
        } else {
          throw Exception('Received empty response');
        }
      } else {
        debugPrint(
            'Failed to load non-stock report: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load non-stock report');
      }
    } catch (error) {
      rethrow;
    }
  }

  Future<void> fetchConsumedStocksReport({
    required String accessToken,
    String? productId,
    String? storeId,
    String? from,
    String? until,
    int? page,
  }) async {
    final queryParameters = <String, String>{};

    if (productId != null && productId.isNotEmpty) {
      queryParameters['product_id'] = productId;
    }
    if (storeId != null && storeId.isNotEmpty) {
      queryParameters['store_id'] = storeId;
    }
    if (from != null && from.isNotEmpty) {
      queryParameters['from'] = from;
    }
    if (until != null && until.isNotEmpty) {
      queryParameters['until'] = until;
    }
    if (page != null) {
      queryParameters['page'] = page.toString();
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    // Only add activeStoreId if store_id is not already provided as parameter
    if (!queryParameters.containsKey('store_id') && activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }

    final uri = Uri.parse(APPUrl.consumedStocksReport)
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

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final jsonData = json.decode(response.body);
          _consumedStocksReport =
              GetConsumedStocksReportResponse.fromJson(jsonData);
          notifyListeners();
        } else {
          throw Exception('Received empty response');
        }
      } else {
        debugPrint(
            'Failed to load consumed stocks report: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load consumed stocks report');
      }
    } catch (error) {
      rethrow;
    }
  }

  Future<void> fetchStockReport({
    required String accessToken,
    String? product,
    String? sortBy,
    String? sortDirection,
    int? storeId,
    int? categoryId,
    String? stockLevel,
    String? expiringWithin,
    String? snapshotDate,
    String? from,
    String? until,
    int? page,
    int? perPage,
  }) async {
    final queryParameters = <String, String>{};

    if (product != null && product.isNotEmpty) {
      queryParameters['product'] = product;
    }
    if (sortBy != null && sortBy.isNotEmpty) {
      queryParameters['sort_by'] = sortBy;
    }
    if (sortDirection != null && sortDirection.isNotEmpty) {
      queryParameters['sort_direction'] = sortDirection;
    }
    if (storeId != null) {
      queryParameters['store_id'] = storeId.toString();
    }
    if (categoryId != null) {
      queryParameters['category_id'] = categoryId.toString();
    }
    if (stockLevel != null && stockLevel.isNotEmpty && stockLevel != 'All') {
      queryParameters['stock_level'] = stockLevel;
    }
    if (expiringWithin != null && expiringWithin.isNotEmpty && expiringWithin != 'All') {
      queryParameters['expiring_within'] = expiringWithin;
    }
    if (snapshotDate != null && snapshotDate.isNotEmpty) {
      queryParameters['snapshot_date'] = snapshotDate;
    }
    if (from != null && from.isNotEmpty) {
      queryParameters['from'] = from;
    }
    if (until != null && until.isNotEmpty) {
      queryParameters['until'] = until;
    }
    if (page != null) {
      queryParameters['page'] = page.toString();
    }
    if (perPage != null) {
      queryParameters['per_page'] = perPage.toString();
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    // Set fallback store_id from activeStoreId if not explicitly filtered
    if (storeId == null && activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }

    final uri = Uri.parse(APPUrl.stockReportUrl)
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

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final jsonData = json.decode(response.body);
          _stockReport = GetStockReportResponse.fromJson(jsonData);
          notifyListeners();
        } else {
          throw Exception('Received empty response');
        }
      } else {
        debugPrint(
            'Failed to load stock report: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load stock report');
      }
    } catch (error) {
      rethrow;
    }
  }
}
