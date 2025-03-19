class SupplierResponse {
  final String status;
  final List<Supplier> data;

  SupplierResponse({
    required this.status,
    required this.data,
  });

  factory SupplierResponse.fromJson(Map<String, dynamic> json) {
    return SupplierResponse(
      status: json['status'] ?? '',
      data: (json['data'] as List<dynamic>?)
              ?.map((item) => Supplier.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class Supplier {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String productCategories;
  final String address;
  final DateTime createdAt;
  final DateTime updatedAt;

  Supplier({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.productCategories,
    required this.address,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      productCategories: json['product_categories'] ?? '',
      address: json['address'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }
} 