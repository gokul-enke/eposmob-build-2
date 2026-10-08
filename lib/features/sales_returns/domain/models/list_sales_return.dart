part 'sales_return_order_details.dart';

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
  final bool hasCreatedAt;
  final DateTime updatedAt;
  final List<SalesReturnItem> items;
  final Order? order; // Add nested order object

  /// Backend order number, e.g. `ORD-004689`.
  String get originalOrderNumber {
    final value = order?.orderNumber.trim() ?? '';
    return value.isNotEmpty ? value : orderId.toString();
  }

  /// Bill number issued on the POS device, e.g. `2-01-260929-0002`. Shown as
  /// "Bill No."; the API field is `receipt_number`, which is unrelated to the
  /// Receipts (payment voucher) module.
  /// Null for orders created before device receipt numbers existed.
  String? get receiptNumber => order?.receiptNumber;

  /// The number a cashier or customer recognises: the bill number when
  /// the sale has one, otherwise the backend order number.
  String get displayNumber => receiptNumber ?? originalOrderNumber;

  SalesReturnOrder({
    required this.id,
    required this.orderId,
    required this.totalAmount,
    required this.userId,
    required this.status,
    required this.createdAt,
    this.hasCreatedAt = true,
    required this.updatedAt,
    required this.items,
    this.order,
  });

  factory SalesReturnOrder.fromJson(Map<String, dynamic> json) {
    final sourceCreatedAt =
        DateTime.tryParse(json['created_at']?.toString() ?? '');
    return SalesReturnOrder(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      orderId: json['order_id'] is int
          ? json['order_id']
          : int.tryParse(json['order_id']?.toString() ?? '0') ?? 0,
      totalAmount: json['total_amount']?.toString() ?? '',
      userId: json['user_id'] is int
          ? json['user_id']
          : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      status: json['status'] is int
          ? json['status']
          : int.tryParse(json['status']?.toString() ?? '0') ?? 0,
      createdAt: sourceCreatedAt ?? DateTime.now(),
      hasCreatedAt: sourceCreatedAt != null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      items: ((json['items'] ?? json['return_items']) as List?)
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
  final String? taxAmount;
  final String? taxableValue;
  final String? subTotal;
  final String? discount;

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
    this.taxAmount,
    this.taxableValue,
    this.subTotal,
    this.discount,
  });

  factory SalesReturnItem.fromJson(Map<String, dynamic> json) {
    final rawCartItem = json['cart_item'];
    final cartItem = rawCartItem is Map
        ? Map<String, dynamic>.from(rawCartItem)
        : <String, dynamic>{};

    // Some API responses put the product fields on the return item instead
    // of hydrating cart_item.product. Merge both shapes before parsing so the
    // detail table still has meaningful product/quantity/price values.
    final cartItemPayload = <String, dynamic>{
      ...json,
      ...cartItem,
      if (cartItem['unit_price'] == null &&
          json['unit_price'] == null &&
          json['price'] != null)
        'unit_price': json['price'],
      if (cartItem['total_price'] == null && json['total_price'] != null)
        'total_price': json['total_price'],
      if (cartItem['product_name'] == null && json['product_name'] != null)
        'product_name': json['product_name'],
      if (cartItem['product'] == null && json['product'] is Map)
        'product': json['product'],
    };

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
      taxAmount: json['tax_amount']?.toString(),
      taxableValue: json['taxable_value']?.toString(),
      subTotal: json['sub_total']?.toString(),
      discount: json['discount']?.toString(),
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
      cartItem: CartItem.fromJson(cartItemPayload,
          hasUnitPrice:
              cartItem['unit_price'] != null || json['unit_price'] != null),
    );
  }
}

class CartItem {
  /// Distinguishes an explicitly free item from a missing API price.
  final bool hasUnitPrice;
  final String? mrp;
  final int id;
  final int cartId;
  final int categoryId;
  final int productId;
  final int? productStockId; // Add this missing field as nullable
  final num quantity;
  final String unitPrice;
  final String totalPrice;
  final String taxRate;
  final bool hasTaxRate;
  final String taxAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Product? product;
  final String? productName;

  CartItem({
    this.hasUnitPrice = true,
    this.mrp,
    required this.id,
    required this.cartId,
    required this.categoryId,
    required this.productId,
    this.productStockId, // Nullable
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.taxRate,
    this.hasTaxRate = true,
    required this.taxAmount,
    required this.createdAt,
    required this.updatedAt,
    this.product,
    this.productName,
  });

  String get displayName => product?.name.trim().isNotEmpty == true
      ? product!.name
      : (productName?.trim().isNotEmpty == true
          ? productName!
          : 'Unknown Product');

  factory CartItem.fromJson(Map<String, dynamic> json, {bool? hasUnitPrice}) {
    return CartItem(
      hasUnitPrice: hasUnitPrice ?? json['unit_price'] != null,
      mrp: json['mrp']?.toString(),
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
      hasTaxRate: json['tax_rate'] != null,
      taxAmount: json['tax_amount']?.toString() ?? '0.00',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      product:
          json['product'] != null ? Product.fromJson(json['product']) : null,
      productName: (json['product_name'] ?? json['item_name'] ?? json['name'])
          ?.toString(),
    );
  }
}
