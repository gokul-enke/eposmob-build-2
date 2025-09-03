class SupplierResponse {
  final String status;
  final String message;
  final List<Supplier> data;

  SupplierResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory SupplierResponse.fromJson(Map<String, dynamic> json) {
    return SupplierResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
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
  final String? altPhone;
  final String productCategories;
  final String address;
  final String balance;
  final String paymentType;
  final int companyId;
  final double currentBalance;
  final String balanceStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int userId;

  Supplier({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.altPhone,
    required this.productCategories,
    required this.address,
    required this.balance,
    required this.paymentType,
    required this.companyId,
    required this.currentBalance,
    required this.balanceStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    // Handle nested user data structure
    final Map<String, dynamic> userData = json['user'] ?? {};
    
    // Handle product_categories which might be a List or String
    String productCategoriesStr = '';
    var productCategories = json['product_categories'];
    if (productCategories is List) {
      productCategoriesStr = productCategories.join(', ');
    } else if (productCategories is String) {
      productCategoriesStr = productCategories;
    }
    
    return Supplier(
      id: json['id'] ?? 0,
      name: userData['name'] ?? '',
      email: userData['email'] ?? '',
      phone: userData['phone'] ?? '',
      altPhone: json['alt_phone'],
      productCategories: productCategoriesStr,
      address: json['address'] ?? '',
      balance: json['balance'] ?? '0.000',
      paymentType: json['payment_type'] ?? 'to_pay',
      companyId: json['company_id'] ?? 0,
      currentBalance: (json['current_balance'] ?? 0.0).toDouble(),
      balanceStatus: json['balance_status'] ?? '',
      userId: json['user_id'] ?? 0,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }
} 