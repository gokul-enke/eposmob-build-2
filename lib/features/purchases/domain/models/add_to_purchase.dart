// To parse this JSON data, do
//
//     final addToPurchaseModel = addToPurchaseModelFromJson(jsonString);

import 'dart:convert';

AddToPurchaseModel addToPurchaseModelFromJson(String str) =>
    AddToPurchaseModel.fromJson(json.decode(str));

String addToPurchaseModelToJson(AddToPurchaseModel data) =>
    json.encode(data.toJson());

class AddToPurchaseModel {
  final String? status;
  final List<PurchaseItem>? purchaseItems;
  final String? message;

  AddToPurchaseModel({
    this.status,
    this.purchaseItems,
    this.message,
  });

  factory AddToPurchaseModel.fromJson(Map<String, dynamic> json) =>
      AddToPurchaseModel(
        status: json["status"],
        purchaseItems: json["purchase_items"] == null
            ? []
            : List<PurchaseItem>.from(
                json["purchase_items"]!.map((x) => PurchaseItem.fromJson(x))),
        message: json["message"],
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "purchase_items": purchaseItems == null
            ? []
            : List<dynamic>.from(purchaseItems!.map((x) => x.toJson())),
        "message": message,
      };
}

class PurchaseItem {
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

  PurchaseItem({
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
  });

  factory PurchaseItem.fromJson(Map<String, dynamic> json) => PurchaseItem(
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
      };
}
