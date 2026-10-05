part of 'purchase_api.dart';

extension PurchaseApiLists on PurchaseApi {
  Future<PurchaseRequest> prepareListPurchase({
    required String accessToken,
    String? storeId,
    String? supplierId,
    String? filterName,
    String? filterProduct,
    String? filterStore,
    String? filterSupplier,
    String? filterDate,
    String? createdBy,
    int? page,
  }) async {
    debugPrint("listPurchase method called with page: $page");

    // Read the current tenant through the injected session.
    final apiKey = await session.apiKey();
    final int? activeStoreId = await session.activeStoreId();

    final queryParameters = <String, String>{
      'page': page.toString(),
    };

    // Prioritize the explicit store, then use the injected active store.
    if (storeId != null) {
      queryParameters['store_id'] = storeId;
    } else if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    if (supplierId != null) queryParameters['supplier_id'] = supplierId;
    if (filterName != null && filterName.isNotEmpty) {
      queryParameters['filter_name'] = filterName;
    }
    if (filterProduct != null && filterProduct.isNotEmpty) {
      queryParameters['filter_product'] = filterProduct;
    }
    if (filterStore != null && filterStore.isNotEmpty) {
      queryParameters['filter_store'] = filterStore;
    }
    if (filterSupplier != null && filterSupplier.isNotEmpty) {
      queryParameters['filter_supplier'] = filterSupplier;
    }
    if (filterDate != null && filterDate.isNotEmpty) {
      queryParameters['filter_date'] = filterDate;
    }
    if (createdBy != null && createdBy.isNotEmpty) {
      queryParameters['created_by'] = createdBy;
    }

    final url = Uri.parse(APPUrl.listPurchases)
        .replace(queryParameters: queryParameters);

    debugPrint("API URL: ${url.toString()}");

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    return PurchaseRequest(
        url,
        () => _get(url, headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
              'X-Tenant': apiKey,
            }));
  }

  Future<PurchaseRequest> prepareListPurchaseVoucher({
    required String accessToken,
    String? filterAmount,
    String? filterStore,
    String? filterDate,
    int? page,
  }) async {
    // debugPrint("LIST ALL Purchase");

    // Read the current tenant through the injected session.
    final apiKey = await session.apiKey();
    final int? activeStoreId = await session.activeStoreId();

    final queryParameters = <String, String>{
      'page': page.toString(),
    };
    if (filterStore != null && filterStore.isNotEmpty) {
      queryParameters['filter_store'] = filterStore;
    }
    if (filterAmount != null && filterAmount.isNotEmpty) {
      queryParameters['filter_amount_total'] = filterAmount;
    }
    if (filterDate != null && filterDate.isNotEmpty) {
      queryParameters['filter_date'] = filterDate;
    }
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }

    final url = Uri.parse(APPUrl.listPurchaseVoucher)
        .replace(queryParameters: queryParameters);

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    return PurchaseRequest(
        url,
        () => _get(url, headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
              'X-Tenant': apiKey,
            }));
  }

  Future<PurchaseRequest> prepareListAllPurchaseItems(
    String accessToken,
  ) async {
    // debugPrint("LIST ALL Purchase Item");

    // Read the current tenant through the injected session.
    final apiKey = await session.apiKey();
    final int? activeStoreId = await session.activeStoreId();

    final Map<String, String> queryParameters = {};
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse(APPUrl.listPurchaseItems)
        .replace(queryParameters: queryParameters);

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    return PurchaseRequest(
        url,
        () => _get(url, headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
              'X-Tenant': apiKey,
            }));
  }

  Future<PurchaseRequest> prepareListPurchaseOrders({
    required String accessToken,
    String? storeId,
    String? supplierId,
    String? dateFrom,
    String? dateTo,
    int? page,
  }) async {
    debugPrint("listPurchaseOrders method called with page: $page");

    final apiKey = await session.apiKey();
    final int? activeStoreId = await session.activeStoreId();

    final queryParameters = <String, String>{
      'page': page?.toString() ?? '1',
    };

    if (storeId != null && storeId.toLowerCase() != "all") {
      queryParameters['store_id'] = storeId;
    } else if (storeId == null && activeStoreId != null) {
      // Default to active store only if no specific store_id was requested (not even "all")
      queryParameters['store_id'] = activeStoreId.toString();
    }
    // If storeId is "all", we skip adding 'store_id' to queryParameters to fetch everything.

    if (supplierId != null && supplierId.isNotEmpty) {
      queryParameters['supplier_id'] = supplierId;
    }
    if (dateFrom != null && dateFrom.isNotEmpty) {
      queryParameters['date_from'] = dateFrom;
      // Backward compatibility for APIs still expecting a single-date filter.
      queryParameters['filter_date'] = dateFrom;
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      queryParameters['date_to'] = dateTo;
    }

    final url = Uri.parse(APPUrl.listPurchaseOrder)
        .replace(queryParameters: queryParameters);

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    return PurchaseRequest(
        url,
        () => _get(url, headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
              'X-Tenant': apiKey,
            }));
  }
}
