import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/list_stock.dart' as stock_models;
import '../resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dedicated provider for managing all stock-related operations
/// This provider handles:
/// - Stock listing and pagination
/// - Stock filtering and searching
/// - Adding new stock entries (locally and batch processing)
/// - Updating existing stock details
/// - Stock details retrieval
class StockProvider extends ChangeNotifier {
  // Stock data management
  List<stock_models.ListStockModelData>? _listStockModelDataList = [];
  List<stock_models.ListStockModelData>? _allStocks =
      []; // Store all stocks for local filtering
  List<stock_models.ListStockModelData>? _filteredStockList = [];
  stock_models.ListStockModelData? _viewStockModelData;

  // Local pending stock items for batch processing
  List<Map<String, dynamic>> _pendingStockItems = [];
  List<Map<String, dynamic>> _processedStockItems = [];

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
  bool _batchProcessingLoading = false;

  // Getters
  List<stock_models.ListStockModelData>? get listStockModelDataList =>
      _filteredStockList ?? _listStockModelDataList;

  List<Map<String, dynamic>> get pendingStockItems => _pendingStockItems;
  List<Map<String, dynamic>> get processedStockItems => _processedStockItems;
  bool get batchProcessingLoading => _batchProcessingLoading;

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

  /// *********************** LOCAL STOCK MANAGEMENT ***************************************************
  
  /// Validate stock item locally before adding to pending list
  Map<String, String?> validateStockItem(Map<String, dynamic> stockItem) {
    Map<String, String?> errors = {};
    
    // Required field validations
    if (stockItem['productId'] == null || stockItem['productId'].toString().isEmpty) {
      errors['product'] = 'Product is required';
    }
    
    if (stockItem['categoryId'] == null || stockItem['categoryId'].toString().isEmpty) {
      errors['category'] = 'Category is required';
    }
    
    if (stockItem['quantity'] == null || stockItem['quantity'].toString().isEmpty) {
      errors['quantity'] = 'Quantity is required';
    } else {
      final qty = double.tryParse(stockItem['quantity'].toString());
      if (qty == null || qty <= 0) {
        errors['quantity'] = 'Quantity must be a positive number';
      }
    }
    
    if (stockItem['retailPrice'] == null || stockItem['retailPrice'].toString().isEmpty) {
      errors['retailPrice'] = 'Retail price is required';
    } else {
      final price = double.tryParse(stockItem['retailPrice'].toString());
      if (price == null || price <= 0) {
        errors['retailPrice'] = 'Retail price must be a positive number';
      }
    }
    
    if (stockItem['purchaseRate'] == null || stockItem['purchaseRate'].toString().isEmpty) {
      errors['purchaseRate'] = 'Purchase rate is required';
    } else {
      final price = double.tryParse(stockItem['purchaseRate'].toString());
      if (price == null || price <= 0) {
        errors['purchaseRate'] = 'Purchase rate must be a positive number';
      }
    }
    
    if (stockItem['unit'] == null || stockItem['unit'].toString().isEmpty) {
      errors['unit'] = 'Unit is required';
    }
    
    if (stockItem['expiryDate'] == null) {
      errors['expiryDate'] = 'Expiry date is required';
    }
    
    // Optional validations with defaults
    if (stockItem['mrp'] != null && stockItem['mrp'].toString().isNotEmpty) {
      final mrp = double.tryParse(stockItem['mrp'].toString());
      if (mrp == null || mrp <= 0) {
        errors['mrp'] = 'MRP must be a positive number';
      }
    }
    
    if (stockItem['wholesalePrice'] != null && stockItem['wholesalePrice'].toString().isNotEmpty) {
      final price = double.tryParse(stockItem['wholesalePrice'].toString());
      if (price == null || price <= 0) {
        errors['wholesalePrice'] = 'Wholesale price must be a positive number';
      }
    }
    
    return errors;
  }
  
