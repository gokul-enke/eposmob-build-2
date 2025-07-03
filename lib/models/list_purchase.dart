// To parse this JSON data, do
//
//     final listPurchaseModel = listPurchaseModelFromJson(jsonString);

import 'dart:convert';

import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';
import 'package:pos_machine/models/pagination.dart';

ListPurchaseModel listPurchaseModelFromJson(String str) =>
    ListPurchaseModel.fromJson(json.decode(str));

String listPurchaseModelToJson(ListPurchaseModel data) =>
    json.encode(data.toJson());

class ListPurchaseModel {
  final String? status;
  final String? message;
  final List<ListPurchaseModelData>? data;
  final Pagination? pagination;

  ListPurchaseModel({
    this.status,
    this.message,
    this.data,
    this.pagination,
  });

  factory ListPurchaseModel.fromJson(Map<String, dynamic> json) =>
      ListPurchaseModel(
        status: json["status"],
        message: json["message"],
        data: json["data"] == null
            ? []
            : List<ListPurchaseModelData>.from(
                (json["data"]["data"]! as List<dynamic>)
                    .map((x) => ListPurchaseModelData.fromJson(x))),
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

class ListPurchaseModelData {
  final int? id;
  final int? purchaserId;
  final int? amountTotal;
  final dynamic taxAmount;
  final String? currency;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final GetStoreModelData? storeName;
  final GetSuppliersModelData? supplierName;
  final List<VoucherDetail>? voucherDetails;
  final List<PurchaseItem>? purchaseItems;
  // final List<Purchase>? purchases;
  // final List<VoucherDetail>? voucherDetails;
  // final List<List<PurchaseItem>>? purchaseItems;

  ListPurchaseModelData({
    this.voucherDetails,
    this.purchaseItems,
    this.id,
    this.purchaserId,
    this.amountTotal,
    this.taxAmount,
    this.currency,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.storeName,
    this.supplierName,
  });

  factory ListPurchaseModelData.fromJson(Map<String, dynamic> json) =>
      ListPurchaseModelData(
        id: json["id"],
        purchaserId: json["purchaser_id"],
        amountTotal: json["amount_total"],
        taxAmount: json["tax_amount"],
        currency: json["currency"],
        status: json["status"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
        storeName: json["store_name"],
        supplierName: json["supplier_name"],
        voucherDetails: json["purchase_vouchers"] == null
            ? []
            : List<VoucherDetail>.from(json["purchase_vouchers"]!
                .map((x) => VoucherDetail.fromJson(x))),
        purchaseItems: json["purchase_items"] == null
            ? []
            : List<PurchaseItem>.from(
                json["purchase_items"]!.map((x) => PurchaseItem.fromJson(x))),
      );
  // purchases: json["purchases"] == null
  //     ? []
  //     : List<Purchase>.from(
  //         json["purchases"]!.map((x) => Purchase.fromJson(x))),
  // voucherDetails: json["voucher_details"] == null
  //     ? []
  //     : List<VoucherDetail>.from(
  //         json["voucher_details"]!.map((x) => VoucherDetail.fromJson(x))),
  // purchaseItems: json["purchase_items"] == null
  //     ? []
  //     : List<List<PurchaseItem>>.from(json["purchase_items"]!.map((x) =>
  //         List<PurchaseItem>.from(
  //             x.map((x) => PurchaseItem.fromJson(x))))),

  Map<String, dynamic> toJson() => {};
}

class Purchase {
  final int? id;
  final int? purchaserId;
  final int? amountTotal;
  final dynamic taxAmount;
  final String? currency;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Purchase({
    this.id,
    this.purchaserId,
    this.amountTotal,
    this.taxAmount,
    this.currency,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) => Purchase(
        id: json["id"],
        purchaserId: json["purchaser_id"],
        amountTotal: json["amount_total"],
        taxAmount: json["tax_amount"],
        currency: json["currency"],
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
        "purchaser_id": purchaserId,
        "amount_total": amountTotal,
        "tax_amount": taxAmount,
        "currency": currency,
        "status": status,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}

class VoucherDetail {
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
  final dynamic transactionId;
  final String? status;
  final int? quantity;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  VoucherDetail({
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
    this.quantity,
    this.createdAt,
    this.updatedAt,
  });

  factory VoucherDetail.fromJson(Map<String, dynamic> json) => VoucherDetail(
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
        quantity: json["quantity"],
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
        "purchase_date": "",
        "store_id": storeId,
        "supplier_id": supplierId,
        "purchase_id": purchaseId,
        "voucher_number": voucherNumber,
        "amount_total": amountTotal,
        "tax_amount": taxAmount,
        "currency": currency,
        "transaction_id": transactionId,
        "status": status,
        "quantity": quantity,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}

ListPurchaseItemModel listPurchaseItemModelFromJson(String str) =>
    ListPurchaseItemModel.fromJson(json.decode(str));

String listPurchaseItemModelToJson(ListPurchaseItemModel data) =>
    json.encode(data.toJson());

class ListPurchaseItemModel {
  final String? status;
  final List<PurchaseItem>? data;

  ListPurchaseItemModel({
    this.status,
    this.data,
  });

  factory ListPurchaseItemModel.fromJson(Map<String, dynamic> json) =>
      ListPurchaseItemModel(
        status: json["status"],
        data: json["data"] == null
            ? []
            : List<PurchaseItem>.from(
                json["data"]!.map((x) => PurchaseItem.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "data": data == null
            ? []
            : List<dynamic>.from(data!.map((x) => x.toJson())),
      };
}

class PurchaseItem {
  final int? id;
  final int? purchaseId;
  final int? voucherId;
  final int? productId;
  final int? storeId;
  final int? supplierId;
  final int? quantity;
  final int? unitPrice;
  final String? unit;
  final String? batchNumber;
  final dynamic barCode;
  final String? status;
  final String? name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PurchaseItem({
    this.id,
    this.purchaseId,
    this.voucherId,
    this.productId,
    this.storeId,
    this.supplierId,
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

  factory PurchaseItem.fromJson(Map<String, dynamic> json) => PurchaseItem(
        id: json["id"],
        purchaseId: json["purchase_id"],
        voucherId: json["voucher_id"],
        productId: json["product_id"],
        storeId: json["store_id"],
        supplierId: json["supplier_id"],
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
        "store_id": storeId,
        "supplier_id": supplierId,
        "quantity": quantity,
        "unit_price": unitPrice,
        "unit": unit,
        "batch_number": batchNumber,
        "bar_code": barCode,
        "status": status,
        "name": name,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}

class VoucherDetails {
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
  final dynamic transactionId;
  final String? status;
  final int? quantity;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final GetStoreModelData? store;
  final GetSuppliersModelData? supplier;

  VoucherDetails(
      {this.id,
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
      this.quantity,
      this.createdAt,
      this.updatedAt,
      this.store,
      this.supplier});

  factory VoucherDetails.fromJson(Map<String, dynamic> json) => VoucherDetails(
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
        quantity: json["quantity"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
        store: json["store"] == null
            ? null
            : GetStoreModelData.fromJson(json["store"]),
        supplier: json["supplier"] == null
            ? null
            : GetSuppliersModelData.fromJson(json["supplier"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "store_manager_id": storeManagerId,
        "purchase_date": "",
        "store_id": storeId,
        "supplier_id": supplierId,
        "purchase_id": purchaseId,
        "voucher_number": voucherNumber,
        "amount_total": amountTotal,
        "tax_amount": taxAmount,
        "currency": currency,
        "transaction_id": transactionId,
        "status": status,
        "quantity": quantity,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "store": store?.toJson(),
        "supplier": supplier?.toJson(),
      };
}
