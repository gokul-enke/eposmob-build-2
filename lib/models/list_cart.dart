import 'dart:convert';

import 'package:pos_machine/models/add_to_cart.dart';

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
  final int? userId; // Changed to nullable to accommodate null in new response
  final int? itemCount;
  final int? storeId;
  final List<ListCartModelDataCartItem>? cartItems;
  final PriceSummary? priceSummary; // Updated to reflect new structure
  final Map<String, double>?
      taxAmounts; // Updated to double to accommodate decimal values

  ListCartModelData({
    this.id,
    this.customerId,
    this.userId,
    this.itemCount,
    this.storeId,
    this.cartItems,
    this.priceSummary,
    this.taxAmounts,
  });

  factory ListCartModelData.fromJson(Map<String, dynamic> json) =>
      ListCartModelData(
        id: json["id"],
        customerId: json["customer_id"],
        userId: json["user_id"], // Keep nullability for userId
        itemCount: json["item_count"],
        storeId: json["store_id"],
        cartItems: json["cart_items"] == null
            ? []
            : List<ListCartModelDataCartItem>.from(json["cart_items"]!
                .map((x) => ListCartModelDataCartItem.fromJson(x))),
        priceSummary: json["price_summary"] == null
            ? null
            : PriceSummary.fromJson(json["price_summary"]),
        taxAmounts: (json["tax_amounts"] is Map<String, dynamic>)
            ? (json["tax_amounts"] as Map<String, dynamic>).map(
                (k, v) =>
                    MapEntry(k, (v as num).toDouble()), // Convert to double
              )
            : {}, // If it's not a map, return an empty map
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
  final String? unitPrice;
  final String? totalPrice;
  final String? taxRate; // Changed from int to String to match new response
  final String? taxAmount; // Changed from int to String to match new response
  final String? currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final ProductAttachment?
      productAttachment; // Changed from List to single object

  ListCartModelDataCartItem({
    this.id,
    this.productId,
    this.productName,
    this.productAttachment,
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
        productAttachment:
            json["product_attachment"] == null // Updated to match new response
                ? null
                : ProductAttachment.fromJson(json["product_attachment"]),
        categoryId: json["category_id"],
        quantity: json["quantity"],
        productUnit: json["product_unit"],
        unitPrice: (json["unit_price"]),
        totalPrice: json["total_price"],
        taxRate: json["tax_rate"], // Now a String
        taxAmount: json["tax_amount"], // Now a String
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
        "product_attachment": productAttachment?.toJson(),
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

class ProductAttachment {
  final int? id;
  final int? productId;
  final String? title;
  final int? isPrimary;
  final String? fileType;
  final String? filePath;
  final String? status;
  final String? alt;
  final String? description;

  ProductAttachment({
    this.id,
    this.productId,
    this.title,
    this.isPrimary,
    this.fileType,
    this.filePath,
    this.status,
    this.alt,
    this.description,
  });

  factory ProductAttachment.fromJson(Map<String, dynamic> json) =>
      ProductAttachment(
        id: json["id"],
        productId: json["product_id"],
        title: json["title"],
        isPrimary: json["is_primary"],
        fileType: json["file_type"],
        filePath: json["file_path"],
        status: json["status"],
        alt: json["alt"],
        description: json["description"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "product_id": productId,
        "title": title,
        "is_primary": isPrimary,
        "file_type": fileType,
        "file_path": filePath,
        "status": status,
        "alt": alt,
        "description": description,
      };
}

// class PriceSummary {
//   final double? subTotal; // Changed to double to match new response
//   final double? totalTax; // Changed to double
//   final double? netTotal; // Changed to double
//   final int? discount; // Remains an integer
//   final double? netPayable; // Changed to double

//   PriceSummary({
//     this.subTotal,
//     this.totalTax,
//     this.netTotal,
//     this.discount,
//     this.netPayable,
//   });

//   factory PriceSummary.fromJson(Map<String, dynamic> json) => PriceSummary(
//         subTotal: (json["sub_total"] as num?)?.toDouble(),
//         totalTax: (json["total_tax"] as num?)?.toDouble(),
//         netTotal: (json["net_total"] as num?)?.toDouble(),
//         discount: json["discount"],
//         netPayable: (json["net_payable"] as num?)?.toDouble(),
//       );

//   Map<String, dynamic> toJson() => {
//         "sub_total": subTotal,
//         "total_tax": totalTax,
//         "net_total": netTotal,
//         "discount": discount,
//         "net_payable": netPayable,
//       };
// }
