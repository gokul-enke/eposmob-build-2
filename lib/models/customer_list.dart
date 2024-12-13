import 'dart:convert';

CustomerListModel customerListModelFromJson(String str) =>
    CustomerListModel.fromJson(json.decode(str));

String customerListModelToJson(CustomerListModel data) =>
    json.encode(data.toJson());

class CustomerListModel {
  final String? status;
  final String? message;
  final List<CustomerListModelData>? data;

  CustomerListModel({
    this.status,
    this.message,
    this.data,
  });

  factory CustomerListModel.fromJson(Map<String, dynamic> json) =>
      CustomerListModel(
        status: json["status"],
        message: json["message"],
        data: json["data"] == null
            ? []
            : List<CustomerListModelData>.from(
                json["data"].map((x) => CustomerListModelData.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": data == null
            ? []
            : List<dynamic>.from(data!.map((x) => x.toJson())),
      };
}

class CustomerListModelData {
  final int? id;
  final String? name;
  final String? email;
  final String? phone;
  final String? altPhone;
  final String? gender;
  final String? dob;
  final dynamic profileImage;
  final int? storeId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CustomerListModelData({
    this.id,
    this.name,
    this.email,
    this.phone,
    this.altPhone,
    this.gender,
    this.dob,
    this.profileImage,
    this.storeId,
    this.createdAt,
    this.updatedAt,
  });

  factory CustomerListModelData.fromJson(Map<String, dynamic> json) =>
      CustomerListModelData(
        id: json["id"] ?? "0",
        name: json["name"] ?? "no name",
        email: json["email"],
        phone: json["phone"],
        altPhone: json["alt_phone"],
        gender: json["gender"],
        dob: json["dob"],
        profileImage: json["profile_image"],
        storeId: json["store_id"],
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
        "alt_phone": altPhone,
        "gender": gender,
        "dob": dob,
        "profile_image": profileImage,
        "store_id": storeId,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}
