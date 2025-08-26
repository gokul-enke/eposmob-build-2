import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../models/list_stock.dart' as stock_models;
import '../providers/local_product_provider.dart';
import '../resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dedicated provider for managing all stock-related operations
/// This provider handles:
/// - Stock listing and pagination
/// - Stock filtering and searching
/// - Adding new stock entries
/// - Updating existing stock details
/// - Stock details retrieval
class StockProvider extends ChangeNotifier {
  // Stock data management
  List<stock_models.ListStockModelData>? _listStockModelDataList = [];
  List<stock_models.ListStockModelData>? _allStocks =
      []; // Store all stocks for local filtering
  List<stock_models.ListStockModelData>? _filteredStockList = [];
  stock_models.ListStockModelData? _viewStockModelData;

  // Pagination properties
  int _stockCurrentPage = 1;
  int _stockTotalPages = 1;
  int _stockItemsPerPage = 20;

  // Filter properties
  String? _stockFilterName;
  String? _stockFilterCategory;
  String? _stockFilterBarcode;
  String? _stockFilterRack;
  String? _stockFilterStore;

  // Loading state
  bool _stockIsLoading = false;

  // Getters
  List<stock_models.ListStockModelData>? get listStockModelDataList =>
      _filteredStockList ?? _listStockModelDataList;

  List<stock_models.ListStockModelData>? get allStocks => _allStocks;

  stock_models.ListStockModelData? get viewStockModelData =>
      _viewStockModelData;

  int get stockCurrentPage => _stockCurrentPage;
  int get stockTotalPages => _stockTotalPages;
  int get stockItemsPerPage => _stockItemsPerPage;
  String? get stockFilterCategory => _stockFilterCategory;
  String? get stockFilterName => _stockFilterName;
  String? get stockFilterBarcode => _stockFilterBarcode;
  String? get stockFilterRack => _stockFilterRack;
  String? get stockFilterStore => _stockFilterStore;
  bool get stockIsLoading => _stockIsLoading;

  /// Search stocks locally by name
  void searchStocks(String query) {
    if (_allStocks == null || _allStocks!.isEmpty) {
      return;
    }

    applyStockFiltersLocally(filterName: query, page: 1);
  }

  /// Extract unique categories from loaded stocks
  List<String> getUniqueCategories() {
    if (_allStocks == null || _allStocks!.isEmpty) {
      return ["All Categories"];
    }

    final uniqueCategories = _allStocks!
        .map((stock) => stock.categoryName ?? "")
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList();

    uniqueCategories.sort();
    return ["All Categories", ...uniqueCategories];
  }

  /// Extract unique stores from loaded stocks
  List<String> getUniqueStores() {
    if (_allStocks == null || _allStocks!.isEmpty) {
      return ["All Stores"];
    }

    final uniqueStores = _allStocks!
        .map((stock) => stock.storeName ?? "")
        .where((store) => store.isNotEmpty)
        .toSet()
        .toList();

    uniqueStores.sort();
    return ["All Stores", ...uniqueStores];
  }

  /// *********************** ADD TO STOCK API ***************************************************

