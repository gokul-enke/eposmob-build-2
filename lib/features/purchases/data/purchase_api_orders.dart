part of 'purchase_api.dart';

extension PurchaseApiOrders on PurchaseApi {
  Future<PurchaseRequest> prepareFetchPurchaseOrderDetails({
    required String accessToken,
    required String purchaseId,
  }) async {
    final apiKey = await session.apiKey();
    final url = Uri.parse(APPUrl.receivePurchaseOrder(purchaseId));

    debugPrint("Fetching purchase details from: $url");

    return PurchaseRequest(
        url,
        () => _get(url, headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
              'X-Tenant': apiKey ?? '',
            }));
  }

  Future<dynamic> createPurchaseOrder({
    required String accessToken,
    required String purchaseDate,
    required String supplierId,
    required String storeId,
    String? voucherNumber,
    String? invoiceRef,
    required double discount,
    List<String>? paymentMethods,
    Map<String, dynamic>? paidAmounts,
    required List<Map<String, dynamic>> items,
  }) async {
    final Map<String, dynamic> apiBodyData = {
      'purchase_date': purchaseDate,
      'supplier_id': supplierId,
      'store_id': storeId,
      'discount': discount,
      'items': items,
    };

    if (voucherNumber != null && voucherNumber.isNotEmpty) {
      apiBodyData['voucher_number'] = voucherNumber;
    }
    if (invoiceRef != null && invoiceRef.isNotEmpty) {
      apiBodyData['invoice_ref'] = invoiceRef;
    }

    if (paymentMethods != null) apiBodyData['payment_methods'] = paymentMethods;
    if (paidAmounts != null) apiBodyData['paid_amounts'] = paidAmounts;

    final url = Uri.parse(APPUrl.addPurchaseOrder);
    final apiKey = await session.apiKey();

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      debugPrint('📤 [Purchase API] createPurchaseOrder URL: $url');
      debugPrint(
          '📤 [Purchase API] createPurchaseOrder Body: ${json.encode(apiBodyData)}');
      final response = await _post(
        url,
        body: json.encode(apiBodyData),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
      );
      debugPrint(
          '📥 [Purchase API] createPurchaseOrder Status: ${response.statusCode}');
      debugPrint(
          '📥 [Purchase API] createPurchaseOrder Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        // Surface the raw decoded body AND the HTTP status so the screen can
        // detect 422 and parse structured error envelopes (A, B, top-level).
        Map<String, dynamic> decoded = {};
        try {
          decoded = Map<String, dynamic>.from(json.decode(response.body));
        } catch (_) {}
        return {
          'status': 'failed',
          'http_status_code': response.statusCode,
          'message': decoded['message'] ??
              'API request failed with status: ${response.statusCode}',
          ...decoded,
        };
      }
    } catch (e) {
      return {
        'status': 'failed',
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  Future<dynamic> receivePurchaseOrder({
    required String accessToken,
    required String purchaseId,
    required List<Map<String, dynamic>> items,
    String? invoiceRef, // NEW!
    required String timeoutMessage,
    required double discount,
    List<String>? paymentMethods,
    Map<String, dynamic>? paidAmounts,
  }) async {
    final Map<String, dynamic> apiBodyData = {
      'discount': discount,
      'items': items,
    };
    if (invoiceRef != null && invoiceRef.isNotEmpty) {
      apiBodyData['invoice_ref'] = invoiceRef;
    }

    if (paymentMethods != null) apiBodyData['payment_methods'] = paymentMethods;
    if (paidAmounts != null) apiBodyData['paid_amounts'] = paidAmounts;

    final url = Uri.parse(APPUrl.receivePurchaseOrder(purchaseId));
    final apiKey = await session.apiKey();

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      debugPrint('📤 [Purchase API] receivePurchaseOrder URL: $url');
      debugPrint(
          '📤 [Purchase API] receivePurchaseOrder Body: ${json.encode(apiBodyData)}');
      final response = await _post(
        url,
        body: json.encode(apiBodyData),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 30));
      debugPrint(
          '📥 [Purchase API] receivePurchaseOrder Status: ${response.statusCode}');
      debugPrint(
          '📥 [Purchase API] receivePurchaseOrder Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        // Surface the raw decoded body AND the HTTP status so the screen can
        // detect 422 and parse structured error envelopes (A, B, top-level).
        Map<String, dynamic> decoded = {};
        try {
          decoded = Map<String, dynamic>.from(json.decode(response.body));
        } catch (_) {}
        return {
          'status': 'failed',
          'http_status_code': response.statusCode,
          'message': decoded['message'] ??
              'API request failed with status: ${response.statusCode}',
          ...decoded,
        };
      }
    } on TimeoutException {
      debugPrint('⏱️ [Purchase API] receivePurchaseOrder timed out after 30s');
      return {
        'status': 'failed',
        'message': timeoutMessage,
      };
    } catch (e) {
      return {
        'status': 'failed',
        'message': 'Error: ${e.toString()}',
      };
    }
  }
}
