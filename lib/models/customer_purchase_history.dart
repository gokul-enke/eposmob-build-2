class CustomerPurchaseHistory {
  final bool success;
  final List<CustomerPurchaseItem> data;

  CustomerPurchaseHistory({
    required this.success,
    required this.data,
  });

  factory CustomerPurchaseHistory.fromJson(Map<String, dynamic> json) {
    return CustomerPurchaseHistory(
      success: json['success'] ?? false,
      data: (json['data'] as List<dynamic>?)
              ?.map((item) => CustomerPurchaseItem.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class CustomerPurchaseItem {
  final String price;
  final String quantity;
  final String total;
  final String date;
  final String orderNumber;

  CustomerPurchaseItem({
    required this.price,
    required this.quantity,
    required this.total,
    required this.date,
    required this.orderNumber,
  });

  factory CustomerPurchaseItem.fromJson(Map<String, dynamic> json) {
    return CustomerPurchaseItem(
      price: json['price']?.toString() ?? '0.000',
      quantity: json['quantity']?.toString() ?? '0.000',
      total: json['total']?.toString() ?? '0.000',
      date: json['date']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? '',
    );
  }

  // Getter for double price value
  double get priceValue => double.tryParse(price) ?? 0.0;
  
  // Getter for double quantity value
  double get quantityValue => double.tryParse(quantity) ?? 0.0;
  
  // Getter for double total value
  double get totalValue => double.tryParse(total) ?? 0.0;
} 