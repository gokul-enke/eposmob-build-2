import 'dart:convert';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/get_product.dart';
import '../helpers/product_search_helper.dart';

import '../resources/app_url.dart';
import 'package:http/http.dart' as http;

class GridSelectionProvider extends ChangeNotifier {
  List<GetProduct>? productList = [];
  List<GetProduct>? quickAccessProductList = [];
  List<GetProduct>? mainProductList = [];
  List<GetProduct>? filteredProductList = [];
  List<GetProduct>? categoryProductList = [];
  List<int> selectedIndices = [];
  GetProduct? productDetails;
  GetProduct? get getProductDetails => productDetails;
  List<GetProduct> selectedProductList = [];
  List<GetProduct>? selectedProductListAPI = [];
  bool isLoading = false;
  bool isSelected = false;
  int selectedCategoryId = 0;
  int? productId;
  int get getselectedCategoryId => selectedCategoryId;
  int? get getProductId => productId;
  List<GetProduct>? get getProducts => productList;
  List<GetProduct>? get getSelectedProductList => selectedProductList;
  List<GetProduct>? get getCategoryProductList => categoryProductList;
  List<GetProduct>? get getSelectedProductListAPI => selectedProductListAPI;

  // Pagination properties
  int currentPage = 1;
  int totalPages = 1;
  String productNameFromProductId(int value) {
    final product = productList?.cast<GetProduct?>().firstWhere(
          (product) => product?.productId == value,
          orElse: () => null,
        );

    return product?.productName ?? "";
  }

  GridSelectionProvider() {
    listAllProducts(categoryId: 0);
    listAllProductsAPI(categoryId: 0);
  }

  void toggleSelection(int index) {
    if (selectedIndices.contains(index)) {
      selectedIndices.remove(index);
    } else {
      selectedIndices.add(index);
    }
    notifyListeners();
  }

  List<GetProduct> get selectedProductsUpOnCategory {
    if (selectedCategoryId == 0) {
      return mainProductList!;
    } else {
      categoryProductList = mainProductList!
          .where((product) => product.categoryId == getselectedCategoryId)
          .toList();
      notifyListeners();
      return categoryProductList!;
    }
  }

  List<GetProduct> searchProducts(String query) {
    if (query.isEmpty) {
      return filteredProductList!;
    }
    return ProductSearchHelper.search(filteredProductList!, query);
  }

  void updateFilteredProducts(List<GetProduct> filtered) {
    productList = filtered;
    notifyListeners();
  }

  void callProductDetails(int productId) {
    GetProduct product = productList!.firstWhere(
      (product) => product.productId == productId,
    );
    productDetails = product;
    notifyListeners();
  }

  String? productName(int value) {
    final product = productList?.cast<GetProduct?>().firstWhere(
          (e) => e?.productId == value,
          orElse: () => null,
        );
    return product?.productName;
  }

  void toggleSelectionProduct(int index, GetProduct product) {
    //  selectedProductList.add(product);
    //  productList![index].isSelected = !productList![index].isSelected;
    if (selectedProductList.contains(product)) {
      selectedProductList.remove(product);
      // isSelected = false;
      // product.isSelected = false;
    } else {
      selectedProductList.add(product);
      // isSelected = true;
      // product.isSelected = true;
    }

    notifyListeners();
  }

  setSelection(bool selected) {
    isSelected = selected;
    notifyListeners();
  }

  setProductIDForAdding(int? value) {
    productId = value;
    notifyListeners();
  }

  //          *********************** SELECT CATEGORY ID FUNCTION ***************************************************
  void updateCategory(int iD) {
    selectedCategoryId = iD;
    notifyListeners();
  }

  void clearSelection() {
    selectedIndices.clear();
    notifyListeners();
  }

  List<GetProduct> selectedProducts(int selectedCategoryID) {
    return selectedCategoryID == 0
        ? productList!
        : productList!
            .where((product) => product.categoryId == selectedCategoryID)
            .toList();
  }
  //          *********************** LIST ALL PRODUCTS  API ***************************************************

