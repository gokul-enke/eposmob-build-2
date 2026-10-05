part of 'purchase_api.dart';

extension PurchaseApiItems on PurchaseApi {
  Future<dynamic> addPurchaseItem({
    required String categoryId,
    required String productId,
    required String quantity,
    required String unit,
    required String supplierId,
    required String storeId,
    required String batchNumber,
    required String accessToken,
  }) async {
    final Map<String, dynamic> apiBodyData = {
      'category_id': categoryId,
      'product_id': productId,
      'quantity': quantity,
      'unit': unit,
      'supplier_id': supplierId,
      'store_id': storeId,
      'batch_number': batchNumber,
    };
    // debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.addToPurchaseItem);
    // Read the current tenant through the injected session.
    final apiKey = await session.apiKey();

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await _post(url, body: apiBodyData, headers: {
        // 'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(json.decode(response.body).toString());

        return json.decode(response.body);
      } else {}
    } finally {
      // _isLoading = false;
      // notifyListeners();
    }
  }

  Future<dynamic> addPurchaseProductStockAPI({
    required String accessToken,
    required String purchaseItemId,
    required String quantity,
    required String purchaseRate,
    required String retailPrice,
    required String wholesalePrice,
    required String wholesaleMinUnit,
    required String expiryDate,
    required String batchNumber,
    required String unit,
  }) async {
    final Map<String, dynamic> error = {
      'status': "failed",
      'message': "Something went wrong, Please try Again!"
    };

    final Map<String, dynamic> apiBodyData = {
      'purchase_item_id': purchaseItemId,
      'quantity': quantity,
      'purchase_rate': purchaseRate,
      'retail_price': retailPrice,
      'wholesale_price': wholesalePrice,
      'wholesale_min_unit': wholesaleMinUnit,
      'expiry_date': expiryDate,
      'unit': unit,
      'batch_number': batchNumber
    };
    // debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.addPurchaseStock);
    // Read the current tenant through the injected session.
    final apiKey = await session.apiKey();

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response =
          await _post(url, body: json.encode(apiBodyData), headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      });

      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(json.decode(response.body).toString());
        return json.decode(response.body);
      } else {
        return error;
      }
    } catch (e) {
      // debugPrint(e.toString());
      return error;
    }
  }

  Future<dynamic> addPurchase({
    required String purchaseId,
    required String accessToken,
  }) async {
    final Map<String, dynamic> apiBodyData = {
      'purchase_id': purchaseId,
    };
    // debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.finishPurchaseOrder);
    // Read the current tenant through the injected session.
    final apiKey = await session.apiKey();

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await _post(url, body: apiBodyData, headers: {
        // 'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(json.decode(response.body).toString());

        return json.decode(response.body);
      } else {}
    } finally {
      // _isLoading = false;
      // notifyListeners();
    }
  }

  Future<dynamic> removePurchaseItem({
    required String itemId,
    required String accessToken,
  }) async {
    final Map<String, dynamic> apiBodyData = {
      'item_id': itemId,
    };
    // debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.removePurchaseitem);
    // Read the current tenant through the injected session.
    final apiKey = await session.apiKey();

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await _post(url, body: apiBodyData, headers: {
        // 'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(json.decode(response.body).toString());

        return json.decode(response.body);
      } else {}
    } finally {
      // _isLoading = false;
      // notifyListeners();
    }
  }

  Future<dynamic> finishPurchaseOrder({
    required String accessToken,
    String? purchaseId,
    String? purchaseVoucherId,
    List<String>? paymentMethods,
    List<Map<String, dynamic>>? paidMethods,
  }) async {
    final int? parsedPurchaseId = (purchaseId != null && purchaseId.isNotEmpty)
        ? int.tryParse(purchaseId)
        : null;
    final int? parsedPurchaseVoucherId =
        (purchaseVoucherId != null && purchaseVoucherId.isNotEmpty)
            ? int.tryParse(purchaseVoucherId)
            : null;

    final List<Map<String, dynamic>> normalizedPaidMethods =
        (paidMethods ?? []).map((method) {
      final int? parsedMethodId =
          int.tryParse(method['method']?.toString() ?? '');
      final double parsedAmount =
          double.tryParse(method['amount']?.toString() ?? '0') ?? 0.0;

      return {
        'method': parsedMethodId ?? method['method'],
        'amount': parsedAmount,
      };
    }).toList();

    final Map<String, dynamic> apiBodyData = {
      if (parsedPurchaseId != null) 'purchase_id': parsedPurchaseId,
      if (parsedPurchaseVoucherId != null)
        'purchase_voucher_id': parsedPurchaseVoucherId,
      'paid_methods': normalizedPaidMethods,
      if (paymentMethods != null && paymentMethods.isNotEmpty)
        'payment_methods': paymentMethods
            .map((methodId) => int.tryParse(methodId) ?? methodId)
            .toList(),
    };

    debugPrint('📦 COMPLETE PURCHASE API REQUEST BODY:');
    debugPrint(const JsonEncoder.withIndent('  ').convert(apiBodyData));

    final url = Uri.parse(APPUrl.finishPurchaseOrder);

    // Read the current tenant through the injected session.
    final apiKey = await session.apiKey();

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final response =
          await _post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });

      debugPrint(
          'Finish Purchase Order API response status: ${response.statusCode}');
      debugPrint('Finish Purchase Order API response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = json.decode(response.body);
        debugPrint('Finish Purchase Order API success: $result');
        return result;
      } else {
        debugPrint(
            'Finish Purchase Order API failed with status: ${response.statusCode}');
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
      debugPrint('Error in finishPurchaseOrder: $e');
      return {
        'status': 'failed',
        'message': 'Error: ${e.toString()}',
      };
    }
  }
}
