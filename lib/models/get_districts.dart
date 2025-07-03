// To parse this JSON data, do
//
//     final getDistrictsModel = getDistrictsModelFromJson(jsonString);

import 'dart:convert';

GetDistrictsModel getDistrictsModelFromJson(String str) =>
    GetDistrictsModel.fromJson(json.decode(str));

String getDistrictsModelToJson(GetDistrictsModel data) =>
    json.encode(data.toJson());

class GetDistrictsModel {
  final String? status;
  final Map<String, String>? data;

  GetDistrictsModel({
    this.status,
    this.data,
  });

  factory GetDistrictsModel.fromJson(Map<String, dynamic> json) =>
      GetDistrictsModel(
        status: json["status"],
        data: Map.from(json["data"]!)
            .map((k, v) => MapEntry<String, String>(k, v)),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "data": data?.map((k, v) => MapEntry<String, dynamic>(k, v)),
      };
}
