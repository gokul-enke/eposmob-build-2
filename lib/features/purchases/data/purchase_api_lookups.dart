part of 'purchase_api.dart';

extension PurchaseApiLookups on PurchaseApi {
  Future<PurchaseRequest> prepareListAllStores(
      String accessToken, String? storeName) async {
    // debugPrint("LIST ALL STORES ");

    // Read the current tenant through the injected session.
    final apiKey = await session.apiKey();
    final int? activeStoreId = await session.activeStoreId();

    final baseUri = Uri.parse(APPUrl.getStores);
    final queryParameters = Map<String, String>.from(baseUri.queryParameters);
    if (storeName != null && storeName.isNotEmpty) {
      queryParameters['store_name'] = storeName;
    }
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final url = baseUri.replace(queryParameters: queryParameters);

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

  Future<PurchaseRequest> prepareListAllSuppliers(
      String accessToken, String? supplierName) async {
    // debugPrint("LIST ALL STORES ");
    // Read the current tenant through the injected session.
    final apiKey = await session.apiKey();
    final int? activeStoreId = await session.activeStoreId();

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    final Map<String, String> queryParameters = {};
    if (supplierName != null && supplierName.isNotEmpty) {
      queryParameters['supplier_name'] = supplierName;
    }
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse(APPUrl.getSuppliers)
        .replace(queryParameters: queryParameters);

    return PurchaseRequest(
        url,
        () => _get(url, headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
              'X-Tenant': apiKey,
            }));
  }

  Future<PurchaseRequest> prepareListAllUnits(
    String accessToken,
  ) async {
    // debugPrint("LIST ALL UNITS ");

    // Read the current tenant through the injected session.
    final apiKey = await session.apiKey();
    final int? activeStoreId = await session.activeStoreId();

    // ApiLocale deliberately withholds the locale from this endpoint until the
    // backend ships the additive `labels` map; the parsing below is already
    // ready for it, so unblocking is a one-line change there.
    final url = ApiLocale.build(APPUrl.listUnits, {
      if (activeStoreId != null) 'store_id': activeStoreId.toString(),
    });

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    return PurchaseRequest(
        url,
        () => _get(
              url,
              headers: ApiLocale.headers(
                apiKey: apiKey,
                accessToken: accessToken,
                localized: ApiLocale.isLocalized(url),
              ),
            ));
  }

  Future<PurchaseRequest> prepareListMasterDataValues(
    String accessToken,
    String code,
  ) async {
    debugPrint("LIST MASTER DATA VALUES for code: $code");

    // Read the current tenant through the injected session.
    final apiKey = await session.apiKey();
    final int? activeStoreId = await session.activeStoreId();

    final url = ApiLocale.build(APPUrl.getMasterDataValues, {
      'code': code,
      if (activeStoreId != null) 'store_id': activeStoreId.toString(),
    });

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    return PurchaseRequest(
        url,
        () => _get(
              url,
              headers:
                  ApiLocale.headers(apiKey: apiKey, accessToken: accessToken),
            ));
  }
}
