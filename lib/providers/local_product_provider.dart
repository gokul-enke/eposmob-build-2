import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/get_product.dart';
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
  List<LocalCartItem> _cartItems = [];
  List<LocalCartItem> get cartItems => _cartItems;
  bool isLoading = false;

  PriceSummary? priceSummary; // Add this line

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
        notifyListeners();
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Filters the locally stored products by an optional [categoryId] and/or [filterName].
  /// Mimics the [listAllProducts] function from GridSelectionProvider, but operates locally.

  void listAllProducts({int? categoryId, String? filterName}) {
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

    _filteredProducts = result;
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
      notifyListeners(); // Notify listeners about the change
      debugPrint("Product added: $product");
    } else {
      // Optionally, you can update the existing product if needed
      _products[index] = product; // Update the existing product
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
        _cartItems[index].price =
            double.tryParse(product!.price?.price); // Use the product price
      }
    } else {
      _cartItems.add(LocalCartItem(
        product: product!,
        quantity: quantity!,
        price: price ??
            double.tryParse(product
                .price?.price), // Use the specified price or product price
      ));
    }
    resetSelectedProduct();
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
      notifyListeners();
    }
  }

  void updateItemPrice(int productId, double newPrice) {
    int index =
        _cartItems.indexWhere((item) => item.product.productId == productId);
    if (index != -1) {
      _cartItems[index].price = newPrice; // Assuming price is mutable
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
      notifyListeners();
    }
  }

  /// Clears all items from the local cart.
  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  /// Resets the local product list and filtered list.
  void resetProducts() {
    _products = [];
    _filteredProducts = [];
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
    refreshProducts();
  }

  /// Removes a product from the local product list.
  void deleteProduct(int productId) {
    _products.removeWhere((p) => p.productId == productId);
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

  // End of LocalProductProvider
}

// End of file.
