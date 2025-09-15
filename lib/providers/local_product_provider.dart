import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/get_product.dart';
import '../models/local_models.dart';
import '../resources/app_url.dart';
import '../providers/app_settings_provider.dart';

/// A model representing a local cart item.
/// It holds a product and its associated quantity in the offline cart.
class LocalCartItem {
  final GetProduct product;
  double? price;
  double? mrp;
  num quantity;
  final Stock? selectedStock;

  LocalCartItem({
    required this.product,
    this.quantity = 1,
    this.price,
    this.mrp,
    this.selectedStock,
  });
}

/// Represents a saved order stored locally
class SavedOrder {
  final String id; // Unique identifier for the order
  final String orderNumber; // Display order number (ORD-1, ORD-2, etc.)
  final List<LocalCartItem> items;
  final String? customerName;
  final String? customerPhone;
  final String? comment;
  final String createdAt;
  final double total;
  final String? deliveryMethod;

  // New fields for API compatibility
  final int? customerId;
  final String? paymentMethod;
  final String? paidAmount;
  final String? balanceAmount;
  final String? transactionId;
  final String? couponId;
  final String? deliveryMethodId;
  final String? carNumber;
  final String? status;
  final String? deliveryDate; // Added for local persistence
  final String? deliveryTime; // Added for local persistence
  final double? flatDiscount;
  final double? percentageDiscount;
  final bool? toCustomerCredit;

  SavedOrder({
    required this.id,
    required this.orderNumber,
    required this.items,
    this.customerName,
    this.customerPhone,
    this.comment,
    required this.createdAt,
    required this.total,
    this.deliveryMethod,
    // New API-compatible fields
    this.customerId,
    this.paymentMethod,
    this.paidAmount,
    this.balanceAmount,
    this.transactionId,
    this.couponId,
    this.deliveryMethodId,
    this.carNumber,
    this.status,
    this.deliveryDate, // Added to constructor
    this.deliveryTime, // Added to constructor
    this.flatDiscount,
    this.percentageDiscount,
    this.toCustomerCredit,
  });
}

class PriceSummary {
  double discount;
  double netPayable;
  double subTotal;
  double totalTax;
  double netTotal;
  double flatDiscount;
  double percentageDiscount;
  double originalSubTotal;

  PriceSummary({
    required this.discount,
    required this.netPayable,
    required this.subTotal,
    required this.totalTax,
    required this.netTotal,
    this.flatDiscount = 0.0,
    this.percentageDiscount = 0.0,
    this.originalSubTotal = 0.0,
  });
}

/// The LocalProductProvider is aimed for an offline approach.
/// Upon login, all products should be loaded into this provider
/// via [initializeProducts]. It maintains a full product list along with
/// a filtered list and a selected product for details, similar to GridSelectionProvider.
/// Additionally, it manages a separate offline cart state.
class LocalProductProvider extends ChangeNotifier {
  // Hive boxes
  final Box<HiveProduct> _productsBox = Hive.box<HiveProduct>('products');
  final Box<HiveLocalCartItem> _cartItemsBox =
      Hive.box<HiveLocalCartItem>('cart_items');
  final Box<HiveSavedOrder> _savedOrdersBox =
      Hive.box<HiveSavedOrder>('saved_orders');
  late Box<HiveSavedOrder> _confirmedOrdersBox;
  bool _isConfirmedBoxInitialized = false;

  // The complete list of products loaded locally.
  List<GetProduct> _products = [];

  // A filtered subset of _products, based on search or category.
  List<GetProduct> _filteredProducts = [];

  // Getter for the complete product list.
  List<GetProduct> get products => _products;

  // Getter for the filtered product list.
  List<GetProduct> get filteredProducts => _filteredProducts;

  // Currently selected product (for showing product details).
  GetProduct? _selectedProduct;
  GetProduct? get selectedProduct => _selectedProduct;

  // Currently selected stock (for the selected product).
  Stock? _selectedStock;
  Stock? get selectedStock => _selectedStock;

  // Local offline cart state.
  final List<LocalCartItem> _cartItems = [];
  List<LocalCartItem> get cartItems => _cartItems;
  bool isLoading = false;

  // List of saved orders
  final List<SavedOrder> _savedOrders = [];
  List<SavedOrder> get savedOrders => _savedOrders;

  // List of confirmed orders
  final List<SavedOrder> _confirmedOrders = [];
  List<SavedOrder> get confirmedOrders => _confirmedOrders;

  // Currently loaded order (for editing)
  SavedOrder? _currentOrder;
  SavedOrder? get currentOrder => _currentOrder;

  PriceSummary? priceSummary;

  // Add pagination properties
  int _currentPage = 1;
  int _totalPages = 1;
  int _itemsPerPage = 10;

  // Getters for pagination
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get itemsPerPage => _itemsPerPage;

  // Stock management settings - need to be injected from outside since this provider
  // doesn't have access to GeneralSettingsProvider directly
  bool? _stockEnabled;

  // Discount management
  double _flatDiscount = 0.0;
  double _percentageDiscount = 0.0;

  /// Sets the stock enabled status from the GeneralSettingsProvider
  void setStockEnabled(bool enabled) {
    _stockEnabled = enabled;
    debugPrint("📦 Stock management setting updated: $_stockEnabled");
  }

  /// Gets the current stock enabled status
  bool get isStockEnabled => _stockEnabled ?? false;

  // Constructor - Load data from Hive on initialization
  LocalProductProvider() {
    _loadProductsFromHive();
    _loadCartFromHive();
    _loadSavedOrdersFromHive();
    _initConfirmedOrdersBox();
  }

  // Initialize the confirmed orders box safely
  Future<void> _initConfirmedOrdersBox() async {
    try {
      if (!Hive.isBoxOpen('confirmed_orders')) {
        _confirmedOrdersBox =
            await Hive.openBox<HiveSavedOrder>('confirmed_orders');
      } else {
        _confirmedOrdersBox = Hive.box<HiveSavedOrder>('confirmed_orders');
      }
      _isConfirmedBoxInitialized = true;
      _loadConfirmedOrdersFromHive();
    } catch (e) {
      debugPrint("Error initializing confirmed orders box: $e");
      _isConfirmedBoxInitialized = false;
    }
  }

