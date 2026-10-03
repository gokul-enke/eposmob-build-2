import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/resources/app_url.dart';
import '../domain/models/expense.dart';

typedef ExpenseHttpGet = Future<http.Response> Function(Uri url,
    {Map<String, String>? headers});
typedef ExpenseHttpPost = Future<http.Response> Function(Uri url,
    {Map<String, String>? headers, Object? body});

/// Tenant-scoped expense HTTP requests; no shared list or UI state.
class ExpenseApi {
  ExpenseApi(
      {ExpenseHttpGet? httpGet,
      ExpenseHttpPost? httpPost,
      this.session = const TenantSession()})
      : _get = httpGet ?? http.get,
        _post = httpPost ?? http.post;
  final ExpenseHttpGet _get;
  final ExpenseHttpPost _post;
  final TenantSession session;
  Future<List<Expense>?> fetchGeneralPayments(
      {required String accessToken,
      String type = "EXPENSE",
      bool Function()? isCurrent}) async {
    final apiKey = await session.apiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('Tenant is unavailable.');
    }
    final storeId = await session.activeStoreId();
    final staged = <Expense>[];
    final references = <String>{};
    var page = 1;
    int? lastPage;
    int? expectedTotal;
    do {
      final uri = Uri.parse(APPUrl.listGeneralPayments).replace(
        queryParameters: {
          'type': type,
          if (storeId != null) 'store_id': '$storeId',
          // Preserve the existing first request for non-paginated responses.
          if (page > 1) 'page': '$page',
        },
      );
      final response = await _get(uri, headers: {
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      }).timeout(const Duration(seconds: 30));
      if (isCurrent != null && !isCurrent()) return null;
      if (response.statusCode != 200) {
        throw StateError('Expense request failed (${response.statusCode}).');
      }
      final body = json.decode(response.body);
      if (body is! Map ||
          body['status'] == 'failed' ||
          body['success'] == false) {
        throw const FormatException('Invalid expense response.');
      }
      final data = body['data'] is List &&
              (body.containsKey('current_page') ||
                  body.containsKey('last_page'))
          ? {
              'data': body['data'],
              'current_page': body['current_page'],
              'last_page': body['last_page'],
              'total': body['total']
            }
          : body['data'];
      final List rows;
      if (data is List && page == 1) {
        rows = data;
        lastPage = 1;
      } else if (data is Map && data['data'] is List) {
        rows = data['data'] as List;
        // An unpaginated nested list is also an existing API contract.
        final hasPagination =
            data.containsKey('current_page') || data.containsKey('last_page');
        if (!hasPagination && page == 1) {
          lastPage = 1;
        } else {
          final current = data['current_page'];
          final last = data['last_page'];
          final total = data['total'];
          if (current is! int ||
              current != page ||
              last is! int ||
              last < page ||
              (lastPage != null && last != lastPage) ||
              (total != null && (total is! int || total < 0)) ||
              (page > 1 && total != expectedTotal) ||
              (rows.isEmpty && (page > 1 || last > 1))) {
            throw const FormatException('Incomplete expense pagination.');
          }
          lastPage = last;
          expectedTotal = total as int?;
        }
      } else {
        throw const FormatException('Expense rows are missing.');
      }
      for (final row in rows) {
        if (row is! Map) throw const FormatException('Invalid expense row.');
        final reference = row['reference_number'] ?? row['reference_no'];
        final date = row['payment_date'];
        final rawAmount = row['amount'];
        final amount = rawAmount is num
            ? rawAmount.toDouble()
            : rawAmount is String
                ? double.tryParse(rawAmount.trim())
                : null;
        if (reference is! String ||
            reference.trim().isEmpty ||
            date is! String ||
            DateTime.tryParse(date) == null ||
            amount == null ||
            !amount.isFinite) {
          throw const FormatException('Required expense fields are invalid.');
        }
        if (!references.add(reference.trim())) {
          throw const FormatException('Duplicate expense reference.');
        }
        final expense = Expense.fromJson({
          ...Map<String, dynamic>.from(row),
          'amount': amount,
        });
        staged.add(expense);
      }
      page++;
    } while (page <= lastPage);
    if (expectedTotal != null && staged.length != expectedTotal) {
      throw const FormatException('Incomplete expense total.');
    }
    if (isCurrent != null && !isCurrent()) return null;
    return staged;
  }

  Future<Map<String, double>> getExpenseBreakdownForDate({
    required String accessToken,
    required int storeId,
    required String businessDate,
  }) async {
    try {
      final apiKey = await session.apiKey();

      final queryParams = <String, String>{
        'type': 'EXPENSE',
        'store_id': storeId.toString(),
      };

      final uri = Uri.parse(APPUrl.listGeneralPayments)
          .replace(queryParameters: queryParams);

      final response = await _get(uri, headers: {
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey ?? '',
      });

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        List<dynamic> rawList = [];
        if (jsonData['data'] is List) {
          rawList = jsonData['data'];
        } else if (jsonData['data'] is Map &&
            jsonData['data']['data'] is List) {
          rawList = jsonData['data']['data'];
        }

        double cash = 0.0;
        double bank = 0.0;

        for (var item in rawList) {
          final expense = Expense.fromJson(item);
          final expDate =
              '${expense.paymentDate.year}-${expense.paymentDate.month.toString().padLeft(2, '0')}-${expense.paymentDate.day.toString().padLeft(2, '0')}';
          if (expDate == businessDate) {
            final credit = expense.creditAccount.toLowerCase();
            if (credit.contains('cash')) {
              cash += expense.amount;
            } else if (credit.contains('bank')) {
              bank += expense.amount;
            }
          }
        }

        return {'cash': cash, 'bank': bank, 'total': cash + bank};
      }
    } catch (e) {
      debugPrint('Error fetching expense breakdown: $e');
    }
    return {'cash': 0.0, 'bank': 0.0, 'total': 0.0};
  }

  Future<dynamic> fetchAccountOptions({required String accessToken}) async {
    final apiKey = await session.apiKey();
    if (apiKey == null || apiKey.isEmpty) return null;
    try {
      final response =
          await _get(Uri.parse(APPUrl.generalPaymentAccountOptions), headers: {
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      if (response.statusCode != 200) return null;
      final jsonData = json.decode(response.body);
      return jsonData['data'] ?? jsonData;
    } catch (e) {
      debugPrint('Exception loading account options: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> createGeneralPayment({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final apiKey = await session.apiKey();
    final activeStoreId = await session.activeStoreId();

    if (apiKey == null || apiKey.isEmpty) {
      return {'status': 'error', 'message': 'API key not found'};
    }

    final body = Map<String, dynamic>.from(payload);
    if (activeStoreId != null) {
      body['store_id'] = activeStoreId;
    }

    final uri = Uri.parse(APPUrl.createGeneralPayment);
    debugPrint("Creating general payment at: $uri");
    debugPrint("Payload: ${json.encode(body)}");

    try {
      final response = await _post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
        body: json.encode(body),
      );

      debugPrint(
          "Create general payment response: ${response.statusCode} - ${response.body}");
      final responseData = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'status': 'success',
          'message': responseData['message'] ?? 'Created successfully',
          'data': responseData['data']
        };
      } else {
        // Extract the first field-level error message if available (e.g. from 422 responses)
        final errors = responseData['errors'];
        String errorMessage =
            responseData['message'] ?? 'Server error ${response.statusCode}';
        if (errors is Map && errors.isNotEmpty) {
          final firstFieldErrors = errors.values.first;
          if (firstFieldErrors is List && firstFieldErrors.isNotEmpty) {
            errorMessage = firstFieldErrors.first.toString();
          }
        }
        return {
          'status': 'error',
          'message': errorMessage,
          'errors': errors,
        };
      }
    } catch (e) {
      debugPrint("Exception creating general payment: $e");
      return {'status': 'error', 'message': e.toString()};
    }
  }
}
