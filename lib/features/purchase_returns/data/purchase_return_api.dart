import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/models/purchase_order_model.dart';
import 'package:pos_machine/resources/app_url.dart';
import '../domain/models/purchase_return.dart';

typedef PurchaseReturnHttpGet = Future<http.Response> Function(Uri url,
    {Map<String, String>? headers});
typedef PurchaseReturnHttpPost = Future<http.Response> Function(Uri url,
    {Map<String, String>? headers, Object? body, Encoding? encoding});

/// Tenant-aware return endpoints. No provider or UI state is mutated here.
class PurchaseReturnApi {
  PurchaseReturnApi(
      {PurchaseReturnHttpGet? httpGet,
      PurchaseReturnHttpPost? httpPost,
      this.session = const TenantSession()})
      : _get = httpGet ?? http.get,
        _post = httpPost ?? http.post;
  final PurchaseReturnHttpGet _get;
  final PurchaseReturnHttpPost _post;
  final TenantSession session;
  Future<ListPurchaseReturnData> listPurchaseReturns({
    required String accessToken,
    int? page,
    String? supplierId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final apiKey = await session.apiKey();

    final queryParameters = <String, String>{
      'page': page?.toString() ?? '1',
    };
    if (supplierId != null && supplierId.isNotEmpty) {
      queryParameters['supplier_id'] = supplierId;
    }
    if (dateFrom != null && dateFrom.isNotEmpty) {
      queryParameters['date_from'] = dateFrom;
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      queryParameters['date_to'] = dateTo;
    }

    final url = Uri.parse(APPUrl.listPurchaseReturns)
        .replace(queryParameters: queryParameters);

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await _get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      if (response.statusCode != 200) {
        throw HttpException(
          'Failed to load purchase returns (HTTP ${response.statusCode}).',
        );
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map || decoded['status'] != 'success') {
        final message = decoded is Map ? decoded['message']?.toString() : null;
        throw HttpException(message ?? 'Failed to load purchase returns.');
      }

      final jsonData = Map<String, dynamic>.from(decoded);
      final model = ListPurchaseReturnModel.fromJson(jsonData);
      return model.data ??
          ListPurchaseReturnData(currentPage: 1, lastPage: 1, data: []);
    } catch (e) {
      if (e is HttpException) rethrow;
      throw const HttpException(
          'Unable to load purchase returns. Please try again.');
    }
  }

  Future<PurchaseReturnData?> fetchPurchaseReturnDetails({
    required String accessToken,
    required int returnId,
  }) async {
    final apiKey = await session.apiKey();

    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }
    try {
      final url = Uri.parse(APPUrl.purchaseReturnDetails(returnId));
      final response = await _get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData["status"] == "success" && jsonData["data"] != null) {
          return PurchaseReturnData.fromJson(jsonData["data"]);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<ReturnableItemsData?> fetchReturnableItems({
    required String accessToken,
    required int purchaseVoucherId,
  }) async {
    final apiKey = await session.apiKey();

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final url = Uri.parse(APPUrl.returnableItems(purchaseVoucherId));
      final response = await _get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      if (response.statusCode != 200) {
        throw HttpException(
          'Failed to load returnable items (HTTP ${response.statusCode}).',
        );
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map || decoded['status'] != 'success') {
        final message = decoded is Map ? decoded['message']?.toString() : null;
        throw HttpException(message ?? 'Failed to load returnable items.');
      }

      final parsed = ReturnableItemsResponse.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return parsed.data;
    } catch (e) {
      if (e is HttpException) rethrow;
      throw const HttpException(
        'Unable to load returnable items. Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>> createPurchaseReturn({
    required String accessToken,
    required int purchaseVoucherId,
    required String returnDate,
    required List<Map<String, dynamic>> items,
    bool hasPayment = false,
    double? paidAmount,
    String? paymentMethod,
  }) async {
    final apiKey = await session.apiKey();

    if (apiKey == null || apiKey.isEmpty) {
      return {
        'status': 'failed',
        'message': 'API key not found. Please restart the app.',
      };
    }

    final payload = <String, dynamic>{
      'purchase_voucher_id': purchaseVoucherId,
      'return_date': returnDate,
      'items': items,
      'has_payment': hasPayment,
    };
    if (hasPayment && paidAmount != null) {
      payload['paid_amount'] = paidAmount;
    }
    if (hasPayment && paymentMethod != null) {
      payload['payment_method'] = paymentMethod;
    }

    final body = json.encode(payload);

    try {
      final url = Uri.parse(APPUrl.createPurchaseReturn);
      final response = await _post(url,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer $accessToken',
                'X-Tenant': apiKey,
              },
              body: body)
          .timeout(const Duration(seconds: 30));

      dynamic decoded;
      try {
        decoded = json.decode(response.body);
      } catch (_) {
        return {
          'status': 'failed',
          'http_status_code': response.statusCode,
          'message': 'Server error (${response.statusCode}). Please try again.',
        };
      }
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (decoded['status'] == 'success') {
          return {'status': 'success', 'message': decoded['message'] ?? ''};
        }
      }
      String errorMessage =
          decoded['message'] ?? 'Failed to create purchase return.';
      final errors = decoded['errors'] ?? decoded['data'];
      if (errors is Map) {
        final firstError = errors.values.firstWhere(
          (v) => v is List && v.isNotEmpty,
          orElse: () => null,
        );
        if (firstError != null) {
          errorMessage = firstError[0].toString();
        }
      }
      return {
        'status': 'failed',
        'http_status_code': response.statusCode,
        'message': errorMessage,
      };
    } on TimeoutException {
      return {
        'status': 'failed',
        'message': 'Request timed out. Please try again.',
      };
    } catch (e) {
      return {
        'status': 'failed',
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  Future<ListPurchaseOrderData> fetchVouchers(
      {required String accessToken, int page = 1}) async {
    final apiKey = await session.apiKey();
    final activeStore = await session.activeStoreId();
    final url = Uri.parse(APPUrl.listPurchaseOrder).replace(queryParameters: {
      'page': page.toString(),
      if (activeStore != null) 'store_id': activeStore.toString()
    });
    if (apiKey == null)
      throw const HttpException('API key not found. Please restart the app.');
    try {
      final response = await _get(url,
          headers:
              TenantSession.headers(accessToken: accessToken, apiKey: apiKey));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['status'] == 'success')
          return ListPurchaseOrderModel.fromJson(decoded).data ??
              ListPurchaseOrderData(currentPage: 1, lastPage: 1, data: []);
      }
    } catch (_) {
      // PurchaseProvider's voucher selector has always cleared rows on request failure.
    }
    return ListPurchaseOrderData(data: []);
  }
}
