import 'dart:convert';

import 'package:pos_machine/models/pagination.dart';

class ListVoucherModel {
  final String? status;
  final String? message;
  final List<VoucherModelData>? data;
  final Pagination? pagination;

  ListVoucherModel({
    this.status,
    this.message,
    this.data,
    this.pagination,
  });

  factory ListVoucherModel.fromJson(Map<String, dynamic> json) =>
      ListVoucherModel(
        status: json["status"],
        message: json["message"],
        data: json["data"] == null
            ? []
            : List<VoucherModelData>.from(
                json["data"]["data"].map((x) => VoucherModelData.fromJson(x))),
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

class VoucherModelData {
  final int? id;
  final int? storeManagerId;
  final String? purchaseDate;
  final int? storeId;
  final int? supplierId;
  final int? purchaseId;
  final dynamic voucherNumber;
  final int? amountTotal;
  final dynamic taxAmount;
  final String? currency;
  final String? transactionId;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  VoucherModelData({
    this.id,
    this.storeManagerId,
    this.purchaseDate,
    this.storeId,
    this.supplierId,
    this.purchaseId,
    this.voucherNumber,
    this.amountTotal,
    this.taxAmount,
    this.currency,
    this.transactionId,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory VoucherModelData.fromJson(Map<String, dynamic> json) =>
      VoucherModelData(
        id: json["id"],
        storeManagerId: json["store_manager_id"],
        purchaseDate: json["purchase_date"],
        storeId: json["store_id"],
        supplierId: json["supplier_id"],
        purchaseId: json["purchase_id"],
        voucherNumber: json["voucher_number"],
        amountTotal: json["amount_total"],
        taxAmount: json["tax_amount"],
        currency: json["currency"],
        transactionId: json["transaction_id"],
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
        "store_manager_id": storeManagerId,
        "purchase_date": purchaseDate,
        "store_id": storeId,
        "supplier_id": supplierId,
        "purchase_id": purchaseId,
        "voucher_number": voucherNumber,
        "amount_total": amountTotal,
        "tax_amount": taxAmount,
        "currency": currency,
        "transaction_id": transactionId,
        "status": status,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}

ListVoucherModel listVoucherModelFromJson(String str) =>
    ListVoucherModel.fromJson(json.decode(str));

String listVoucherModelToJson(ListVoucherModel data) =>
    json.encode(data.toJson());
