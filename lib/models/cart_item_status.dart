class CartItemStatus {
  final int id;
  final String value;
  final String description;

  CartItemStatus({
    required this.id,
    required this.value,
    required this.description,
  });

  factory CartItemStatus.fromJson(Map<String, dynamic> json) {
    return CartItemStatus(
      id: json['id'] ?? 0,
      value: json['value'] ?? '',
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'value': value,
      'description': description,
    };
  }

  @override
  String toString() {
    return 'CartItemStatus(id: $id, value: $value, description: $description)';
  }
}

class CartItemStatusResponse {
  final String status;
  final String message;
  final List<CartItemStatus> data;

  CartItemStatusResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory CartItemStatusResponse.fromJson(Map<String, dynamic> json) {
    return CartItemStatusResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      data: (json['data'] as List<dynamic>?)
              ?.map((item) => CartItemStatus.fromJson(item))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'data': data.map((item) => item.toJson()).toList(),
    };
  }
}