  // Load confirmed orders from Hive
  void _loadConfirmedOrdersFromHive() {
    if (!_isConfirmedBoxInitialized) return;

    _confirmedOrders.clear();
    try {
      for (var hiveSavedOrder in _confirmedOrdersBox.values) {
        List<LocalCartItem> orderItems =
            hiveSavedOrder.items.map((hiveCartItem) {
          final productJson = json.decode(hiveCartItem.serializedProduct.value);
          final product = GetProduct.fromJson(productJson);

          // Deserialize selected stock if it exists
          Stock? selectedStock;
          if (hiveCartItem.serializedSelectedStock != null) {
            final stockJson =
                json.decode(hiveCartItem.serializedSelectedStock!.value);
            selectedStock = Stock.fromJson(stockJson);
          }

          return LocalCartItem(
            product: product,
            quantity: hiveCartItem.quantity,
            price: hiveCartItem.price,
            mrp: hiveCartItem
                .mrp, // 🔧 FIX: Include MRP when loading confirmed orders from Hive
            selectedStock: selectedStock,
          );
        }).toList();

        _confirmedOrders.add(SavedOrder(
          id: hiveSavedOrder.id,
          orderNumber: hiveSavedOrder.orderNumber,
          items: orderItems,
          customerName: hiveSavedOrder.customerName,
          customerPhone: hiveSavedOrder.customerPhone,
          comment: hiveSavedOrder.comment,
          createdAt: hiveSavedOrder.createdAt,
          total: hiveSavedOrder.total,
          deliveryMethod: hiveSavedOrder.deliveryMethod,
          // Load new API-compatible fields
          customerId: hiveSavedOrder.customerId,
          paymentMethod: hiveSavedOrder.paymentMethod,
          paidAmount: hiveSavedOrder.paidAmount,
          balanceAmount: hiveSavedOrder.balanceAmount,
          transactionId: hiveSavedOrder.transactionId,
          couponId: hiveSavedOrder.couponId,
          deliveryMethodId: hiveSavedOrder.deliveryMethodId,
          carNumber: hiveSavedOrder.carNumber,
          status: hiveSavedOrder.status,
          deliveryDate: hiveSavedOrder.deliveryDate, // Restore delivery date
          deliveryTime: hiveSavedOrder.deliveryTime, // Restore delivery time
          flatDiscount: hiveSavedOrder.flatDiscount,
          percentageDiscount: hiveSavedOrder.percentageDiscount,
          toCustomerCredit: hiveSavedOrder.toCustomerCredit,
        ));
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading confirmed orders: $e");
    }
  }

  // Save confirmed orders to Hive
  void _saveConfirmedOrdersToHive() {
    if (!_isConfirmedBoxInitialized) {
      _initConfirmedOrdersBox().then((_) {
        _saveConfirmedOrdersToHive();
      });
      return;
    }

    try {
      _confirmedOrdersBox.clear();
      for (var order in _confirmedOrders) {
        List<HiveLocalCartItem> hiveItems = order.items.map((item) {
          // Serialize selected stock if it exists
          HiveStringValue? serializedStock;
          if (item.selectedStock != null) {
            serializedStock =
                HiveStringValue(json.encode(item.selectedStock!.toJson()));
          }

          return HiveLocalCartItem(
            productId: item.product.productId!,
            quantity: item.quantity,
            price: item.price,
            mrp: item
                .mrp, // 🔧 FIX: Include MRP when saving confirmed orders to Hive
            serializedProduct:
                HiveStringValue(json.encode(item.product.toJson())),
            serializedSelectedStock: serializedStock,
          );
        }).toList();

        final hiveSavedOrder = HiveSavedOrder(
          id: order.id,
          orderNumber: order.orderNumber,
          items: hiveItems,
          customerName: order.customerName,
          customerPhone: order.customerPhone,
          comment: order.comment,
          createdAt: order.createdAt,
          total: order.total,
          deliveryMethod: order.deliveryMethod,
          // Save new API-compatible fields
          customerId: order.customerId,
          paymentMethod: order.paymentMethod,
          paidAmount: order.paidAmount,
          balanceAmount: order.balanceAmount,
          transactionId: order.transactionId,
          couponId: order.couponId,
          deliveryMethodId: order.deliveryMethodId,
          carNumber: order.carNumber,
          status: order.status,
          deliveryDate: order.deliveryDate,
          deliveryTime: order.deliveryTime,
          flatDiscount: order.flatDiscount,
          percentageDiscount: order.percentageDiscount,
          toCustomerCredit: order.toCustomerCredit,
        );

        _confirmedOrdersBox.add(hiveSavedOrder);
      }
    } catch (e) {
      debugPrint("Error saving confirmed orders: $e");
    }
  }

  // Load products from Hive
  void _loadProductsFromHive() {
    _products = _productsBox.values.map((hiveProduct) {
      final jsonData = json.decode(hiveProduct.serializedData.value);
      return GetProduct.fromJson(jsonData);
    }).toList();
    _filteredProducts = List.from(_products);
    notifyListeners();
  }

  // Load cart items from Hive
  void _loadCartFromHive() {
    _cartItems.clear();
    for (var hiveCartItem in _cartItemsBox.values) {
      final productJson = json.decode(hiveCartItem.serializedProduct.value);
      final product = GetProduct.fromJson(productJson);

      // Deserialize selected stock if it exists
      Stock? selectedStock;
      if (hiveCartItem.serializedSelectedStock != null) {
        final stockJson =
            json.decode(hiveCartItem.serializedSelectedStock!.value);
        selectedStock = Stock.fromJson(stockJson);
      }

      _cartItems.add(LocalCartItem(
        product: product,
        quantity: hiveCartItem.quantity,
        price: hiveCartItem.price,
        mrp:
            hiveCartItem.mrp, // 🔧 FIX: Include MRP when loading cart from Hive
        selectedStock: selectedStock,
      ));
    }
    notifyListeners();
  }

  // Load saved orders from Hive
  void _loadSavedOrdersFromHive() {
    _savedOrders.clear();
    for (var hiveSavedOrder in _savedOrdersBox.values) {
      List<LocalCartItem> orderItems = hiveSavedOrder.items.map((hiveCartItem) {
        final productJson = json.decode(hiveCartItem.serializedProduct.value);
        final product = GetProduct.fromJson(productJson);

        // Deserialize selected stock if it exists
        Stock? selectedStock;
        if (hiveCartItem.serializedSelectedStock != null) {
          final stockJson =
              json.decode(hiveCartItem.serializedSelectedStock!.value);
          selectedStock = Stock.fromJson(stockJson);
        }

        return LocalCartItem(
          product: product,
          quantity: hiveCartItem.quantity,
          price: hiveCartItem.price,
          mrp: hiveCartItem
              .mrp, // 🔧 FIX: Include MRP when loading saved orders from Hive
          selectedStock: selectedStock,
        );
      }).toList();

      _savedOrders.add(SavedOrder(
        id: hiveSavedOrder.id,
        orderNumber: hiveSavedOrder.orderNumber,
        items: orderItems,
        customerName: hiveSavedOrder.customerName,
        customerPhone: hiveSavedOrder.customerPhone,
        comment: hiveSavedOrder.comment,
        createdAt: hiveSavedOrder.createdAt,
        total: hiveSavedOrder.total,
        deliveryMethod: hiveSavedOrder.deliveryMethod,
        // Load new API-compatible fields
        customerId: hiveSavedOrder.customerId,
        paymentMethod: hiveSavedOrder.paymentMethod,
        paidAmount: hiveSavedOrder.paidAmount,
        balanceAmount: hiveSavedOrder.balanceAmount,
        transactionId: hiveSavedOrder.transactionId,
        couponId: hiveSavedOrder.couponId,
        deliveryMethodId: hiveSavedOrder.deliveryMethodId,
        carNumber: hiveSavedOrder.carNumber,
        status: hiveSavedOrder.status,
        deliveryDate: hiveSavedOrder.deliveryDate, // Restore delivery date
        deliveryTime: hiveSavedOrder.deliveryTime, // Restore delivery time
        flatDiscount: hiveSavedOrder.flatDiscount,
        percentageDiscount: hiveSavedOrder.percentageDiscount,
        toCustomerCredit: hiveSavedOrder.toCustomerCredit,
      ));
    }
    notifyListeners();
  }

  // Save products to Hive
  void _saveProductsToHive() {
    _productsBox.clear();
    for (var product in _products) {
      final hiveProduct = HiveProduct(
        productId: product.productId,
        categoryId: product.categoryId,
        productName: product.productName,
        barcode: product.barcode,
        serializedData: HiveStringValue(json.encode(product.toJson())),
      );
      _productsBox.add(hiveProduct);
    }
  }

  // Save cart items to Hive
  void _saveCartToHive() {
    _cartItemsBox.clear();
    for (var cartItem in _cartItems) {
      // Serialize selected stock if it exists
      HiveStringValue? serializedStock;
      if (cartItem.selectedStock != null) {
        serializedStock =
            HiveStringValue(json.encode(cartItem.selectedStock!.toJson()));
      }

      final hiveCartItem = HiveLocalCartItem(
        productId: cartItem.product.productId!,
        quantity: cartItem.quantity,
        price: cartItem.price,
        mrp: cartItem.mrp, // 🔧 FIX: Include MRP when saving cart to Hive
        serializedProduct:
            HiveStringValue(json.encode(cartItem.product.toJson())),
        serializedSelectedStock: serializedStock,
      );
      _cartItemsBox.add(hiveCartItem);
    }
  }

  // Save orders to Hive
  void _saveSavedOrdersToHive() {
    _savedOrdersBox.clear();
    for (var order in _savedOrders) {
      List<HiveLocalCartItem> hiveItems = order.items.map((item) {
        // Serialize selected stock if it exists
        HiveStringValue? serializedStock;
        if (item.selectedStock != null) {
          serializedStock =
              HiveStringValue(json.encode(item.selectedStock!.toJson()));
        }

        return HiveLocalCartItem(
          productId: item.product.productId!,
          quantity: item.quantity,
          price: item.price,
          mrp: item.mrp, // 🔧 FIX: Include MRP when saving saved orders to Hive
          serializedProduct:
              HiveStringValue(json.encode(item.product.toJson())),
          serializedSelectedStock: serializedStock,
        );
      }).toList();

      final hiveSavedOrder = HiveSavedOrder(
        id: order.id,
        orderNumber: order.orderNumber,
        items: hiveItems,
        customerName: order.customerName,
        customerPhone: order.customerPhone,
        comment: order.comment,
        createdAt: order.createdAt,
        total: order.total,
        deliveryMethod: order.deliveryMethod,
        // Save new API-compatible fields
        customerId: order.customerId,
        paymentMethod: order.paymentMethod,
        paidAmount: order.paidAmount,
        balanceAmount: order.balanceAmount,
        transactionId: order.transactionId,
        couponId: order.couponId,
        deliveryMethodId: order.deliveryMethodId,
        carNumber: order.carNumber,
        status: order.status,
        deliveryDate: order.deliveryDate,
        deliveryTime: order.deliveryTime,
        flatDiscount: order.flatDiscount,
        percentageDiscount: order.percentageDiscount,
        toCustomerCredit: order.toCustomerCredit,
      );

      _savedOrdersBox.add(hiveSavedOrder);
    }
  }

  double get cartTotal {
    double subTotal = 0.0;
    double totalTax = 0.0; // Assuming you have a way to calculate tax

    // Calculate subtotal from all cart items
    for (var item in _cartItems) {
      subTotal += (item.price ?? 0) * item.quantity;
    }

    // Calculate discount amounts
    double flatDiscountAmount = _flatDiscount;
    double percentageDiscountAmount = (subTotal * _percentageDiscount / 100);
    double totalDiscount = flatDiscountAmount + percentageDiscountAmount;

    // Ensure discount doesn't exceed subtotal
    if (totalDiscount > subTotal) {
      totalDiscount = subTotal;
    }

    double netPayable = subTotal - totalDiscount;
    double netTotal = netPayable + totalTax;

    // Create a PriceSummary instance with discount details
    priceSummary = PriceSummary(
      discount: totalDiscount,
      netPayable: netPayable,
      subTotal: subTotal,
      totalTax: totalTax,
      netTotal: netTotal,
      flatDiscount: flatDiscountAmount,
      percentageDiscount: percentageDiscountAmount,
      originalSubTotal: subTotal,
    );

    return netTotal; // Return the final total after discount
  }

  /// Sets the selected product and optionally the selected stock for product details.
  void callProductDetails(int productId, {Stock? selectedStock}) {
    GetProduct product = _products.firstWhere(
      (product) => product.productId == productId,
    );
    _selectedProduct = product;
    _selectedStock = selectedStock;
    notifyListeners();
  }

  /// Resets the selected product and stock.
  void resetSelectedProduct() {
    _selectedProduct = null;
    _selectedStock = null;
    notifyListeners();
  }

  /// Initializes the provider with a list of products.
  /// This should be called after a successful login and after fetching
  /// all products (possibly from a one-time API call or local cache).
  void initializeProducts(List<GetProduct> products) {
    _products = products;
    // Initially, set filtered products same as the full list.
    _filteredProducts = List.from(_products);
    _saveProductsToHive();
    notifyListeners();
  }

  /// Fetches products from the API (similar to GridSelectionProvider) and stores them locally.
  Future<void> fetchProductsFromAPI(
      {int? categoryId, String? filterName}) async {
    List<GetProduct> allProducts = [];
    int currentPage = 1;
    // const int itemsPerPage = 500; // Assuming 500 items per page

    isLoading = true;
    notifyListeners();

    try {
      while (true) {
        final queryParams = <String, String>{
          // if (filterName != null) 'name': filterName,
          // if (categoryId != null && categoryId != 0)
          // 'category_id': categoryId.toString(),
          'page': currentPage.toString(),
          // 'items_per_page': itemsPerPage.toString(),
        };

        final url = Uri.parse(APPUrl.getProductUrl)
            .replace(queryParameters: queryParams);

        // Get API key from SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? apiKey = prefs.getString('api_key');

        if (apiKey == null || apiKey.isEmpty) {
          throw const HttpException(
              "API key not found. Please restart the app.");
        }

        final response = await http.get(url, headers: {
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        });
        debugPrint(
            'Fetching products - Page $currentPage, Status Code: ${response.statusCode}');

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          GetProductModel getProductModel = GetProductModel.fromJson(jsonData);

          if (getProductModel.product == null ||
              getProductModel.product!.isEmpty) {
            debugPrint('No more products to load. Breaking loop.');
            break; // No more products
          }

          allProducts.addAll(getProductModel.product!);
          debugPrint(
              'Fetched ${getProductModel.product!.length} products on page $currentPage. Total products fetched so far: ${allProducts.length}');
          currentPage++;
        } else {
          debugPrint('API Error: Status code ${response.statusCode}');
          debugPrint('Failed URL: $url');
          // Optionally handle non-200 status codes, e.g., throw an exception
          break; // Exit loop on error
        }
      }

      _products = allProducts;
      _filteredProducts = List.from(
          _products); // Initialize filtered list with all loaded products
      _updatePagination(); // Update pagination info based on loaded products
      _saveProductsToHive();
      debugPrint(
          'All products loaded successfully. Total: ${_products.length}');
    } catch (e) {
      debugPrint("Error fetching all products from API: $e");
      // Handle error appropriately, maybe clear products or show an error message
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Updates pagination info based on filtered products
  void _updatePagination() {
    _totalPages = (_filteredProducts.length / _itemsPerPage).ceil();
    if (_totalPages < 1) _totalPages = 1;
    if (_currentPage > _totalPages) _currentPage = _totalPages;
  }

  /// Gets paginated products based on current page
  List<GetProduct> get paginatedProducts {
    if (_filteredProducts.isEmpty) {
      return [];
    }

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    if (startIndex >= _filteredProducts.length) {
      return [];
    }

    final endIndex = startIndex + _itemsPerPage;
    return _filteredProducts.sublist(
      startIndex,
      endIndex > _filteredProducts.length ? _filteredProducts.length : endIndex,
    );
  }

  /// Sets the current page
  void setPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      _currentPage = page;
      notifyListeners();
    }
  }

