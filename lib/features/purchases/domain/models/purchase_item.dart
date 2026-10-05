// To parse this JSON data, do
//
//     final purchaseItemModel = purchaseItemModelFromJson(jsonString);

import 'dart:convert';

PurchaseItemModel purchaseItemModelFromJson(String str) =>
    PurchaseItemModel.fromJson(json.decode(str));

String purchaseItemModelToJson(PurchaseItemModel data) =>
    json.encode(data.toJson());

class PurchaseItemModel {
  final String? status;
  final int? purchaseId;
  final Item? item;
  final String? message;

  PurchaseItemModel({
    this.status,
    this.purchaseId,
    this.item,
    this.message,
  });

  factory PurchaseItemModel.fromJson(Map<String, dynamic> json) =>
      PurchaseItemModel(
        status: json["status"],
        purchaseId: json["purchase_id"],
        item: json["item"] == null ? null : Item.fromJson(json["item"]),
        message: json["message"],
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "purchase_id": purchaseId,
        "item": item?.toJson(),
        "message": message,
      };
}

class Item {
  final int? id;
  final int? purchaseId;
  final int? voucherId;
  final int? productId;
  final int? quantity;
  final int? unitPrice;
  final String? unit;
  final String? batchNumber;
  final dynamic barCode;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? name;

  Item({
    this.id,
    this.purchaseId,
    this.voucherId,
    this.productId,
    this.quantity,
    this.unitPrice,
    this.unit,
    this.batchNumber,
    this.barCode,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.name,
  });

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: json["id"],
        purchaseId: json["purchase_id"],
        voucherId: json["voucher_id"],
        productId: json["product_id"],
        quantity: json["quantity"],
        unitPrice: json["unit_price"],
        unit: json["unit"],
        batchNumber: json["batch_number"],
        barCode: json["bar_code"],
        status: json["status"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
        name: json["name"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "purchase_id": purchaseId,
        "voucher_id": voucherId,
        "product_id": productId,
        "quantity": quantity,
        "unit_price": unitPrice,
        "unit": unit,
        "batch_number": batchNumber,
        "bar_code": barCode,
        "status": status,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "name": name,
      };
}
