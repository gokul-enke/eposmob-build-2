import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dashboard_widget_data.dart';
import '../resources/app_url.dart';

/// Additive read-only APIs. Existing DashboardProvider requests are untouched.
/// Only default parameters have been verified; these widgets intentionally do
/// not send the existing dashboard's period, store, year or limit parameters.
class DashboardWidgetsRepository {
  DashboardWidgetsRepository({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client;

  final http.Client? _client;
  final Duration timeout;

  Future<Map<String, dynamic>> _fetch(String token, String endpoint) async {
    if (token.trim().isEmpty) {
      throw const HttpException('Missing dashboard authentication');
    }
    final prefs = await SharedPreferences.getInstance()
        .timeout(const Duration(seconds: 3));
    final tenant = prefs.getString('api_key');
    if (tenant == null || tenant.trim().isEmpty) {
      throw const HttpException('Missing dashboard tenant');
    }
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'X-Tenant': tenant,
    };
    final uri = Uri.parse(endpoint);
    final response = await (_client?.get(uri, headers: headers) ??
            http.get(uri, headers: headers))
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw HttpException(
          'Dashboard widget request failed (${response.statusCode})');
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> ||
        body['status'] != 'success' ||
        body['data'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid dashboard widget response');
    }
    return body['data'] as Map<String, dynamic>;
  }

  Future<OrdersWidgetData> fetchOrdersWidget(String token) async =>
      OrdersWidgetData.fromJson(await _fetch(token, APPUrl.ordersWidget));

  Future<LatestOrdersData> fetchLatestOrders(String token) async =>
      LatestOrdersData.fromJson(await _fetch(token, APPUrl.latestOrders));

  Future<CustomerTransactionsSummaryData> fetchCustomerTransactionsSummary(
          String token) async =>
      CustomerTransactionsSummaryData.fromJson(
          await _fetch(token, APPUrl.customerTransactionsSummary));

  Future<SuppliersGraphData> fetchSuppliersGraph(String token) async =>
      SuppliersGraphData.fromJson(await _fetch(token, APPUrl.suppliersGraph));

  Future<RevenueStatsData> fetchRevenueStats(String token) async =>
      RevenueStatsData.fromJson(await _fetch(token, APPUrl.revenueStats));
}
