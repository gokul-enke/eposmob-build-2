class SalesReturnItemsResponse {
  final String status;
  final String message;
  final List<SalesReturnCart> data;

  SalesReturnItemsResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory SalesReturnItemsResponse.fromJson(Map<String, dynamic> json) {
    var dataList = json['data'] as List;
    List<SalesReturnCart> salesReturnItems =
        dataList.map((item) => SalesReturnCart.fromJson(item)).toList();

    return SalesReturnItemsResponse(
      status: json['status'],
      message: json['message'],
      data: salesReturnItems,
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
      unitPrice: json['unit_price'],
      totalPrice: json['total_price'],
      returnedQuantity: (json['returned_quantity'] is int)
          ? json['returned_quantity']
          : int.tryParse(json['returned_quantity'].toString()) ?? 0,
      returnedTotal: json['returned_total'].toString(),
      isReturned: json['is_returned'],
    );
  }
}
