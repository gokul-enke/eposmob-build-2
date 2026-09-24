// To parse this JSON data, do
//
//     final getVoucherAccountTypesModel = getVoucherAccountTypesModelFromJson(jsonString);

import 'dart:convert';

GetVoucherAccountTypesModel getVoucherAccountTypesModelFromJson(String str) =>
    GetVoucherAccountTypesModel.fromJson(json.decode(str));

String getVoucherAccountTypesModelToJson(GetVoucherAccountTypesModel data) =>
    json.encode(data.toJson());

class GetVoucherAccountTypesModel {
  final String? status;
  final String? message;
  final Map<String, String>? getVoucherAccountTypesModelData;

  GetVoucherAccountTypesModel({
    this.status,
    this.message,
    this.getVoucherAccountTypesModelData,
  });

  factory GetVoucherAccountTypesModel.fromJson(Map<String, dynamic> json) =>
      GetVoucherAccountTypesModel(
        status: json["status"],
        message: json["message"],
        getVoucherAccountTypesModelData: _stringMap(json["data"]),
      );

  /// Some tenants legitimately have no voucher account types configured. The
  /// API represents that as `data: null` (and older versions sometimes return
  /// an empty list), neither of which should abort store bootstrap.
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
          getVoucherAccountTypesModelData ?? const <String, String>{},
        ),
      };
}
