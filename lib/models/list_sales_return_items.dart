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
      if (json['data']['items'] is List) {
        salesReturnItems = (json['data']['items'] as List)
            .map((item) => SalesReturnCart.fromJson(item))
            .toList();
      }
      if (json['data']['order'] is Map) {
        orderInfo = SalesReturnOrderInfo.fromJson(json['data']['order']);
      }
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
      id: json['id'],
      shippingCost: json['shipping_cost']?.toString() ?? '0.00',
    );
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
  final int returnedQuantity;
  final String returnedTotal;
  final bool isReturned;

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
  });

  factory SalesReturnCart.fromJson(Map<String, dynamic> json) {
    return SalesReturnCart(
      cartItemId: json['cart_item_id'],
      returnOrderId: json['return_order_id'] ?? 0,
      productName: json['product_name'],
      quantity: json['quantity'],
      unitPrice: json['unit_price'].toString(),
      totalPrice: json['total_price'].toString(),
      returnedQuantity: json['returned_quantity'] != null 
          ? (json['returned_quantity'] is int)
              ? json['returned_quantity']
              : int.tryParse(json['returned_quantity'].toString()) ?? 0
          : 0,
      returnedTotal: json['returned_total']?.toString() ?? '0',
      isReturned: json['is_returned'],
    );
  }
}
