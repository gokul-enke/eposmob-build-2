// To parse this JSON data, do
//
//     final getStatesModel = getStatesModelFromJson(jsonString);

import 'dart:convert';

GetStatesModel getStatesModelFromJson(String str) =>
    GetStatesModel.fromJson(json.decode(str));

String getStatesModelToJson(GetStatesModel data) => json.encode(data.toJson());

class GetStatesModel {
  final String? status;
  final Map<String, String>? data;

  GetStatesModel({
    this.status,
    this.data,
  });

  factory GetStatesModel.fromJson(Map<String, dynamic> json) => GetStatesModel(
        status: json["status"],
        data: Map.from(json["data"]!)
            .map((k, v) => MapEntry<String, String>(k, v)),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "data": data?.map((k, v) => MapEntry<String, dynamic>(k, v)),
      };
}
