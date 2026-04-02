import 'dart:convert';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:http/http.dart' as http;
import 'package:pos_machine/models/list_purchase_voucher.dart';
import 'package:pos_machine/models/list_unit.dart';

import '../models/get_store.dart';
import '../models/get_suppliers.dart';
import '../models/list_purchase.dart';

import '../models/purchase_order_model.dart';
import '../resources/app_url.dart';

class PurchaseProvider extends ChangeNotifier {
  bool isLoading = false;
  ListPurchaseOrderModel? listPurchaseOrderModel;
  List<PurchaseOrderData> purchaseOrdersList = [];
  int listPurchaseOrderCurrentPage = 1;
  int listPurchaseOrderTotalPages = 1;

  List<GetStoreModelData> storeList = [];
  List<GetSuppliersModelData> supplierList = [];
  List<PurchaseItem> purchaseItems = [];
  List<PurchaseItem> _purchaseItemListAllPurchase = [];

  // Getter with safe null handling
  List<PurchaseItem> get purchaseItemListAllPurchase =>
      _purchaseItemListAllPurchase;

  // Setter that ensures the list is never null
  set purchaseItemListAllPurchase(List<PurchaseItem>? value) {
    _purchaseItemListAllPurchase = value ?? [];
  }

  List<PurchaseItem> listPurchaseItemView = [];
  List<GetStoreModelData>? get getStoreList => storeList;
  List<VoucherDetail> voucherDetailsList = [];
  List<VoucherModelData> voucherDetailsListData = [];
  VoucherDetail? voucherDetails;
  List<PurchaseItem>? get getlistPurchaseItemView => listPurchaseItemView;
  VoucherDetail? get getVoucherDetails => voucherDetails;
  int currentPage = 1;
  int totalPages = 1;
  int purchaseVoucherCurrentPage = 1;
  int purchaseVoucherTotalPages = 1;

  ListPurchaseModelData? ListPurchaseModelDataDetails;
  // List<PurchaseItem>? get getlistPurchaseItemView => listPurchaseItemView;
  ListPurchaseModelData? get getListPurchaseModelDataDetails =>
      ListPurchaseModelDataDetails;
  // UnitList? unitList;
  // UnitList? get getUnitList => unitList;
  Map<String, String>? unitList;
  Map<String, String>? get getUnitList => unitList;
  Map<String, String>? masterDataValues;
  Map<String, dynamic>? activePurchaseOrderDetails;

  Map<String, String>? get getMasterDataValues => masterDataValues;
  List<VoucherDetail>? get getVoucherDetailsList => voucherDetailsList;
  List<PurchaseItem> get getPurchaseDetailsList {
    debugPrint("getPurchaseDetailsList called");
    try {
      // Our class getter already ensures non-null list
      var list = purchaseItemListAllPurchase;
      debugPrint("purchaseItemListAllPurchase type: ${list.runtimeType}");
      debugPrint("purchaseItemListAllPurchase length: ${list.length}");
      return list;
    } catch (e) {
      debugPrint("Error in getPurchaseDetailsList: $e");
      return [];
    }
  }

  List<VoucherModelData>? get getVoucherModelDataList => voucherDetailsListData;
  List<GetSuppliersModelData>? get getSupplierList => supplierList;
  GetStoreModelData storeDemo = GetStoreModelData(
    id: 0,
    name: "Select Store",
    code: "Select Store",
    status: "Y",
  );

  String getStoreNameFromId(int storeId) {
    if (storeList == null || storeList!.isEmpty) {
      return "Unknown";
    }

    var store = storeList!.firstWhere(
      (e) => e.id == storeId,
      orElse: () => GetStoreModelData(id: 0, name: "Unknown"),
    );

    return store.name ?? "Unknown";
  }

  void callVoucherDetails({required int voucherId, required int purchaseId}) {
    debugPrint(
        "callVoucherDetails called with voucherId: $voucherId, purchaseId: $purchaseId");
    debugPrint(
        "purchaseItemListAllPurchase before assignment: $purchaseItemListAllPurchase");
    debugPrint(
        "purchaseItemListAllPurchase type: ${purchaseItemListAllPurchase.runtimeType}");
    debugPrint(
        "purchaseItemListAllPurchase null?: ${purchaseItemListAllPurchase == null}");

    List<PurchaseItem> purchaseItemList = purchaseItemListAllPurchase;
    // .firstWhere((element) =>
    //     element.any((element) => element.purchaseId == purchaseId));
    listPurchaseItemView = purchaseItemList;

    debugPrint("voucherDetailsList before assignment: $voucherDetailsList");
    debugPrint("voucherDetailsList type: ${voucherDetailsList.runtimeType}");
    debugPrint("voucherDetailsList null?: ${voucherDetailsList == null}");

    try {
      VoucherDetail? voucher = voucherDetailsList.firstWhere(
        (element) => element.id == voucherId,
      );
      voucherDetails = voucher;
    } catch (e) {
      debugPrint("Error in callVoucherDetails: $e");
      voucherDetails = null;
    }

    notifyListeners();
  }

