// To parse this JSON data, do
//
//     final getPaymentMethodsModel = getPaymentMethodsModelFromJson(jsonString);

import 'dart:convert';
import 'package:pos_machine/models/master_data.dart';

GetPaymentMethodsModel getPaymentMethodsModelFromJson(String str) =>
    GetPaymentMethodsModel.fromJson(json.decode(str));

class GetPaymentMethodsModel {
  final String? status;
  final String? message;
  final List<MasterDataValue>? paymentList;

  GetPaymentMethodsModel({
    this.status,
    this.message,
    this.paymentList,
  });

  factory GetPaymentMethodsModel.fromJson(Map<String, dynamic> json) {
    List<MasterDataValue>? payments;
    if (json["data"] != null) {
      if (json["data"] is List) {
        // New structure: List of objects with id, value, description
        payments = (json["data"] as List)
            .map((item) => MasterDataValue.fromJson(item))
            .toList();
      } else if (json["data"] is Map) {
        // Legacy structure: Map<String, String> - convert to MasterDataValue list
        int index = 0;
        payments = (json["data"] as Map<String, dynamic>).entries.map((entry) {
          return MasterDataValue(
            id: index++,
            value: entry.key,
            description: entry.value.toString(),
          );
        }).toList();
      }
    }
    return GetPaymentMethodsModel(
      status: json["status"],
      message: json["message"],
      paymentList: payments,
    );
  }

  /// Helper to get a Map<String, String> for backwards compatibility
  /// Returns value -> description mapping
  Map<String, String>? get paymentListAsMap {
    if (paymentList == null) return null;
    return {for (var item in paymentList!) item.value: item.description};
  }

  /// Helper to get payment method ID by value
  int? getIdByValue(String value) {
    if (paymentList == null) return null;
    try {
      return paymentList!.firstWhere((item) => item.value == value).id;
    } catch (e) {
      return null;
    }
  }

  /// Helper to get payment method value by ID
  String? getValueById(int id) {
    if (paymentList == null) return null;
    try {
      return paymentList!.firstWhere((item) => item.id == id).value;
    } catch (e) {
      return null;
    }
  }
}
