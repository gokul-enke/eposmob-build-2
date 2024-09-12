// To parse this JSON data, do
//
//     final listStockModel = listStockModelFromJson(jsonString);

import 'dart:convert';

ListStockModel listStockModelFromJson(String str) =>
    ListStockModel.fromJson(json.decode(str));

String listStockModelToJson(ListStockModel data) => json.encode(data.toJson());

class ListStockModel {
  final String? status;
  final String? message;
  final List<ListStockModelData>? data;

  ListStockModel({
    this.status,
    this.message,
    this.data,
  });

  factory ListStockModel.fromJson(Map<String, dynamic> json) => ListStockModel(
        status: json["status"],
        message: json["message"],
        data: json["data"] == null
            ? []
            : List<ListStockModelData>.from(json["data"]["data"]!
                .map((x) => ListStockModelData.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": data == null
            ? []
            : List<dynamic>.from(data!.map((x) => x.toJson())),
      };
}

class ListStockModelData {
  final int? id;
  final int? productId;
  final int? storeId;
  final int? userId;
  final int? quantity;
  final String? unit;
  final double? purchaseRate;
  final double? retailPrice;
  final double? wholesalePrice;
  final int? wholesaleMinUnit;
  final String? expiryDate;
  final String? batchNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? productName;
  final String? storeName;
  final ProductDetails? product;
  final StoreDetails? store;
  final String? userName;
  final List<dynamic>? stockProperties;

  final UserDetails? user;

  ListStockModelData({
    this.id,
    this.productId,
    this.storeId,
    this.userId,
    this.quantity,
    this.unit,
    this.purchaseRate,
    this.retailPrice,
    this.wholesalePrice,
    this.wholesaleMinUnit,
    this.expiryDate,
    this.batchNumber,
    this.createdAt,
    this.updatedAt,
    this.productName,
    this.storeName,
    this.product,
    this.store,
    this.userName,
    this.stockProperties,
    this.user,
  });

  factory ListStockModelData.fromJson(Map<String, dynamic> json) =>
      ListStockModelData(
        id: json["id"],
        productId: json["product_id"],
        storeId: json["store_id"],
        userId: json["user_id"],
        quantity: json["quantity"],
        unit: json["unit"],
        purchaseRate: (json["purchase_rate"] is int)
            ? (json["purchase_rate"] as int).toDouble()
            : json["purchase_rate"],
        retailPrice: (json["retail_price"] is int)
            ? (json["retail_price"] as int).toDouble()
            : json["retail_price"],
        wholesalePrice: (json["wholesale_price"] is int)
            ? (json["wholesale_price"] as int).toDouble()
            : json["wholesale_price"],
        wholesaleMinUnit: json["wholesale_min_unit"],
        expiryDate: json["expiry_date"],
        //  == null
        //     ? null
        //     : DateTime.parse(json["expiry_date"]),
        batchNumber: json["batch_number"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
        productName: json["product_name"],
        storeName: json["store_name"],
        product: json["product"] == null
            ? null
            : ProductDetails.fromJson(json["product"]),
        store:
            json["store"] == null ? null : StoreDetails.fromJson(json["store"]),
        userName: json["user_name"],
        stockProperties: json["stock_properties"] == null
            ? []
            : List<dynamic>.from(json["stock_properties"]!.map((x) => x)),
        user: json["user"] == null ? null : UserDetails.fromJson(json["user"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "product_id": productId,
        "store_id": storeId,
        "user_id": userId,
        "quantity": quantity,
        "unit": unit,
        "purchase_rate": purchaseRate,
        "retail_price": retailPrice,
        "wholesale_price": wholesalePrice,
        "wholesale_min_unit": wholesaleMinUnit,
        "expiry_date": expiryDate,
        //  "${expiryDate!.year.toString().padLeft(4, '0')}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')}",
        "batch_number": batchNumber,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "product_name": productName,
        "store_name": storeName,
        "product": product?.toJson(),
        "store": store?.toJson(),
      };
}

class ProductDetails {
  final int? id;
  final String? name;
  final int? categoryId;
  final String? slug;
  final int? price;
  final dynamic createdUser;
  final String? updatedUser;
  final String? barcode;
  final String? unit;
  final String? status;
  final String? currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProductDetails({
    this.id,
    this.name,
    this.categoryId,
    this.slug,
    this.price,
    this.createdUser,
    this.updatedUser,
    this.barcode,
    this.unit,
    this.status,
    this.currency,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductDetails.fromJson(Map<String, dynamic> json) => ProductDetails(
        id: json["id"],
        name: json["name"],
        categoryId: json["category_id"],
        slug: json["slug"],
        price: json["price"],
        createdUser: json["created_user"],
        updatedUser: json["updated_user"],
        barcode: json["barcode"],
        unit: json["unit"],
        status: json["status"],
        currency: json["currency"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "category_id": categoryId,
        "slug": slug,
        "price": price,
        "created_user": createdUser,
        "updated_user": updatedUser,
        "barcode": barcode,
        "unit": unit,
        "status": status,
        "currency": currency,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}

class StoreDetails {
  final int? id;
  final String? name;
  final String? code;
  final int? companyId;
  final int? locationId;
  final String? status;
  final int? userId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  StoreDetails({
    this.id,
    this.name,
    this.code,
    this.companyId,
    this.locationId,
    this.status,
    this.userId,
    this.createdAt,
    this.updatedAt,
  });

  factory StoreDetails.fromJson(Map<String, dynamic> json) => StoreDetails(
        id: json["id"],
        name: json["name"],
        code: json["code"],
        companyId: json["company_id"],
        locationId: json["location_id"],
        status: json["status"],
        userId: json["user_id"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "code": code,
        "company_id": companyId,
        "location_id": locationId,
        "status": status,
        "user_id": userId,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}

class UserDetails {
  final int? id;
  final String? name;
  final String? email;
  final String? phone;
  final String? phoneVerified;
  final dynamic emailVerifiedAt;
  final String? defaultPassword;
  final int? doneBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserDetails({
    this.id,
    this.name,
    this.email,
    this.phone,
    this.phoneVerified,
    this.emailVerifiedAt,
    this.defaultPassword,
    this.doneBy,
    this.createdAt,
    this.updatedAt,
  });

  factory UserDetails.fromJson(Map<String, dynamic> json) => UserDetails(
        id: json["id"],
        name: json["name"],
        email: json["email"],
        phone: json["phone"],
        phoneVerified: json["phone_verified"],
        emailVerifiedAt: json["email_verified_at"],
        defaultPassword: json["default_password"],
        doneBy: json["done_by"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "email": email,
        "phone": phone,
        "phone_verified": phoneVerified,
        "email_verified_at": emailVerifiedAt,
        "default_password": defaultPassword,
        "done_by": doneBy,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}
