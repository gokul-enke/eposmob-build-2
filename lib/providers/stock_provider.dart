import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
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
  double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    final String normalized = value.toString().trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  int _parseIntOrDefault(dynamic value, int fallback) {
    if (value == null) return fallback;
    return int.tryParse(value.toString()) ?? fallback;
  }

  // Stock data management
  List<stock_models.ListStockModelData>? _listStockModelDataList = [];
  List<stock_models.ListStockModelData>? _allStocks =
      []; // Store all stocks for local filtering
  List<stock_models.ListStockModelData>? _filteredStockList = [];
  stock_models.ListStockModelData? _viewStockModelData;

  // Local pending stock items for batch processing
  List<Map<String, dynamic>> _pendingStockItems = [];
  List<Map<String, dynamic>> _processedStockItems = [];

  // Hive box name for pending stock items persistence
  static const String _kPendingStockBoxName = 'pending_stock_items';

  // Hive box for persistence
  Box? _pendingStockBox;
  bool _isHiveInitialized = false;

  // Pagination properties
  int _stockCurrentPage = 1;
  int _stockTotalPages = 1;
  int _stockItemsPerPage = 20;

  // Filter properties
  String? _stockFilterName;
  String? _stockFilterNameSecondary;
  String? _stockFilterCategory;
  String? _stockFilterBarcode;
  String? _stockFilterRack;
  String? _stockFilterStore;
  String? _stockFilterStatus;
  bool _stockIncludeVariants = false;

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
  String? get stockFilterNameSecondary => _stockFilterNameSecondary;
  String? get stockFilterBarcode => _stockFilterBarcode;
  String? get stockFilterRack => _stockFilterRack;
  String? get stockFilterStore => _stockFilterStore;
  String? get stockFilterStatus => _stockFilterStatus;
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
    if (stockItem['productId'] == null ||
        stockItem['productId'].toString().isEmpty) {
      errors['product'] = 'Product is required';
    }

    if (stockItem['categoryId'] == null ||
        stockItem['categoryId'].toString().isEmpty) {
      errors['category'] = 'Category is required';
    }

    if (stockItem['quantity'] == null ||
        stockItem['quantity'].toString().isEmpty) {
      errors['quantity'] = 'Quantity is required';
    } else {
      final qty = double.tryParse(stockItem['quantity'].toString());
      if (qty == null || qty <= 0) {
        errors['quantity'] = 'Quantity must be a positive number';
      }
    }

    if (stockItem['purchaseUnitId'] != null &&
        stockItem['purchaseUnitId'].toString().trim().isNotEmpty &&
        (stockItem['purchaseQty'] == null ||
            stockItem['purchaseQty'].toString().trim().isEmpty)) {
      errors['purchaseQty'] = 'Purchase qty is required';
    } else if (stockItem['purchaseQty'] != null &&
        stockItem['purchaseQty'].toString().trim().isNotEmpty) {
      final qty = double.tryParse(stockItem['purchaseQty'].toString());
      if (qty == null || qty <= 0) {
        errors['purchaseQty'] = 'Purchase qty must be a positive number';
      }
    }

    if (stockItem['retailPrice'] == null ||
        stockItem['retailPrice'].toString().isEmpty) {
      errors['retailPrice'] = 'Retail price is required';
    } else {
      final price = double.tryParse(stockItem['retailPrice'].toString());
      if (price == null || price <= 0) {
        errors['retailPrice'] = 'Retail price must be a positive number';
      }
    }

    if (stockItem['purchaseRate'] == null ||
        stockItem['purchaseRate'].toString().isEmpty) {
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

    if (stockItem['wholesalePrice'] != null &&
        stockItem['wholesalePrice'].toString().isNotEmpty) {
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
    _savePendingItemsToHive(); // Persist to Hive
    notifyListeners();

    debugPrint('✅ STOCK ITEM ADDED TO PENDING LIST');
    debugPrint('   - Total pending items: ${_pendingStockItems.length}');

    return true;
  }

  /// Remove stock item from pending list
  void removeStockItemLocally(String localId) {
    _pendingStockItems.removeWhere((item) => item['localId'] == localId);
    _savePendingItemsToHive(); // Persist to Hive
    notifyListeners();
    debugPrint('🗑︝ REMOVED STOCK ITEM FROM PENDING LIST: $localId');
  }

  /// Update existing stock item in pending list
  bool updateStockItemLocally(
      String localId, Map<String, dynamic> updatedData) {
    debugPrint('🔄 UPDATING STOCK ITEM LOCALLY');
    debugPrint('   - Local ID: $localId');
    debugPrint('   - Updated Data: $updatedData');

    // Find the item in pending list
    int index =
        _pendingStockItems.indexWhere((item) => item['localId'] == localId);

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

    _savePendingItemsToHive(); // Persist to Hive
    notifyListeners();

    debugPrint('✅ STOCK ITEM UPDATED IN PENDING LIST');
    debugPrint('   - Local ID: $localId');

    return true;
  }

  /// Get stock item from pending list by local ID
  Map<String, dynamic>? getPendingStockItem(String localId) {
    try {
      return _pendingStockItems
          .firstWhere((item) => item['localId'] == localId);
    } catch (e) {
      return null;
    }
  }

  /// Clear all pending stock items
  void clearPendingStockItems() {
    _pendingStockItems.clear();
    _processedStockItems.clear();
    clearPendingItemsFromHive(); // Clear from Hive too
    notifyListeners();
    debugPrint('🧹 CLEARED ALL PENDING STOCK ITEMS');
  }

  /// Get pending stock items count
  int get pendingStockItemsCount => _pendingStockItems.length;

  /// Get processed stock items count
  int get processedStockItemsCount => _processedStockItems.length;

  /// Get failed stock items count
  int get failedStockItemsCount =>
      _pendingStockItems.where((item) => item['status'] == 'failed').length;

  /// Reset failed items status to pending for retry
  void resetFailedItemsForRetry() {
    for (var item in _pendingStockItems) {
      if (item['status'] == 'failed') {
        item['status'] = 'pending';
      }
    }
    _savePendingItemsToHive();
    notifyListeners();
    debugPrint(
        '🔄 RESET ${failedStockItemsCount} FAILED ITEMS TO PENDING FOR RETRY');
  }

  /// *********************** HIVE PERSISTENCE ***************************************************

  /// Initialize Hive box for pending stock items persistence
  Future<void> initHive() async {
    if (_isHiveInitialized) return;

    try {
      if (!Hive.isBoxOpen(_kPendingStockBoxName)) {
        _pendingStockBox = await Hive.openBox(_kPendingStockBoxName);
      } else {
        _pendingStockBox = Hive.box(_kPendingStockBoxName);
      }
      _isHiveInitialized = true;
      debugPrint('✅ StockProvider Hive box initialized');

      // Load any previously saved pending items
      await loadPendingItemsFromHive();
    } catch (e) {
      debugPrint('❌ Failed to initialize StockProvider Hive box: $e');
    }
  }

  /// Save pending stock items to Hive
  Future<void> _savePendingItemsToHive() async {
    if (_pendingStockBox == null || !_pendingStockBox!.isOpen) {
      debugPrint('⚠︝ Hive box not ready, skipping save');
      return;
    }

    try {
      // Convert pending items to JSON-serializable format
      final List<Map<String, dynamic>> itemsToSave =
          _pendingStockItems.map((item) {
        // Create a copy and ensure all values are serializable
        final Map<String, dynamic> serializable = {};
        item.forEach((key, value) {
          if (value == null ||
              value is String ||
              value is num ||
              value is bool) {
            serializable[key] = value;
          } else if (value is DateTime) {
            serializable[key] = value.toIso8601String();
          } else {
            serializable[key] = value.toString();
          }
        });
        return serializable;
      }).toList();

      await _pendingStockBox!.put('pending_items', itemsToSave);
      debugPrint('💾 Saved ${itemsToSave.length} pending stock items to Hive');
    } catch (e) {
      debugPrint('❌ Failed to save pending items to Hive: $e');
    }
  }

  /// Load pending stock items from Hive
  Future<void> loadPendingItemsFromHive() async {
    if (_pendingStockBox == null || !_pendingStockBox!.isOpen) {
      debugPrint('⚠︝ Hive box not ready, skipping load');
      return;
    }

    try {
      final savedItems = _pendingStockBox!.get('pending_items');
      if (savedItems != null && savedItems is List) {
        _pendingStockItems.clear();
        for (var item in savedItems) {
          if (item is Map) {
            _pendingStockItems.add(Map<String, dynamic>.from(item));
          }
        }
        debugPrint(
            '📂 Loaded ${_pendingStockItems.length} pending stock items from Hive');
        notifyListeners();
      } else {
        debugPrint('📂 No pending stock items found in Hive');
      }
    } catch (e) {
      debugPrint('❌ Failed to load pending items from Hive: $e');
    }
  }

  /// Clear pending items from Hive
  Future<void> clearPendingItemsFromHive() async {
    if (_pendingStockBox == null || !_pendingStockBox!.isOpen) return;

    try {
      await _pendingStockBox!.delete('pending_items');
      debugPrint('🗑︝ Cleared pending stock items from Hive');
    } catch (e) {
      debugPrint('❌ Failed to clear pending items from Hive: $e');
    }
  }

  /// *********************** BATCH PROCESS STOCK ITEMS ***************************************************

  /// Process all pending stock items via API calls
  Future<Map<String, dynamic>> processPendingStockItems(
    String accessToken, {
    bool variantsEnabled = false,
  }) async {
    if (_pendingStockItems.isEmpty) {
      return {
        'success': false,
        'message': 'No pending stock items to process',
        'results': []
      };
    }

    debugPrint(
        '🚀 STARTING BATCH PROCESSING OF ${_pendingStockItems.length} STOCK ITEMS');

    _batchProcessingLoading = true;
    notifyListeners();

    List<Map<String, dynamic>> results = [];
    List<Map<String, dynamic>> successfulItems = [];
    List<Map<String, dynamic>> failedItems = [];

    try {
      // Extract common fields from first item (all items share these)
      final firstItem = _pendingStockItems.first;
      final supplierId = firstItem['supplierId'];
      final storeId = firstItem['storeId'];
      final purchaseDate = firstItem['purchaseDate'];

      // Build products array
      List<Map<String, dynamic>> products = [];
      for (int i = 0; i < _pendingStockItems.length; i++) {
        final stockItem = _pendingStockItems[i];
        final productData = <String, dynamic>{
          'product_id': int.parse(stockItem['productId'].toString()),
          if (variantsEnabled && stockItem['productVariantId'] != null)
            'product_variant_id':
                int.parse(stockItem['productVariantId'].toString()),
          'category_id': int.parse(stockItem['categoryId'].toString()),
          'quantity': double.parse(stockItem['quantity'].toString()),
          'retail_price': double.parse(stockItem['retailPrice'].toString()),
          'purchase_rate': double.parse(stockItem['purchaseRate'].toString()),
          'mrp':
              stockItem['mrp'] != null && stockItem['mrp'].toString().isNotEmpty
                  ? double.parse(stockItem['mrp'].toString())
                  : double.parse(stockItem['retailPrice'].toString()),
          'wholesale_price': stockItem['wholesalePrice'] != null &&
                  stockItem['wholesalePrice'].toString().isNotEmpty
              ? double.parse(stockItem['wholesalePrice'].toString())
              : 0.0,
          'unit': stockItem['unit'].toString(),
          'expiry_date': stockItem['expiryDate'].toString(),
          'barcode': stockItem['barcode']?.toString() ?? '',
          'batch_number': stockItem['batchNumber']?.toString() ?? '',
          'date': stockItem['date'].toString(),
          'wholesale_min_unit': stockItem['wholesaleMinUnit'] != null &&
                  stockItem['wholesaleMinUnit'].toString().isNotEmpty
              ? int.parse(stockItem['wholesaleMinUnit'].toString())
              : 0,
          'tax_include': stockItem['taxInclude'] ?? false,
          'rack': stockItem['rack']?.toString() ?? '',
          'tax_amount_retail':
              _parseNullableDouble(stockItem['taxAmountRetail']),
          'tax_amount_wholesale':
              _parseNullableDouble(stockItem['taxAmountWholesale']),
          'initial_retail_price': stockItem['initialRetailPrice'] != null &&
                  stockItem['initialRetailPrice'].toString().isNotEmpty
              ? double.parse(stockItem['initialRetailPrice'].toString())
              : double.parse(stockItem['retailPrice'].toString()),
          'initial_wholesale_price':
              stockItem['initialWholesalePrice'] != null &&
                      stockItem['initialWholesalePrice'].toString().isNotEmpty
                  ? double.parse(stockItem['initialWholesalePrice'].toString())
                  : 0.0,
          'retail_price_tax': _parseNullableDouble(stockItem['retailPriceTax']),
          'wholesale_price_tax':
              _parseNullableDouble(stockItem['wholesalePriceTax']),
        };

        final purchaseQty = stockItem['purchaseQty']?.toString().trim();
        if (purchaseQty != null && purchaseQty.isNotEmpty) {
          productData['purchase_qty'] = double.parse(purchaseQty);
        }

        final purchaseUnitId = stockItem['purchaseUnitId']?.toString().trim();
        if (purchaseUnitId != null && purchaseUnitId.isNotEmpty) {
          productData['purchase_unit_id'] = int.parse(purchaseUnitId);
        }

        products.add(productData);
      }

      debugPrint('📦 CALLING BULK STOCK API WITH ${products.length} PRODUCTS');

      // Call bulk API
      final result = await addBulkProductStockAPI(
        accessToken: accessToken,
        products: products,
        supplierId: supplierId.toString(),
        storeId: storeId.toString(),
        purchaseDate: purchaseDate.toString(),
      );

      if (result is Map<String, dynamic> && result['status'] == 'success') {
        debugPrint('✅ BULK API CALL SUCCESSFUL');

        // Mark all items as successful
        for (int i = 0; i < _pendingStockItems.length; i++) {
          final stockItem = _pendingStockItems[i];
          final localId = stockItem['localId'];

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
        }

        debugPrint(
            '✅ ALL ${successfulItems.length} ITEMS MARKED AS SUCCESSFUL');
      } else {
        debugPrint('❌ BULK API CALL FAILED');

        // Mark all items as failed
        String errorMessage = 'Failed to add stock items';
        if (result is Map<String, dynamic> && result['message'] != null) {
          errorMessage = result['message'].toString();
        }

        for (int i = 0; i < _pendingStockItems.length; i++) {
          final stockItem = _pendingStockItems[i];
          final localId = stockItem['localId'];

          stockItem['status'] = 'failed';
          stockItem['apiResponse'] = result;
          failedItems.add(stockItem);

          results.add({
            'localId': localId,
            'status': 'failed',
            'message': errorMessage,
            'error': result,
            'itemIndex': i + 1,
          });
        }

        debugPrint(
            '❌ ALL ${failedItems.length} ITEMS MARKED AS FAILED: $errorMessage');
      }

      // Move only successful items to processed list, keep failed items in pending
      _processedStockItems.addAll(successfulItems);

      // Remove only successful items from pending list
      _pendingStockItems.removeWhere((item) => successfulItems
          .any((successItem) => successItem['localId'] == item['localId']));

      // Reset failed items status back to 'pending' so they can be retried
      for (var failedItem in failedItems) {
        final pendingItem = _pendingStockItems.firstWhere(
          (item) => item['localId'] == failedItem['localId'],
          orElse: () => failedItem,
        );
        pendingItem['status'] = 'pending';
      }

      debugPrint('🝝 BATCH PROCESSING COMPLETED');
      debugPrint('   - Successful: ${successfulItems.length}');
      debugPrint('   - Failed: ${failedItems.length}');
      debugPrint('   - Total: ${results.length}');
      debugPrint('   - Remaining in pending: ${_pendingStockItems.length}');

      String message =
          'Batch processing completed: ${successfulItems.length} successful, ${failedItems.length} failed';
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
      _savePendingItemsToHive(); // Save updated pending list to Hive
      notifyListeners();
    }
  }

  /// *********************** ADD BULK STOCK API ***************************************************

  Future<dynamic> addBulkProductStockAPI({
    required String accessToken,
    required List<Map<String, dynamic>> products,
    required String supplierId,
    required String storeId,
    required String purchaseDate,
  }) async {
    final Map<String, dynamic> apiBodyData = {
      'products': products,
      'supplier_id': _parseIntOrDefault(supplierId, 0),
      'store_id': _parseIntOrDefault(storeId, 0),
      'purchase_date': purchaseDate,
    };

    debugPrint('📦 ADD STOCK API REQUEST BODY:');
    debugPrint(const JsonEncoder.withIndent('  ').convert(apiBodyData));

    final url = Uri.parse(APPUrl.addBulkStock);
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
        debugPrint(
            "✅ Bulk stock added successfully - will be synced via SyncProvider");

        return result;
      } else {
        // Capture the response body even on non-200 status for debugging
        debugPrint(
            '❌ ADD BULK PRODUCT STOCK API FAILED (Status: ${response.statusCode})');
        debugPrint('   - Response Body: ${response.body}');
        return {'status': 'failed', 'message': response.body};
      }
    } catch (e) {
      debugPrint("Error in addBulkProductStockAPI: $e");
      return {'status': 'failed', 'message': 'Error: ${e.toString()}'};
    }
  }

  /// *********************** ADD TO STOCK API ***************************************************

  Future<dynamic> addProductStockAPI({
    required String accessToken,
    required String productId,
    String? productVariantId,
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
      if (productVariantId != null && productVariantId.trim().isNotEmpty)
        'product_variant_id': int.parse(productVariantId),
      'category_id': int.parse(categoryId),
      'quantity': double.parse(quantity),
      'retail_price': double.parse(retailPrice),
      'purchase_rate': double.parse(purchaseRate),
      'mrp': mrp.isNotEmpty ? double.parse(mrp) : double.parse(retailPrice),
      'wholesale_price':
          wholesalePrice.isNotEmpty ? double.parse(wholesalePrice) : 0.0,
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
          : 0.0,
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
        debugPrint(
            "✅ Stock added successfully - will be synced via SyncProvider");

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

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    final queryParameters = <String, String>{
      'price': price.toString(),
      'product_id': productId.toString(),
      'tax_include': taxInclude ? '1' : '0',
      'category_id': categoryId.toString(),
    };

    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }

    final url = Uri.parse(APPUrl.calculateTax)
        .replace(queryParameters: queryParameters);
    debugPrint("Tax API URL: $url");

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

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }

    final uri =
        Uri.parse(APPUrl.listStock).replace(queryParameters: queryParameters);

    try {
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
            if (listStockModel.data != null &&
                listStockModel.data!.isNotEmpty) {
              debugPrint('🔝 BARCODE DEBUG - First 3 stock items:');
              for (int i = 0;
                  i <
                      (listStockModel.data!.length > 3
                          ? 3
                          : listStockModel.data!.length);
                  i++) {
                final stock = listStockModel.data![i];
                debugPrint(
                    '  Item $i: Product=${stock.productName}, Barcode=${stock.barCode}');
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

  void applyRealtimeStocks(
    List<stock_models.ListStockModelData> stocks,
  ) {
    _allStocks = List<stock_models.ListStockModelData>.from(stocks);
    applyStockFiltersLocally(
      filterName: _stockFilterName,
      filterNameSecondary: _stockFilterNameSecondary,
      filterCategory: _stockFilterCategory,
      filterBarcode: _stockFilterBarcode,
      filterRack: _stockFilterRack,
      filterStore: _stockFilterStore,
      filterStatus: _stockFilterStatus,
      page: _stockCurrentPage,
    );
    notifyListeners();
  }

  /// Apply local pagination and filtering for stocks
  void applyStockFiltersLocally({
    String? filterName,
    String? filterNameSecondary,
    String? filterCategory,
    String? filterBarcode,
    String? filterRack,
    String? filterStore,
    String? filterStatus,
    bool? includeVariants,
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
    _stockFilterNameSecondary = filterNameSecondary;
    _stockFilterCategory = filterCategory;
    _stockFilterBarcode = filterBarcode;
    _stockFilterRack = filterRack;
    _stockFilterStore = filterStore;
    _stockFilterStatus = filterStatus;
    _stockIncludeVariants = includeVariants ?? _stockIncludeVariants;
    _stockCurrentPage = page;

    // Apply filters
    List<stock_models.ListStockModelData> filteredList = [..._allStocks!];

    // Apply name filter
    if (filterName != null && filterName.isNotEmpty) {
      filteredList = filteredList.where((stock) {
        final query = filterName.toLowerCase();
        return (stock.productName?.toLowerCase().contains(query) ?? false) ||
            (_stockIncludeVariants &&
                (stock.variantName?.toLowerCase().contains(query) ?? false));
      }).toList();
    }

    // Apply secondary product name filter
    if (filterNameSecondary != null && filterNameSecondary.isNotEmpty) {
      filteredList = filteredList.where((stock) {
        final query = filterNameSecondary.toLowerCase();
        return (stock.productName?.toLowerCase().contains(query) ?? false) ||
            (_stockIncludeVariants &&
                (stock.variantName?.toLowerCase().contains(query) ?? false));
      }).toList();
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
      debugPrint('🔝 BARCODE FILTER DEBUG:');
      debugPrint('  Filter value: "$filterBarcode"');
      debugPrint('  Items before filter: ${filteredList.length}');

      filteredList = filteredList.where((stock) {
        final matches = stock.barCode != null &&
            stock.barCode!.toLowerCase().contains(filterBarcode.toLowerCase());
        if (stock.barCode != null) {
          debugPrint('  Checking: "${stock.barCode}" -> $matches');
        }
        return matches;
      }).toList();

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

    // Apply status filter
    if (filterStatus != null &&
        filterStatus.isNotEmpty &&
        filterStatus != "All Statuses") {
      filteredList = filteredList
          .where((stock) =>
              stock.stockStatus != null &&
              stock.stockStatus!.toLowerCase() == filterStatus.toLowerCase())
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
    _stockFilterNameSecondary = null;
    _stockFilterCategory = null;
    _stockFilterBarcode = null;
    _stockFilterRack = null;
    _stockFilterStore = null;
    _stockFilterStatus = null;
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
      filterNameSecondary: _stockFilterNameSecondary,
      filterCategory: _stockFilterCategory,
      filterBarcode: _stockFilterBarcode,
      filterRack: _stockFilterRack,
      filterStore: _stockFilterStore,
      filterStatus: _stockFilterStatus,
      page: page,
    );
  }

  /// *********************** CALL VIEW STOCK DETAILS API ***************************************************

  Future<void> callStockDetails(
      {required int stockId, required String accessToken}) async {
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    final Map<String, String> queryParameters = {'id': stockId.toString()};
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse(APPUrl.detailsOfStock)
        .replace(queryParameters: queryParameters);

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
    String? quantity,
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
      final payload = <String, dynamic>{
        'retail_price': retailPrice,
        'mrp': mrp,
        'purchase_price': purchasePrice,
        'rack': rack,
      };
      if (quantity != null && quantity.trim().isNotEmpty) {
        payload['quantity'] = quantity.trim();
      }

      debugPrint('🚀 [StockProvider.updateStockDetails] REQUEST START');
      debugPrint('   URL: $url');
      debugPrint('   STOCK ID: $stockId');
      debugPrint('   QUANTITY INCLUDED: ${payload.containsKey('quantity')}');
      debugPrint('   PAYLOAD: ${jsonEncode(payload)}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
        body: jsonEncode(payload),
      );

      debugPrint('📥 [StockProvider.updateStockDetails] RESPONSE');
      debugPrint('   STATUS: ${response.statusCode}');
      debugPrint('   BODY: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          debugPrint(
              '✅ [StockProvider.updateStockDetails] API success for stockId=$stockId. Updating local stock cache...');
          _updateStockInLocalCache(
            stockId: stockId,
            responseStock: responseData['data']?['stock'],
            retailPrice: retailPrice,
            mrp: mrp,
            purchasePrice: purchasePrice,
            quantity: quantity,
            rack: rack,
          );
          debugPrint(
              '✅ [StockProvider.updateStockDetails] Local stock cache update complete for stockId=$stockId');
          return true;
        }
        debugPrint(
            '⚠︝ [StockProvider.updateStockDetails] API returned 200 but status was not success: ${responseData['status']}');
      }

      debugPrint(
          '❌ [StockProvider.updateStockDetails] Request failed for stockId=$stockId with status=${response.statusCode}');

      return false;
    } catch (e) {
      debugPrint('❌ [StockProvider.updateStockDetails] Exception: $e');
      return false;
    }
  }

  void _updateStockInLocalCache({
    required int stockId,
    required dynamic responseStock,
    required String retailPrice,
    required String mrp,
    required String purchasePrice,
    required String? quantity,
    required String rack,
  }) {
    final stockJson = responseStock is Map<String, dynamic>
        ? responseStock
        : responseStock is Map
            ? Map<String, dynamic>.from(responseStock)
            : <String, dynamic>{};
    final updatedQuantity =
        _parseNullableDouble(stockJson['quantity'] ?? quantity);
    final updatedRetailPrice =
        stockJson['retail_price']?.toString() ?? retailPrice;
    final updatedMrp = stockJson['mrp']?.toString() ?? mrp;
    final updatedPurchasePrice =
        stockJson['purchase_price']?.toString() ?? purchasePrice;
    final updatedRack = stockJson.containsKey('rack')
        ? stockJson['rack']?.toString()
        : (rack.isEmpty ? null : rack);

    bool updateList(List<stock_models.ListStockModelData>? list) {
      if (list == null || list.isEmpty) return false;
      final index = list.indexWhere((stock) => stock.stockId == stockId);
      if (index == -1) return false;

      final existing = list[index];
      list[index] = existing.copyWith(
        qty: updatedQuantity,
        retailPrice: updatedRetailPrice,
        mrp: updatedMrp,
        purchaseRate: updatedPurchasePrice,
        rack: updatedRack,
      );
      return true;
    }

    final didUpdate = updateList(_allStocks) |
        updateList(_listStockModelDataList) |
        updateList(_filteredStockList);

    final isViewStockUpdated = _viewStockModelData?.stockId == stockId;
    if (isViewStockUpdated) {
      _viewStockModelData = _viewStockModelData!.copyWith(
        qty: updatedQuantity,
        retailPrice: updatedRetailPrice,
        mrp: updatedMrp,
        purchaseRate: updatedPurchasePrice,
        rack: updatedRack,
      );
    }

    if (didUpdate || isViewStockUpdated) {
      notifyListeners();
    }
  }

  /// *********************** ADJUST STOCK API ***************************************************

  Future<bool> adjustStockAPI({
    required int stockId,
    required String type,
    required double quantity,
    required String reason,
    required String accessToken,
  }) async {
    try {
      final url = Uri.parse('${APPUrl.adjustStock}/$stockId');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found. Please restart the app.");
      }
      final body = jsonEncode({
        'type': type,
        'quantity': quantity,
        'reason': reason,
      });

      debugPrint('🚀 ADJUST STOCK REQUEST:');
      debugPrint('   URL: $url');
      debugPrint('   BODY: $body');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
        body: body,
      );

      debugPrint('📥 ADJUST STOCK RESPONSE:');
      debugPrint('   STATUS: ${response.statusCode}');
      debugPrint('   BODY: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          await loadAllStocks(accessToken);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error adjusting stock: $e');
      return false;
    }
  }

  /// *********************** MOVE STOCK API ***************************************************

  Future<bool> moveStockAPI({
    required int stockId,
    required int destStoreId,
    required double quantity,
    required String accessToken,
  }) async {
    try {
      final url = Uri.parse('${APPUrl.moveStock}/$stockId');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found. Please restart the app.");
      }
      final body = jsonEncode({
        'dest_store_id': destStoreId,
        'quantity': quantity,
      });

      debugPrint('🚀 MOVE STOCK REQUEST:');
      debugPrint('   URL: $url');
      debugPrint('   BODY: $body');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
        body: body,
      );

      debugPrint('📥 MOVE STOCK RESPONSE:');
      debugPrint('   STATUS: ${response.statusCode}');
      debugPrint('   BODY: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          await loadAllStocks(accessToken);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error moving stock: $e');
      return false;
    }
  }

  /// *********************** WITHDRAW STOCK API ***************************************************

  Future<bool> withdrawStockAPI({
    required int stockId,
    required double quantity,
    required String accessToken,
  }) async {
    try {
      final url = Uri.parse('${APPUrl.withdrawStock}/$stockId');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found. Please restart the app.");
      }
      final body = jsonEncode({
        'quantity': quantity,
      });

      debugPrint('🚀 WITHDRAW STOCK REQUEST:');
      debugPrint('   URL: $url');
      debugPrint('   BODY: $body');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
        body: body,
      );

      debugPrint('📥 WITHDRAW STOCK RESPONSE:');
      debugPrint('   STATUS: ${response.statusCode}');
      debugPrint('   BODY: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          await loadAllStocks(accessToken);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error withdrawing stock: $e');
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
    _stockFilterStatus = null;
    _stockIsLoading = false;
    _batchProcessingLoading = false;
    _pendingStockItems.clear();
    _processedStockItems.clear();
    notifyListeners();
  }
}
