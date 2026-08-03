import 'dart:convert';

class SalesReturnItemsResponse {
  final String status;
  final String message;
  final List<SalesReturnCart> data;
  final SalesReturnOrderInfo? order;

  SalesReturnItemsResponse({
    required this.status,
    required this.message,
    required this.data,
    this.order,
  });

  factory SalesReturnItemsResponse.fromJson(Map<String, dynamic> json) {
    // Determine data based on structure (could be List or Map with 'items')
    List<SalesReturnCart> salesReturnItems = [];
    SalesReturnOrderInfo? orderInfo;

    if (json['data'] is List) {
      salesReturnItems = (json['data'] as List)
          .map((item) => SalesReturnCart.fromJson(item))
          .toList();
    } else if (json['data'] is Map) {
      final data = Map<String, dynamic>.from(json['data'] as Map);
      final rawItems = data['items'] ??
          data['return_items'] ??
          data['sales_return_items'] ??
          data['data'];
      if (rawItems is List) {
        salesReturnItems =
            rawItems.map((item) => SalesReturnCart.fromJson(item)).toList();
      }
      if (data['order'] is Map) {
        orderInfo = SalesReturnOrderInfo.fromJson(data['order']);
      }
    }

    if (orderInfo == null && json['order'] is Map) {
      orderInfo = SalesReturnOrderInfo.fromJson(json['order']);
    }

    return SalesReturnItemsResponse(
      status: json['status'],
      message: json['message'],
      data: salesReturnItems,
      order: orderInfo,
    );
  }
}

class SalesReturnOrderInfo {
  final int id;
  final String shippingCost;

  SalesReturnOrderInfo({
    required this.id,
    required this.shippingCost,
  });

  factory SalesReturnOrderInfo.fromJson(Map<String, dynamic> json) {
    return SalesReturnOrderInfo(
      id: _parseInt(json['id']),
      shippingCost: json['shipping_cost']?.toString() ?? '0.00',
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

// Model class for each item in the return order
class SalesReturnCart {
  final int cartItemId;
  final int returnOrderId;
  final String productName;
  final String quantity;
  final String unitPrice;
  final String totalPrice;
  final double returnedQuantity;
  final String returnedTotal;
  final bool isReturned;
  final String? reason;
  final int? productVariantId;
  final Map<String, dynamic>? variantAttributes;

  SalesReturnCart({
    required this.cartItemId,
    required this.returnOrderId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.returnedQuantity,
    required this.returnedTotal,
    required this.isReturned,
    this.reason,
    this.productVariantId,
    this.variantAttributes,
  });

  /// Formatted variant attribute line (values joined with " | "). Empty when
  /// there are no attributes to display.
  String get formattedVariantAttributes {
    final attrs = variantAttributes;
    if (attrs == null || attrs.isEmpty) return '';
    return attrs.values
        .map((value) => value?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .join(' | ');
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  // variant_attributes may arrive as a Map or a JSON-encoded String.
  static Map<String, dynamic>? _parseVariantAttributes(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      return raw.isEmpty ? null : Map<String, dynamic>.from(raw);
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map && decoded.isNotEmpty) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return null;
  }

  factory SalesReturnCart.fromJson(Map<String, dynamic> json) {
    final product = json['product'] is Map
        ? Map<String, dynamic>.from(json['product'] as Map)
        : const <String, dynamic>{};

    return SalesReturnCart(
      cartItemId: _parseInt(json['cart_item_id'] ?? json['id']),
      returnOrderId: _parseInt(json['return_order_id']),
      productName: (json['product_name'] ??
                  product['name'] ??
                  product['product_name'] ??
                  json['name'] ??
                  json['item_name'])
              ?.toString() ??
          '',
      quantity: json['quantity']?.toString() ?? '0',
      unitPrice: (json['unit_price'] ?? json['price'] ?? '0.00').toString(),
      totalPrice:
          (json['total_price'] ?? json['line_total'] ?? '0.00').toString(),
      returnedQuantity: json['returned_quantity'] != null
          ? double.tryParse(json['returned_quantity'].toString()) ?? 0
          : 0,
      returnedTotal: json['returned_total']?.toString() ?? '0',
      isReturned: _parseBool(json['is_returned'] ?? json['returned']),
      reason: (json['reason'] ?? json['return_reason'])?.toString(),
      productVariantId: _parseNullableInt(json['product_variant_id']),
      variantAttributes: _parseVariantAttributes(json['variant_attributes']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
}
