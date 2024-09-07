// To parse this JSON data, do
//
//     final listCartModel = listCartModelFromJson(jsonString);

import 'dart:convert';

import 'package:pos_machine/models/add_to_cart.dart';
import 'package:pos_machine/models/get_product.dart';

ListCartModel listCartModelFromJson(String str) =>
    ListCartModel.fromJson(json.decode(str));

String listCartModelToJson(ListCartModel data) => json.encode(data.toJson());

class ListCartModel {
  final String? status;
  final List<ListCartModelData>? data;

  ListCartModel({
    this.status,
    this.data,
  });

  factory ListCartModel.fromJson(Map<String, dynamic> json) => ListCartModel(
        status: json["status"],
        data: json["data"] == null
            ? []
            : List<ListCartModelData>.from(
                json["data"]!.map((x) => ListCartModelData.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "data": data == null
            ? []
            : List<dynamic>.from(data!.map((x) => x.toJson())),
      };
}

class ListCartModelData {
  final int? id;
  final int? customerId;
  final int? userId;
  final int? itemCount;
  final int? storeId;
  final List<ListCartModelDataCartItem>? cartItems;
  final List<String>? taxNames;
  final PriceSummary? priceSummary;
  final Map<String, int>? taxAmounts;

  ListCartModelData({
    this.id,
    this.customerId,
    this.userId,
    this.itemCount,
    this.storeId,
    this.cartItems,
    this.taxNames,
    this.priceSummary,
    this.taxAmounts,
  });

  factory ListCartModelData.fromJson(Map<String, dynamic> json) =>
      ListCartModelData(
        id: json["id"],
        customerId: json["customer_id"],
        userId: json["user_id"],
        itemCount: json["item_count"],
        storeId: json["store_id"],
        cartItems: json["cart_items"] == null
            ? []
            : List<ListCartModelDataCartItem>.from(json["cart_items"]!
                .map((x) => ListCartModelDataCartItem.fromJson(x))),
        taxNames: json["tax_names"] == null
            ? []
            : List<String>.from(json["tax_names"]!.map((x) => x)),
        priceSummary: json["price_summary"] == null
            ? null
            : PriceSummary.fromJson(json["price_summary"]),
        taxAmounts: json["tax_amounts"] is Map // Check if tax_amounts is a Map
            ? Map<String, int>.from(json["tax_amounts"]
                .map((k, v) => MapEntry(k as String, v as int)))
            : null, // Handle the empty array case by assigning `null`
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "customer_id": customerId,
        "user_id": userId,
        "item_count": itemCount,
        "store_id": storeId,
        "cart_items": cartItems == null
            ? []
            : List<dynamic>.from(cartItems!.map((x) => x.toJson())),
        "tax_names":
            taxNames == null ? [] : List<dynamic>.from(taxNames!.map((x) => x)),
        "price_summary": priceSummary?.toJson(),
        "tax_amounts":
            taxAmounts != null ? Map<String, dynamic>.from(taxAmounts!) : null,
      };
}

class ListCartModelDataCartItem {
  final int? id;
  final int? productId;
  final String? productName;
  final int? categoryId;
  final int? quantity;
  final String? productUnit;
  final int? unitPrice;
  final String? totalPrice;
  final int? taxRate;
  final int? taxAmount;
  final String? currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<Attachment>? productAttchment;

  ListCartModelDataCartItem({
    this.id,
    this.productId,
    this.productName,
    this.productAttchment,
    this.categoryId,
    this.quantity,
    this.productUnit,
    this.unitPrice,
    this.totalPrice,
    this.taxRate,
    this.taxAmount,
    this.currency,
    this.createdAt,
    this.updatedAt,
  });

  factory ListCartModelDataCartItem.fromJson(Map<String, dynamic> json) =>
      ListCartModelDataCartItem(
        id: json["id"],
        productId: json["product_id"],
        productName: json["product_name"],
        productAttchment: json["product_attchment"] == null
            ? []
            : List<Attachment>.from(
                json["product_attchment"]!.map((x) => Attachment.fromJson(x))),
        categoryId: json["category_id"],
        quantity: json["quantity"],
        productUnit: json["product_unit"],
        unitPrice: json["unit_price"],
        totalPrice: json["total_price"],
        taxRate: json["tax_rate"],
        taxAmount: json["tax_amount"],
        currency: json["currency"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "product_id": productId,
        "product_name": productName,
        "product_attchment": productAttchment == null
            ? []
            : List<dynamic>.from(productAttchment!.map((x) => x.toJson())),
        "category_id": categoryId,
        "quantity": quantity,
        "product_unit": productUnit,
        "unit_price": unitPrice,
        "total_price": totalPrice,
        "tax_rate": taxRate,
        "tax_amount": taxAmount,
        "currency": currency,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}

// class PriceSummary {
//     final int? subTotal;
//     final int? totalTax;
//     final int? netTotal;
//     final int? discount;
//     final int? netPayable;

//     PriceSummary({
//         this.subTotal,
//         this.totalTax,
//         this.netTotal,
//         this.discount,
//         this.netPayable,
//     });

//     factory PriceSummary.fromJson(Map<String, dynamic> json) => PriceSummary(
//         subTotal: json["sub_total"],
//         totalTax: json["total_tax"],
//         netTotal: json["net_total"],
//         discount: json["discount"],
//         netPayable: json["net_payable"],
//     );

//     Map<String, dynamic> toJson() => {
//         "sub_total": subTotal,
//         "total_tax": totalTax,
//         "net_total": netTotal,
//         "discount": discount,
//         "net_payable": netPayable,
//     };
// }
// class ListCartModelDataPriceSummary {
//   final String? subtotal;
//   final String? taxAmount;
//   final String? shippingCharge;
//   final String? total;

//   ListCartModelDataPriceSummary({
//     this.subtotal,
//     this.taxAmount,
//     this.shippingCharge,
//     this.total,
//   });

//   factory ListCartModelDataPriceSummary.fromJson(Map<String, dynamic> json) =>
//       ListCartModelDataPriceSummary(
//         subtotal: json["subtotal"],
//         taxAmount: json["tax_amount"],
//         shippingCharge: json["shipping_charge"],
//         total: json["total"],
//       );

//   Map<String, dynamic> toJson() => {
//         "subtotal": subtotal,
//         "tax_amount": taxAmount,
//         "shipping_charge": shippingCharge,
//         "total": total,
//       };
// }
