class SalesReturnResponse {
  final String status;
  final String message;
  final List<SalesReturnOrder> data;

  SalesReturnResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory SalesReturnResponse.fromJson(Map<String, dynamic> json) {
    return SalesReturnResponse(
      status: json['status'],
      message: json['message'],
      data: (json['data'] as List)
          .map((order) => SalesReturnOrder.fromJson(order))
          .toList(),
    );
  }
}

class SalesReturnOrder {
  final int id;
  final int orderId;
  final String totalAmount;
  final int userId;
  final int status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SalesReturnItem> items;

  SalesReturnOrder({
    required this.id,
    required this.orderId,
    required this.totalAmount,
    required this.userId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
  });

  factory SalesReturnOrder.fromJson(Map<String, dynamic> json) {
    return SalesReturnOrder(
      id: json['id'],
      orderId: json['order_id'],
      totalAmount: json['total_amount'] ?? '0.00', // Default value
      userId: json['user_id'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      items: (json['items'] as List)
          .map((item) => SalesReturnItem.fromJson(item))
          .toList(),
    );
  }
}

class SalesReturnItem {
  final int id;
  final int orderReturnId;
  final int cartItemId;
  final String price;
  final String reason;
  final int quantity;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CartItem cartItem;

  SalesReturnItem({
    required this.id,
    required this.orderReturnId,
    required this.cartItemId,
    required this.price,
    required this.reason,
    required this.quantity,
    required this.createdAt,
    required this.updatedAt,
    required this.cartItem,
  });

  factory SalesReturnItem.fromJson(Map<String, dynamic> json) {
    return SalesReturnItem(
      id: json['id'],
      orderReturnId: json['order_return_id'],
      cartItemId: json['cart_item_id'],
      price: json['price'] ?? '0.00', // Provide a default value if null
      reason: json['reason'] ?? '', // Provide an empty string if null
      quantity: json['quantity'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      cartItem: CartItem.fromJson(json['cart_item']),
    );
  }
}

class CartItem {
  final int id;
  final int cartId;
  final int categoryId;
  final int productId;
  final int quantity;
  final String unitPrice;
  final String totalPrice;
  final String taxRate;
  final String taxAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Product product;

  CartItem({
    required this.id,
    required this.cartId,
    required this.categoryId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.taxRate,
    required this.taxAmount,
    required this.createdAt,
    required this.updatedAt,
    required this.product,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      cartId: json['cart_id'],
      categoryId: json['category_id'],
      productId: json['product_id'],
      quantity: json['quantity'],
      unitPrice: json['unit_price'],
      totalPrice: json['total_price'],
      taxRate: json['tax_rate'],
      taxAmount: json['tax_amount'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      product: Product.fromJson(json['product']),
    );
  }
}

class Product {
  final int id;
  final int categoryId;
  final String barcode;
  final String name;
  final String? description; // Make this field nullable
  final String slug;
  final int active;
  final String price;
  final String? purchasePrice; // Make this field nullable
  final String unit;
  final int userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.categoryId,
    required this.barcode,
    required this.name,
    this.description, // Nullable
    required this.slug,
    required this.active,
    required this.price,
    this.purchasePrice, // Nullable
    required this.unit,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      categoryId: json['category_id'],
      barcode: json['barcode'],
      name: json['name'],
      description: json['description'] ?? '', // Provide an empty string if null
      slug: json['slug'],
      active: json['active'],
      price: json['price'],
      purchasePrice:
          json['purchase_price'] ?? '0.00', // Provide a default value if null
      unit: json['unit'],
      userId: json['user_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