  Future<void> listAllProducts({
    int? categoryId,
    String? filterName,
    String? filterCategory,
    String? filterBarcode,
    String? filterPrice,
    String? filterCreatedBy,
    String? filterProperties,
    String? filterStore,
    String? filterSupplier,
    int page = 1,
  }) async {
    // debugPrint("LIST ALL PRODUCTS categoryId $categoryId");

    // Build query parameters
    final queryParams = <String, String>{
      if (filterName != null) 'name': filterName,
      if (filterCategory != null && filterCategory != "0")
        'category_id': filterCategory,
      if (filterBarcode != null) 'barcode': filterBarcode,
      if (filterPrice != null) 'filter_price': filterPrice,
      if (filterCreatedBy != null) 'filter_created_by': filterCreatedBy,
      // if (filterProperties != null) 'filter_properties': filterProperties,
      if (filterStore != null) 'filter_store': filterStore,
      if (filterSupplier != null) 'filter_supplier': filterSupplier,
      'page': page.toString(),
    };
    debugPrint("LIST ALL PRODUCTS categoryId $categoryId ");

    // Build query parameters

    isLoading = true;
    // selectedCategoryId = categoryId;
    notifyListeners();
    productList = [];
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    final baseUri = Uri.parse(APPUrl.getSellableProductUrl);
    final finalQueryParams = Map<String, dynamic>.from(baseUri.queryParameters)
      ..addAll(queryParams);

    // Add store_id if not already present
    if (activeStoreId != null && !finalQueryParams.containsKey('store_id')) {
      finalQueryParams['store_id'] = activeStoreId.toString();
    }

    final url = baseUri.replace(queryParameters: finalQueryParams);

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.get(url, headers: {
        'X-Tenant': apiKey,
      });

      debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint('inside product 200 ${response.body.toString()}');

        // debugPrint(json.decode(response.body).toString());
        final jsonData = json.decode(response.body);
        GetProductModel getProductModel = GetProductModel.fromJson(jsonData);

        productList = getProductModel.product;
        filteredProductList = getProductModel.product;
        mainProductList = getProductModel.product;
        categoryProductList = getProductModel.product;

        // debugPrint("categoryListModel.pagination?.toString()");
        // debugPrint(getProductModel.meta?.toString());

        currentPage = getProductModel.meta?.currentPage ?? 1;
        totalPages = getProductModel.meta?.lastPage ?? 1;
        // selectedCategoryId =
        //     productList!.isEmpty ? 0 : productList![0].categoryId ?? 0;
        notifyListeners();
        // debugPrint('List Product Name in Category Provider');
      } else {
        // debugPrint('outside product 200 ${response.body.toString()}');
        // debugPrint('outside product 200 ${response.statusCode}');
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // List Quick Access Products

  Future<void> listQuickAccessProducts({
    int? categoryId,
    String? filterName,
    String? filterCategory,
    String? filterPrice,
    String? filterCreatedBy,
    String? filterProperties,
    String? filterStore,
    String? filterSupplier,
    int page = 1,
  }) async {
    // debugPrint("LIST ALL PRODUCTS categoryId $categoryId");

    // Build query parameters
    final queryParams = <String, String>{
      if (filterName != null) 'name': filterName,
      if (filterCategory != null && filterCategory != "0")
        'category_id': filterCategory,
      if (filterPrice != null) 'filter_price': filterPrice,
      if (filterCreatedBy != null) 'filter_created_by': filterCreatedBy,
      // if (filterProperties != null) 'filter_properties': filterProperties,
      if (filterStore != null) 'filter_store': filterStore,
      if (filterSupplier != null) 'filter_supplier': filterSupplier,
      'page': page.toString(),
      'quick_access': "true",
    };
    debugPrint("LIST ALL PRODUCTS categoryId $categoryId ");

    // Build query parameters

    isLoading = true;
    // selectedCategoryId = categoryId;
    notifyListeners();
    productList = [];
    final baseUri = Uri.parse(APPUrl.getSellableProductUrl);
    final finalQueryParams = Map<String, dynamic>.from(baseUri.queryParameters)
      ..addAll(queryParams);

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    // Add store_id if not already present
    if (activeStoreId != null && !finalQueryParams.containsKey('store_id')) {
      finalQueryParams['store_id'] = activeStoreId.toString();
    }

    final url = baseUri.replace(queryParameters: finalQueryParams);

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.get(url, headers: {
        'X-Tenant': apiKey,
      });

      debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint('inside product 200 ${response.body.toString()}');

        // debugPrint(json.decode(response.body).toString());
        final jsonData = json.decode(response.body);
        GetProductModel getProductModel = GetProductModel.fromJson(jsonData);

        quickAccessProductList = getProductModel.product;

        // debugPrint("categoryListModel.pagination?.toString()");
        // debugPrint(getProductModel.meta?.toString());

        currentPage = getProductModel.meta?.currentPage ?? 1;
        totalPages = getProductModel.meta?.lastPage ?? 1;
        // selectedCategoryId =
        //     productList!.isEmpty ? 0 : productList![0].categoryId ?? 0;
        notifyListeners();
        // debugPrint('List Product Name in Category Provider');
      } else {
        // debugPrint('outside product 200 ${response.body.toString()}');
        // debugPrint('outside product 200 ${response.statusCode}');
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  //          *********************** LIST ALL PRODUCTS  API ***************************************************

  Future<void> listAllProductsAPI({int? categoryId, String? barCode}) async {
    // debugPrint("LIST ALL PRODUCTS categoryId $categoryId ");
    final Map<String, dynamic> apiBodyData = {
      'category_id': categoryId == 0 ? null : categoryId,
      'barcode': barCode,
    };

    debugPrint("apiBodyData ${apiBodyData.toString()}");

    isLoading = true;
    // selectedCategoryId = categoryId;
    notifyListeners();
    selectedProductListAPI = [];
    final url = Uri.parse(APPUrl.getSellableProductUrl);
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (activeStoreId != null) {
      apiBodyData['store_id'] = activeStoreId;
    }

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.post(url,
          body: json.encode(apiBodyData),
          headers: {'Content-Type': 'application/json', 'api_key': apiKey});
      // debugPrint('inside ${response.body}');
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        GetProductModel getProductModel = GetProductModel.fromJson(jsonData);

        selectedProductListAPI = getProductModel.product;
        // selectedCategoryId =
        //     productList!.isEmpty ? 0 : productList![0].categoryId ?? 0;
        notifyListeners();
        // debugPrint('List Product Name in Category Provider');
      } else {}
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  //          *********************** FILTER PRODUCT BY BARCODE API ***************************************************

  Future<List<GetProduct>?> filterProductByBarcodeAPI({String? barCode}) async {
    final queryParams = <String, String>{
      if (barCode != null) 'barcode': barCode,
    };

    isLoading = true;
    notifyListeners();

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    final baseUri = Uri.parse(APPUrl.getSellableProductUrl);
    final finalQueryParams = Map<String, dynamic>.from(baseUri.queryParameters)
      ..addAll(queryParams);

    // Add store_id if not already present
    if (activeStoreId != null && !finalQueryParams.containsKey('store_id')) {
      finalQueryParams['store_id'] = activeStoreId.toString();
    }

    final url = baseUri.replace(queryParameters: finalQueryParams);

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.get(url, headers: {
        'X-Tenant': apiKey,
      });
      debugPrint('Response Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('Response Body: ${response.body.toString()}');

        final jsonData = json.decode(response.body);
        GetProductModel getProductModel = GetProductModel.fromJson(jsonData);

        productList = getProductModel.product;
        filteredProductList = getProductModel.product;
        mainProductList = getProductModel.product;
        categoryProductList = getProductModel.product;

        debugPrint("Pagination Info: ${getProductModel.meta?.toString()}");

        currentPage = getProductModel.meta?.currentPage ?? 1;
        totalPages = getProductModel.meta?.lastPage ?? 1;

        notifyListeners();
        return productList; // Return the list of products
      } else {
        // debugPrint('Error Response: ${response.body.toString()}');
        // debugPrint('Error Status Code: ${response.statusCode}');
        return null; // Return null if the response is not successful
      }
    } catch (e) {
      // debugPrint('Exception occurred: $e');
      return null; // Return null in case of an exception
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  //          *********************** LIST ALL PRODUCTS FUNCTION RETURNING PRODUCT LIST API ***************************************************

  Future<List<GetProduct>> listAllProductList(
      {required int categoryId, required String barCode}) async {
    List<GetProduct> productLists = [];
    // debugPrint("LIST ALL PRODUCTS  categoryId $categoryId ");
    final Map<String, dynamic> apiBodyData = {
      'category_id': categoryId == 0 ? null : categoryId,
      'barcode': barCode,
    };
    isLoading = true;
    selectedCategoryId = categoryId;
    notifyListeners();
    productList = [];
    final url = Uri.parse(APPUrl.getSellableProductUrl);
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (activeStoreId != null) {
      apiBodyData['store_id'] = activeStoreId;
    }

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint('inside');

        // debugPrint(json.decode(response.body).toString());
        final jsonData = json.decode(response.body);
        GetProductModel getProductModel = GetProductModel.fromJson(jsonData);
        productList = productLists = getProductModel.product ?? [];
        notifyListeners();
        // selectedCategoryId =
        //     productList!.isEmpty ? 0 : productList![0].categoryId ?? 0;
        return productLists;

        // debugPrint('List Product Name in Category Provider');
      } else {
        return productLists;
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  //          *********************** GENERATE BARCODE API ***************************************************

  Future<Map<String, dynamic>?> generateBarcodeAPI(
      {required String accessToken}) async {
    // Debug: Print request details
    debugPrint('=== GENERATE BARCODE API REQUEST ===');
    debugPrint('URL: ${APPUrl.generateBarcode}');
    debugPrint('Method: GET');
    debugPrint(
        'Access Token: ${accessToken.isNotEmpty ? "Present" : "Missing"}');
    debugPrint('==========================================');

    final Map<String, dynamic> error = {
      'status': "failed",
      'message': "Something went wrong, Please try Again!"
    };

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('=== API KEY ERROR ===');
      debugPrint('API key not found in SharedPreferences');
      debugPrint('=====================');
      throw const HttpException("API key not found. Please restart the app.");
    }

    // Build URL with store_id parameter
    final Map<String, String> queryParams = {};
    if (activeStoreId != null) {
      queryParams['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse(APPUrl.generateBarcode)
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    // Debug: Print headers
    Map<String, String> headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
      'X-Tenant': apiKey,
    };
    debugPrint('Headers: $headers');

    try {
      final response = await http.get(url, headers: headers);

      // Debug: Print response details
      debugPrint('=== GENERATE BARCODE API RESPONSE ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Headers: ${response.headers}');
      debugPrint('Response Body: ${response.body}');
      debugPrint('=======================================');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        // Debug: Print parsed response data
        debugPrint('=== PARSED RESPONSE DATA ===');
        debugPrint('Full Response: $responseData');
        debugPrint('Status: ${responseData['status']}');
        debugPrint('Message: ${responseData['message']}');
        debugPrint('Data: ${responseData['data']}');

        if (responseData['data'] != null &&
            responseData['data']['barcode'] != null) {
          debugPrint('Generated Barcode: ${responseData['data']['barcode']}');
        }
        debugPrint('============================');

        return responseData;
      } else {
        debugPrint('=== HTTP ERROR ===');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
        debugPrint('==================');
        return error;
      }
    } catch (e) {
      debugPrint('=== EXCEPTION ERROR ===');
      debugPrint('Exception Type: ${e.runtimeType}');
      debugPrint('Exception Message: ${e.toString()}');
      debugPrint('======================');
      return error;
    }
  }

  //          *********************** CREATE PRODUCT  API ***************************************************

  Future<dynamic> createProductAPI({
    required String categoryId,
    required String productName,
    required String sellingPrice,
    required String mrp,
    required String quantity,
    required String unit,
    required String barcode,
    required String accessToken,
    required String purchasePrice,
    List<Map<String, dynamic>>? productNames,
    List<Map<String, dynamic>>? saleUnits,
    List<Map<String, dynamic>>? variants,
    String? conversionRateBase,
    String? itemCode,
    String? minMarginPercentage,
    String? minMarginPrice,
  }) async {
    final Map<String, dynamic> apiBodyData = {
      'name': productName,
      'price': sellingPrice,
      'category_id': categoryId,
      'mrp': mrp,
      'barcode': barcode,
      'quantity': quantity,
      'unit': unit,
      'purchase_rate': double.parse(purchasePrice),
      'conversion_rate_base': num.parse(conversionRateBase ?? '1'),
    };

    if (itemCode != null && itemCode.isNotEmpty) {
      apiBodyData['item_code'] = itemCode;
    }

    if (minMarginPercentage != null && minMarginPercentage.isNotEmpty) {
      apiBodyData['min_margin_percentage'] = num.tryParse(minMarginPercentage);
    }

    if (minMarginPrice != null && minMarginPrice.isNotEmpty) {
      apiBodyData['min_margin_price'] = num.tryParse(minMarginPrice);
    }

    if (productNames != null && productNames.isNotEmpty) {
      apiBodyData['product_names'] = productNames;
    }

    if (saleUnits != null && saleUnits.isNotEmpty) {
      apiBodyData['sale_units'] = saleUnits;
    }

    if (variants != null && variants.isNotEmpty) {
      apiBodyData['variants'] = variants;
    }

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (activeStoreId != null) {
      apiBodyData['store_id'] = activeStoreId;
    }

    debugPrint("apiBodyData ${apiBodyData.toString()}");
    debugPrint(
        "Product request access token present: ${accessToken.isNotEmpty}");

    final url = Uri.parse(APPUrl.createProductUrl);

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
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}'); // Log the response body

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        // Log the error response for debugging
        debugPrint('Error creating product: ${response.body}');
        return response.body; // Return the error response
      }
    } catch (e) {
      debugPrint('Error in createProductAPI: $e');
      rethrow;
    }
  }

