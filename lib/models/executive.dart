// To parse this JSON data, do
//
//     final executiveModel = executiveModelFromJson(jsonString);

import 'dart:convert';

ExecutiveModel executiveModelFromJson(String str) =>
    ExecutiveModel.fromJson(json.decode(str));

String executiveModelToJson(ExecutiveModel data) => json.encode(data.toJson());

class ExecutiveModel {
  final String? status;
  final String? message;
  final ExecutiveModelData? data;

  ExecutiveModel({
    this.status,
    this.message,
    this.data,
  });

  factory ExecutiveModel.fromJson(Map<String, dynamic> json) => ExecutiveModel(
        status: json["status"],
        message: json["message"],
        data: json["data"] == null
            ? null
            : ExecutiveModelData.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": data?.toJson(),
      };
}

class ExecutiveModelData {
  final String? accessToken;
  final String? tokenType;
  final int? userId;
  final String? userName;
  final int? companyId;
  final String? companyName;
  final String? userRole;
  final List<Store>? stores;
  // ZATCA fields for Saudi Arabia e-invoicing
  final String? crNumber;
  final String? vatNumber;
  final String? zatcaCompanyName;
  final String? timeZone;

  ExecutiveModelData({
    this.accessToken,
    this.tokenType,
    this.userId,
    this.userName,
    this.companyId,
    this.companyName,
    this.userRole,
    this.stores,
    this.crNumber,
    this.vatNumber,
    this.zatcaCompanyName,
    this.timeZone,
  });

  factory ExecutiveModelData.fromJson(Map<String, dynamic> json) =>
      ExecutiveModelData(
        accessToken: json["access_token"],
        tokenType: json["token_type"],
        userId: json["user_id"],
        userName: json["name"],
        companyId: json["company_id"],
        companyName: json["company_name"],
        userRole: json["user_role"],
        stores: json["stores"] == null
            ? null
            : List<Store>.from(json["stores"].map((x) => Store.fromJson(x))),
        crNumber: json["cr_number"]?.toString(),
        vatNumber: json["vat_number"],
        zatcaCompanyName: json["zatca_company_name"],
        timeZone: json["time_zone"],
      );

  Map<String, dynamic> toJson() => {
        "access_token": accessToken,
        "token_type": tokenType,
        "user_id": userId,
        "name": userName,
        "company_id": companyId,
        "company_name": companyName,
        "user_role": userRole,
        "stores": stores == null
            ? null
            : List<dynamic>.from(stores!.map((x) => x.toJson())),
        "cr_number": crNumber,
        "vat_number": vatNumber,
        "zatca_company_name": zatcaCompanyName,
        "time_zone": timeZone,
      };
}

class Store {
  final int? storeId;
  final String? storeName;
  final String? location;
  final String? email;
  final String? phone;

  Store({
    this.storeId,
    this.storeName,
    this.location,
    this.email,
    this.phone,
  });

  factory Store.fromJson(Map<String, dynamic> json) => Store(
        storeId: json["store_id"],
        storeName: json["store_name"],
        location: json["location"],
        email: json["email"],
        phone: json["phone"]?.toString(),
      );

  Map<String, dynamic> toJson() => {
        "store_id": storeId,
        "store_name": storeName,
        "location": location,
        "email": email,
        "phone": phone,
      };
}
