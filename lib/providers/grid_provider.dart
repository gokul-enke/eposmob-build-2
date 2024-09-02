import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/get_product.dart';
import '../models/list_stock.dart';
import '../resources/app_url.dart';
import 'package:http/http.dart' as http;

class GridSelectionProvider extends ChangeNotifier {
  List<GetProduct>? productList = [];
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
  List<ListStockModelData>? listStockModelDataList = [];
  List<ListStockModelData>? filteredStockList = [];
  List<ListStockModelData>? get getListStockModelDataList =>
      filteredStockList ?? listStockModelDataList;
  ListStockModelData? viewStockModelData;

  ListStockModelData? get getViewStockModelData => viewStockModelData;
  String productNameFromProductId(int value) {
    var product = productList!.firstWhere(
      (product) => product.productId == value,
    );

    return product.productName ?? "";
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

  void searchStocks(String query) {
    if (query.isEmpty) {
      filteredStockList = listStockModelDataList;
    } else {
      filteredStockList = listStockModelDataList?.where((stock) {
        final productNameLower = stock.productName?.toLowerCase() ?? '';
        final storeNameLower = stock.storeName?.toLowerCase() ?? '';
        final queryLower = query.toLowerCase();

        return productNameLower.contains(queryLower) ||
            storeNameLower.contains(queryLower);
      }).toList();
    }
    notifyListeners();
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
    debugPrint("LIST ALL PRODUCTS categoryId $categoryId");

    // Build query parameters
    final queryParams = <String, String>{
      if (filterName != null) 'filter_name': filterName,
      if (filterCategory != null && filterCategory != "0")
        'filter_category': filterCategory,
      if (filterPrice != null) 'filter_price': filterPrice,
      if (filterCreatedBy != null) 'filter_created_by': filterCreatedBy,
      if (filterProperties != null) 'filter_properties': filterProperties,
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
        Uri.parse(APPUrl.getProcductUrl).replace(queryParameters: queryParams);
    try {
      final response = await http.get(url);

      debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        debugPrint('inside product 200 ${response.body.toString()}');

        // debugPrint(json.decode(response.body).toString());
        final jsonData = json.decode(response.body);
        GetProductModel getProductModel = GetProductModel.fromJson(jsonData);

        productList = getProductModel.product;
        filteredProductList = getProductModel.product;
        mainProductList = getProductModel.product;
        categoryProductList = getProductModel.product;
        // selectedCategoryId =
        //     productList!.isEmpty ? 0 : productList![0].categoryId ?? 0;
        notifyListeners();
        // debugPrint('List Product Name in Category Provider');
      } else {
        debugPrint('outside product 200 ${response.body.toString()}');
        debugPrint('outside product 200 ${response.statusCode}');
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
  //          *********************** LIST ALL PRODUCTS  API ***************************************************

  Future<void> listAllProductsAPI({int? categoryId}) async {
    debugPrint("LIST ALL PRODUCTS categoryId $categoryId ");
    final Map<String, dynamic> apiBodyData = {
      'category_id': categoryId == 0 ? null : categoryId,
    };
    isLoading = true;
    // selectedCategoryId = categoryId;
    notifyListeners();
    selectedProductListAPI = [];
    final url = Uri.parse(APPUrl.getProcductUrl);
    try {
      final response = await http.post(url,
          body: json.encode(apiBodyData),
          headers: {'Content-Type': 'application/json'});
      debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint('inside');

        // debugPrint(json.decode(response.body).toString());
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

  //          *********************** LIST ALL PRODUCTS FUNCTION RETURNING PRODUCT LIST API ***************************************************

  Future<List<GetProduct>> listAllProductList({required int categoryId}) async {
    List<GetProduct> productLists = [];
    debugPrint("LIST ALL PRODUCTS  categoryId $categoryId ");
    final Map<String, dynamic> apiBodyData = {
      'category_id': categoryId == 0 ? null : categoryId,
    };
    isLoading = true;
    selectedCategoryId = categoryId;
    notifyListeners();
    productList = [];
    final url = Uri.parse(APPUrl.getProcductUrl);
    try {
      final response = await http.post(url,
          body: json.encode(apiBodyData),
          headers: {'Content-Type': 'application/json'});
      debugPrint('inside ${response.statusCode}');
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
    debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.addProductUrl);
    try {
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        debugPrint(json.decode(response.body).toString());
        debugPrint(json.decode(response.body).toString());
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
    debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.addProductNameUrl);
    try {
      final response = await http.post(url, body: apiBodyData, headers: {
        // 'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        debugPrint(json.decode(response.body).toString());
        debugPrint(json.decode(response.body).toString());
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

    debugPrint("add prop body ${apiBodyData.toString()}");

//     Two keys in a map literal shouldn't be equal.
// Change or remove the duplicate key.
    final Map<String, dynamic> error = {
      'status': "failed",
      'message': "Something went wrong, Please try Again!"
    };
    debugPrint("apiBodyData + ${apiBodyData.toString()}");
    final url = Uri.parse(APPUrl.addProductPropsUrl);
    try {
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        debugPrint(json.decode(response.body).toString());
        debugPrint(json.decode(response.body).toString());
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
    debugPrint("apiBodyData + ${apiBodyData.toString()}" + filePath);
    final Map<String, dynamic> error = {
      'status': "failed",
      'message': "Something went wrong, Please try Again!"
    };
    debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.addProductImageUrl);
    try {
      final response = await http.post(url, body: apiBodyData, headers: {
        //  'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        debugPrint(json.decode(response.body).toString());
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
    debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.editProductUrl);
    try {
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        debugPrint(json.decode(response.body).toString());
        debugPrint(json.decode(response.body).toString());
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
    print({
      'product_id': productId,
      'product_lang_name[ar]': productNameEnglish,
      'product_lang_name[hi]': productNameHindi,
      'product_lang_name[en]': productNameArabic,
    });
    final Map<String, dynamic> error = {
      'status': "failed",
      'message': "Something went wrong, Please try Again!"
    };

    debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.editProductNameUrl);
    try {
      final response = await http.post(url, body: apiBodyData, headers: {
        // 'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        debugPrint(json.decode(response.body).toString());
        debugPrint(json.decode(response.body).toString());
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

    debugPrint("edit prop body ${apiBodyData.toString()}");
//     Two keys in a map literal shouldn't be equal.
// Change or remove the duplicate key.
    final Map<String, dynamic> error = {
      'status': "failed",
      'message': "Something went wrong, Please try Again!"
    };
    debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.editProductPropsUrl);
    try {
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        debugPrint(json.decode(response.body).toString());
        debugPrint(json.decode(response.body).toString());
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
    debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.editProductImageUrl);
    try {
      final response = await http.post(url, body: apiBodyData, headers: {
        //  'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        debugPrint(json.decode(response.body).toString());

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

      debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        debugPrint(json.decode(response.body).toString());
        debugPrint(json.decode(response.body).toString());
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
    final Map<String, dynamic> error = {
      'status': "failed",
      'message': "Something went wrong, Please try Again!"
    };

    debugPrint("date ${expiryDate.toString()}");
    debugPrint("productProperties ${jsonEncode(productProperties).toString()}");

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
    debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.addToStock);
    try {
      final response = await http.post(url,
          body: json.encode(apiBodyData),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json'
          });

      debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        debugPrint(json.decode(response.body).toString());
        debugPrint(json.decode(response.body).toString());
        listAllProducts();
        listAllProductsAPI();
        notifyListeners();
        return json.decode(response.body);
      } else {
        return error;
      }
    } finally {}
  }

  //          *********************** LIST STOCK  API ***************************************************

  Future<void> listSTockAPI({
    required String accessToken,
    String? filterName,
    int? page,
  }) async {
    final queryParameters = <String, String>{
      'page': page.toString(),
    };

    if (filterName != null && filterName.isNotEmpty) {
      queryParameters['filter_name'] = filterName;
    }

    final uri =
        Uri.parse(APPUrl.listStock).replace(queryParameters: queryParameters);

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
          debugPrint('Received JSON data: ${jsonData.toString()}');

          // Detailed error handling for JSON parsing
          try {
            ListStockModel listStockModel = ListStockModel.fromJson(jsonData);
            listStockModelDataList = listStockModel.data;
            filteredStockList =
                List<ListStockModelData>.from(listStockModelDataList!);
            notifyListeners();
          } catch (e) {
            debugPrint('Error parsing JSON data: $e');
            debugPrint('JSON structure: ${jsonData.runtimeType}');
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
    }
  }
  //          *********************** CALL VIEW STOCK DETAILS  API ***************************************************

  void callStockDetails(
      {required int stockId, required String accessToken}) async {
    debugPrint("stockId $stockId ");

    final url = Uri.parse("${APPUrl.detailsOfStock}?id=$stockId");
    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json'
      });

      debugPrint('inside  listSTockAPI ${response.statusCode}');
      if (response.statusCode == 200) {
        debugPrint(json.decode(response.body).toString());
        final jsonData = json.decode(response.body);

        ListStockModelData listStockModel =
            ListStockModelData.fromJson(jsonData["data"]);
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
}