  Future<dynamic> createProductAPILocal({
    required String categoryId,
    required String productName,
    required String sellingPrice,
    required String mrp,
    required String unit,
    required String barcode,
    required String accessToken,
    required String purchasePrice,
    List<Map<String, dynamic>>? productNames,
    List<Map<String, dynamic>>? saleUnits,
    List<Map<String, dynamic>>? variants,
    String? conversionRateBase,
    String? itemCode,
    String? minMarginPercentage,
    String? minMarginPrice,
  }) async {
    final Map<String, dynamic> apiBodyData = {
      'name': productName,
      'price': sellingPrice,
      'category_id': categoryId,
      'mrp': mrp,
      'barcode': barcode,
      'unit': unit,
      'purchase_rate': double.parse(purchasePrice),
      'conversion_rate_base': num.parse(conversionRateBase ?? '1'),
    };

    if (itemCode != null && itemCode.isNotEmpty) {
      apiBodyData['item_code'] = itemCode;
    }

    if (minMarginPercentage != null && minMarginPercentage.isNotEmpty) {
      apiBodyData['min_margin_percentage'] = num.tryParse(minMarginPercentage);
    }

    if (minMarginPrice != null && minMarginPrice.isNotEmpty) {
      apiBodyData['min_margin_price'] = num.tryParse(minMarginPrice);
    }

    if (productNames != null && productNames.isNotEmpty) {
      apiBodyData['product_names'] = productNames;
    }

    if (saleUnits != null && saleUnits.isNotEmpty) {
      apiBodyData['sale_units'] = saleUnits;
    }

    if (variants != null && variants.isNotEmpty) {
      apiBodyData['variants'] = variants;
    }

    debugPrint("apiBodyData ${apiBodyData.toString()}");
    debugPrint(
        "Product request access token present: ${accessToken.isNotEmpty}");

    final url = Uri.parse(APPUrl.createProductUrl);
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
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}'); // Log the response body

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        // Log the error response for debugging
        debugPrint('Error creating product: ${response.body}');
        return response.body; // Return the error response
      }
    } catch (e) {
      debugPrint('Error in createProductAPI: $e');
      rethrow;
    }
  }

  //          *********************** ADD PRODUCT  API ***************************************************

  Future<dynamic> addProductAPI(
      {required String categoryId,
      required String slug,
      required String productName,
      required String price,
      required String currency,
      required String unit,
      required String barcode,
      required String accessToken}) async {
    final Map<String, dynamic> apiBodyData = {
      'name': productName,
      'slug': slug,
      'price': price,
      'currency': currency,
      'category_id': categoryId,
      'barcode': barcode,
      'unit': unit,
    };
    final Map<String, dynamic> error = {
      'status': "failed",
      'message': "Something went wrong, Please try Again!"
    };
    // debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.addProductUrl);
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
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(json.decode(response.body).toString());
        // debugPrint(json.decode(response.body).toString());
        return json.decode(response.body);
      } else {
        return error;
      }
    } finally {}
  }
  //          *********************** ADD PRODUCT NAMES API ***************************************************

  Future<dynamic> addProductNamesAPI(
      {required String productId,
      required String productNameEnglish,
      required String productNameHindi,
      required String productNameArabic,
      required String accessToken}) async {
    final Map<String, dynamic> apiBodyData = {
      'product_id': productId,
      'product_lang_name[ar]': productNameEnglish,
      'product_lang_name[hi]': productNameHindi,
      'product_lang_name[en]': productNameArabic,
    };
    final Map<String, dynamic> error = {
      'status': "failed",
      'message': "Something went wrong, Please try Again!"
    };
    // debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.addProductNameUrl);
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
        // debugPrint(json.decode(response.body).toString());
        return json.decode(response.body);
      } else {
        return error;
      }
    } finally {}
  }
  //          *********************** ADD PRODUCT PROPS API ***************************************************

  Future<dynamic> addProductPropsAPI({
    required String productId,
    required Map<String, List<String>> productPropData,
    required Map<String, String> productPropStockApplicable,
    String? accessToken,
    required List<String> productPropCodes,
    required List<String> productPropIds,
  }) async {
    // final Map<String, dynamic> apiBodyData = {
    //   'prop_id[]': "1",
    //   'prop_code[]': "MANUFACTURER",
    //   'propdata': {
    //     'MANUFACTURER': ['USHA']
    //   },
    //   'product_id': 79,
    //   'stock_applicable[MANUFACTURER]': "Y",
    // };

    final Map<String, dynamic> apiBodyData = {
      'prop_id[]': productPropIds,
      'prop_code[]': productPropCodes,
      'propdata': productPropData,
      'product_id': productId,
      'stock_applicable': productPropStockApplicable,
    };

    // debugPrint("add prop body ${apiBodyData.toString()}");

//     Two keys in a map literal shouldn't be equal.
// Change or remove the duplicate key.
    final Map<String, dynamic> error = {
      'status': "failed",
      'message': "Something went wrong, Please try Again!"
    };
    // debugPrint("apiBodyData + ${apiBodyData.toString()}");
    final url = Uri.parse(APPUrl.addProductPropsUrl);
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
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(json.decode(response.body).toString());
        // debugPrint(json.decode(response.body).toString());
        return json.decode(response.body);
      } else {
        return error;
      }
    } finally {}
  }
  //          *********************** ADD PRODUCT IMAGE/VIDEO API ***************************************************

  Future<dynamic> addProductImageAPI(
      {required String title,
      required String alt,
      required String filePath,
      required String productId,
      required String isPrimary,
      required String accessToken}) async {
    final Map<String, dynamic> apiBodyData = {
      'product_id': productId,
      'is_primary[1]': isPrimary,
      'title[]': title,
      'alt[]': alt,
      'file_path[]': filePath,
    };
    // debugPrint("apiBodyData + ${apiBodyData.toString()}$filePath");
    final Map<String, dynamic> error = {
      'status': "failed",
      'message': "Something went wrong, Please try Again!"
    };
    // debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.addProductImageUrl);
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.post(url, body: apiBodyData, headers: {
        //  'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(json.decode(response.body).toString());
        listAllProducts(categoryId: 0);
        listAllProductsAPI(categoryId: 0);
        notifyListeners();
        return json.decode(response.body);
      } else {
        return error;
      }
    } finally {}
  }

  Future<dynamic> editProductAPI(
      {required String productId,
      required String categoryId,
      required String slug,
      required String productName,
      required String price,
      required String currency,
      required String unit,
      required String barcode,
      required String accessToken}) async {
    final Map<String, dynamic> apiBodyData = {
      'name': productName,
      'slug': slug,
      'price': price,
      'currency': currency,
      'category_id': categoryId,
      'barcode': barcode,
      'unit': unit,
      'product_id': productId,
    };
    final Map<String, dynamic> error = {
      'status': "failed",
      'message': "Something went wrong, Please try Again!"
    };
    // debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.editProductUrl);
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
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(json.decode(response.body).toString());
        // debugPrint(json.decode(response.body).toString());
        return json.decode(response.body);
      } else {
        return error;
      }
    } finally {}
  }
  //          *********************** ADD PRODUCT NAMES API ***************************************************

  Future<dynamic> editProductNamesAPI(
      {required String productId,
      required String productNameEnglish,
      required String productNameHindi,
      required String productNameArabic,
      required String accessToken}) async {
    final Map<String, dynamic> apiBodyData = {
      'product_id': productId,
      'product_lang_name[ar]': productNameEnglish,
      'product_lang_name[hi]': productNameHindi,
      'product_lang_name[en]': productNameArabic,
    };
    // debugPrint({
    //   'product_id': productId,
    //   'product_lang_name[ar]': productNameEnglish,
    //   'product_lang_name[hi]': productNameHindi,
    //   'product_lang_name[en]': productNameArabic,
    // });
    final Map<String, dynamic> error = {
      'status': "failed",
      'message': "Something went wrong, Please try Again!"
    };

    // debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.editProductNameUrl);
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
        // debugPrint(json.decode(response.body).toString());
        return json.decode(response.body);
      } else {
        return error;
      }
    } finally {}
  }
  //          *********************** ADD PRODUCT PROPS API ***************************************************

  Future<dynamic> editProductPropsAPI({
    required String productId,
    required Map<String, List<String>> productPropData,
    required Map<String, String> productPropStockApplicable,
    required List<String> productPropCodes,
    required List<String> productPropIds,
    required String accessToken,
  }) async {
    final Map<String, dynamic> apiBodyData = {
      'prop_id[]': productPropIds,
      'prop_code[]': productPropCodes,
      'propdata': productPropData,
      'product_id': productId,
      'stock_applicable': productPropStockApplicable,
    };

    // debugPrint("edit prop body ${apiBodyData.toString()}");
//     Two keys in a map literal shouldn't be equal.
// Change or remove the duplicate key.
    final Map<String, dynamic> error = {
      'status': "failed",
      'message': "Something went wrong, Please try Again!"
    };
    // debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.editProductPropsUrl);
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
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(json.decode(response.body).toString());
        // debugPrint(json.decode(response.body).toString());
        return json.decode(response.body);
      } else {
        return error;
      }
    } finally {}
  }
  //          *********************** ADD PRODUCT IMAGE/VIDEO API ***************************************************

  Future<dynamic> editProductImageAPI(
      {required String title,
      required String alt,
      required String filePath,
      required String productId,
      required String isPrimary,
      required String accessToken}) async {
    final Map<String, dynamic> apiBodyData = {
      'product_id': productId,
      'is_primary[1]': isPrimary,
      'title[]': title,
      'alt[]': alt,
      'file_path[]': filePath,
    };
    final Map<String, dynamic> error = {
      'status': "failed",
      'message': "Something went wrong, Please try Again!"
    };
    // debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.editProductImageUrl);
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.post(url, body: apiBodyData, headers: {
        //  'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(json.decode(response.body).toString());

        return json.decode(response.body);
      } else {
        return error;
      }
    } finally {}
  }

  //          *********************** GET PRODUCT LIST FILES API ***************************************************

  Future<dynamic> getProductListFilesAPI({required String accessToken}) async {
    final Map<String, dynamic> error = {
      'status': "failed",
      'message': "Something went wrong, Please try Again!"
    };

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    // Build URL with store_id parameter
    final Map<String, String> queryParams = {};
    if (activeStoreId != null) {
      queryParams['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse(APPUrl.listFilesForImageUrl)
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      });

      debugPrint('FILES API URL: $url');
      debugPrint('FILES API STATUS: ${response.statusCode}');
      debugPrint('FILES API BODY: ${response.body}');

      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return error;
      }
    } finally {}
  }
}
