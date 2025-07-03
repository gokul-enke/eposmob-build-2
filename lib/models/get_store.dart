// To parse this JSON data, do
//
//     final getStoreModel = getStoreModelFromJson(jsonString);

import 'dart:convert';

GetStoreModel getStoreModelFromJson(String str) =>
    GetStoreModel.fromJson(json.decode(str));

String getStoreModelToJson(GetStoreModel data) => json.encode(data.toJson());

class GetStoreModel {
  final String? status;
  final List<GetStoreModelData>? data;

  GetStoreModel({
    this.status,
    this.data,
  });

  factory GetStoreModel.fromJson(Map<String, dynamic> json) => GetStoreModel(
        status: json["status"],
        data: json["data"] == null
            ? []
            : List<GetStoreModelData>.from(
                json["data"]!.map((x) => GetStoreModelData.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "data": data == null
            ? []
            : List<dynamic>.from(data!.map((x) => x.toJson())),
      };
}

class GetStoreModelData {
  final int? id;
  final String? name;
  final String? code;
  final int? companyId;
  final int? locationId;
  final String? status;
  final int? userId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GetStoreModelData({
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

  factory GetStoreModelData.fromJson(Map<String, dynamic> json) =>
      GetStoreModelData(
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

  // Override the equality operator
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is GetStoreModelData && id == other.id);

  // Override the hashCode
  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}