  String? storeName(int value) {
    var store = storeList.firstWhere((e) => e.id == value,
        orElse: () => GetStoreModelData(id: 0, name: "Unknown"));
    return store.name;
  }

  String? supplierName(int value) {
    var supplier = supplierList.firstWhere((e) => e.id == value,
        orElse: () => GetSuppliersModelData(
            id: 0, user: User(name: "Unknown") // Now correctly nested
            ));
    return supplier.user?.name;
  }

  PurchaseProvider() {
    debugPrint("PurchaseProvider constructor called");
    // Ensure lists are initialized to prevent null issues
    storeList = [];
    supplierList = [];
    purchaseItems = [];
    purchaseItemListAllPurchase = [];
    listPurchaseItemView = [];
    voucherDetailsList = [];
    voucherDetailsListData = [];

    debugPrint(
        "Initial purchaseItemListAllPurchase type: ${purchaseItemListAllPurchase.runtimeType}");
    debugPrint(
        "Initial purchaseItemListAllPurchase length: ${purchaseItemListAllPurchase.length}");
  }
  GetSuppliersModelData supplierDemo = GetSuppliersModelData(
    id: 0,
    user: User(name: "Select Supplier"), // Name now properly nested
    phone: "",
    email: "",
  );

  //          *********************** LIST ALL STORES  API ***************************************************