  /// Add stock item to local pending list with validation
  bool addStockItemLocally(Map<String, dynamic> stockItem) {
    debugPrint('🔄 ADDING STOCK ITEM LOCALLY');
    debugPrint('   - Stock Item Data: $stockItem');
    
    // Validate the stock item
    Map<String, String?> validationErrors = validateStockItem(stockItem);
    
    if (validationErrors.isNotEmpty) {
      debugPrint('❌ VALIDATION FAILED:');
      validationErrors.forEach((field, error) {
        debugPrint('   - $field: $error');
      });
      return false;
    }
    
    // Add timestamp and unique ID for tracking
    stockItem['localId'] = DateTime.now().millisecondsSinceEpoch.toString();
    stockItem['addedAt'] = DateTime.now().toIso8601String();
    stockItem['status'] = 'pending'; // pending, processing, success, failed
    
    _pendingStockItems.add(stockItem);
    notifyListeners();
    
    debugPrint('✅ STOCK ITEM ADDED TO PENDING LIST');
    debugPrint('   - Total pending items: ${_pendingStockItems.length}');
    
    return true;
  }
  
  /// Remove stock item from pending list
  void removeStockItemLocally(String localId) {
    _pendingStockItems.removeWhere((item) => item['localId'] == localId);
    notifyListeners();
    debugPrint('🗑️ REMOVED STOCK ITEM FROM PENDING LIST: $localId');
  }

  /// Update existing stock item in pending list
  bool updateStockItemLocally(String localId, Map<String, dynamic> updatedData) {
    debugPrint('🔄 UPDATING STOCK ITEM LOCALLY');
    debugPrint('   - Local ID: $localId');
    debugPrint('   - Updated Data: $updatedData');
    
    // Find the item in pending list
    int index = _pendingStockItems.indexWhere((item) => item['localId'] == localId);
    
    if (index == -1) {
      debugPrint('❌ STOCK ITEM NOT FOUND IN PENDING LIST: $localId');
      return false;
    }
    
    // Validate the updated data
    Map<String, String?> validationErrors = validateStockItem(updatedData);
    
    if (validationErrors.isNotEmpty) {
      debugPrint('❌ UPDATE VALIDATION FAILED:');
      validationErrors.forEach((field, error) {
        debugPrint('   - $field: $error');
      });
      return false;
    }
    
    // Update the item while preserving original metadata
    final originalItem = _pendingStockItems[index];
    _pendingStockItems[index] = {
      ...updatedData,
      'localId': originalItem['localId'], // Preserve original ID
      'addedAt': originalItem['addedAt'], // Preserve original timestamp
      'status': originalItem['status'], // Preserve status
      'updatedAt': DateTime.now().toIso8601String(), // Add update timestamp
    };
    
    notifyListeners();
    
    debugPrint('✅ STOCK ITEM UPDATED IN PENDING LIST');
    debugPrint('   - Local ID: $localId');
    
    return true;
  }
  
  /// Get stock item from pending list by local ID
  Map<String, dynamic>? getPendingStockItem(String localId) {
    try {
      return _pendingStockItems.firstWhere((item) => item['localId'] == localId);
    } catch (e) {
      return null;
    }
  }
  
  /// Clear all pending stock items
  void clearPendingStockItems() {
    _pendingStockItems.clear();
    _processedStockItems.clear();
    notifyListeners();
    debugPrint('🧹 CLEARED ALL PENDING STOCK ITEMS');
  }
  
  /// Get pending stock items count
  int get pendingStockItemsCount => _pendingStockItems.length;
  
  /// Get processed stock items count
  int get processedStockItemsCount => _processedStockItems.length;
  
  /// Get failed stock items count
  int get failedStockItemsCount => _pendingStockItems.where((item) => item['status'] == 'failed').length;
  
  /// Reset failed items status to pending for retry
  void resetFailedItemsForRetry() {
    for (var item in _pendingStockItems) {
      if (item['status'] == 'failed') {
        item['status'] = 'pending';
      }
    }
    notifyListeners();
    debugPrint('🔄 RESET ${failedStockItemsCount} FAILED ITEMS TO PENDING FOR RETRY');
  }
  
  /// *********************** BATCH PROCESS STOCK ITEMS ***************************************************
  
