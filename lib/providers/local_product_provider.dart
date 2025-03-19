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
  num quantity;

  LocalCartItem({
    required this.product,
    this.quantity = 1,
    this.price,
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

      _cartItems.add(LocalCartItem(
        product: product,
        quantity: hiveCartItem.quantity,
        price: hiveCartItem.price,
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

        return LocalCartItem(
          product: product,
          quantity: hiveCartItem.quantity,
          price: hiveCartItem.price,
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
      final hiveCartItem = HiveLocalCartItem(
        productId: cartItem.product.productId!,
        quantity: cartItem.quantity,
        price: cartItem.price,
        serializedProduct:
            HiveStringValue(json.encode(cartItem.product.toJson())),
      );
      _cartItemsBox.add(hiveCartItem);
    }
  }

  // Save orders to Hive
  void _saveSavedOrdersToHive() {
    _savedOrdersBox.clear();
    for (var order in _savedOrders) {
      List<HiveLocalCartItem> hiveItems = order.items
          .map((item) => HiveLocalCartItem(
                productId: item.product.productId!,
                quantity: item.quantity,
                price: item.price,
                serializedProduct:
                    HiveStringValue(json.encode(item.product.toJson())),
              ))
          .toList();

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
    final startIndex = (_currentPage - 1) * _itemsPerPage;
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
    notifyListeners();
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
      // If the product does not exist, add it to the list
      _products.add(product);
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
    int? productId,
  }) {
    debugPrint("addToCart");
    debugPrint(product.toString());
    debugPrint(quantity.toString());
    debugPrint(price.toString());
    debugPrint(productId.toString());

    if (productId != null) {
      product = _products.firstWhere((p) => p.productId == productId);
    }

    int index = _cartItems
        .indexWhere((item) => item.product.productId == product!.productId);

    if (index != -1) {
      _cartItems[index].quantity +=
          quantity!; // Increment by the specified quantity
      if (price != null) {
        _cartItems[index].price = price; // Update the price if provided
      } else {
        // Safely handle null product price
        _cartItems[index].price = _cartItems[index].price ??
            (product!.price?.price != null
                ? double.tryParse(product.price!.price!)
                : 0.0);
      }
    } else {
      // Safely handle null product price when adding new cart item
      double productPrice = 0.0;
      if (price != null) {
        productPrice = price;
      } else if (product!.price?.price != null) {
        productPrice = double.tryParse(product.price!.price!) ?? 0.0;
      }

      _cartItems.add(LocalCartItem(
        product: product!,
        quantity: quantity!,
        price: productPrice,
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

  void removeFromCart(int productId) {
    int index =
        _cartItems.indexWhere((item) => item.product.productId == productId);
    if (index != -1) {
      _cartItems.removeAt(index);
      _saveCartToHive();
      notifyListeners();
    }
  }

  void updateItemPrice(int productId, double newPrice) {
    int index =
        _cartItems.indexWhere((item) => item.product.productId == productId);
    if (index != -1) {
      _cartItems[index].price = newPrice; // Assuming price is mutable
      _saveCartToHive();
      notifyListeners();
    }
  }

  /// Decrements the quantity of the product in the cart.
  /// If the quantity becomes less than 1, the product is removed from the cart.
  void decrementCartItem(int productId) {
    int index =
        _cartItems.indexWhere((item) => item.product.productId == productId);
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

  // End of LocalProductProvider
}

// End of file.
