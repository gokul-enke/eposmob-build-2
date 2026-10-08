import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/features/reports/domain/models/product_sales_report.dart';
import 'package:pos_machine/models/get_sales_report_model.dart';
import 'package:pos_machine/models/get_supplier_sales_report_model.dart';
import 'package:pos_machine/features/reports/domain/models/non_stock_report.dart';
import 'package:pos_machine/features/reports/data/non_stock_report_api.dart';
import 'package:pos_machine/features/reports/domain/non_stock_report_query.dart';
import 'package:pos_machine/features/reports/domain/models/consumed_stocks_report.dart';
import 'package:pos_machine/features/reports/domain/consumed_stocks_report_query.dart';
import 'package:pos_machine/features/reports/data/consumed_stocks_report_api.dart';
import 'package:pos_machine/features/reports/domain/models/stock_report.dart';

import 'package:pos_machine/features/reports/data/product_sales_api.dart';
import '../features/reports/data/stock_report_api.dart';
import '../models/get_customer_account_book_model.dart';
import '../resources/app_url.dart';

class ReportsProvider with ChangeNotifier {
  ReportsProvider(
      {ProductSalesApi? productSalesApi,
      StockReportApi? stockReportApi,
      ConsumedStocksReportApi? consumedStocksApi,
      NonStockReportApi? nonStockApi})
      : productSalesApi = productSalesApi ?? ProductSalesApi(),
        stockReportApi = stockReportApi ?? StockReportApi(),
        _consumedStocksApi = consumedStocksApi ?? ConsumedStocksReportApi(),
        _nonStockApi = nonStockApi ?? NonStockReportApi();
  final ProductSalesApi productSalesApi;
  final StockReportApi stockReportApi;
  final ConsumedStocksReportApi _consumedStocksApi;
  final NonStockReportApi _nonStockApi;
  Future<NonStockReportScope> nonStockReportScope(String token) =>
      _nonStockApi.scope(token);

  Future<GetNonStockReportResponse> fetchNonStockReportSnapshot(
          {required String accessToken,
          String? store,
          String? category,
          String? product,
          String? barcode,
          int? page}) =>
      _nonStockApi.fetch(
          accessToken: accessToken,
          store: store,
          category: category,
          product: product,
          barcode: barcode,
          page: page);

  Future<ConsumedStocksReportScope> consumedStocksReportScope(String token) =>
      _consumedStocksApi.scope(token);
  Future<GetConsumedStocksReportResponse> fetchConsumedStocksReportSnapshot(
          {required String accessToken,
          String? productId,
          String? storeId,
          String? from,
          String? until,
          int? page}) =>
      _consumedStocksApi.fetch(
          accessToken: accessToken,
          productId: productId,
          storeId: storeId,
          from: from,
          until: until,
          page: page);

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

  static Uri buildProductSalesReportUri({
    required String endpoint,
    String? categoryId,
    String? productId,
    String? customerId,
    String? startDate,
    String? endDate,
    int page = 1,
    int perPage = 25,
  }) {
    return ProductSalesApi.uri(
        endpoint: endpoint,
        categoryId: categoryId,
        productId: productId,
        customerId: customerId,
        startDate: startDate,
        endDate: endDate,
        page: page,
        perPage: perPage);
  }

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

  Future<GetProductSalesReportResponse> fetchProductSalesReport({
    required String accessToken,
    String? categoryId,
    String? productId,
    String? customerId,
    String? startDate,
    String? endDate,
    int page = 1,
    int perPage = 25,
    bool updateState = true,
  }) async {
    final report = await productSalesApi.fetch(
        accessToken: accessToken,
        categoryId: categoryId,
        productId: productId,
        customerId: customerId,
        startDate: startDate,
        endDate: endDate,
        page: page,
        perPage: perPage);
    if (updateState) {
      _productSalesReport = report;
      notifyListeners();
    }
    return report;
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
    _nonStockReport = await fetchNonStockReportSnapshot(
        accessToken: accessToken,
        store: store,
        category: category,
        product: product,
        barcode: barcode,
        page: page);
    notifyListeners();
  }

  Future<void> fetchConsumedStocksReport(
      {required String accessToken,
      String? productId,
      String? storeId,
      String? from,
      String? until,
      int? page}) async {
    _consumedStocksReport = await fetchConsumedStocksReportSnapshot(
        accessToken: accessToken,
        productId: productId,
        storeId: storeId,
        from: from,
        until: until,
        page: page);
    notifyListeners();
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
    _stockReport = await fetchStockReportSnapshot(
        accessToken: accessToken,
        product: product,
        sortBy: sortBy,
        sortDirection: sortDirection,
        storeId: storeId,
        categoryId: categoryId,
        stockLevel: stockLevel,
        expiringWithin: expiringWithin,
        snapshotDate: snapshotDate,
        from: from,
        until: until,
        page: page,
        perPage: perPage);
    notifyListeners();
  }

  /// A request-local page for listing/export; leaves shared rows untouched.
  Future<GetStockReportResponse> fetchStockReportSnapshot({
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
  }) =>
      stockReportApi.fetch(
          accessToken: accessToken,
          product: product,
          sortBy: sortBy,
          sortDirection: sortDirection,
          storeId: storeId,
          categoryId: categoryId,
          stockLevel: stockLevel,
          expiringWithin: expiringWithin,
          snapshotDate: snapshotDate,
          from: from,
          until: until,
          page: page,
          perPage: perPage);
}
