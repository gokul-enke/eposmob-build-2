import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/resources/app_url.dart';

import '../domain/models/daily_sales_close.dart';
import '../domain/models/day_close_pending_status.dart';
import 'sales_http.dart';

class DailyCloseApi {
  DailyCloseApi(
      {SalesHttpGet? get,
      SalesHttpPost? post,
      this.session = const TenantSession()})
      : _get = get ?? http.get,
        _post = post ?? http.post;
  final SalesHttpGet _get;
  final SalesHttpPost _post;
  final TenantSession session;
  Future<DailySalesCloseModel?> fetchDailySalesClose({
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

    try {
      final apiKey = await session.apiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found.");
      }

      final headers = {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      };

      final response = await _get(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final model = DailySalesCloseModel.fromJson(jsonData);
        return model;
      } else {
        return null;
      }
    } catch (error) {
      rethrow;
    }
  }

  Future<DailySalesCloseData?> fetchDailySalesCloseDetail({
    required String accessToken,
    required int id,
  }) async {
    final uri = Uri.parse(APPUrl.viewDailySalesClose(id.toString()));

    try {
      final apiKey = await session.apiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found.");
      }

      final headers = {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      };

      final response = await _get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['data'] != null) {
          final detailData = DailySalesCloseData.fromJson(jsonData['data']);
          return detailData;
        }
      }
      return null;
    } catch (error) {
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

    try {
      final apiKey = await session.apiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found.");
      }

      final response = await _get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final model = DailySalesCloseSummaryResponse.fromJson(jsonData);
        return model.data;
      } else {
        throw HttpException('Failed to fetch summary: ${response.statusCode}');
      }
    } catch (error) {
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

    try {
      final apiKey = await session.apiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found.");
      }

      final response = await _post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
        body: requestBodyJson,
      ).timeout(const Duration(seconds: 15));

      final jsonData = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': jsonData['success'] ?? true,
          'message': jsonData['message'] ?? 'Day close created successfully',
          'errors': jsonData['errors'],
        };
      } else {
        return {
          'success': false,
          'message': jsonData['message'] ?? 'Failed to create day close',
          'errors': jsonData['errors'],
        };
      }
    } catch (error) {
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
      final apiKey = await session.apiKey();
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

      final response = await _post(
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
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<DayClosePendingStatus?> fetchDayClosePendingStatus({
    required String accessToken,
    required int storeId,
    required int userId,
  }) async {
    try {
      final apiKey = await session.apiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found.");
      }

      final uri = Uri.parse('${APPUrl.dailySalesClosePendingStatus}'
          '?store_id=$storeId&user_id=$userId');
      final response = await _get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        return DayClosePendingStatus.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