  /// Process all pending stock items via API calls
  Future<Map<String, dynamic>> processPendingStockItems(String accessToken) async {
    if (_pendingStockItems.isEmpty) {
      return {
        'success': false,
        'message': 'No pending stock items to process',
        'results': []
      };
    }
    
    debugPrint('🚀 STARTING BATCH PROCESSING OF ${_pendingStockItems.length} STOCK ITEMS');
    
    _batchProcessingLoading = true;
    notifyListeners();
    
    List<Map<String, dynamic>> results = [];
    List<Map<String, dynamic>> successfulItems = [];
    List<Map<String, dynamic>> failedItems = [];
    
    try {
      for (int i = 0; i < _pendingStockItems.length; i++) {
        final stockItem = _pendingStockItems[i];
        final localId = stockItem['localId'];
        
        debugPrint('📦 PROCESSING ITEM ${i + 1}/${_pendingStockItems.length} (ID: $localId)');
        
        // Update status to processing
        stockItem['status'] = 'processing';
        notifyListeners();
        
        try {
          // Call the existing addProductStockAPI method
          final result = await addProductStockAPI(
            accessToken: accessToken,
            productId: stockItem['productId'].toString(),
            categoryId: stockItem['categoryId'].toString(),
            quantity: stockItem['quantity'].toString(),
            retailPrice: stockItem['retailPrice'].toString(),
            purchaseRate: stockItem['purchaseRate'].toString(),
            mrp: stockItem['mrp']?.toString() ?? stockItem['retailPrice'].toString(),
            wholesalePrice: stockItem['wholesalePrice']?.toString() ?? stockItem['retailPrice'].toString(),
            unit: stockItem['unit'].toString(),
            supplierId: stockItem['supplierId'].toString(),
            storeId: stockItem['storeId'].toString(),
            expiryDate: stockItem['expiryDate'].toString(),
            userId: stockItem['userId']?.toString() ?? '1',
            purchaseVoucherId: stockItem['purchaseVoucherId']?.toString(),
            purchaseId: stockItem['purchaseId']?.toString(),
            taxAmountRetail: stockItem['taxAmountRetail']?.toString(),
            taxAmountWholesale: stockItem['taxAmountWholesale']?.toString(),
            wholesaleMinUnit: stockItem['wholesaleMinUnit']?.toString() ?? '1',
            rack: stockItem['rack']?.toString() ?? '',
            barcode: stockItem['barcode']?.toString() ?? '',
            batchNumber: stockItem['batchNumber']?.toString() ?? '',
            date: stockItem['date'].toString(),
            purchaseDate: stockItem['purchaseDate'].toString(),
            purchaseNumber: stockItem['purchaseNumber']?.toString(),
            taxInclude: stockItem['taxInclude'] ?? false,
            initialRetailPrice: stockItem['initialRetailPrice']?.toString() ?? stockItem['retailPrice'].toString(),
            initialWholesalePrice: stockItem['initialWholesalePrice']?.toString() ?? stockItem['retailPrice'].toString(),
            retailPriceTax: stockItem['retailPriceTax']?.toString(),
            wholesalePriceTax: stockItem['wholesalePriceTax']?.toString(),
          );
          
          if (result is Map<String, dynamic> && result['status'] == 'success') {
            stockItem['status'] = 'success';
            stockItem['apiResponse'] = result;
            successfulItems.add(stockItem);
            
            results.add({
              'localId': localId,
              'status': 'success',
              'message': 'Stock item added successfully',
              'data': result['data'],
              'itemIndex': i + 1,
            });
            
            debugPrint('✅ ITEM ${i + 1} PROCESSED SUCCESSFULLY');
          } else {
            stockItem['status'] = 'failed';
            stockItem['apiResponse'] = result;
            failedItems.add(stockItem);
            
            String errorMessage = 'Failed to add stock item';
            if (result is Map<String, dynamic> && result['message'] != null) {
              errorMessage = result['message'].toString();
            }
            
            results.add({
              'localId': localId,
              'status': 'failed',
              'message': errorMessage,
              'error': result,
              'itemIndex': i + 1,
            });
            
            debugPrint('❌ ITEM ${i + 1} FAILED: $errorMessage');
          }
        } catch (e) {
          stockItem['status'] = 'failed';
          stockItem['error'] = e.toString();
          failedItems.add(stockItem);
          
          results.add({
            'localId': localId,
            'status': 'failed',
            'message': 'Exception occurred: ${e.toString()}',
            'error': e.toString(),
            'itemIndex': i + 1,
          });
          
          debugPrint('💥 ITEM ${i + 1} EXCEPTION: $e');
        }
        
        notifyListeners();
        
        // Small delay between API calls to prevent overwhelming the server
        if (i < _pendingStockItems.length - 1) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
      
      // Move only successful items to processed list, keep failed items in pending
      _processedStockItems.addAll(successfulItems);
      
      // Remove only successful items from pending list
      _pendingStockItems.removeWhere((item) => 
        successfulItems.any((successItem) => successItem['localId'] == item['localId']));
      
      // Reset failed items status back to 'pending' so they can be retried
      for (var failedItem in failedItems) {
        final pendingItem = _pendingStockItems.firstWhere(
          (item) => item['localId'] == failedItem['localId'],
          orElse: () => failedItem,
        );
        pendingItem['status'] = 'pending';
      }
      
      debugPrint('🏁 BATCH PROCESSING COMPLETED');
      debugPrint('   - Successful: ${successfulItems.length}');
      debugPrint('   - Failed: ${failedItems.length}');
      debugPrint('   - Total: ${results.length}');
      debugPrint('   - Remaining in pending: ${_pendingStockItems.length}');
      
      String message = 'Batch processing completed: ${successfulItems.length} successful, ${failedItems.length} failed';
      if (failedItems.isNotEmpty) {
        message += '. Failed items remain in pending list for retry.';
      }
      
      return {
        'success': successfulItems.isNotEmpty,
        'message': message,
        'results': results,
        'summary': {
          'total': results.length,
          'successful': successfulItems.length,
          'failed': failedItems.length,
          'successfulItems': successfulItems,
          'failedItems': failedItems,
          'remainingPending': _pendingStockItems.length,
        }
      };
      
    } catch (e) {
      debugPrint('💥 BATCH PROCESSING EXCEPTION: $e');
      return {
        'success': false,
        'message': 'Batch processing failed: ${e.toString()}',
        'error': e.toString(),
        'results': results,
      };
    } finally {
      _batchProcessingLoading = false;
      notifyListeners();
    }
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

        // Note: Local stock will be updated via sync functionality
        // This ensures data consistency with the server
        debugPrint("✅ Stock added successfully - will be synced via SyncProvider");

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

            // Debug: Log barcode data for first few items
            if (listStockModel.data != null && listStockModel.data!.isNotEmpty) {
              debugPrint('🔍 BARCODE DEBUG - First 3 stock items:');
              for (int i = 0; i < (listStockModel.data!.length > 3 ? 3 : listStockModel.data!.length); i++) {
                final stock = listStockModel.data![i];
                debugPrint('  Item $i: Product=${stock.productName}, Barcode=${stock.barCode}');
              }
            }

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
      debugPrint('🔍 BARCODE FILTER DEBUG:');
      debugPrint('  Filter value: "$filterBarcode"');
      debugPrint('  Items before filter: ${filteredList.length}');
      
      filteredList = filteredList
          .where((stock) {
            final matches = stock.barCode != null &&
                stock.barCode!
                    .toLowerCase()
                    .contains(filterBarcode.toLowerCase());
            if (stock.barCode != null) {
              debugPrint('  Checking: "${stock.barCode}" -> $matches');
            }
            return matches;
          })
          .toList();
      
      debugPrint('  Items after filter: ${filteredList.length}');
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

  //          *********************** SYNC STOCK DATA ***************************************************
  
  /// Sync stock data from server - fetches latest stock quantities and details
  Future<Map<String, dynamic>> syncStockData(String accessToken) async {
    debugPrint('🔄 STARTING DEDICATED STOCK DATA SYNC');
    
    try {
      // Use existing stock listing API but with all data
      await listStockAPI(
        accessToken: accessToken,
        page: 1,
        loadAll: true, // Get large batch for sync
        filterName: null,
      );
      
      debugPrint('✅ Stock sync API successful');
      
      return {
        'status': 'success',
        'message': 'Stock data synced successfully',
        'synced_count': _allStocks?.length ?? 0,
      };
    } catch (e) {
      debugPrint('❌ Stock sync failed with error: $e');
      return {
        'status': 'failed',
        'message': 'Stock sync failed: $e',
      };
    }
  }
  
  /// Get stock sync summary for reporting
  Map<String, dynamic> getStockSyncSummary() {
    return {
      'total_stocks': _allStocks?.length ?? 0,
      'last_sync_time': DateTime.now().toIso8601String(),
    };
  }

  //          *********************** CLEAR STOCK DATA ***************************************************
  
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
    _batchProcessingLoading = false;
    _pendingStockItems.clear();
    _processedStockItems.clear();
    notifyListeners();
  }
}