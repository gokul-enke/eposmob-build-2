import 'dart:convert';
import 'package:flutter/foundation.dart';

class ListSalesOrderModel {
  final String? status;
  final String? message;
  final List<ListOrderModelData>? data;
  final PaginationInfo? pagination;

  ListSalesOrderModel({
    this.status,
    this.message,
    this.data,
    this.pagination,
  });

  factory ListSalesOrderModel.fromJson(Map<String, dynamic> json) {
    debugPrint('=== ListSalesOrderModel.fromJson DEBUG ===');
    debugPrint('Input JSON keys: ${json.keys.toList()}');
    debugPrint('Status: ${json["status"]}');
    debugPrint('Message: ${json["message"]}');
    debugPrint('Data type: ${json["data"]?.runtimeType}');

    if (json["data"] != null) {
      debugPrint(
          'Data keys: ${json["data"] is Map ? json["data"].keys.toList() : "Not a Map"}');
      if (json["data"] is Map && json["data"]["data"] != null) {
        debugPrint('Orders data type: ${json["data"]["data"].runtimeType}');
        debugPrint(
            'Orders length: ${json["data"]["data"] is List ? json["data"]["data"].length : "Not a List"}');
      }
    }

    try {
      return ListSalesOrderModel(
        status: json["status"],
        message: json["message"],
        data: json["data"]?["data"] == null
            ? []
            : List<ListOrderModelData>.from(json["data"]["data"]
                .map((x) => ListOrderModelData.fromJson(x))),
        pagination:
            json["data"] != null ? PaginationInfo.fromJson(json["data"]) : null,
      );
    } catch (e, stackTrace) {
      debugPrint('=== ListSalesOrderModel.fromJson ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": data == null
            ? []
            : List<dynamic>.from(data!.map((x) => x.toJson())),
        "pagination": pagination?.toJson(),
      };
}

class ListOrderModelData {
  final int? id;
  final int? cartId;
  final DateTime? orderDate;
  final String? orderNumber;
  final String? grantTotal;
  final String? paymentStatus;
  final String? status;
  final CustomerDetails? customerDetails;
  final PriceSummary? priceSummary;
  final List<OrderProp>? orderProps;
  final List<CartItem>? cartItems;
  final String? customerName;

  ListOrderModelData({
    this.id,
    this.cartId,
    this.orderDate,
    this.orderNumber,
    this.grantTotal,
    this.paymentStatus,
    this.status,
    this.customerDetails,
    this.priceSummary,
    this.orderProps,
    this.cartItems,
    this.customerName,
  });

  factory ListOrderModelData.fromJson(Map<String, dynamic> json) {
    try {
      debugPrint('=== ListOrderModelData.fromJson DEBUG ===');
      debugPrint('Order ID: ${json["id"]}');
      debugPrint('Order Number: ${json["order_number"]}');
      debugPrint(
          'Grant Total: ${json["grant_total"]} (${json["grant_total"]?.runtimeType})');
      debugPrint(
          'Order Date: ${json["order_date"]} (${json["order_date"]?.runtimeType})');
      debugPrint('Customer Name: ${json["customer_name"]}');
      debugPrint('Cart Items Type: ${json["cart_items"]?.runtimeType}');

      if (json["cart_items"] != null) {
        debugPrint(
            'Cart Items Keys: ${json["cart_items"] is Map ? json["cart_items"].keys.toList() : "Not a Map"}');
        if (json["cart_items"] is Map &&
            json["cart_items"]["cart_items"] != null) {
          debugPrint(
              'Cart Items Array Type: ${json["cart_items"]["cart_items"].runtimeType}');
          debugPrint(
              'Cart Items Length: ${json["cart_items"]["cart_items"] is List ? json["cart_items"]["cart_items"].length : "Not a List"}');
        }
      }

      return ListOrderModelData(
        id: json["id"],
        cartId: json["cart_id"],
        orderDate: json["order_date"] == null
            ? null
            : DateTime.tryParse(json["order_date"]),
        orderNumber: json["order_number"],
        grantTotal: json["grant_total"],
        paymentStatus: json["payment_status"],
        status: json["status"],
        customerName: json["customer_name"],
        customerDetails:
            json["orderProps"] != null ? CustomerDetails.fromJson(json) : null,
        priceSummary: json["cart_items"]?["price_summary"] != null
            ? PriceSummary.fromJson(json["cart_items"]["price_summary"])
            : null,
        orderProps: json["order_props"] == null
            ? []
            : List<OrderProp>.from(
                json["order_props"].map((x) => OrderProp.fromJson(x))),
        cartItems: json["cart_items"]?["cart_items"] == null
            ? []
            : List<CartItem>.from(json["cart_items"]["cart_items"]
                .map((x) => CartItem.fromJson(x))),
      );
    } catch (e, stackTrace) {
      debugPrint('=== ListOrderModelData.fromJson ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON input: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "cart_id": cartId,
        "order_date": orderDate?.toIso8601String(),
        "order_number": orderNumber,
        "grant_total": grantTotal,
        "payment_status": paymentStatus,
        "status": status,
        "customer_name": customerName,
        "orderProps": customerDetails?.toJson(),
        "cart_items": {
          "cart_items": cartItems == null
              ? []
              : List<dynamic>.from(cartItems!.map((x) => x.toJson())),
          "price_summary": priceSummary?.toJson(),
        },
        "order_props": orderProps == null
            ? []
            : List<dynamic>.from(orderProps!.map((x) => x.toJson())),
      };
}

class CartItem {
  final int? id;
  final int? cartId;
  final int? customerId;
  final int? storeId;
  final int? productId;
  final String? productName;
  final num? quantity;
  final String? totalPrice;

  CartItem({
    this.id,
    this.cartId,
    this.customerId,
    this.storeId,
    this.productId,
    this.productName,
    this.quantity,
    this.totalPrice,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    try {
      debugPrint('=== CartItem.fromJson DEBUG ===');
      debugPrint('Cart Item ID: ${json["id"]}');
      debugPrint('Product Name: ${json["product_name"]}');
      debugPrint(
          'Quantity: ${json["quantity"]} (${json["quantity"]?.runtimeType})');
      debugPrint(
          'Total Price: ${json["total_price"]} (${json["total_price"]?.runtimeType})');

      return CartItem(
        id: json["id"],
        cartId: json["cart_id"],
        customerId: json["customer_id"],
        storeId: json["store_id"],
        productId: json["product_id"],
        productName: json["product_name"],
        quantity: json["quantity"] is String
            ? num.tryParse(json["quantity"])
            : json["quantity"],
        totalPrice: json["total_price"].toString(),
      );
    } catch (e, stackTrace) {
      debugPrint('=== CartItem.fromJson ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON input: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "cart_id": cartId,
        "customer_id": customerId,
        "store_id": storeId,
        "product_id": productId,
        "product_name": productName,
        "quantity": quantity,
        "total_price": totalPrice,
      };
}

class CustomerDetails {
  final String? name;
  final String? email;
  final String? phone;

  CustomerDetails({
    this.name,
    this.email,
    this.phone,
  });

  factory CustomerDetails.fromJson(Map<String, dynamic> json) {
    String? email;
    String? phone;
    String? name = "NA";

    // Iterate over the order_props list to extract needed information
    if (json["order_props"] != null) {
      for (var prop in json["order_props"]) {
        if (prop["code"] == "CUSTOMER_EMAIL") {
          email = jsonDecode(prop["value"]); // Assuming it's a JSON string
        } else if (prop["code"] == "CUSTOMER_PHONE") {
          phone = jsonDecode(prop["value"]); // Assuming it's a JSON string
        } else if (prop["code"] == "DELIVERY_ADDRESS") {
          var address = jsonDecode(prop["value"]);
          if (address is Map<String, dynamic>) {
            name = address["name"] ?? "NA";
          }
        }
      }
    }

    return CustomerDetails(
      name: name,
      email: email,
      phone: phone,
    );
  }

  Map<String, dynamic> toJson() => {
        "name": name,
        "CUSTOMER_EMAIL": email,
        "CUSTOMER_PHONE": phone,
      };
}

class OrderProp {
  final String? propsId;
  final String? propsValue;

  OrderProp({
    this.propsId,
    this.propsValue,
  });

  factory OrderProp.fromJson(Map<String, dynamic> json) => OrderProp(
        propsId: json["code"],
        propsValue: json["value"],
      );

  Map<String, dynamic> toJson() => {
        "props_id": propsId,
        "props_value": propsValue,
      };
}

class PriceSummary {
  final String? grandTotal;
  final String? taxTotal;

  PriceSummary({this.grandTotal, this.taxTotal});

  factory PriceSummary.fromJson(Map<String, dynamic> json) {
    try {
      debugPrint('=== PriceSummary.fromJson DEBUG ===');
      debugPrint(
          'Grand Total: ${json["grand_total"]} (${json["grand_total"]?.runtimeType})');
      debugPrint(
          'Tax Total: ${json["tax_total"]} (${json["tax_total"]?.runtimeType})');

      return PriceSummary(
        grandTotal: json["grand_total"]?.toString(),
        taxTotal: json["tax_total"]?.toString(),
      );
    } catch (e, stackTrace) {
      debugPrint('=== PriceSummary.fromJson ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON input: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
        "grand_total": grandTotal,
        "tax_total": taxTotal,
      };
}

class PaginationInfo {
  final int? currentPage;
  final int? from;
  final int? to;
  final int? totalPages;
  final String? firstPageUrl;
  final String? nextPageUrl;
  final String? prevPageUrl;

  PaginationInfo({
    this.currentPage,
    this.from,
    this.to,
    this.totalPages,
    this.firstPageUrl,
    this.nextPageUrl,
    this.prevPageUrl,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    debugPrint('=== PaginationInfo.fromJson DEBUG ===');
    debugPrint('Input JSON keys: ${json.keys.toList()}');
    debugPrint(
        'Current Page: ${json["current_page"]} (${json["current_page"]?.runtimeType})');
    debugPrint(
        'Last Page: ${json["last_page"]} (${json["last_page"]?.runtimeType})');
    debugPrint('From: ${json["from"]}');
    debugPrint('To: ${json["to"]}');
    debugPrint('Next Page URL: ${json["next_page_url"]}');
    debugPrint('Prev Page URL: ${json["prev_page_url"]}');

    return PaginationInfo(
      currentPage: json["current_page"],
      from: json["from"],
      to: json["to"],
      totalPages: (json["last_page"] != null) ? json["last_page"] : null,
      firstPageUrl: json["first_page_url"],
      nextPageUrl: json["next_page_url"],
      prevPageUrl: json["prev_page_url"],
    );
  }

  Map<String, dynamic> toJson() => {
        "current_page": currentPage,
        "from": from,
        "to": to,
        "total_pages": totalPages,
        "first_page_url": firstPageUrl,
        "next_page_url": nextPageUrl,
        "prev_page_url": prevPageUrl,
      };
}
