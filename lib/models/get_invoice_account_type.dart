// To parse this JSON data, do
//
//     final getInvoiceAccountTypesModel = getInvoiceAccountTypesModelFromJson(jsonString);

import 'dart:convert';

GetInvoiceAccountTypesModel getInvoiceAccountTypesModelFromJson(String str) =>
    GetInvoiceAccountTypesModel.fromJson(json.decode(str));

String getInvoiceAccountTypesModelToJson(GetInvoiceAccountTypesModel data) =>
    json.encode(data.toJson());

class GetInvoiceAccountTypesModel {
  final String? status;
  final String? message;
  final Map<String, String>? getInvoiceAccountTypesModelData;

  GetInvoiceAccountTypesModel({
    this.status,
    this.message,
    this.getInvoiceAccountTypesModelData,
  });

  factory GetInvoiceAccountTypesModel.fromJson(Map<String, dynamic> json) =>
      GetInvoiceAccountTypesModel(
        status: json["status"],
        message: json["message"],
        getInvoiceAccountTypesModelData: _stringMap(json["data"]),
      );

  static Map<String, String> _stringMap(dynamic raw) {
    if (raw is! Map) return <String, String>{};

    final result = <String, String>{};
    raw.forEach((key, value) {
      if (value == null) return;
      result[key.toString()] = value.toString();
    });
    return result;
  }

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": Map<String, dynamic>.from(
          getInvoiceAccountTypesModelData ?? const <String, String>{},
        ),
      };
}
