import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/get_product.dart';
import '../models/list_stock.dart' as stock_models;
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
  
  // Stock related properties
  List<stock_models.ListStockModelData>? listStockModelDataList = [];
  List<stock_models.ListStockModelData>? _allStocks = []; // Store all stocks for local filtering
  List<stock_models.ListStockModelData>? filteredStockList = [];
  List<stock_models.ListStockModelData>? get getListStockModelDataList =>
      filteredStockList ?? listStockModelDataList;
  stock_models.ListStockModelData? viewStockModelData;
  
  // Pagination properties
  int currentPage = 1;
  int totalPages = 1;
  int stockCurrentPage = 1;
  int stockTotalPages = 1;
  int _stockItemsPerPage = 20;
  String? _stockFilterName;
  String? _stockFilterCategory;
  bool _stockIsLoading = false;

  // Getters for stock pagination
  int get stockItemsPerPage => _stockItemsPerPage;
  bool get stockIsLoading => _stockIsLoading;
  String? get stockFilterCategory => _stockFilterCategory;

  stock_models.ListStockModelData? get getViewStockModelData => viewStockModelData;
  String productNameFromProductId(int value) {
    var product = productList!.firstWhere(
      (product) => product.productId == value,
    );

    return product.productName ?? "";
  }

  List<stock_models.ListStockModelData>? get allStocks => _allStocks;

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

  void searchStocks(String query) {
    if (_allStocks == null || _allStocks!.isEmpty) {
      return;
    }
    
    applyStockFiltersLocally(
      filterName: query,
      page: 1
    );
  }

  List<GetProduct> searchProducts(String query) {
    if (query.isEmpty) {
      return filteredProductList!;
    } else {
      return filteredProductList!
          .where((product) =>
              product.productName!.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
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
    var product = productList!.firstWhere(
      (e) => e.productId == value,
    );
    return product.productName;
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
    };
    debugPrint("LIST ALL PRODUCTS categoryId $categoryId ");

    // Build query parameters

    isLoading = true;
    // selectedCategoryId = categoryId;
    notifyListeners();
    productList = [];
    final url =
        Uri.parse(APPUrl.getProductUrl).replace(queryParameters: queryParams);
    try {
      final response = await http.get(url);

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
    final url =
        Uri.parse(APPUrl.getProductUrl).replace(queryParameters: queryParams);
    try {
      final response = await http.get(url);

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
    final url = Uri.parse(APPUrl.getProductUrl);
    try {
      final response = await http.post(url,
          body: json.encode(apiBodyData),
          headers: {'Content-Type': 'application/json'});
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

    final url =
        Uri.parse(APPUrl.getProductUrl).replace(queryParameters: queryParams);

    try {
      final response = await http.get(url);
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
    final url = Uri.parse(APPUrl.getProductUrl);
    try {
      final response = await http.post(url,
          body: json.encode(apiBodyData),
          headers: {'Content-Type': 'application/json'});
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
  }) async {
    final Map<String, dynamic> apiBodyData = {
      'name': productName,
      'price': sellingPrice,
      'category_id': categoryId,
      'mrp': mrp,
      'barcode': barcode,
      'quantity': quantity,
      'unit': unit,
    };

    debugPrint("apiBodyData ${apiBodyData.toString()}");
    debugPrint("accessToken ${accessToken.toString()}");

    final url = Uri.parse(APPUrl.createProductUrl);
    try {
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
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
  }) async {
    final Map<String, dynamic> apiBodyData = {
      'name': productName,
      'price': sellingPrice,
      'category_id': categoryId,
      'mrp': mrp,
      'barcode': barcode,
      'unit': unit,
    };

    debugPrint("apiBodyData ${apiBodyData.toString()}");
    debugPrint("accessToken ${accessToken.toString()}");

    final url = Uri.parse(APPUrl.createProductUrl);
    try {
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
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
    try {
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
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
    try {
      final response = await http.post(url, body: apiBodyData, headers: {
        // 'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
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
    try {
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
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
    try {
      final response = await http.post(url, body: apiBodyData, headers: {
        //  'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
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
    try {
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
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
    try {
      final response = await http.post(url, body: apiBodyData, headers: {
        // 'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
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
    try {
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
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
    try {
      final response = await http.post(url, body: apiBodyData, headers: {
        //  'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
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

    final url = Uri.parse(APPUrl.listFilesForImageUrl);
    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json'
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
  //          *********************** ADD TO STOCK API ***************************************************

  Future<dynamic> addProductStockAPI({
    required String accessToken,
    required String productId,
    required String storeId,
    required String quantity,
    required String purchaseRate,
    required String retailPrice,
    required String wholesalePrice,
    required String wholesaleMinUnit,
    required String expiryDate,
    required String batchNumber,
    required String unit,
    required List<Map<String, dynamic>> productProperties,
  }) async {
    // Print all parameters
    // debugPrint("Access Token: $accessToken");
    // debugPrint("Product ID: $productId");
    // debugPrint("Store ID: $storeId");
    // debugPrint("Quantity: $quantity");
    // debugPrint("Purchase Rate: $purchaseRate");
    // debugPrint("Retail Price: $retailPrice");
    // debugPrint("Wholesale Price: $wholesalePrice");
    // debugPrint("Wholesale Min Unit: $wholesaleMinUnit");
    // debugPrint("Expiry Date: $expiryDate");
    // debugPrint("Batch Number: $batchNumber");
    // debugPrint("Unit: $unit");
    // debugPrint("Product Properties: ${jsonEncode(productProperties)}");

    final Map<String, dynamic> apiBodyData = {
      'product_id': productId,
      'store_id': storeId,
      'quantity': quantity,
      'purchase_rate': purchaseRate,
      'retail_price': retailPrice,
      'wholesale_price': wholesalePrice,
      'wholesale_min_unit': wholesaleMinUnit,
      'expiry_date': expiryDate,
      'unit': unit,
      'batch_number': batchNumber,
      'product_properties': jsonEncode(productProperties),
      'tax_include': "N"
    };

    // debugPrint("API Body Data: ${apiBodyData.toString()}");
    final url = Uri.parse(APPUrl.addToStock);
    try {
      final response = await http.post(url,
          body: json.encode(apiBodyData),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json'
          });

      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(json.decode(response.body).toString());
        // debugPrint(json.decode(response.body).toString());
        listAllProducts();
        listAllProductsAPI();
        notifyListeners();
        return json.decode(response.body);
      }
    } catch (e) {
      // Handle any exceptions that occur during the API call
      return {
        'status': "failed",
        'message': e.toString(), // Print the exact error
      };
    }
  }

  //          *********************** LIST STOCK  API ***************************************************

  Future<void> listSTockAPI({
    required String accessToken,
    String? filterName,
    int? page,
    bool loadAll = false, // Add parameter to load all stocks
  }) async {
    _stockIsLoading = true;
    notifyListeners();
    
    final queryParameters = <String, String>{
      'page': (page ?? 1).toString(),
      // If loadAll is true, request a large page size to get all stocks
      if (loadAll) 'per_page': '1000',
    };

    if (filterName != null && filterName.isNotEmpty) {
      queryParameters['filter_name'] = filterName;
    }

    final uri = Uri.parse(APPUrl.listStock).replace(queryParameters: queryParameters);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('inside listSTockAPI ${response.statusCode}');

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final jsonData = json.decode(response.body);
          // debugPrint('Received JSON data: ${jsonData.toString()}');

          // Detailed error handling for JSON parsing
          try {
            stock_models.ListStockModel listStockModel = stock_models.ListStockModel.fromJson(jsonData);
            
            if (loadAll) {
              // Store all stocks for local filtering and pagination
              _allStocks = listStockModel.data;
              applyStockFiltersLocally(page: 1);
            } else {
              listStockModelDataList = listStockModel.data;
              filteredStockList = List<stock_models.ListStockModelData>.from(listStockModelDataList!);
              
              stockCurrentPage = listStockModel.pagination?.currentPage ?? 1;
              // Calculate total pages based on total items and per_page
              int totalItems = listStockModel.pagination?.lastPage ?? 0;
              int itemsPerPage = listStockModel.pagination?.perPage ?? 20;
              stockTotalPages = (totalItems / itemsPerPage).ceil();
            }

            notifyListeners();
          } catch (e) {
            debugPrint('Error parsing JSON data: $e');
            if (jsonData is Map) {
              jsonData.forEach((key, value) {
                debugPrint('Key: $key, Value type: ${value.runtimeType}');
              });
            }
            throw Exception('Failed to parse stock list data: $e');
          }
        } else {
          debugPrint('Empty response body');
          throw Exception('Received empty response');
        }
      } else {
        debugPrint(
            'Failed to load stock list: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load stock list');
      }
    } catch (error) {
      debugPrint('Error in listSTockAPI: $error');
      rethrow;
    } finally {
      _stockIsLoading = false;
      notifyListeners();
    }
  }
  
  // Load all stocks for local filtering
  Future<void> loadAllStocks(String accessToken) async {
    try {
      await listSTockAPI(
        accessToken: accessToken,
        loadAll: true,
      );
    } catch (error) {
      debugPrint('Error loading all stocks: $error');
      rethrow;
    }
  }
  
  // Apply local pagination and filtering for stocks
  void applyStockFiltersLocally({
    String? filterName,
    String? filterCategory,
    int page = 1,
  }) {
    if (_allStocks == null || _allStocks!.isEmpty) {
      listStockModelDataList = [];
      filteredStockList = [];
      stockCurrentPage = 1;
      stockTotalPages = 1;
      notifyListeners();
      return;
    }

    // Save filter values
    _stockFilterName = filterName;
    _stockFilterCategory = filterCategory;
    stockCurrentPage = page;

    // Apply filters
    List<stock_models.ListStockModelData> filteredList = [..._allStocks!];
    
    if (filterName != null && filterName.isNotEmpty) {
      filteredList = filteredList.where((stock) => 
        stock.productName != null && 
        stock.productName!.toLowerCase().contains(filterName.toLowerCase())
      ).toList();
    }
    
    // Apply category filter
    if (filterCategory != null && filterCategory.isNotEmpty && filterCategory != "0") {
      filteredList = filteredList.where((stock) => 
        stock.categoryName != null && 
        stock.categoryName!.toLowerCase() == filterCategory.toLowerCase()
      ).toList();
    }

    // Calculate pagination
    stockTotalPages = (filteredList.length / _stockItemsPerPage).ceil();
    stockTotalPages = stockTotalPages == 0 ? 1 : stockTotalPages;
    
    // Ensure current page is valid
    if (stockCurrentPage > stockTotalPages) {
      stockCurrentPage = stockTotalPages;
    }
    
    // Apply pagination
    int startIndex = (stockCurrentPage - 1) * _stockItemsPerPage;
    int endIndex = startIndex + _stockItemsPerPage;
    
    if (startIndex >= filteredList.length) {
      listStockModelDataList = [];
      filteredStockList = [];
    } else {
      endIndex = endIndex > filteredList.length ? filteredList.length : endIndex;
      listStockModelDataList = filteredList.sublist(startIndex, endIndex);
      filteredStockList = List<stock_models.ListStockModelData>.from(listStockModelDataList!);
    }
    
    notifyListeners();
  }
  
  // Reset stock filters and pagination
  void resetStockFilters() {
    _stockFilterName = null;
    _stockFilterCategory = null;
    stockCurrentPage = 1;
    
    if (_allStocks != null && _allStocks!.isNotEmpty) {
      applyStockFiltersLocally(page: 1);
    }
  }
  
  // Change stock page
  void goToStockPage(int page) {
    if (page < 1 || page > stockTotalPages) return;
    
    applyStockFiltersLocally(
      filterName: _stockFilterName,
      filterCategory: _stockFilterCategory,
      page: page
    );
  }

  //          *********************** CALL VIEW STOCK DETAILS  API ***************************************************

  void callStockDetails(
      {required int stockId, required String accessToken}) async {
    // debugPrint("stockId $stockId ");

    final url = Uri.parse("${APPUrl.detailsOfStock}?id=$stockId");
    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json'
      });

      // debugPrint('inside  listSTockAPI ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(json.decode(response.body).toString());
        final jsonData = json.decode(response.body);

        stock_models.ListStockModelData listStockModel =
            stock_models.ListStockModelData.fromJson(jsonData["data"]);
        //  listStockModelDataList = listStockModel.data;
        // ListStockModelData? stockDetails = listStockModelDataList!.firstWhere(
        //   (element) => element.id == stockId,
        // );
        viewStockModelData = listStockModel;

        notifyListeners();
      } else {
        // return error;
      }
    } finally {}
  }

  //          *********************** UPDATE STOCK DETAILS API ***************************************************
  
  Future<bool> updateStockDetails({
    required int stockId,
    required String retailPrice,
    required String mrp,
    required String purchasePrice,
    required String quantity,
    required String rack,
    required String accessToken,
  }) async {
    try {
      final url = Uri.parse('${APPUrl.updateStockDetails}/$stockId');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'retail_price': retailPrice,
          'mrp': mrp,
          'purchase_price': purchasePrice,
          'quantity': quantity,
          'rack': rack,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          // Refresh the stock list after successful update
          await loadAllStocks(accessToken);
          return true;
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('Error updating stock details: $e');
      return false;
    }
  }
}
