part of 'purchase_provider.dart';

extension PurchaseProviderOperations1 on PurchaseProvider {
  Future<void> _listAllStoresOperation(
      String accessToken, String? storeName) async {
    final request =
        await repository.prepareListAllStores(accessToken, storeName);
    try {
      final response = await request.send();
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        GetStoreModel getStoreModel = response.stores;

        storeList = getStoreModel.data ?? [];

        _notifyPurchaseListeners();
      } else {}
    } finally {}
  }
  //          *********************** LIST ALL STORES  API ***************************************************

  Future<void> _listAllSuppliersOperation(
      String accessToken, String? supplierName) async {
    final request =
        await repository.prepareListAllSuppliers(accessToken, supplierName);
    try {
      final response = await request.send();
      debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        debugPrint(response.body.toString());
        GetSuppliersModel getSuppliersModel = response.suppliers;

        supplierList = getSuppliersModel.data ?? [];
        supplierList.insert(0, supplierDemo);

        _notifyPurchaseListeners();
        // debugPrint('List supplierList Name in Purchase Provider');
        for (var v in supplierList) {
          // debugPrint(v.name);
        }
      } else {}
    } catch (e) {
      debugPrint("Error in listAllSuppliers: $e");
    } finally {}
  }
  //          *********************** LIST ALL UNITS  API ***************************************************

  Future<void> _listAllUnitsOperation(
    String accessToken,
  ) async {
    final request = await repository.prepareListAllUnits(accessToken);
    try {
      final response = await request.send();
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(response.body.toString());
        UnitsResponse unitsResponse = response.units;

        // Machine values, never the localized labels — product/stock forms
        // match a stored unit against these.
        unitList = unitsResponse.unitList;
        unitLabels = unitsResponse.displayList;

        _notifyPurchaseListeners();
      } else {}
    } finally {}
  }

  //          *********************** LIST MASTER DATA VALUES  API ***************************************************

  Future<void> _listMasterDataValuesOperation(
    String accessToken,
    String code,
  ) async {
    final request =
        await repository.prepareListMasterDataValues(accessToken, code);
    try {
      final response = await request.send();
      debugPrint('Master data API response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        debugPrint('Master data response: ${response.body}');
        final jsonData = response.json;

        if (jsonData['status'] == 'success' && jsonData['data'] != null) {
          // Handle both new List structure and legacy Map structure
          if (jsonData['data'] is List) {
            // New structure: List of objects with id, value, description.
            // Parsed through MasterDataValue so the row's `translations` map is
            // honored: `label` resolves against the active locale and falls
            // back to the server-resolved description, then the machine value.
            // The key stays `value` — it is what gets persisted on stock rows,
            // so it must never become a translated string.
            masterDataValues = {};
            for (final parsed in response.masterDataRows) {
              if (parsed.value.isEmpty) continue;
              masterDataValues![parsed.value] = parsed.label;
            }
            debugPrint(
                'Master data values loaded (from List): $masterDataValues');
          } else if (jsonData['data'] is Map) {
            // Legacy structure: Map<String, String>
            masterDataValues = response.legacyMasterData;
            debugPrint(
                'Master data values loaded (from Map): $masterDataValues');
          } else {
            debugPrint(
                'Unexpected data format: ${jsonData['data'].runtimeType}');
            masterDataValues = {};
          }
        } else {
          debugPrint('Failed to load master data: ${jsonData['message']}');
          masterDataValues = {};
        }

        _notifyPurchaseListeners();
      } else {
        debugPrint(
            'Master data API failed with status: ${response.statusCode}');
        masterDataValues = {};
        _notifyPurchaseListeners();
      }
    } catch (e) {
      debugPrint('Error loading master data: $e');
      masterDataValues = {};
      _notifyPurchaseListeners();
    }
  }

  //          *********************** LIST PURCHASES  API ***************************************************

  Future<void> _listPurchaseOperation({
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
    purchaseItemListAllPurchase = [];
    final request = await repository.prepareListPurchase(
        accessToken: accessToken,
        storeId: storeId,
        supplierId: supplierId,
        filterName: filterName,
        filterProduct: filterProduct,
        filterStore: filterStore,
        filterSupplier: filterSupplier,
        filterDate: filterDate,
        createdBy: createdBy,
        page: page);
    try {
      final response = await request.send();
      debugPrint('API response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = response.json;
        debugPrint("API Response status: ${jsonData["status"]}");

        if (jsonData["status"] == "failed") {
          debugPrint(
              "API response status is failed: ${jsonData["message"] ?? 'No error message provided'}");
          purchaseItemListAllPurchase = [];
          _notifyPurchaseListeners();
          return;
        }

        try {
          debugPrint("Attempting to parse ListPurchaseModel");
          ListPurchaseModel listPurchaseModel = response.purchases;
          debugPrint("ListPurchaseModel parsed successfully");

          // Check pagination
          debugPrint("Pagination: ${listPurchaseModel.pagination}");
          currentPage = listPurchaseModel.pagination?.currentPage ??
              1; // Set the current page
          totalPages = listPurchaseModel.pagination?.lastPage ??
              1; // Set the total pages

          // Check data
          List<ListPurchaseModelData>? data = listPurchaseModel.data;
          debugPrint("data is null: ${data == null}");
          debugPrint("data class: ${data.runtimeType}");

          if (data == null || data.isEmpty) {
            debugPrint(
                "data is null or empty, setting purchaseItemListAllPurchase to empty list");
            purchaseItemListAllPurchase = [];
            _notifyPurchaseListeners();
            return;
          }

          try {
            // Initialize empty list
            List<PurchaseItem> aggregatedPurchaseItems = [];

            // Iterate through each model data
            for (var index = 0; index < data.length; index++) {
              var modelData = data[index];
              debugPrint(
                  "Processing modelData[$index]: id=${modelData.id}, items length=${modelData.purchaseItems?.length ?? 0}");

              if (modelData.purchaseItems != null &&
                  modelData.purchaseItems!.isNotEmpty) {
                for (var item in modelData.purchaseItems!) {
                  debugPrint("Item: id=${item.id}, product=${item.productId}");
                  aggregatedPurchaseItems.add(item);
                }
              }
            }

            debugPrint(
                "Aggregated purchase items count: ${aggregatedPurchaseItems.length}");

            if (aggregatedPurchaseItems.isEmpty) {
              debugPrint(
                  "No purchase items found, setting purchaseItemListAllPurchase to empty list");
              purchaseItemListAllPurchase = [];
            } else {
              debugPrint(
                  "Setting purchaseItemListAllPurchase with ${aggregatedPurchaseItems.length} items");
              purchaseItemListAllPurchase = aggregatedPurchaseItems;
            }

            try {
              if (data.isNotEmpty) {
                ListPurchaseModelDataDetails = data.first;
                debugPrint(
                    "ListPurchaseModelDataDetails set successfully: ${data.first.id}");
              } else {
                debugPrint(
                    "Cannot set ListPurchaseModelDataDetails, data is empty");
                ListPurchaseModelDataDetails = null;
              }
            } catch (e) {
              debugPrint("Error setting ListPurchaseModelDataDetails: $e");
              ListPurchaseModelDataDetails = null;
            }

            _notifyPurchaseListeners();
            debugPrint(
                "After notifyListeners, purchaseItemListAllPurchase length: ${purchaseItemListAllPurchase.length}");
          } catch (e) {
            debugPrint("Error processing purchase items: $e");
            purchaseItemListAllPurchase = [];
            _notifyPurchaseListeners();
          }
        } catch (e) {
          debugPrint("Error parsing ListPurchaseModel: $e");
          purchaseItemListAllPurchase = [];
          _notifyPurchaseListeners();
        }
      } else {
        debugPrint("API request failed with status: ${response.statusCode}");
        debugPrint("Response body: ${response.body}");
        debugPrint("Request URL: ${request.url.toString()}");
        debugPrint("Request headers: ${{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${accessToken.substring(0, 10)}...'
        }}}");
        purchaseItemListAllPurchase = [];
        _notifyPurchaseListeners();
      }
    } catch (e) {
      debugPrint("Error making API request: $e");
      purchaseItemListAllPurchase = [];
      _notifyPurchaseListeners();
    }
  }

  //          *********************** LIST VOUCHER API ***************************************************

  Future<void> _listPurchaseVoucherOperation({
    required String accessToken,
    String? filterAmount,
    String? filterStore,
    String? filterDate,
    int? page,
  }) async {
    final request = await repository.prepareListPurchaseVoucher(
        accessToken: accessToken,
        filterAmount: filterAmount,
        filterStore: filterStore,
        filterDate: filterDate,
        page: page);
    try {
      final response = await request.send();
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint('Response body: ${response.body}');
        // Use the new ListVoucherModel
        ListVoucherModel listVoucherModel = response.vouchers;
        List<VoucherModelData>? vouchersData = listVoucherModel.data;
        // debugPrint("categoryListModel.pagination?.toString()");
        // debugPrint(listVoucherModel.pagination?.toString());
        purchaseVoucherCurrentPage = listVoucherModel.pagination?.currentPage ??
            1; // Set the current page
        purchaseVoucherTotalPages =
            listVoucherModel.pagination?.lastPage ?? 1; // Set the total pages

        // Here you can handle the vouchers data as needed
        if (vouchersData != null && vouchersData.isNotEmpty) {
          // debugPrint("Vouchers found: ${vouchersData.length}");
          // debugPrint(vouchersData.toString());
          voucherDetailsListData = vouchersData;

          _notifyPurchaseListeners();
        } else {
          // debugPrint("No vouchers found.");
        }
      } else {
        // debugPrint("Error: ${response.reasonPhrase}");
      }
    } catch (e) {
      // debugPrint("Exception occurred: $e");
    }
  }

  //          *********************** LIST ALL PURCHASE ITEMS API ***************************************************
}
