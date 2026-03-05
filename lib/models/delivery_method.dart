class DeliveryMethod {
  final String id;
  final String name;
  final String? code;
  final List<DeliveryPrice>? _prices;

  List<DeliveryPrice> get prices => _prices ?? const [];

  DeliveryMethod({
    required this.id,
    required this.name,
    this.code,
    List<DeliveryPrice>? prices,
  }) : _prices = prices;

  // Get the base price (first price in the list)
  double? get basePrice {
    if (prices.isEmpty) return null;
    return prices.first.price;
  }

  // Get all unique prices as a formatted string
  String get pricesDisplay {
    if (prices.isEmpty) return 'Free';
    final priceList = prices.map((p) => p.price.toString()).toList();
    return priceList.join(', ');
  }

  factory DeliveryMethod.fromJson(
    String id,
    String name,
  ) {
    return DeliveryMethod(
      id: id,
      name: name,
    );
  }
}

class DeliveryPrice {
  final String id;
  final String deliveryMethodId;
  final double price;
  final String? createdAt;
  final String? updatedAt;

  DeliveryPrice({
    required this.id,
    required this.deliveryMethodId,
    required this.price,
    this.createdAt,
    this.updatedAt,
  });

  factory DeliveryPrice.fromJson(Map<String, dynamic> json) {
    return DeliveryPrice(
      id: json['id']?.toString() ?? '',
      deliveryMethodId: json['delivery_method_id']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}
