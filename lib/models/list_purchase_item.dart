// To parse this JSON data, do
//
//     final listPurchaseItemModel = listPurchaseItemModelFromJson(jsonString);

// import 'dart:convert';

// import 'package:pos_machine/models/add_to_purchase.dart';

// ListPurchaseItemModel listPurchaseItemModelFromJson(String str) =>
//     ListPurchaseItemModel.fromJson(json.decode(str));

// String listPurchaseItemModelToJson(ListPurchaseItemModel data) =>
//     json.encode(data.toJson());

// class ListPurchaseItemModel {
//   final String? status;
//   final List<PurchaseItem>? data;

//   ListPurchaseItemModel({
//     this.status,
//     this.data,
//   });

//   factory ListPurchaseItemModel.fromJson(Map<String, dynamic> json) =>
//       ListPurchaseItemModel(
//         status: json["status"],
//         data: json["data"] == null
//             ? []
//             : List<PurchaseItem>.from(
//                 json["data"]!.map((x) => PurchaseItem.fromJson(x))),
//       );

//   Map<String, dynamic> toJson() => {
//         "status": status,
//         "data": data == null
//             ? []
//             : List<dynamic>.from(data!.map((x) => x.toJson())),
//       };
// }