  /// Updates items per page
  void setItemsPerPage(int items) {
    if (items > 0) {
      _itemsPerPage = items;
      _updatePagination();
      notifyListeners();
    }
  }

  /// Modified listAllProducts to handle pagination
  void listAllProducts({
    int? categoryId,
    String? filterName,
    String? filterPrice,
    String? filterBarcode,
    String? filterHsnCode,
    String? filterCreatedBy,
    String? filterProperties,
    String? filterStore,
    String? filterSupplier,
    int page = 1,
  }) {
    List<GetProduct> result = List.from(_products);

    if (categoryId != null && categoryId != 0) {
      result = result.where((p) => p.categoryId == categoryId).toList();
    }

    if (filterName != null && filterName.isNotEmpty) {
      result = result
          .where((p) => (p.productName ?? '')
              .toLowerCase()
              .contains(filterName.toLowerCase()))
          .toList();
    }

    if (filterBarcode != null && filterBarcode.isNotEmpty) {
      result = result
          .where((p) =>
              p.barcode != null &&
              p.barcode!.toLowerCase().contains(filterBarcode.toLowerCase()))
          .toList();
    }

    // HSN Code filter - check both product level and stock level HSN codes
    if (filterHsnCode != null && filterHsnCode.isNotEmpty) {
      result = result
          .where((p) =>
              // Check product level HSN code
              (p.hsnCode != null &&
                  p.hsnCode!
                      .toLowerCase()
                      .contains(filterHsnCode.toLowerCase())) ||
              // Check stock level HSN codes
              (p.stock != null &&
                  p.stock!.any((stock) =>
                      stock.hsnCode != null &&
                      stock.hsnCode!
                          .toLowerCase()
                          .contains(filterHsnCode.toLowerCase()))))
          .toList();
    }

    if (filterPrice != null && filterPrice.isNotEmpty) {
      result = result.where((p) {
        // Convert product price to string for partial matching
        final priceString = p.price?.price?.toString() ?? '';

        // Check if the price string contains the filter text
        return priceString.contains(filterPrice);
      }).toList();
    }

    // Note: createdBy, properties, store, and supplier filters are not available in the GetProduct model
    // These filters are kept for API compatibility but won't affect the results

    _filteredProducts = result;
    _updatePagination();
    setPage(page);

    // Make sure UI updates by calling notifyListeners
    notifyListeners();

    // Debug info to help diagnose issues
    debugPrint(
        "Category filter applied: $categoryId - Products count: ${result.length}");
  }

