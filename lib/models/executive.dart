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

  ExecutiveModelData({
    this.accessToken,
    this.tokenType,
    this.userId,
    this.userName,
  });

  factory ExecutiveModelData.fromJson(Map<String, dynamic> json) =>
      ExecutiveModelData(
        accessToken: json["access_token"],
        tokenType: json["token_type"],
        userId: json["user_id"],
        userName: json["name"],
      );

  Map<String, dynamic> toJson() => {
        "access_token": accessToken,
        "token_type": tokenType,
        "user_id": userId,
        "name": userName,
      };
}
