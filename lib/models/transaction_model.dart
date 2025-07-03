import 'dart:convert';

import 'package:pos_machine/models/pagination.dart';

TransactionResponse transactionResponseFromJson(String str) =>
    TransactionResponse.fromJson(json.decode(str));

String transactionResponseToJson(TransactionResponse data) =>
    json.encode(data.toJson());

class TransactionResponse {
  final String? status;
  final String? message;
  final TransactionData? data;

  TransactionResponse({
    this.status,
    this.message,
    this.data,
  });

  factory TransactionResponse.fromJson(Map<String, dynamic> json) =>
      TransactionResponse(
        status: json["status"],
        message: json["message"],
        data: json["data"] == null
            ? null
            : TransactionData.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": data?.toJson(),
      };
}

class TransactionData {
  final int currentPage;
  final List<TransactionModel> data;
  final String firstPageUrl;
  final int from;
  final int lastPage;
  final String lastPageUrl;
  final List<Link> links;
  final String? nextPageUrl;
  final String path;
  final int perPage;
  final String? prevPageUrl;
  final int to;
  final int total;

  TransactionData({
    required this.currentPage,
    required this.data,
    required this.firstPageUrl,
    required this.from,
    required this.lastPage,
    required this.lastPageUrl,
    required this.links,
    this.nextPageUrl,
    required this.path,
    required this.perPage,
    this.prevPageUrl,
    required this.to,
    required this.total,
  });

  factory TransactionData.fromJson(Map<String, dynamic> json) =>
      TransactionData(
        currentPage: json["current_page"],
        data: List<TransactionModel>.from(
            json["data"].map((x) => TransactionModel.fromJson(x))),
        firstPageUrl: json["first_page_url"],
        from: json["from"],
        lastPage: json["last_page"],
        lastPageUrl: json["last_page_url"],
        links: List<Link>.from(json["links"].map((x) => Link.fromJson(x))),
        nextPageUrl: json["next_page_url"],
        path: json["path"],
        perPage: json["per_page"],
        prevPageUrl: json["prev_page_url"],
        to: json["to"],
        total: json["total"],
      );

  Map<String, dynamic> toJson() => {
        "current_page": currentPage,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
        "first_page_url": firstPageUrl,
        "from": from,
        "last_page": lastPage,
        "last_page_url": lastPageUrl,
        "links": List<dynamic>.from(links.map((x) => x.toJson())),
        "next_page_url": nextPageUrl,
        "path": path,
        "per_page": perPage,
        "prev_page_url": prevPageUrl,
        "to": to,
        "total": total,
      };
}

class Link {
  final String? url;
  final String label;
  final bool active;

  Link({
    this.url,
    required this.label,
    required this.active,
  });

  factory Link.fromJson(Map<String, dynamic> json) => Link(
        url: json["url"],
        label: json["label"],
        active: json["active"],
      );

  Map<String, dynamic> toJson() => {
        "url": url,
        "label": label,
        "active": active,
      };
}

class TransactionModel {
  final int id;
  final int supplierId;
  final int? supplierVoucherId;
  final String date;
  final String type;
  final int? referenceId;
  final String transactionType;
  final String paymentMode;
  final String amount;
  final String? taxAmount;
  final String currency;
  final String reference;
  final String? transactionComment;
  final String status;
  final int userId;
  final String createdAt;
  final String updatedAt;
  final Supplier supplier;
  final int siNo; // Added for UI display

  TransactionModel({
    required this.id,
    required this.supplierId,
    this.supplierVoucherId,
    required this.date,
    required this.type,
    this.referenceId,
    required this.transactionType,
    required this.paymentMode,
    required this.amount,
    this.taxAmount,
    required this.currency,
    required this.reference,
    this.transactionComment,
    required this.status,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    required this.supplier,
    required this.siNo,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) =>
      TransactionModel(
        id: json["id"],
        supplierId: json["supplier_id"],
        supplierVoucherId: json["supplier_voucher_id"],
        date: json["date"],
        type: json["type"],
        referenceId: json["reference_id"],
        transactionType: json["transaction_type"],
        paymentMode: json["payment_mode"],
        amount: json["amount"],
        taxAmount: json["tax_amount"],
        currency: json["currency"],
        reference: json["reference"],
        transactionComment: json["transaction_comment"],
        status: json["status"],
        userId: json["user_id"],
        createdAt: json["created_at"],
        updatedAt: json["updated_at"],
        supplier: Supplier.fromJson(json["supplier"]),
        siNo: 0, // Will be set when processing the list
      );

  // For UI display with index
  factory TransactionModel.withIndex(TransactionModel model, int index) {
    return TransactionModel(
      id: model.id,
      supplierId: model.supplierId,
      supplierVoucherId: model.supplierVoucherId,
      date: model.date,
      type: model.type,
      referenceId: model.referenceId,
      transactionType: model.transactionType,
      paymentMode: model.paymentMode,
      amount: model.amount,
      taxAmount: model.taxAmount,
      currency: model.currency,
      reference: model.reference,
      transactionComment: model.transactionComment,
      status: model.status,
      userId: model.userId,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      supplier: model.supplier,
      siNo: index + 1,
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "supplier_id": supplierId,
        "supplier_voucher_id": supplierVoucherId,
        "date": date,
        "type": type,
        "reference_id": referenceId,
        "transaction_type": transactionType,
        "payment_mode": paymentMode,
        "amount": amount,
        "tax_amount": taxAmount,
        "currency": currency,
        "reference": reference,
        "transaction_comment": transactionComment,
        "status": status,
        "user_id": userId,
        "created_at": createdAt,
        "updated_at": updatedAt,
        "supplier": supplier.toJson(),
      };
}

class Supplier {
  final int id;
  final int userId;
  final String? altPhone;
  final String? productCategories;
  final String? address;
  final String balance;
  final String createdAt;
  final String updatedAt;
  final User user;

  Supplier({
    required this.id,
    required this.userId,
    this.altPhone,
    this.productCategories,
    this.address,
    required this.balance,
    required this.createdAt,
    required this.updatedAt,
    required this.user,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id: json["id"],
        userId: json["user_id"],
        altPhone: json["alt_phone"],
        productCategories: json["product_categories"],
        address: json["address"],
        balance: json["balance"],
        createdAt: json["created_at"],
        updatedAt: json["updated_at"],
        user: User.fromJson(json["user"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "user_id": userId,
        "alt_phone": altPhone,
        "product_categories": productCategories,
        "address": address,
        "balance": balance,
        "created_at": createdAt,
        "updated_at": updatedAt,
        "user": user.toJson(),
      };
}

class User {
  final int id;
  final String name;
  final String email;
  final String phone;
  final dynamic emailVerifiedAt;
  final int phoneVerified;
  final int companyId;
  final String createdAt;
  final String updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.emailVerifiedAt,
    required this.phoneVerified,
    required this.companyId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json["id"],
        name: json["name"],
        email: json["email"],
        phone: json["phone"],
        emailVerifiedAt: json["email_verified_at"],
        phoneVerified: json["phone_verified"],
        companyId: json["company_id"],
        createdAt: json["created_at"],
        updatedAt: json["updated_at"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "email": email,
        "phone": phone,
        "email_verified_at": emailVerifiedAt,
        "phone_verified": phoneVerified,
        "company_id": companyId,
        "created_at": createdAt,
        "updated_at": updatedAt,
      };
}