  Future<void> listAllStores(String accessToken, String? storeName) async {
    // debugPrint("LIST ALL STORES ");

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

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
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        GetStoreModel getStoreModel = GetStoreModel.fromJson(jsonData);

        storeList = getStoreModel.data ?? [];

        notifyListeners();
      } else {}
    } finally {}
  }
  //          *********************** LIST ALL STORES  API ***************************************************

  Future<void> listAllSuppliers(
      String accessToken, String? supplierName) async {
    // debugPrint("LIST ALL STORES ");
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

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
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        debugPrint(response.body.toString());
        final jsonData = json.decode(response.body);
        GetSuppliersModel getSuppliersModel =
            GetSuppliersModel.fromJson(jsonData);

        supplierList = getSuppliersModel.data ?? [];
        supplierList.insert(0, supplierDemo);

        notifyListeners();
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

  Future<void> listAllUnits(
    String accessToken,
  ) async {
    // debugPrint("LIST ALL UNITS ");

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    final Map<String, String> queryParameters = {};
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final url =
        Uri.parse(APPUrl.listUnits).replace(queryParameters: queryParameters);

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(response.body.toString());
        final jsonData = json.decode(response.body);
        UnitsResponse unitsResponse = UnitsResponse.fromJson(jsonData);

        unitList = unitsResponse.unitList;

        notifyListeners();
      } else {}
    } finally {}
  }

  //          *********************** LIST MASTER DATA VALUES  API ***************************************************

  Future<void> listMasterDataValues(
    String accessToken,
    String code,
  ) async {
    debugPrint("LIST MASTER DATA VALUES for code: $code");

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    final Map<String, String> queryParameters = {'code': code};
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse(APPUrl.getMasterDataValues)
        .replace(queryParameters: queryParameters);

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      debugPrint('Master data API response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        debugPrint('Master data response: ${response.body}');
        final jsonData = json.decode(response.body);

        if (jsonData['status'] == 'success' && jsonData['data'] != null) {
          // Handle both new List structure and legacy Map structure
          if (jsonData['data'] is List) {
            // New structure: List of objects with id, value, description
            masterDataValues = {};
            for (var item in jsonData['data']) {
              final value = item['value']?.toString() ?? '';
              final description = item['description']?.toString() ?? value;
              if (value.isNotEmpty) {
                masterDataValues![value] = description;
              }
            }
            debugPrint(
                'Master data values loaded (from List): $masterDataValues');
          } else if (jsonData['data'] is Map) {
            // Legacy structure: Map<String, String>
            masterDataValues = Map<String, String>.from(jsonData['data']);
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

        notifyListeners();
      } else {
        debugPrint(
            'Master data API failed with status: ${response.statusCode}');
        masterDataValues = {};
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading master data: $e');
      masterDataValues = {};
      notifyListeners();
    }
  }

  //          *********************** LIST PURCHASES  API ***************************************************

  Future<void> listPurchase({
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

    // Initialize with empty list through our setter
    purchaseItemListAllPurchase = [];

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    final queryParameters = <String, String>{
      'page': page.toString(),
    };

    // Prioritize function parameter, fallback to SharedPreferences
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
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      debugPrint('API response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        debugPrint("API Response status: ${jsonData["status"]}");

        if (jsonData["status"] == "failed") {
          debugPrint(
              "API response status is failed: ${jsonData["message"] ?? 'No error message provided'}");
          purchaseItemListAllPurchase = [];
          notifyListeners();
          return;
        }

        try {
          debugPrint("Attempting to parse ListPurchaseModel");
          ListPurchaseModel listPurchaseModel =
              ListPurchaseModel.fromJson(jsonData);
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
            notifyListeners();
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

            notifyListeners();
            debugPrint(
                "After notifyListeners, purchaseItemListAllPurchase length: ${purchaseItemListAllPurchase.length}");
          } catch (e) {
            debugPrint("Error processing purchase items: $e");
            purchaseItemListAllPurchase = [];
            notifyListeners();
          }
        } catch (e) {
          debugPrint("Error parsing ListPurchaseModel: $e");
          purchaseItemListAllPurchase = [];
          notifyListeners();
        }
      } else {
        debugPrint("API request failed with status: ${response.statusCode}");
        debugPrint("Response body: ${response.body}");
        debugPrint("Request URL: ${url.toString()}");
        debugPrint("Request headers: ${{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${accessToken.substring(0, 10)}...'
        }}}");
        purchaseItemListAllPurchase = [];
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error making API request: $e");
      purchaseItemListAllPurchase = [];
      notifyListeners();
    }
  }

  //          *********************** LIST VOUCHER API ***************************************************

  Future<void> listPurchaseVoucher({
    required String accessToken,
    String? filterAmount,
    String? filterStore,
    String? filterDate,
    int? page,
  }) async {
    // debugPrint("LIST ALL Purchase");

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

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
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint('Response body: ${response.body}');
        final jsonData = json.decode(response.body);

        // Use the new ListVoucherModel
        ListVoucherModel listVoucherModel = ListVoucherModel.fromJson(jsonData);
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

          notifyListeners();
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

  Future<dynamic> listAllPurchaseItems(
    String accessToken,
  ) async {
    // debugPrint("LIST ALL Purchase Item");

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    final Map<String, String> queryParameters = {};
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse(APPUrl.listPurchaseItems)
        .replace(queryParameters: queryParameters);

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(response.body.toString());
        final jsonData = json.decode(response.body);
        ListPurchaseItemModel listPurchaseItemModel =
            ListPurchaseItemModel.fromJson(jsonData);

        purchaseItems = listPurchaseItemModel.data ?? [];

        notifyListeners();
        return json.decode(response.body);
      } else {}
    } finally {}
  }
  //          *********************** ADD PURCHASE ITEM API ***************************************************

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
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.post(url, body: apiBodyData, headers: {
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
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
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
  //          *********************** ADD PURCHASE  API ***************************************************

  Future<dynamic> addPurchase({
    required String purchaseId,
    required String accessToken,
  }) async {
    final Map<String, dynamic> apiBodyData = {
      'purchase_id': purchaseId,
    };
    // debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.finishPurchaseOrder);
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.post(url, body: apiBodyData, headers: {
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
  //          *********************** REMOVE PURCHASE ITEM API ***************************************************

  Future<dynamic> removePurchaseItem({
    required String itemId,
    required String accessToken,
  }) async {
    final Map<String, dynamic> apiBodyData = {
      'item_id': itemId,
    };
    // debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.removePurchaseitem);
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.post(url, body: apiBodyData, headers: {
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

  //          *********************** FINISH PURCHASE ORDER API ***************************************************

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

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });

      debugPrint(
          'Finish Purchase Order API response status: ${response.statusCode}');
      debugPrint('Finish Purchase Order API response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        debugPrint('Finish Purchase Order API success: $result');
        return result;
      } else {
        debugPrint(
            'Finish Purchase Order API failed with status: ${response.statusCode}');
        return {
          'status': 'failed',
          'message': 'API request failed with status: ${response.statusCode}',
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

  Future<void> listPurchaseOrders({
    required String accessToken,
    String? storeId,
    String? supplierId,
    String? dateFrom,
    String? dateTo,
    int? page,
  }) async {
    debugPrint("listPurchaseOrders method called with page: $page");

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

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
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData["status"] == "success") {
          listPurchaseOrderModel = ListPurchaseOrderModel.fromJson(jsonData);
          listPurchaseOrderCurrentPage =
              listPurchaseOrderModel?.data?.currentPage ?? 1;
          listPurchaseOrderTotalPages =
              listPurchaseOrderModel?.data?.lastPage ?? 1;
          purchaseOrdersList = listPurchaseOrderModel?.data?.data ?? [];
        } else {
          purchaseOrdersList = [];
        }
        notifyListeners();
      } else {
        purchaseOrdersList = [];
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error making API request: $e");
      purchaseOrdersList = [];
      notifyListeners();
    }
  }

  Future<void> fetchPurchaseOrderDetails({
    required String accessToken,
    required String purchaseId,
  }) async {
    isLoading = true;
    notifyListeners();

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');
      final url = Uri.parse(APPUrl.receivePurchaseOrder(purchaseId));

      debugPrint("Fetching purchase details from: $url");

      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey ?? '',
      });

      debugPrint("Details response status: ${response.statusCode}");
      debugPrint("Details response body: ${response.body}");

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == 'success' && jsonData['data'] != null) {
          activePurchaseOrderDetails = jsonData['data'];

          // Map to PurchaseItem for ViewPurchaseWidget compatibility
          if (jsonData['data']['purchase_items'] != null) {
            listPurchaseItemView = List<PurchaseItem>.from(
                (jsonData['data']['purchase_items'] as List)
                    .map((x) => PurchaseItem.fromJson(x)));

            // Map header data to voucherDetails
            voucherDetails = VoucherDetail.fromJson(jsonData['data']);

            // Map to ListPurchaseModelDataDetails for ViewPurchaseWidget compatibility
            ListPurchaseModelDataDetails =
                ListPurchaseModelData.fromJson(jsonData['data']);
          } else {
            listPurchaseItemView = [];
            voucherDetails = null;
          }
        }
      } else {
        debugPrint("Failed to fetch details: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching purchase details: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<dynamic> createPurchaseOrder({
    required String accessToken,
    required String purchaseDate,
    required String supplierId,
    required String storeId,
    String? voucherNumber,
    String? invoiceRef,
    List<String>? paymentMethods,
    Map<String, dynamic>? paidAmounts,
    required List<Map<String, dynamic>> items,
  }) async {
    final Map<String, dynamic> apiBodyData = {
      'purchase_date': purchaseDate,
      'supplier_id': supplierId,
      'store_id': storeId,
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      debugPrint('📤 [Purchase API] createPurchaseOrder URL: $url');
      debugPrint(
          '📤 [Purchase API] createPurchaseOrder Body: ${json.encode(apiBodyData)}');
      final response = await http.post(
        url,
        body: json.encode(apiBodyData),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        return {
          'status': 'failed',
          'message': 'API request failed with status: ${response.statusCode}',
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
    List<String>? paymentMethods,
    Map<String, dynamic>? paidAmounts,
  }) async {
    final Map<String, dynamic> apiBodyData = {
      'items': items,
    };
    if (invoiceRef != null && invoiceRef.isNotEmpty) {
      apiBodyData['invoice_ref'] = invoiceRef;
    }

    if (paymentMethods != null) apiBodyData['payment_methods'] = paymentMethods;
    if (paidAmounts != null) apiBodyData['paid_amounts'] = paidAmounts;

    final url = Uri.parse(APPUrl.receivePurchaseOrder(purchaseId));
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      debugPrint('📤 [Purchase API] receivePurchaseOrder URL: $url');
      debugPrint(
          '📤 [Purchase API] receivePurchaseOrder Body: ${json.encode(apiBodyData)}');
      final response = await http.post(
        url,
        body: json.encode(apiBodyData),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        return {
          'status': 'failed',
          'message': 'API request failed with status: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'status': 'failed',
        'message': 'Error: ${e.toString()}',
      };
    }
  }
}
