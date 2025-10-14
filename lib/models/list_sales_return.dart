class SalesReturnResponse {
  final String status;
  final String message;
  final SalesReturnData data;

  SalesReturnResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory SalesReturnResponse.fromJson(Map<String, dynamic> json) {
    return SalesReturnResponse(
      status: json['status'],
      message: json['message'],
      data: SalesReturnData.fromJson(json['data']),
    );
  }
}

class SalesReturnData {
  final int currentPage;
  final List<SalesReturnOrder> data;
  final String firstPageUrl;
  final int from;
  final int lastPage;
  final String lastPageUrl;
  final List<SalesReturnLink> links;
  final String? nextPageUrl;
  final String path;
  final int perPage;
  final String? prevPageUrl;
  final int to;
  final int total;

  SalesReturnData({
    required this.currentPage,
    required this.data,
    required this.firstPageUrl,
    required this.from,
    required this.lastPage,
    required this.lastPageUrl,
    required this.links,
    this.nextPageUrl,
    required this.path,
    required this.perPage,
    this.prevPageUrl,
    required this.to,
    required this.total,
  });

  factory SalesReturnData.fromJson(Map<String, dynamic> json) {
    return SalesReturnData(
      currentPage: json['current_page'],
      data: (json['data'] as List)
          .map((order) => SalesReturnOrder.fromJson(order))
          .toList(),
      firstPageUrl: json['first_page_url'],
      from: json['from'],
      lastPage: json['last_page'],
      lastPageUrl: json['last_page_url'],
      links: (json['links'] as List)
          .map((link) => SalesReturnLink.fromJson(link))
          .toList(),
      nextPageUrl: json['next_page_url'],
      path: json['path'],
      perPage: json['per_page'],
      prevPageUrl: json['prev_page_url'],
      to: json['to'],
      total: json['total'],
    );
  }
}

class SalesReturnLink {
  final String? url;
  final String label;
  final bool active;

  SalesReturnLink({
    this.url,
    required this.label,
    required this.active,
  });

  factory SalesReturnLink.fromJson(Map<String, dynamic> json) {
    return SalesReturnLink(
      url: json['url'], // This can be null
      label: json['label'],
      active: json['active'],
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
      items: (json['items'] as List?)
              ?.map((item) => SalesReturnItem.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class SalesReturnItem {
  final int id;
  final int orderReturnId;
  final int cartItemId;
  final String price;
  final String reason;
  final num quantity;
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
      price: json['price']?.toString() ?? '0.00', // Convert to string and provide default
      reason: json['reason'] ?? '', // Provide an empty string if null
      quantity: (json['quantity'] is String)
          ? num.tryParse(json['quantity']) ?? 0
          : json['quantity'],
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
  final int? productStockId; // Add this missing field as nullable
  final num quantity;
  final String unitPrice;
  final String totalPrice;
  final String taxRate;
  final String taxAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Product? product;

  CartItem({
    required this.id,
    required this.cartId,
    required this.categoryId,
    required this.productId,
    this.productStockId, // Nullable
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.taxRate,
    required this.taxAmount,
    required this.createdAt,
    required this.updatedAt,
    this.product,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      cartId: json['cart_id'],
      categoryId: json['category_id'],
      productId: json['product_id'],
      productStockId: json['product_stock_id'], // This can be null
      quantity: (json['quantity'] is String)
          ? num.tryParse(json['quantity']) ?? 0
          : json['quantity'],
      unitPrice: json['unit_price'].toString(),
      totalPrice: json['total_price'].toString(),
      taxRate: json['tax_rate'].toString(),
      taxAmount: json['tax_amount'].toString(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      product: json['product'] != null ? Product.fromJson(json['product']) : null,
    );
  }
}

class Product {
  final int id;
  final int categoryId;
  final String? barcode; // Make this nullable since it can be null in JSON
  final String name;
  final String? description; // Make this field nullable
  final String slug;
  final int active;
  final String price;
  final String mrp;
  final String? purchasePrice; // Make this field nullable
  final String unit;
  final String? sku; // Add this missing field as nullable
  final int reorderLevel;
  final int userId;
  final int companyId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.categoryId,
    this.barcode, // Nullable
    required this.name,
    this.description, // Nullable
    required this.slug,
    required this.active,
    required this.price,
    required this.mrp,
    this.purchasePrice, // Nullable
    required this.unit,
    this.sku, // Nullable
    required this.reorderLevel,
    required this.userId,
    required this.companyId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      categoryId: json['category_id'],
      barcode: json['barcode'], // This can be null
      name: json['name'],
      description: json['description'], // This can be null
      slug: json['slug'],
      active: json['active'],
      price: json['price'].toString(),
      mrp: json['mrp'].toString(),
      purchasePrice: json['purchase_price']?.toString(),
      unit: json['unit'],
      sku: json['sku'], // This can be null
      reorderLevel: json['reorder_level'],
      userId: json['user_id'],
      companyId: json['company_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
