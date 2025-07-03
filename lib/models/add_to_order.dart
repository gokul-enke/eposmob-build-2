// To parse this JSON data, do
//
//     final addToOrderModel = addToOrderModelFromJson(jsonString);

import 'dart:convert';

AddToOrderModel addToOrderModelFromJson(String str) =>
    AddToOrderModel.fromJson(json.decode(str));

String addToOrderModelToJson(AddToOrderModel data) =>
    json.encode(data.toJson());

class AddToOrderModel {
  final String? status;
  final String? message;
  final Order? order;

  AddToOrderModel({
    this.status,
    this.order,
    this.message,
  });

  factory AddToOrderModel.fromJson(Map<String, dynamic> json) =>
      AddToOrderModel(
        status: json["status"],
        message: json["message"],
        order: json["data"] == null ? null : Order.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "data": order?.toJson(),
      };
}

class Order {
  final int? parentId;
  final int? customerId;
  final int? cartId;
  final int? storeId;
  final String? paymentId;
  final String? orderNumber;
  final int? price;
  final String? ip;
  final DateTime? orderDate;
  final String? status;
  final DateTime? updatedAt;
  final DateTime? createdAt;
  final int? orderId;

  Order({
    this.parentId,
    this.customerId,
    this.cartId,
    this.storeId,
    this.paymentId,
    this.orderNumber,
    this.price,
    this.ip,
    this.orderDate,
    this.status,
    this.updatedAt,
    this.createdAt,
    this.orderId,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        parentId: json["parent_id"],
        customerId: json["customer_id"],
        cartId: json["cart_id"],
        storeId: json["store_id"],
        paymentId: json["payment_id"],
        orderNumber: json["order_number"],
        price: json["price"],
        ip: json["ip"],
        orderDate: json["order_date"] == null
            ? null
            : DateTime.parse(json["order_date"]),
        status: json["status"],
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        orderId: json["order_id"],
      );

  Map<String, dynamic> toJson() => {
        "parent_id": parentId,
        "customer_id": customerId,
        "cart_id": cartId,
        "store_id": storeId,
        "payment_id": paymentId,
        "order_number": orderNumber,
        "price": price,
        "ip": ip,
        "order_date": orderDate?.toIso8601String(),
        "status": status,
        "updated_at": updatedAt?.toIso8601String(),
        "created_at": createdAt?.toIso8601String(),
        "order_id": orderId,
      };
}