  Future<dynamic> addProductStockAPI({
    required String accessToken,
    required String productId,
    required String categoryId,
    required String quantity,
    required String retailPrice,
    required String purchaseRate,
    required String mrp,
    required String wholesalePrice,
    required String unit,
    required String supplierId,
    required String storeId,
    required String expiryDate,
    required String userId,
    String? purchaseVoucherId,
    String? purchaseId,
    String? taxAmountRetail,
    String? taxAmountWholesale,
    required String wholesaleMinUnit,
    required String rack,
    required String barcode,
    required String batchNumber,
    required String date,
    required String purchaseDate,
    String? purchaseNumber,
    required bool taxInclude,
    required String initialRetailPrice,
    required String initialWholesalePrice,
    String? retailPriceTax,
    String? wholesalePriceTax,
    BuildContext? context, // Add optional context for manual updates
  }) async {
    final Map<String, dynamic> apiBodyData = {
      'product_id': int.parse(productId),
      'category_id': int.parse(categoryId),
      'quantity': int.parse(quantity),
      'retail_price': double.parse(retailPrice),
      'purchase_rate': double.parse(purchaseRate),
      'mrp': mrp.isNotEmpty ? double.parse(mrp) : double.parse(retailPrice),
      'wholesale_price': wholesalePrice.isNotEmpty
          ? double.parse(wholesalePrice)
          : double.parse(retailPrice),
      'unit': unit,
      'supplier_id': int.parse(supplierId),
      'store_id': int.parse(storeId),
      'expiry_date': expiryDate,
      'user_id': int.parse(userId),
      'purchase_voucher_id': purchaseVoucherId,
      'purchase_id': purchaseId,
      'tax_amount_retail': taxAmountRetail,
      'tax_amount_wholesale': taxAmountWholesale,
      'wholesale_min_unit':
          wholesaleMinUnit.isNotEmpty ? int.parse(wholesaleMinUnit) : 1,
      'rack': rack,
      'barcode': barcode,
      'batch_number': batchNumber,
      'date': date,
      'purchase_date': purchaseDate,
      'purchase_number': purchaseNumber,
      'tax_include': taxInclude,
      'initial_retail_price': double.parse(initialRetailPrice),
      'initial_wholesale_price': initialWholesalePrice.isNotEmpty
          ? double.parse(initialWholesalePrice)
          : double.parse(retailPrice),
      'retail_price_tax': retailPriceTax,
      'wholesale_price_tax': wholesalePriceTax,
    };

    debugPrint('📦 ADD STOCK API REQUEST BODY: ${json.encode(apiBodyData)}');

    final url = Uri.parse(APPUrl.addToStock);
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

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        // ✅ FAST UPDATE: Manually update LocalProductProvider instead of full API fetch
        if (context != null) {
          try {
            final localProductProvider =
                Provider.of<LocalProductProvider>(context, listen: false);

            // Extract stock ID from response (adjust based on your API response structure)
            int stockId;
            if (result['data'] != null && result['data']['id'] != null) {
              stockId = result['data']['id'];
            } else if (result['stock_id'] != null) {
              stockId = result['stock_id'];
            } else if (result['id'] != null) {
              stockId = result['id'];
            } else {
              stockId = DateTime.now().millisecondsSinceEpoch; // Fallback ID
            }

            // Manually update the product stock in LocalProductProvider
            localProductProvider.addStockToProduct(
              productId: int.parse(productId),
              stockId: stockId,
              quantity: num.parse(quantity),
              price: retailPrice,
              mrp: mrp,
              purchasePrice: purchaseRate,
            );
          } catch (e) {
            debugPrint("Error updating local product provider: $e");
          }
        }

        return result;
      } else {
        // Capture the response body even on non-200 status for debugging
        debugPrint(
            '❌ ADD PRODUCT STOCK API FAILED (Status: ${response.statusCode})');
        debugPrint('   - Response Body: ${response.body}');
        return {'status': 'failed', 'message': response.body};
      }
    } catch (e) {
      debugPrint("Error in addProductStockAPI: $e");
      return {'status': 'failed', 'message': 'Error: ${e.toString()}'};
    }
  }

  //          *********************** CALCULATE TAX API ***************************************************

  Future<Map<String, dynamic>?> calculateTaxAPI({
    required String accessToken,
    required double price,
    required int productId,
    required int categoryId,
    required bool taxInclude,
  }) async {
    debugPrint("CALCULATE TAX API CALLED");
    final queryParameters = <String, String>{
      'price': price.toString(),
      'product_id': productId.toString(),
      'tax_include': taxInclude ? '1' : '0',
      'category_id': categoryId.toString(),
    };

    final url = Uri.parse(APPUrl.calculateTax)
        .replace(queryParameters: queryParameters);
    debugPrint("Tax API URL: $url");

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });

      debugPrint('Calculate Tax API response status: ${response.statusCode}');
      debugPrint('Calculate Tax API response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == 'success' && result['data'] != null) {
          return Map<String, dynamic>.from(result['data']);
        } else {
          debugPrint(
              'Failed to calculate tax: ${result['message'] ?? 'Unknown error'}');
          return null;
        }
      } else {
        debugPrint(
            'Calculate Tax API failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error in calculateTaxAPI: $e');
      return null;
    }
  }

  /// *********************** LIST STOCK API ***************************************************

  Future<void> listStockAPI({
    required String accessToken,
    String? filterName,
    int? page,
    bool loadAll = false,
  }) async {
    _stockIsLoading = true;
    notifyListeners();

    final queryParameters = <String, String>{
      'page': (page ?? 1).toString(),
      if (loadAll) 'per_page': '1000',
    };

    if (filterName != null && filterName.isNotEmpty) {
      queryParameters['filter_name'] = filterName;
    }

    final uri =
        Uri.parse(APPUrl.listStock).replace(queryParameters: queryParameters);

    try {
      // Get API key from SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found. Please restart the app.");
      }
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Stock API Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final jsonData = json.decode(response.body);

          try {
            stock_models.ListStockModel listStockModel =
                stock_models.ListStockModel.fromJson(jsonData);

            if (loadAll) {
              _allStocks = listStockModel.data;
              applyStockFiltersLocally(page: 1);
            } else {
              _listStockModelDataList = listStockModel.data;
              _filteredStockList = List<stock_models.ListStockModelData>.from(
                  _listStockModelDataList!);

              _stockCurrentPage = listStockModel.pagination?.currentPage ?? 1;
              int totalItems = listStockModel.pagination?.lastPage ?? 0;
              int itemsPerPage = listStockModel.pagination?.perPage ?? 20;
              _stockTotalPages = (totalItems / itemsPerPage).ceil();
            }

            notifyListeners();
          } catch (e) {
            debugPrint('Error parsing stock data: $e');
            throw Exception('Failed to parse stock list data: $e');
          }
        } else {
          debugPrint('Empty response body');
          throw Exception('Received empty response');
        }
      } else {
        debugPrint('Failed to load stock list: ${response.statusCode}');
        throw Exception('Failed to load stock list');
      }
    } catch (error) {
      debugPrint('Error in listStockAPI: $error');
      rethrow;
    } finally {
      _stockIsLoading = false;
      notifyListeners();
    }
  }

  /// Load all stocks for local filtering and pagination
  Future<void> loadAllStocks(String accessToken) async {
    try {
      await listStockAPI(
        accessToken: accessToken,
        loadAll: true,
      );
    } catch (error) {
      debugPrint('Error loading all stocks: $error');
      rethrow;
    }
  }

  /// Apply local pagination and filtering for stocks
  void applyStockFiltersLocally({
    String? filterName,
    String? filterCategory,
    String? filterBarcode,
    String? filterRack,
    String? filterStore,
    int page = 1,
  }) {
    if (_allStocks == null || _allStocks!.isEmpty) {
      _listStockModelDataList = [];
      _filteredStockList = [];
      _stockCurrentPage = 1;
      _stockTotalPages = 1;
      notifyListeners();
      return;
    }

    // Save filter values
    _stockFilterName = filterName;
    _stockFilterCategory = filterCategory;
    _stockFilterBarcode = filterBarcode;
    _stockFilterRack = filterRack;
    _stockFilterStore = filterStore;
    _stockCurrentPage = page;

    // Apply filters
    List<stock_models.ListStockModelData> filteredList = [..._allStocks!];

    // Apply name filter
    if (filterName != null && filterName.isNotEmpty) {
      filteredList = filteredList
          .where((stock) =>
              stock.productName != null &&
              stock.productName!
                  .toLowerCase()
                  .contains(filterName.toLowerCase()))
          .toList();
    }

    // Apply category filter
    if (filterCategory != null &&
        filterCategory.isNotEmpty &&
        filterCategory != "All Categories") {
      filteredList = filteredList
          .where((stock) =>
              stock.categoryName != null &&
              stock.categoryName!.toLowerCase() == filterCategory.toLowerCase())
          .toList();
    }

    // Apply barcode filter
    if (filterBarcode != null && filterBarcode.isNotEmpty) {
      filteredList = filteredList
          .where((stock) =>
              stock.barCode != null &&
              stock.barCode!
                  .toLowerCase()
                  .contains(filterBarcode.toLowerCase()))
          .toList();
    }

    // Apply rack filter
    if (filterRack != null && filterRack.isNotEmpty) {
      filteredList = filteredList
          .where((stock) =>
              stock.rack != null &&
              stock.rack!.toLowerCase().contains(filterRack.toLowerCase()))
          .toList();
    }

    // Apply store filter
    if (filterStore != null &&
        filterStore.isNotEmpty &&
        filterStore != "All Stores") {
      filteredList = filteredList
          .where((stock) =>
              stock.storeName != null &&
              stock.storeName!.toLowerCase() == filterStore.toLowerCase())
          .toList();
    }

    // Calculate pagination
    _stockTotalPages = (filteredList.length / _stockItemsPerPage).ceil();
    _stockTotalPages = _stockTotalPages == 0 ? 1 : _stockTotalPages;

    // Ensure current page is valid
    if (_stockCurrentPage > _stockTotalPages) {
      _stockCurrentPage = _stockTotalPages;
    }

    // Apply pagination
    int startIndex = (_stockCurrentPage - 1) * _stockItemsPerPage;
    int endIndex = startIndex + _stockItemsPerPage;

    if (startIndex >= filteredList.length) {
      _listStockModelDataList = [];
      _filteredStockList = [];
    } else {
      endIndex =
          endIndex > filteredList.length ? filteredList.length : endIndex;
      _listStockModelDataList = filteredList.sublist(startIndex, endIndex);
      _filteredStockList =
          List<stock_models.ListStockModelData>.from(_listStockModelDataList!);
    }

    notifyListeners();
  }

  /// Reset stock filters and pagination
  void resetStockFilters() {
    _stockFilterName = null;
    _stockFilterCategory = null;
    _stockFilterBarcode = null;
    _stockFilterRack = null;
    _stockFilterStore = null;
    _stockCurrentPage = 1;

    if (_allStocks != null && _allStocks!.isNotEmpty) {
      applyStockFiltersLocally(page: 1);
    }
  }

  /// Change stock page
  void goToStockPage(int page) {
    if (page < 1 || page > _stockTotalPages) return;

    applyStockFiltersLocally(
      filterName: _stockFilterName,
      filterCategory: _stockFilterCategory,
      filterBarcode: _stockFilterBarcode,
      filterRack: _stockFilterRack,
      filterStore: _stockFilterStore,
      page: page,
    );
  }

  /// *********************** CALL VIEW STOCK DETAILS API ***************************************************

  Future<void> callStockDetails(
      {required int stockId, required String accessToken}) async {
    final url = Uri.parse("${APPUrl.detailsOfStock}?id=$stockId");
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      });

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        _viewStockModelData =
            stock_models.ListStockModelData.fromJson(jsonData["data"]);
        notifyListeners();
      } else {
        debugPrint('Failed to load stock details: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading stock details: $e');
    }
  }

  /// *********************** UPDATE STOCK DETAILS API ***************************************************

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
      // Get API key from SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found. Please restart the app.");
      }
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
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

  /// Clear all stock data
  void clearStockData() {
    _listStockModelDataList = [];
    _allStocks = [];
    _filteredStockList = [];
    _viewStockModelData = null;
    _stockCurrentPage = 1;
    _stockTotalPages = 1;
    _stockFilterName = null;
    _stockFilterCategory = null;
    _stockFilterBarcode = null;
    _stockFilterRack = null;
    _stockFilterStore = null;
    _stockIsLoading = false;
    notifyListeners();
  }
}