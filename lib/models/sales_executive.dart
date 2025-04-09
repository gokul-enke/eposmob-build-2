class SalesExecutive {
  final int id;
  final String name;
  final String email;
  final String phone;
  final DateTime? emailVerifiedAt;
  final int phoneVerified;
  final int? companyId;
  final DateTime createdAt;
  final DateTime updatedAt;

  SalesExecutive({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.emailVerifiedAt,
    required this.phoneVerified,
    this.companyId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SalesExecutive.fromJson(Map<String, dynamic> json) {
    return SalesExecutive(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      emailVerifiedAt: json['email_verified_at'] != null
          ? DateTime.parse(json['email_verified_at'])
          : null,
      phoneVerified: json['phone_verified'],
      companyId: json['company_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'email_verified_at': emailVerifiedAt?.toIso8601String(),
      'phone_verified': phoneVerified,
      'company_id': companyId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
} 