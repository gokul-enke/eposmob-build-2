import 'dart:convert';

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
    } catch (e) {
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
      return PriceSummary(
        grandTotal: json["grand_total"]?.toString(),
        taxTotal: json["tax_total"]?.toString(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
        "grand_total": grandTotal,
        "tax_total": taxTotal,
      };
}
