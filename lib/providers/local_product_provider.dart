import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import '../models/get_product.dart';
import '../models/local_models.dart';
import '../resources/app_url.dart';

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
  });
}

class PriceSummary {
  double discount;
  double netPayable;
  double subTotal;
  double totalTax;
  double netTotal;

  PriceSummary({
    required this.discount,
    required this.netPayable,
    required this.subTotal,
    required this.totalTax,
    required this.netTotal,
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
      );

      _savedOrdersBox.add(hiveSavedOrder);
    }
  }

  double get cartTotal {
    double total = 0.0;
    double totalTax = 0.0; // Assuming you have a way to calculate tax
    double discount = 0.0; // Assuming you have a way to calculate discount

    for (var item in _cartItems) {
      total += (item.price ?? 0) * item.quantity; // Calculate total price
    }

    // Create a PriceSummary instance
    priceSummary = PriceSummary(
      discount: discount,
      netPayable:
          total - discount, // Assuming net payable is total minus discount
      subTotal: total,
      totalTax: totalTax,
      netTotal: total - discount + totalTax, // Assuming net total includes tax
    );

    return total;
  }

  void resetSelectedProduct() {
    _selectedProduct = null;
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
      {int? categoryId, String? filterName, int page = 1}) async {
    final queryParams = <String, String>{
      if (filterName != null) 'name': filterName,
      if (categoryId != null && categoryId != 0)
        'category_id': categoryId.toString(),
      'page': page.toString(),
      'list_all': "true",
    };
    isLoading = true;
    notifyListeners();
    final url =
        Uri.parse(APPUrl.getProductUrl).replace(queryParameters: queryParams);
    try {
      final response = await http.get(url);
      debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        // Assumes that GetProductModel is defined and imported in this file.
        GetProductModel getProductModel = GetProductModel.fromJson(jsonData);
        _products = getProductModel.product ?? [];
        _filteredProducts = List.from(_products);
        _saveProductsToHive();
        notifyListeners();
      }
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
      result = result.where((p) => p.barcode == filterBarcode).toList();
    }

    if (filterPrice != null && filterPrice.isNotEmpty) {
      result = result.where((p) {
        final price = double.tryParse(p.price?.price ?? '0') ?? 0;
        final filterPriceValue = double.tryParse(filterPrice) ?? 0;
        return price == filterPriceValue;
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
    // Check if the product already exists in the list
    int index = _products.indexWhere((p) => p.productId == product.productId);
    if (index == -1) {
      // If the product does not exist, add it to the first position in the list
      _products.insert(0, product);
      _saveProductsToHive();
      notifyListeners(); // Notify listeners about the change
      debugPrint("Product added: $product");
    } else {
      // Optionally, you can update the existing product if needed
      _products[index] = product; // Update the existing product
      _saveProductsToHive();
      notifyListeners(); // Notify listeners about the change
      debugPrint("Product updated: $product");
    }
  }

  /// Updates the filtered products with a new [filtered] list.
  void updateFilteredProducts(List<GetProduct> filtered) {
    _filteredProducts = filtered;
    notifyListeners();
  }

  /// Sets the selected product based on [productId] to show product details.
  void callProductDetails(int productId) {
    try {
      _selectedProduct =
          _products.firstWhere((product) => product.productId == productId);
    } catch (e) {
      _selectedProduct = null;
    }
    notifyListeners();
  }

  /// Adds a [product] to the local cart with a specified [quantity].
  /// If the product already exists in the cart, its quantity is incremented.
  /// Optionally updates the price of the cart item if provided.
  void addToCart({
    GetProduct? product,
    num? quantity = 1,
    double? price,
    double? mrp,
    int? productId,
    bool? isIncreamentUsingCompactQuantityControl = false,
    Stock? selectedStock,
  }) {
    debugPrint("addToCart");
    debugPrint(product.toString());
    debugPrint(quantity.toString());
    debugPrint(price.toString());
    debugPrint(mrp.toString());
    debugPrint(productId.toString());
    debugPrint(selectedStock.toString());

    if (productId != null) {
      product = _products.firstWhere((p) => p.productId == productId);
    }

    int index = _cartItems.indexWhere((item) =>
        item.product.productId == product!.productId &&
        (item.selectedStock?.id == selectedStock?.id ||
            (item.selectedStock == null && selectedStock == null)));

    if (index != -1) {
      // If the product already exists in cart with the same stock, just update the quantity and price
      _cartItems[index].quantity +=
          quantity!; // Increment by the specified quantity
      if (price != null) {
        _cartItems[index].price = price; // Update the price if provided
      } else if (selectedStock != null && selectedStock.price != null) {
        _cartItems[index].price =
            double.tryParse(selectedStock.price!); // Use stock price
      } else {
        // Safely handle null product price
        _cartItems[index].price = _cartItems[index].price ??
            (product!.price?.price != null
                ? double.tryParse(product.price!.price!)
                : 0.0);
      }

      if (mrp != null) {
        _cartItems[index].mrp = mrp;
      } else if (selectedStock != null && selectedStock.mrp != null) {
        _cartItems[index].mrp =
            double.tryParse(selectedStock.mrp!); // Use stock price
      } else {
        _cartItems[index].mrp = _cartItems[index].mrp ??
            (product!.mrp != null ? double.tryParse(product.mrp!) : 0.0);
      }

      if (!isIncreamentUsingCompactQuantityControl!) {
        // Move this item to the beginning of the array
        final cartItem = _cartItems.removeAt(index);
        _cartItems.insert(0, cartItem);
      }
    } else {
      // Safely handle null product price when adding new cart item
      double productPrice = 0.0;
      double productMrp = 0.0;
      if (price != null) {
        productPrice = price;
      } else if (selectedStock != null && selectedStock.price != null) {
        productPrice = double.tryParse(selectedStock.price!) ?? 0.0;
      } else if (product!.price?.price != null) {
        productPrice = double.tryParse(product.price!.price!) ?? 0.0;
      }

      if (mrp != null) {
        productMrp = mrp;
      } else if (selectedStock != null && selectedStock.mrp != null) {
        productMrp = double.tryParse(selectedStock.mrp!) ?? 0.0;
      } else if (product!.mrp != null) {
        productMrp = double.tryParse(product.mrp!) ?? 0.0;
      }

      // Insert at the beginning of the array instead of appending
      _cartItems.insert(
          0,
          LocalCartItem(
            product: product!,
            quantity: quantity!,
            price: productPrice,
            selectedStock: selectedStock,
          ));
    }
    resetSelectedProduct();
    _saveCartToHive();
    notifyListeners();
  }

  /// Removes the product with [productId] from the local cart.
  List<LocalCartItem> getCartItems() {
    return _cartItems;
  }

  void removeFromCart(int productId, Stock? selectedStock) {
    // Add selectedStock parameter
    int index = _cartItems.indexWhere((item) =>
        item.product.productId == productId &&
        (item.selectedStock?.id == selectedStock?.id ||
            (item.selectedStock == null && selectedStock == null)));

    if (index != -1) {
      _cartItems.removeAt(index);
      _saveCartToHive();
      notifyListeners();
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

  /// Decrements the quantity of the product in the cart.
  /// If the quantity becomes less than 1, the product is removed from the cart.
  void decrementCartItem(int productId, Stock? selectedStock) {
    int index = _cartItems.indexWhere((item) =>
        item.product.productId == productId &&
        (item.selectedStock?.id == selectedStock?.id ||
            (item.selectedStock == null && selectedStock == null)));

    if (index != -1) {
      if (_cartItems[index].quantity > 1) {
        _cartItems[index].quantity--;
      } else {
        _cartItems.removeAt(index);
      }
      _saveCartToHive();
      notifyListeners();
    }
  }

  /// Clears all items from the local cart.
  void clearCart() {
    _cartItems.clear();
    _cartItemsBox.clear();
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
  }) {
    if (_cartItems.isEmpty) {
      throw Exception("Cannot save an empty cart as confirmed order");
    }

    // Generate a unique ID for the order (timestamp-based)
    final String orderId = DateTime.now().millisecondsSinceEpoch.toString();

    // Calculate total
    double total = cartTotal;

    // Create a deep copy of cart items to prevent modification
    List<LocalCartItem> orderItems = _cartItems
        .map((item) => LocalCartItem(
              product: item.product,
              quantity: item.quantity,
              price: item.price,
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
  }) {
    if (_cartItems.isEmpty) {
      throw Exception("Cannot save an empty cart as order");
    }

    // Generate a unique ID for the order (timestamp-based)
    final String orderId = DateTime.now().millisecondsSinceEpoch.toString();

    // Calculate total
    double total = cartTotal;

    // Create a deep copy of cart items to prevent modification
    List<LocalCartItem> orderItems = _cartItems
        .map((item) => LocalCartItem(
              product: item.product,
              quantity: item.quantity,
              price: item.price,
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
    );

    // Add to saved orders list
    _savedOrders.add(order);
    _saveSavedOrdersToHive();
    notifyListeners();

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

      // Clear current cart
      _cartItems.clear();

      // Add items from the saved order to the cart
      for (var item in order.items) {
        _cartItems.add(LocalCartItem(
          product: item.product,
          quantity: item.quantity,
          price: item.price,
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
  }) {
    int index = _savedOrders.indexWhere((o) => o.id == orderId);

    if (index != -1) {
      // Get current cart total
      double total = cartTotal;

      // Create a copy of current cart items
      List<LocalCartItem> orderItems = _cartItems
          .map((item) => LocalCartItem(
                product: item.product,
                quantity: item.quantity,
                price: item.price,
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
      );

      // Update in list
      _savedOrders[index] = updatedOrder;

      // Clear current order reference
      _currentOrder = null;

      _saveSavedOrdersToHive();
      notifyListeners();
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

  // End of LocalProductProvider
}

// End of file.
