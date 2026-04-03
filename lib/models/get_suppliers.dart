import 'dart:convert';

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}

GetSuppliersModel getSuppliersModelFromJson(String str) => 
    GetSuppliersModel.fromJson(json.decode(str));

String getSuppliersModelToJson(GetSuppliersModel data) => 
    json.encode(data.toJson());

class GetSuppliersModel {
  final String? status;
  final List<GetSuppliersModelData>? data;

  GetSuppliersModel({this.status, this.data});

  factory GetSuppliersModel.fromJson(Map<String, dynamic> json) => GetSuppliersModel(
    status: json["status"],
    data: json["data"] == null ? [] : List<GetSuppliersModelData>.from(
      json["data"]!.map((x) => GetSuppliersModelData.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "status": status,
    "data": data == null ? [] : List<dynamic>.from(data!.map((x) => x.toJson())),
  };
}

class GetSuppliersModelData {
  final int? id;
  final int? userId;
  final String? name; // This might be null (real name is in `user.name`)
  final String? phone;
  final String? email;
  final String? productCategory;
  final String? address;
  final double currentBalance;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final User? user; // Nested user object

  /// Returns the supplier name, checking both direct name and nested user.name
  String get displayName => name ?? user?.name ?? 'Unknown';

  GetSuppliersModelData({
    this.id,
    this.userId,
    this.name,
    this.phone,
    this.email,
    this.productCategory,
    this.address,
    this.currentBalance = 0.0,
    this.createdAt,
    this.updatedAt,
    this.user,
  });

  factory GetSuppliersModelData.fromJson(Map<String, dynamic> json) => GetSuppliersModelData(
    id: json["id"],
    userId: json["user_id"],
    name: json["name"], // Often null (depends on API)
    phone: json["phone"],
    email: json["email"],
    productCategory: json["product_category"],
    address: json["address"],
    currentBalance: _toDouble(
      json["current_balance"] ?? json["currentBalance"] ?? json["balance"],
    ),
    createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
    user: json["user"] != null ? User.fromJson(json["user"]) : null, // Parse nested user
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "user_id": userId,
    "name": name,
    "phone": phone,
    "email": email,
    "product_category": productCategory,
    "address": address,
    "current_balance": currentBalance,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "user": user?.toJson(),
  };
}

class User {
  final int? id;
  final String? name; // Actual supplier name is here
  final String? email;
  final String? phone;

  User({this.id, this.name, this.email, this.phone});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json["id"],
    name: json["name"],
    email: json["email"],
    phone: json["phone"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "email": email,
    "phone": phone,
  };
}