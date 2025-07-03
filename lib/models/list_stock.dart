// To parse this JSON data, do
//
//     final listStockModel = listStockModelFromJson(jsonString);

import 'dart:convert';

import 'package:pos_machine/models/pagination.dart';

ListStockModel listStockModelFromJson(String str) =>
    ListStockModel.fromJson(json.decode(str));

String listStockModelToJson(ListStockModel data) => json.encode(data.toJson());

class ListStockModel {
  final String? status;
  final String? message;
  final List<ListStockModelData>? data;
  final Pagination? pagination;

  ListStockModel({
    this.status,
    this.message,
    this.data,
    this.pagination,
  });

  factory ListStockModel.fromJson(Map<String, dynamic> json) => ListStockModel(
        status: json["status"],
        message: json["message"],
        data: json["data"] == null
            ? []
            : List<ListStockModelData>.from(json["data"]["data"]!
                .map((x) => ListStockModelData.fromJson(x))),
        pagination:
            json["data"] == null ? null : Pagination.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": data == null
            ? []
            : List<dynamic>.from(data!.map((x) => x.toJson())),
        "pagination": pagination?.toJson(),
      };
}

class ListStockModelData {
  final int? stockId;
  final String? barCode;
  final String? productName;
  final String? categoryName;
  final String? supplierName;
  final String? orderDate;
  final int? qty;
  final String? retailPrice;
  final String? wholesalePrice;
  final String? purchaseRate;
  final String? mrp;
  final String? unit;
  final String? storeName;
  final String? rack;

  ListStockModelData({
    this.stockId,
    this.barCode,
    this.productName,
    this.categoryName,
    this.supplierName,
    this.orderDate,
    this.qty,
    this.retailPrice,
    this.wholesalePrice,
    this.purchaseRate,
    this.mrp,
    this.unit,
    this.storeName,
    this.rack,
  });

  factory ListStockModelData.fromJson(Map<String, dynamic> json) =>
      ListStockModelData(
        stockId: json["id"],
        barCode: json["barcode"],
        productName: json["product_name"],
        categoryName: json["category_name"],
        supplierName: json["supplier_name"],
        orderDate: json["order_date"],
        qty: json["qty"],
        retailPrice: json["retail_price"],
        wholesalePrice: json["wholesale_price"],
        purchaseRate: json["purchase_rate"],
        mrp: json["mrp"],
        unit: json["unit"],
        storeName: json["store_name"],
        rack: json["rack"],
      );

  Map<String, dynamic> toJson() => {
        "id": stockId,
        "barcode": barCode,
        "product_name": productName,
        "category_name": categoryName,
        "supplier_name": supplierName,
        "order_date": orderDate,
        "qty": qty,
        "retail_price": retailPrice,
        "wholesale_price": wholesalePrice,
        "purchase_rate": purchaseRate,
        "mrp": mrp,
        "unit": unit,
        "store_name": storeName,
        "rack": rack,
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