  /// Searches through the filtered products using [query] on the product name.
  /// Returns the list of products matching the search criteria.
  List<GetProduct> searchProducts(String query) {
    if (query.isEmpty) {
      return _filteredProducts;
    }
    return _filteredProducts
        .where((p) =>
            (p.productName ?? '').toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  /// Adds a product to the local products list.
  void addProduct(GetProduct product) {
    debugPrint("🔍 ADDING PRODUCT TO LOCAL STORAGE:");
    debugPrint("  - Product ID: ${product.productId}");
    debugPrint("  - Product Name: ${product.productName}");
    debugPrint("  - Product Purchase Price: ${product.purchasePrice}");
    debugPrint("  - Product MRP: ${product.mrp}");
    debugPrint("  - Product Sale Price: ${product.price?.price}");
    debugPrint("  - Product Stock Count: ${product.stock?.length ?? 0}");
    
    if (product.stock != null && product.stock!.isNotEmpty) {
      debugPrint("  - Stock Details:");
      for (int i = 0; i < product.stock!.length; i++) {
        final stock = product.stock![i];
        debugPrint("    Stock $i:");
        debugPrint("      - Stock ID: ${stock.id}");
        debugPrint("      - Stock Purchase Price: ${stock.purchasePrice}");
        debugPrint("      - Stock Sale Price: ${stock.price}");
        debugPrint("      - Stock MRP: ${stock.mrp}");
        debugPrint("      - Stock Quantity: ${stock.quantity}");
      }
    } else {
      debugPrint("  - No stock information available");
    }

    // Check if the product already exists in the list
    int index = _products.indexWhere((p) => p.productId == product.productId);
    if (index == -1) {
      // If the product does not exist, add it to the first position in the list
      _products.insert(0, product);
      _saveProductsToHive();
      notifyListeners(); // Notify listeners about the change
      debugPrint("✅ Product added to local storage successfully");
    } else {
      // Optionally, you can update the existing product if needed
      _products[index] = product; // Update the existing product
      _saveProductsToHive();
      notifyListeners(); // Notify listeners about the change
      debugPrint("✅ Product updated in local storage successfully");
    }
    
    debugPrint("📊 Total products in local storage: ${_products.length}");
  }

  /// Updates the filtered products with a new [filtered] list.
  void updateFilteredProducts(List<GetProduct> filtered) {
    _filteredProducts = filtered;
    notifyListeners();
  }

  /// Updates the stock quantity for a specific stock entry
  /// This method handles the actual stock tracking without validation
  void _updateStockQuantity(Stock stock, num quantityChange, String operation) {
    if (!isStockEnabled) {
      debugPrint("📦 Stock management disabled - skipping stock update");
      return;
    }

    // Find and update the stock in the products list
    for (var product in _products) {
      if (product.stock != null) {
        for (int i = 0; i < product.stock!.length; i++) {
          if (product.stock![i].id == stock.id) {
            final currentStock = product.stock![i];
            final previousQuantity = currentStock.quantity ?? 0;
            final newQuantity = previousQuantity + quantityChange;

            debugPrint("📦 STOCK UPDATE:");
            debugPrint("  - Stock ID: ${stock.id}");
            debugPrint("  - Operation: $operation");
            debugPrint("  - Quantity Change: $quantityChange");
            debugPrint("  - Previous Quantity: $previousQuantity");
            debugPrint("  - New Quantity: $newQuantity");

            // Show warning if stock goes negative (but don't prevent the operation)
            if (newQuantity < 0) {
              debugPrint(
                  "⚠️ WARNING: Stock quantity went negative ($newQuantity) - this indicates overselling");
              // Note: We don't prevent this - business decision is to allow sales even with negative stock
            }

            // Create a new Stock object with updated quantity (since Stock fields are final)
            product.stock![i] = Stock(
              id: currentStock.id,
              productId: currentStock.productId,
              quantity: newQuantity,
              price: currentStock.price,
              mrp: currentStock.mrp,
              purchasePrice: currentStock.purchasePrice,
            );

            debugPrint(
                "📦 Updated stock in product list: ${product.productName}");

            // Save updated products to Hive
            _saveProductsToHive();

            // Notify listeners to update UI
            notifyListeners();
            return;
          }
        }
      }
    }

    debugPrint("⚠️ Stock entry not found for update: ${stock.id}");
  }

  /// Updates a specific stock entry within the products list
  void _updateProductStockInList(Stock updatedStock) {
    for (var product in _products) {
      if (product.stock != null) {
        for (int i = 0; i < product.stock!.length; i++) {
          if (product.stock![i].id == updatedStock.id) {
            product.stock![i] = updatedStock;
            debugPrint(
                "📦 Updated stock in product list: ${product.productName}");
            return;
          }
        }
      }
    }
  }

  /// Adds a [product] to the local cart with a specified [quantity].
  /// If the product already exists in the cart, its quantity is incremented.
  /// Optionally updates the price of the cart item if provided.
  /// Also handles stock deduction when stock management is enabled.
  void addToCart({
    GetProduct? product,
    num? quantity = 1,
    double? price,
    double? mrp,
    int? productId,
    bool? isIncreamentUsingCompactQuantityControl = false,
    Stock? selectedStock,
  }) {
    debugPrint("🛒 ADD TO CART STARTED");
    debugPrint("Product: ${product?.productName}");
    debugPrint("Quantity: $quantity");
    debugPrint("Price: $price");
    debugPrint("MRP: $mrp");
    debugPrint("Product ID: $productId");
    debugPrint("Selected Stock: ${selectedStock?.id}");
    debugPrint("Stock Management Enabled: $isStockEnabled");

    if (productId != null) {
      product = _products.firstWhere((p) => p.productId == productId);
    }

    if (product == null) {
      debugPrint("❌ Cannot add to cart: product is null");
      return;
    }

    final cartQuantity = quantity ?? 1;

    int index = _cartItems.indexWhere((item) =>
        item.product.productId == product!.productId &&
        (item.selectedStock?.id == selectedStock?.id ||
            (item.selectedStock == null && selectedStock == null)));

    if (index != -1) {
      debugPrint("📝 Product already in cart - updating quantity");

      // STOCK DEDUCTION: Deduct the additional quantity being added
      if (isStockEnabled && selectedStock != null) {
        _updateStockQuantity(
            selectedStock, -cartQuantity, "ADD_TO_CART_INCREMENT");
      }

      // If the product already exists in cart with the same stock, just update the quantity and price
      _cartItems[index].quantity +=
          cartQuantity; // Increment by the specified quantity

      // 🔧 FIX: Handle price updates based on explicit price provision and source
      if (price != null) {
        // When ANY source provides an explicit price, use it (custom pricing from Add Item, quantity control, etc.)
        _cartItems[index].price = price;
        debugPrint("💰 Using explicit price: $price");
      } else if (!isIncreamentUsingCompactQuantityControl!) {
        // When adding from external sources WITHOUT explicit price, preserve existing custom price
        // Only update if it's a completely new addition (no existing price set)
        if (_cartItems[index].price == null || _cartItems[index].price == 0.0) {
          // No existing price set, use defaults
          if (selectedStock != null && selectedStock.price != null) {
            _cartItems[index].price = double.tryParse(selectedStock.price!);
            debugPrint("💰 Using stock price: ${_cartItems[index].price}");
          } else {
            _cartItems[index].price = product.price?.price != null
                ? double.tryParse(product.price!.price!)
                : 0.0;
            debugPrint("💰 Using product price: ${_cartItems[index].price}");
          }
        } else {
          debugPrint(
              "💰 Preserving existing price: ${_cartItems[index].price}");
        }
        // If existing price exists (could be custom), preserve it when adding from external sources without explicit price
      } else {
        debugPrint(
            "💰 Preserving existing price from quantity control: ${_cartItems[index].price}");
      }
      // Always use explicit price when provided, otherwise preserve existing custom price

      // 🔧 FIX: Apply same logic for MRP to preserve custom values
      if (mrp != null) {
        // When ANY source provides an explicit MRP, use it
        _cartItems[index].mrp = mrp;
        debugPrint("💰 Using explicit MRP: $mrp");
      } else if (!isIncreamentUsingCompactQuantityControl!) {
        // When adding from external sources WITHOUT explicit MRP, preserve existing custom MRP
        // Only update if it's a completely new addition (no existing MRP set)
        if (_cartItems[index].mrp == null || _cartItems[index].mrp == 0.0) {
          // No existing MRP set, use defaults
          if (selectedStock != null && selectedStock.mrp != null) {
            _cartItems[index].mrp = double.tryParse(selectedStock.mrp!);
            debugPrint("💰 Using stock MRP: ${_cartItems[index].mrp}");
          } else {
            _cartItems[index].mrp =
                product.mrp != null ? double.tryParse(product.mrp!) : 0.0;
            debugPrint("💰 Using product MRP: ${_cartItems[index].mrp}");
          }
        } else {
          debugPrint("💰 Preserving existing MRP: ${_cartItems[index].mrp}");
        }
        // If existing MRP exists (could be custom), preserve it when adding from external sources without explicit MRP
      } else {
        debugPrint(
            "💰 Preserving existing MRP from quantity control: ${_cartItems[index].mrp}");
      }
      // Always use explicit MRP when provided, otherwise preserve existing custom MRP

      if (!isIncreamentUsingCompactQuantityControl!) {
        // Move this item to the beginning of the array
        final cartItem = _cartItems.removeAt(index);
        _cartItems.insert(0, cartItem);
      }
    } else {
      debugPrint("🆕 Adding new product to cart");

      // STOCK DEDUCTION: Deduct quantity for new cart item
      if (isStockEnabled && selectedStock != null) {
        _updateStockQuantity(selectedStock, -cartQuantity, "ADD_TO_CART_NEW");
      }

      // Safely handle null product price when adding new cart item
      double productPrice = 0.0;
      double productMrp = 0.0;
      if (price != null) {
        productPrice = price;
      } else if (selectedStock != null && selectedStock.price != null) {
        productPrice = double.tryParse(selectedStock.price!) ?? 0.0;
      } else if (product.price?.price != null) {
        productPrice = double.tryParse(product.price!.price!) ?? 0.0;
      }

      if (mrp != null) {
        productMrp = mrp;
      } else if (selectedStock != null && selectedStock.mrp != null) {
        productMrp = double.tryParse(selectedStock.mrp!) ?? 0.0;
      } else if (product.mrp != null) {
        productMrp = double.tryParse(product.mrp!) ?? 0.0;
      }

      // Insert at the beginning of the array instead of appending
      _cartItems.insert(
          0,
          LocalCartItem(
            product: product,
            quantity: cartQuantity,
            price: productPrice,
            mrp: productMrp,
            selectedStock: selectedStock,
          ));
    }

    resetSelectedProduct();
    _saveCartToHive();
    notifyListeners();

    debugPrint("✅ ADD TO CART COMPLETED");
  }

  /// Removes the product with [productId] from the local cart.
  /// Also restores stock quantity when stock management is enabled.
  List<LocalCartItem> getCartItems() {
    return _cartItems;
  }

  void removeFromCart(int productId, Stock? selectedStock) {
    debugPrint("🗑️ REMOVE FROM CART STARTED");
    debugPrint("Product ID: $productId");
    debugPrint("Selected Stock: ${selectedStock?.id}");
    debugPrint("Stock Management Enabled: $isStockEnabled");

    int index = _cartItems.indexWhere((item) =>
        item.product.productId == productId &&
        (item.selectedStock?.id == selectedStock?.id ||
            (item.selectedStock == null && selectedStock == null)));

    if (index != -1) {
      final cartItem = _cartItems[index];
      final quantityToRestore = cartItem.quantity;

      debugPrint("📝 Found cart item - removing ${quantityToRestore} units");

      // STOCK RESTORATION: Add back the quantity being removed
      if (isStockEnabled && selectedStock != null) {
        _updateStockQuantity(
            selectedStock, quantityToRestore, "REMOVE_FROM_CART");
      }

      _cartItems.removeAt(index);
      _saveCartToHive();
      notifyListeners();

      debugPrint("✅ REMOVE FROM CART COMPLETED");
    } else {
      debugPrint("⚠️ Cart item not found for removal");
    }
  }

  void updateItemPrice(int productId, Stock? selectedStock, double newPrice) {
    // Add selectedStock
    int index = _cartItems.indexWhere((item) =>
        item.product.productId == productId &&
        (item.selectedStock?.id == selectedStock?.id ||
            (item.selectedStock == null && selectedStock == null)));

    if (index != -1) {
      _cartItems[index].price = newPrice;
      _saveCartToHive();
      notifyListeners();
    }
  }

  void updateItemMrp(int productId, Stock? selectedStock, double newMrp) {
    // Update MRP for cart item
    int index = _cartItems.indexWhere((item) =>
        item.product.productId == productId &&
        (item.selectedStock?.id == selectedStock?.id ||
            (item.selectedStock == null && selectedStock == null)));

    if (index != -1) {
      _cartItems[index].mrp = newMrp;
      _saveCartToHive();
      notifyListeners();
    }
  }

  /// Decrements the quantity of the product in the cart.
  /// If the quantity becomes less than 1, the product is removed from the cart.
  /// Also handles stock restoration when stock management is enabled.
  void decrementCartItem(int productId, Stock? selectedStock) {
    debugPrint("➖ DECREMENT CART ITEM STARTED");
    debugPrint("Product ID: $productId");
    debugPrint("Selected Stock: ${selectedStock?.id}");
    debugPrint("Stock Management Enabled: $isStockEnabled");

    int index = _cartItems.indexWhere((item) =>
        item.product.productId == productId &&
        (item.selectedStock?.id == selectedStock?.id ||
            (item.selectedStock == null && selectedStock == null)));

    if (index != -1) {
      debugPrint(
          "📝 Found cart item - current quantity: ${_cartItems[index].quantity}");

      if (_cartItems[index].quantity > 1) {
        // STOCK RESTORATION: Add back 1 unit
        if (isStockEnabled && selectedStock != null) {
          _updateStockQuantity(selectedStock, 1, "DECREMENT_CART_ITEM");
        }

        _cartItems[index].quantity--;
        debugPrint("📝 Decremented quantity to: ${_cartItems[index].quantity}");
      } else {
        // STOCK RESTORATION: Add back the last unit
        if (isStockEnabled && selectedStock != null) {
          _updateStockQuantity(selectedStock, 1, "DECREMENT_CART_ITEM_REMOVE");
        }

        _cartItems.removeAt(index);
        debugPrint("📝 Removed item from cart (quantity was 1)");
      }

      _saveCartToHive();
      notifyListeners();

      debugPrint("✅ DECREMENT CART ITEM COMPLETED");
    } else {
      debugPrint("⚠️ Cart item not found for decrement");
    }
  }

  /// Clears all items from the local cart.
  /// Also restores all stock quantities when stock management is enabled.
  void clearCart() {
    debugPrint("🧹 CLEAR CART STARTED");
    debugPrint("Cart items count: ${_cartItems.length}");
    debugPrint("Stock Management Enabled: $isStockEnabled");

    // STOCK RESTORATION: Restore all quantities from cart items
    if (isStockEnabled) {
      for (var cartItem in _cartItems) {
        if (cartItem.selectedStock != null) {
          _updateStockQuantity(
              cartItem.selectedStock!, cartItem.quantity, "CLEAR_CART");
        }
      }
    }

    _cartItems.clear();
    _cartItemsBox.clear();
    clearDiscount(); // Also clear discounts when cart is cleared
    notifyListeners();

    debugPrint("✅ CLEAR CART COMPLETED");
  }

  /// Clears the current order being edited
  void clearCurrentOrder() {
    debugPrint("🧹 CLEARING CURRENT ORDER REFERENCE");
    _currentOrder = null;
    notifyListeners();
  }

  /// Resets the local product list and filtered list.
  void resetProducts() {
    _products = [];
    _filteredProducts = [];
    _productsBox.clear();
    notifyListeners();
  }

  /// Refreshes products by reinitializing the filtered list to the full product list.
  void refreshProducts() {
    _filteredProducts = List.from(_products);
    notifyListeners();
  }

  /// Updates a single product in the local list.
  /// If the product exists, it gets updated; otherwise, it is added.
  void updateProduct(GetProduct product) {
    int index = _products.indexWhere((p) => p.productId == product.productId);
    if (index != -1) {
      _products[index] = product;
    } else {
      _products.add(product);
    }
    _saveProductsToHive();
    refreshProducts();
  }

  /// Manually adds new stock entry to an existing product
  /// This is much faster than fetching all products from API
  void addStockToProduct({
    required int productId,
    required int stockId,
    required num quantity,
    required String price,
    required String mrp,
    required String purchasePrice,
  }) {
    debugPrint("📦 MANUAL STOCK UPDATE STARTED");
    debugPrint("Product ID: $productId");
    debugPrint("Stock ID: $stockId");
    debugPrint("Quantity: $quantity");
    debugPrint("Price: $price");

    // Find the product in the local list
    int productIndex = _products.indexWhere((p) => p.productId == productId);

    if (productIndex != -1) {
      GetProduct oldProduct = _products[productIndex];

      // Create a copy of existing stock list
      List<Stock> updatedStock =
          oldProduct.stock != null ? List<Stock>.from(oldProduct.stock!) : [];

      // Check if stock entry already exists
      int stockIndex = updatedStock.indexWhere((s) => s.id == stockId);

      if (stockIndex != -1) {
        // Update existing stock entry
        Stock existingStock = updatedStock[stockIndex];
        updatedStock[stockIndex] = Stock(
          id: existingStock.id,
          productId: existingStock.productId,
          quantity: (existingStock.quantity ?? 0) +
              quantity, // Add to existing quantity
          price: price,
          mrp: mrp,
          purchasePrice: purchasePrice,
        );
        debugPrint(
            "📦 Updated existing stock entry - New quantity: ${updatedStock[stockIndex].quantity}");
      } else {
        // Add new stock entry
        Stock newStock = Stock(
          id: stockId,
          productId: productId,
          quantity: quantity,
          price: price,
          mrp: mrp,
          purchasePrice: purchasePrice,
        );

        updatedStock.add(newStock);
        debugPrint("📦 Added new stock entry to product");
      }

      // Create new product instance with updated stock
      GetProduct updatedProduct = GetProduct(
        productId: oldProduct.productId,
        categoryId: oldProduct.categoryId,
        productName: oldProduct.productName,
        productSlug: oldProduct.productSlug,
        barcode: oldProduct.barcode,
        category: oldProduct.category,
        numberOfProductsAvailable: oldProduct.numberOfProductsAvailable,
        rating: oldProduct.rating,
        unit: oldProduct.unit,
        currency: oldProduct.currency,
        description: oldProduct.description,
        price: oldProduct.price,
        mrp: oldProduct.mrp,
        purchasePrice: oldProduct.purchasePrice,
        attachment: oldProduct.attachment,
        names: oldProduct.names,
        productProps: oldProduct.productProps,
        weightInfo: oldProduct.weightInfo,
        stock: updatedStock, // Updated stock list
      );

      // Update the product in the list
      _products[productIndex] = updatedProduct;

      // Save to Hive
      _saveProductsToHive();

      // Update filtered products if needed
      refreshProducts();

      debugPrint("✅ MANUAL STOCK UPDATE COMPLETED");
    } else {
      debugPrint("❌ Product not found for stock update: $productId");
    }
  }

  /// Updates stock quantity for a specific stock entry
  /// Used when stock quantities change (e.g., after sales, returns, etc.)
  void updateStockQuantity({
    required int productId,
    required int stockId,
    required num newQuantity,
  }) {
    debugPrint("📦 MANUAL STOCK QUANTITY UPDATE");
    debugPrint(
        "Product ID: $productId, Stock ID: $stockId, New Quantity: $newQuantity");

    int productIndex = _products.indexWhere((p) => p.productId == productId);

    if (productIndex != -1) {
      GetProduct oldProduct = _products[productIndex];

      if (oldProduct.stock != null) {
        // Create a copy of existing stock list
        List<Stock> updatedStock = List<Stock>.from(oldProduct.stock!);

        int stockIndex = updatedStock.indexWhere((s) => s.id == stockId);

        if (stockIndex != -1) {
          Stock existingStock = updatedStock[stockIndex];
          updatedStock[stockIndex] = Stock(
            id: existingStock.id,
            productId: existingStock.productId,
            quantity: newQuantity,
            price: existingStock.price,
            mrp: existingStock.mrp,
            purchasePrice: existingStock.purchasePrice,
          );

          // Create new product instance with updated stock
          GetProduct updatedProduct = GetProduct(
            productId: oldProduct.productId,
            categoryId: oldProduct.categoryId,
            productName: oldProduct.productName,
            productSlug: oldProduct.productSlug,
            barcode: oldProduct.barcode,
            category: oldProduct.category,
            numberOfProductsAvailable: oldProduct.numberOfProductsAvailable,
            rating: oldProduct.rating,
            unit: oldProduct.unit,
            currency: oldProduct.currency,
            description: oldProduct.description,
            price: oldProduct.price,
            mrp: oldProduct.mrp,
            purchasePrice: oldProduct.purchasePrice,
            attachment: oldProduct.attachment,
            names: oldProduct.names,
            productProps: oldProduct.productProps,
            weightInfo: oldProduct.weightInfo,
            stock: updatedStock, // Updated stock list
          );

          // Update the product in the list
          _products[productIndex] = updatedProduct;

          // Save to Hive
          _saveProductsToHive();

          // Refresh products
          refreshProducts();

          debugPrint("✅ Stock quantity updated successfully");
        } else {
          debugPrint("❌ Stock entry not found: $stockId");
        }
      }
    } else {
      debugPrint("❌ Product not found: $productId");
    }
  }

  /// Removes a product from the local product list.
  void deleteProduct(int productId) {
    _products.removeWhere((p) => p.productId == productId);
    _saveProductsToHive();
    refreshProducts();
  }

  /// Retrieves a product by its ID.
  GetProduct? getProductById(int productId) {
    try {
      return _products.firstWhere((p) => p.productId == productId);
    } catch (e) {
      return null;
    }
  }

  List<GetProduct> filterProductByBarcode({required String barCode}) {
    debugPrint("filterProductByBarcode $barCode");
    List<GetProduct> filteredProducts = [];
    // Filter the products
    filteredProducts =
        _products.where((product) => product.barcode == barCode).toList();

    // Check if any product was found before accessing .first
    if (filteredProducts.isNotEmpty) {
      debugPrint(filteredProducts.first.productName);
    } else {
      debugPrint("No product found for barcode: $barCode");
    }
    return filteredProducts;
  }

  /// Saves the current cart as a confirmed order
  SavedOrder saveCurrentCartAsConfirmedOrder({
    String? customerName,
    String? customerPhone,
    String? comment,
    String? deliveryMethod,
    // New API-compatible parameters
    int? customerId,
    String? paymentMethod,
    String? paidAmount,
    String? balanceAmount,
    String? transactionId,
    String? couponId,
    String? deliveryMethodId,
    String? carNumber,
    String? status,
    String? deliveryDate, // Add deliveryDate
    String? deliveryTime, // Add deliveryTime
    bool? toCustomerCredit,
    BuildContext? context, // Add context parameter
  }) {
    if (_cartItems.isEmpty) {
      throw Exception("Cannot save an empty cart as confirmed order");
    }

    // Generate a unique ID for the order (timestamp-based)
    final String orderId = DateTime.now().millisecondsSinceEpoch.toString();

    // Calculate total with rounding if enabled
    double total = context != null ? getRoundedTotal(context) : cartTotal;

    // Create a deep copy of cart items to prevent modification
    List<LocalCartItem> orderItems = _cartItems
        .map((item) => LocalCartItem(
              product: item.product,
              quantity: item.quantity,
              price: item.price,
              mrp: item.mrp, // 🔧 FIX: Include MRP when saving confirmed order
              selectedStock: item.selectedStock,
            ))
        .toList();

    // Generate sequential order number - use "CONF-" prefix for confirmed orders
    String orderNumber = generateConfirmedOrderNumber();

    // Create the confirmed order
    final SavedOrder order = SavedOrder(
      id: orderId,
      orderNumber: orderNumber,
      items: orderItems,
      customerName: customerName,
      customerPhone: customerPhone,
      comment: comment,
      createdAt: DateTime.now().toIso8601String(),
      total: total,
      deliveryMethod: deliveryMethod,
      // Include new API-compatible fields
      customerId: customerId,
      paymentMethod: paymentMethod,
      paidAmount: paidAmount,
      balanceAmount: balanceAmount,
      transactionId: transactionId,
      couponId: couponId,
      deliveryMethodId: deliveryMethodId,
      carNumber: carNumber,
      status: status ?? "confirmed", // Default to "confirmed" if not provided
      deliveryDate: deliveryDate, // Pass deliveryDate
      deliveryTime: deliveryTime, // Pass deliveryTime
      flatDiscount: _flatDiscount,
      percentageDiscount: _percentageDiscount,
      toCustomerCredit: toCustomerCredit,
    );

    // Add to confirmed orders list
    _confirmedOrders.add(order);
    _saveConfirmedOrdersToHive();
    notifyListeners();

    return order;
  }

  /// Moves an existing saved order to confirmed orders
  SavedOrder? moveToConfirmedOrders(String orderId) {
    try {
      // Find the order in saved orders
      int index = _savedOrders.indexWhere((o) => o.id == orderId);

      if (index != -1) {
        // Get the order
        SavedOrder order = _savedOrders[index];

        // Create a new order with "CONF-" prefix for order number
        SavedOrder confirmedOrder = SavedOrder(
          id: order.id,
          orderNumber: "CONF-${order.orderNumber.split('-')[1]}",
          items: order.items,
          customerName: order.customerName,
          customerPhone: order.customerPhone,
          comment: order.comment,
          createdAt: order.createdAt,
          total: order.total,
          deliveryMethod: order.deliveryMethod,
          // Preserve API-compatible fields
          customerId: order.customerId,
          paymentMethod: order.paymentMethod,
          paidAmount: order.paidAmount,
          balanceAmount: order.balanceAmount,
          transactionId: order.transactionId,
          couponId: order.couponId,
          deliveryMethodId: order.deliveryMethodId,
          carNumber: order.carNumber,
          status: order.status ?? "confirmed",
          deliveryDate: order.deliveryDate, // Store deliveryDate in Hive
          deliveryTime: order.deliveryTime, // Store deliveryTime in Hive
          flatDiscount: order.flatDiscount,
          percentageDiscount: order.percentageDiscount,
          toCustomerCredit: order.toCustomerCredit,
        );

        // Add to confirmed orders
        _confirmedOrders.add(confirmedOrder);

        // Remove from saved orders
        _savedOrders.removeAt(index);

        // Save both lists
        _saveSavedOrdersToHive();
        _saveConfirmedOrdersToHive();

        notifyListeners();

        return confirmedOrder;
      }
      return null;
    } catch (e) {
      debugPrint("Error moving order to confirmed orders: $e");
      return null;
    }
  }

  /// Generates sequential order numbers in format CONF-1, CONF-2, etc. for confirmed orders
  String generateConfirmedOrderNumber() {
    // Find the highest existing order number
    int highestNumber = 0;

    for (var order in _confirmedOrders) {
      // Extract the number part from the orderNumber (e.g., "CONF-5" -> 5)
      String numPart = order.orderNumber.split('-')[1];
      int orderNum = int.tryParse(numPart) ?? 0;

      if (orderNum > highestNumber) {
        highestNumber = orderNum;
      }
    }

    // Return next number in sequence
    return 'CONF-${highestNumber + 1}';
  }

  /// Finds a confirmed order by its ID
  SavedOrder? findConfirmedOrderById(String orderId) {
    try {
      return _confirmedOrders.firstWhere((order) => order.id == orderId);
    } catch (e) {
      return null;
    }
  }

  /// Deletes a confirmed order
  void deleteConfirmedOrder(String orderId) {
    _confirmedOrders.removeWhere((o) => o.id == orderId);
    _saveConfirmedOrdersToHive();
    notifyListeners();
  }

  /// Saves the current cart as an order
  SavedOrder saveCurrentCartAsOrder({
    String? customerName,
    String? customerPhone,
    String? comment,
    String? deliveryMethod,
    // New API-compatible parameters
    int? customerId,
    String? paymentMethod,
    String? paidAmount,
    String? balanceAmount,
    String? transactionId,
    String? couponId,
    String? deliveryMethodId,
    String? carNumber,
    String? status,
    String? deliveryDate, // Add deliveryDate
    String? deliveryTime, // Add deliveryTime
    bool? toCustomerCredit,
    BuildContext? context, // Add context parameter
  }) {
    debugPrint("💾 LOCAL PROVIDER - saveCurrentCartAsOrder called");
    debugPrint("  - Customer Phone parameter: '$customerPhone'");
    debugPrint("  - Customer Name parameter: '$customerName'");
    debugPrint("  - Customer ID parameter: $customerId");

    if (_cartItems.isEmpty) {
      throw Exception("Cannot save an empty cart as order");
    }

    // Generate a unique ID for the order (timestamp-based)
    final String orderId = DateTime.now().millisecondsSinceEpoch.toString();

    // Calculate total with rounding if enabled
    double total = context != null ? getRoundedTotal(context) : cartTotal;

    // Create a deep copy of cart items to prevent modification
    List<LocalCartItem> orderItems = _cartItems
        .map((item) => LocalCartItem(
              product: item.product,
              quantity: item.quantity,
              price: item.price,
              mrp: item.mrp, // 🔧 FIX: Include MRP when saving order
              selectedStock: item.selectedStock,
            ))
        .toList();

    // Generate sequential order number
    String orderNumber = generateOrderNumber();

    // Create the saved order
    final SavedOrder order = SavedOrder(
      id: orderId,
      orderNumber: orderNumber,
      items: orderItems,
      customerName: customerName,
      customerPhone: customerPhone,
      comment: comment,
      createdAt: DateTime.now().toIso8601String(),
      total: total,
      deliveryMethod: deliveryMethod,
      // Include new API-compatible fields
      customerId: customerId,
      paymentMethod: paymentMethod,
      paidAmount: paidAmount,
      balanceAmount: balanceAmount,
      transactionId: transactionId,
      couponId: couponId,
      deliveryMethodId: deliveryMethodId,
      carNumber: carNumber,
      status: status ?? "saved", // Default to "saved" for regular orders
      deliveryDate: deliveryDate, // Pass deliveryDate
      deliveryTime: deliveryTime, // Pass deliveryTime
      flatDiscount: _flatDiscount,
      percentageDiscount: _percentageDiscount,
      toCustomerCredit: toCustomerCredit,
    );

    // Add to saved orders list
    _savedOrders.add(order);
    _saveSavedOrdersToHive();
    notifyListeners();

    debugPrint("  - New order created: ${order.orderNumber}");
    debugPrint("  - Saved order phone: '${order.customerPhone}'");
    debugPrint("  - Saved order name: '${order.customerName}'");
    debugPrint("  - Saved order customer ID: ${order.customerId}");
    debugPrint("💾 LOCAL PROVIDER - saveCurrentCartAsOrder completed");

    return order;
  }

  /// Generates sequential order numbers in format ORD-1, ORD-2, etc.
  String generateOrderNumber() {
    // Find the highest existing order number
    int highestNumber = 0;

    for (var order in _savedOrders) {
      // Extract the number part from the orderNumber (e.g., "ORD-5" -> 5)
      String numPart = order.orderNumber.split('-')[1];
      int orderNum = int.tryParse(numPart) ?? 0;

      if (orderNum > highestNumber) {
        highestNumber = orderNum;
      }
    }

    // Return next number in sequence
    return 'ORD-${highestNumber + 1}';
  }

  /// Finds a saved order by its ID
  SavedOrder? findOrderById(String orderId) {
    try {
      return _savedOrders.firstWhere((order) => order.id == orderId);
    } catch (e) {
      return null;
    }
  }

  /// Loads a saved order into the current cart for editing
  void loadOrderForEditing(String orderId) {
    try {
      // Find the order
      final SavedOrder order = _savedOrders.firstWhere((o) => o.id == orderId);

      // Restore discounts
      _flatDiscount = order.flatDiscount ?? 0.0;
      _percentageDiscount = order.percentageDiscount ?? 0.0;

      // Clear current cart
      _cartItems.clear();

      // Add items from the saved order to the cart
      for (var item in order.items) {
        _cartItems.add(LocalCartItem(
          product: item.product,
          quantity: item.quantity,
          price: item.price,
          mrp: item.mrp, // 🔧 FIX: Include MRP when loading order for editing
          selectedStock: item.selectedStock,
        ));
      }

      // Set current order
      _currentOrder = order;

      _saveCartToHive();
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading order: $e");
    }
  }

  /// Updates an existing saved order
  void updateSavedOrder(
    String orderId, {
    String? customerName,
    String? customerPhone,
    String? comment,
    String? deliveryMethod,
    // New API-compatible parameters
    int? customerId,
    String? paymentMethod,
    String? paidAmount,
    String? balanceAmount,
    String? transactionId,
    String? couponId,
    String? deliveryMethodId,
    String? carNumber,
    String? status,
    String? deliveryDate, // Add deliveryDate
    String? deliveryTime, // Add deliveryTime
    bool? toCustomerCredit,
  }) {
    debugPrint("💾 LOCAL PROVIDER - updateSavedOrder called");
    debugPrint("  - Order ID: $orderId");
    debugPrint("  - Customer Phone parameter: '$customerPhone'");
    debugPrint("  - Customer Name parameter: '$customerName'");
    debugPrint("  - Customer ID parameter: $customerId");

    int index = _savedOrders.indexWhere((o) => o.id == orderId);

    if (index != -1) {
      debugPrint("  - Found order at index: $index");
      debugPrint(
          "  - Original order phone: '${_savedOrders[index].customerPhone}'");
      // Get current cart total
      double total = cartTotal;

      // Create a copy of current cart items
      List<LocalCartItem> orderItems = _cartItems
          .map((item) => LocalCartItem(
                product: item.product,
                quantity: item.quantity,
                price: item.price,
                mrp: item.mrp, // 🔧 FIX: Include MRP when updating saved order
                selectedStock: item.selectedStock,
              ))
          .toList();

      // Create updated order
      SavedOrder updatedOrder = SavedOrder(
        id: orderId,
        orderNumber: _savedOrders[index].orderNumber,
        items: orderItems,
        customerName: customerName ?? _savedOrders[index].customerName,
        customerPhone: customerPhone ?? _savedOrders[index].customerPhone,
        comment: comment ?? _savedOrders[index].comment,
        createdAt:
            DateTime.now().toIso8601String(), // Keep original creation date
        total: total,
        deliveryMethod: deliveryMethod ?? _savedOrders[index].deliveryMethod,
        // Update or preserve API-compatible fields
        customerId: customerId ?? _savedOrders[index].customerId,
        paymentMethod: paymentMethod ?? _savedOrders[index].paymentMethod,
        paidAmount: paidAmount ?? _savedOrders[index].paidAmount,
        balanceAmount: balanceAmount ?? _savedOrders[index].balanceAmount,
        transactionId: transactionId ?? _savedOrders[index].transactionId,
        couponId: couponId ?? _savedOrders[index].couponId,
        deliveryMethodId:
            deliveryMethodId ?? _savedOrders[index].deliveryMethodId,
        carNumber: carNumber ?? _savedOrders[index].carNumber,
        status: status ?? _savedOrders[index].status,
        deliveryDate: deliveryDate ??
            _savedOrders[index].deliveryDate, // Update deliveryDate
        deliveryTime: deliveryTime ??
            _savedOrders[index].deliveryTime, // Update deliveryTime
        flatDiscount: _flatDiscount,
        percentageDiscount: _percentageDiscount,
        toCustomerCredit:
            toCustomerCredit ?? _savedOrders[index].toCustomerCredit,
      );

      // Update in list
      _savedOrders[index] = updatedOrder;

      debugPrint("  - Updated order phone: '${updatedOrder.customerPhone}'");
      debugPrint("  - Updated order name: '${updatedOrder.customerName}'");
      debugPrint("  - Updated order customer ID: ${updatedOrder.customerId}");

      // Clear current order reference
      _currentOrder = null;

      _saveSavedOrdersToHive();
      notifyListeners();

      debugPrint("💾 LOCAL PROVIDER - updateSavedOrder completed");
    } else {
      debugPrint("⚠️ LOCAL PROVIDER - Order not found: $orderId");
    }
  }

  /// Deletes a saved order
  void deleteSavedOrder(String orderId) {
    _savedOrders.removeWhere((o) => o.id == orderId);

    // If current order is deleted, clear reference
    if (_currentOrder != null && _currentOrder!.id == orderId) {
      _currentOrder = null;
    }

    _saveSavedOrdersToHive();
    notifyListeners();
  }

  /// Checks if a product has available stock
  bool hasAvailableStock(GetProduct product, {num quantity = 1}) {
    if (product.stock == null || product.stock!.isEmpty) {
      // If stock isn't tracked, assume it's available
      return true;
    }

    // Check if at least one stock entry has enough quantity
    return product.stock!
        .any((stock) => stock.quantity != null && stock.quantity! >= quantity);
  }

  /// Gets the available stock quantity for a product
  num getAvailableStockQuantity(GetProduct product) {
    if (product.stock == null || product.stock!.isEmpty) {
      // If stock isn't tracked, return a large number
      return 9999;
    }

    // Sum all stock quantities
    return product.stock!.fold(0, (sum, stock) => sum + (stock.quantity ?? 0));
  }

  /// Gets a list of available stock options for a product
  List<Stock> getStockOptions(GetProduct product) {
    if (product.stock == null) {
      return [];
    }
    return product.stock!
        .where((stock) => stock.quantity != null && stock.quantity! > 0)
        .toList();
  }

  /// Selects the optimal stock entry based on quantity needed
  Stock? selectStockForQuantity(GetProduct product, num quantity) {
    if (product.stock == null || product.stock!.isEmpty) {
      return null;
    }

    // First try to find a stock entry with exact or more quantity
    var availableStocks = product.stock!
        .where((stock) => stock.quantity != null && stock.quantity! >= quantity)
        .toList();

    if (availableStocks.isNotEmpty) {
      // Sort by price if available, otherwise return the first one
      availableStocks.sort((a, b) {
        if (a.price == null || b.price == null) return 0;
        return (double.tryParse(a.price!) ?? 0)
            .compareTo(double.tryParse(b.price!) ?? 0);
      });
      return availableStocks.first;
    }

    // If no single stock entry has enough quantity, return the one with most quantity
    var sortedStocks = List<Stock>.from(product.stock!);
    sortedStocks.sort((a, b) => (b.quantity ?? 0).compareTo(a.quantity ?? 0));

    return sortedStocks.isNotEmpty ? sortedStocks.first : null;
  }

  /// Gets current stock information for a product (for debugging/monitoring)
  Map<String, dynamic> getStockInfo(int productId) {
    final product = _products.firstWhere((p) => p.productId == productId,
        orElse: () => throw Exception("Product not found"));

    if (product.stock == null || product.stock!.isEmpty) {
      return {
        'productName': product.productName,
        'stockManagementEnabled': isStockEnabled,
        'hasStockEntries': false,
        'stockEntries': []
      };
    }

    List<Map<String, dynamic>> stockEntries = product.stock!
        .map((stock) => {
              'stockId': stock.id,
              'quantity': stock.quantity,
              'price': stock.price,
              'mrp': stock.mrp,
              'status':
                  (stock.quantity ?? 0) <= 0 ? 'OUT_OF_STOCK' : 'AVAILABLE'
            })
        .toList();

    return {
      'productName': product.productName,
      'stockManagementEnabled': isStockEnabled,
      'hasStockEntries': true,
      'stockEntries': stockEntries,
      'totalAvailableQuantity': product.stock!
          .fold<num>(0, (sum, stock) => sum + (stock.quantity ?? 0))
    };
  }

  /// Sets the exact quantity of a cart item. Supports fractional quantities.
  /// If [newQuantity] is 0 or less, the item is removed from the cart.
  /// Stock levels are adjusted based on the difference between old and new quantities.
  void setCartItemQuantity(
      int productId, Stock? selectedStock, num newQuantity) {
    debugPrint("🔄 SET CART ITEM QUANTITY STARTED");
    debugPrint("Product ID: $productId");
    debugPrint("Selected Stock: ${selectedStock?.id}");
    debugPrint("Requested Quantity: $newQuantity");
    debugPrint("Stock Management Enabled: $isStockEnabled");

    int index = _cartItems.indexWhere((item) =>
        item.product.productId == productId &&
        (item.selectedStock?.id == selectedStock?.id ||
            (item.selectedStock == null && selectedStock == null)));

    if (index == -1) {
      debugPrint("⚠️ Cart item not found – cannot set quantity");
      return;
    }

    final currentQuantity = _cartItems[index].quantity;
    final num difference =
        newQuantity - currentQuantity; // positive if increasing

    // Handle stock adjustment if enabled
    if (isStockEnabled && selectedStock != null && difference != 0) {
      // If difference is positive we are selling more → deduct stock (-difference)
      // If difference is negative we are reducing sale → restore stock (+abs(difference))
      _updateStockQuantity(
          selectedStock, -difference, "SET_CART_ITEM_QUANTITY");
    }

    if (newQuantity <= 0) {
      // Remove item
      debugPrint("🗑️ New quantity <= 0 – removing item from cart");
      _cartItems.removeAt(index);
    } else {
      // Update quantity
      _cartItems[index].quantity = newQuantity;
      debugPrint("✅ Quantity updated: $currentQuantity → $newQuantity");
    }

    _saveCartToHive();
    notifyListeners();
    debugPrint("🔄 SET CART ITEM QUANTITY COMPLETED");
  }

  // Add method to get rounded total
  double getRoundedTotal(BuildContext context) {
    double originalTotal = cartTotal;

    // Check if rounding is enabled
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    if (appSettingsProvider.appSettings?.priceRoundOff == true) {
      return AmountHelper.roundOffAmount(originalTotal);
    }

    return originalTotal;
  }

  /// Applies discount to the cart
  void applyDiscount({
    required double flatDiscount,
    required double percentageDiscount,
  }) {
    debugPrint("🏷️ APPLYING DISCOUNT");
    debugPrint("  - Flat Discount: $flatDiscount");
    debugPrint("  - Percentage Discount: $percentageDiscount%");

    _flatDiscount = flatDiscount;
    _percentageDiscount = percentageDiscount;

    // Recalculate totals by calling cartTotal getter
    cartTotal;

    notifyListeners();

    debugPrint("✅ DISCOUNT APPLIED SUCCESSFULLY");
  }

  /// Clears all applied discounts
  void clearDiscount() {
    debugPrint("🧹 CLEARING DISCOUNT");

    _flatDiscount = 0.0;
    _percentageDiscount = 0.0;

    // Recalculate totals by calling cartTotal getter
    cartTotal;

    notifyListeners();

    debugPrint("✅ DISCOUNT CLEARED SUCCESSFULLY");
  }

  /// Gets current discount values
  Map<String, double> getCurrentDiscount() {
    return {
      'flatDiscount': _flatDiscount,
      'percentageDiscount': _percentageDiscount,
    };
  }

  // End of LocalProductProvider
}

// End of file.
