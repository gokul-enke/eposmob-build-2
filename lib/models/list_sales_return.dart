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
      currentPage: json['current_page'] ?? 1,
      data: (json['data'] as List?)
              ?.map((order) => SalesReturnOrder.fromJson(order))
              .toList() ??
          [],
      firstPageUrl: json['first_page_url']?.toString() ?? '',
      from: json['from'] ?? 0,
      lastPage: json['last_page'] ?? 1,
      lastPageUrl: json['last_page_url']?.toString() ?? '',
      links: (json['links'] as List?)
              ?.map((link) => SalesReturnLink.fromJson(link))
              .toList() ??
          [],
      nextPageUrl: json['next_page_url']?.toString(),
      path: json['path']?.toString() ?? '',
      perPage: json['per_page'] is int
          ? json['per_page']
          : int.tryParse(json['per_page']?.toString() ?? '15') ?? 15,
      prevPageUrl: json['prev_page_url']?.toString(),
      to: json['to'] ?? 0,
      total: json['total'] ?? 0,
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
  final Order? order; // Add nested order object

  SalesReturnOrder({
    required this.id,
    required this.orderId,
    required this.totalAmount,
    required this.userId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    this.order,
  });

  factory SalesReturnOrder.fromJson(Map<String, dynamic> json) {
    return SalesReturnOrder(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      orderId: json['order_id'] is int
          ? json['order_id']
          : int.tryParse(json['order_id']?.toString() ?? '0') ?? 0,
      totalAmount: json['total_amount']?.toString() ?? '0.00',
      userId: json['user_id'] is int
          ? json['user_id']
          : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      status: json['status'] is int
          ? json['status']
          : int.tryParse(json['status']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      items: (json['items'] as List?)
              ?.map((item) => SalesReturnItem.fromJson(item))
              .toList() ??
          [],
      order: json['order'] != null ? Order.fromJson(json['order']) : null,
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
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      orderReturnId: json['order_return_id'] is int
          ? json['order_return_id']
          : int.tryParse(json['order_return_id']?.toString() ?? '0') ?? 0,
      cartItemId: json['cart_item_id'] is int
          ? json['cart_item_id']
          : int.tryParse(json['cart_item_id']?.toString() ?? '0') ?? 0,
      price: json['price']?.toString() ?? '0.00',
      reason: json['reason']?.toString() ?? '',
      quantity: (json['quantity'] is String)
          ? num.tryParse(json['quantity']) ?? 0
          : json['quantity'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
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
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      cartId: json['cart_id'] is int
          ? json['cart_id']
          : int.tryParse(json['cart_id']?.toString() ?? '0') ?? 0,
      categoryId: json['category_id'] is int
          ? json['category_id']
          : int.tryParse(json['category_id']?.toString() ?? '0') ?? 0,
      productId: json['product_id'] is int
          ? json['product_id']
          : int.tryParse(json['product_id']?.toString() ?? '0') ?? 0,
      productStockId: json['product_stock_id'] is int
          ? json['product_stock_id']
          : int.tryParse(json['product_stock_id']?.toString() ?? '0'),
      quantity: (json['quantity'] is String)
          ? num.tryParse(json['quantity']) ?? 0
          : json['quantity'] ?? 0,
      unitPrice: json['unit_price']?.toString() ?? '0.00',
      totalPrice: json['total_price']?.toString() ?? '0.00',
      taxRate: json['tax_rate']?.toString() ?? '0.00',
      taxAmount: json['tax_amount']?.toString() ?? '0.00',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      product:
          json['product'] != null ? Product.fromJson(json['product']) : null,
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
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      categoryId: json['category_id'] is int
          ? json['category_id']
          : int.tryParse(json['category_id']?.toString() ?? '0') ?? 0,
      barcode: json['barcode']?.toString(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      slug: json['slug']?.toString() ?? '',
      active: json['active'] is int
          ? json['active']
          : int.tryParse(json['active']?.toString() ?? '0') ?? 0,
      price: json['price']?.toString() ?? '0.00',
      mrp: json['mrp']?.toString() ?? '0.00',
      purchasePrice: json['purchase_price']?.toString(),
      unit: json['unit']?.toString() ?? '',
      sku: json['sku']?.toString(),
      reorderLevel: json['reorder_level'] is int
          ? json['reorder_level']
          : int.tryParse(json['reorder_level']?.toString() ?? '0') ?? 0,
      userId: json['user_id'] is int
          ? json['user_id']
          : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      companyId: json['company_id'] is int
          ? json['company_id']
          : int.tryParse(json['company_id']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

// Add Order class for nested order object in sales return
class Order {
  final int id;
  final int cartId;
  final int? addressId;
  final String orderDate;
  final String orderNumber;
  final int? paymentId;
  final List<String>? paymentMethod;
  final String? paymentStatus;
  final String? deliveryStatus;
  final String status;
  final String subTotal;
  final String discount;
  final String grandTotal;
  final String? tax;
  final String? shippingCost;
  final String sourceType;
  final int deliveryMethodId;
  final int companyId;
  final OrderCustomer? customer;
  final DateTime createdAt;
  final DateTime updatedAt;

  Order({
    required this.id,
    required this.cartId,
    this.addressId,
    required this.orderDate,
    required this.orderNumber,
    this.paymentId,
    this.paymentMethod,
    this.paymentStatus,
    this.deliveryStatus,
    required this.status,
    required this.subTotal,
    required this.discount,
    required this.grandTotal,
    this.tax,
    this.shippingCost,
    required this.sourceType,
    required this.deliveryMethodId,
    required this.companyId,
    this.customer,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      cartId: json['cart_id'] is int
          ? json['cart_id']
          : int.tryParse(json['cart_id']?.toString() ?? '0') ?? 0,
      addressId: json['address_id'] is int
          ? json['address_id']
          : int.tryParse(json['address_id']?.toString() ?? '0'),
      orderDate: json['order_date']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? '',
      // Handling possible List for payment_id
      paymentId: json['payment_id'] is List
          ? (json['payment_id'].isNotEmpty
              ? int.tryParse(json['payment_id'][0].toString())
              : null)
          : (json['payment_id'] is int
              ? json['payment_id']
              : int.tryParse(json['payment_id']?.toString() ?? '')),
      paymentMethod: json['payment_method'] is List
          ? List<String>.from(json['payment_method'].map((v) => v.toString()))
          : (json['payment_method'] != null
              ? [json['payment_method'].toString()]
              : null),
      paymentStatus: json['payment_status']?.toString(),
      deliveryStatus: json['delivery_status']?.toString(),
      status: json['status']?.toString() ?? '',
      subTotal: json['sub_total']?.toString() ?? '0.00',
      discount: json['discount']?.toString() ?? '0.00',
      grandTotal: json['grand_total']?.toString() ?? '0.00',
      tax: json['tax']?.toString(),
      shippingCost: json['shipping_cost']?.toString(),
      sourceType: json['source_type']?.toString() ?? '',
      deliveryMethodId: json['delivery_method_id'] is int
          ? json['delivery_method_id']
          : int.tryParse(json['delivery_method_id']?.toString() ?? '0') ?? 0,
      companyId: json['company_id'] is int
          ? json['company_id']
          : int.tryParse(json['company_id']?.toString() ?? '0') ?? 0,
      customer: json['customer'] != null
          ? OrderCustomer.fromJson(json['customer'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class OrderCustomer {
  final int id;
  final int userId;
  final int? laravelThroughKey;
  final OrderCustomerUser? user;

  OrderCustomer({
    required this.id,
    required this.userId,
    this.laravelThroughKey,
    this.user,
  });

  factory OrderCustomer.fromJson(Map<String, dynamic> json) {
    return OrderCustomer(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      userId: json['user_id'] is int
          ? json['user_id']
          : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      laravelThroughKey: json['laravel_through_key'] is int
          ? json['laravel_through_key']
          : int.tryParse(json['laravel_through_key']?.toString() ?? '0'),
      user: json['user'] != null
          ? OrderCustomerUser.fromJson(json['user'])
          : null,
    );
  }
}

class OrderCustomerUser {
  final int id;
  final String name;

  OrderCustomerUser({
    required this.id,
    required this.name,
  });

  factory OrderCustomerUser.fromJson(Map<String, dynamic> json) {
    return OrderCustomerUser(
      id: json['id'],
      name: json['name']?.toString() ?? '',
    );
  }
}
