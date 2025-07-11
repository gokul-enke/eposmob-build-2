import 'dart:convert';

CustomerListModel customerListModelFromJson(String str) =>
    CustomerListModel.fromJson(json.decode(str));

String customerListModelToJson(CustomerListModel data) =>
    json.encode(data.toJson());

class CustomerListModel {
  final String? status;
  final String? message;
  final List<CustomerListModelData>? data;

  CustomerListModel({
    this.status,
    this.message,
    this.data,
  });

  factory CustomerListModel.fromJson(Map<String, dynamic> json) =>
      CustomerListModel(
        status: json["status"],
        message: json["message"],
        data: json["data"] == null
            ? []
            : List<CustomerListModelData>.from(
                json["data"].map((x) => CustomerListModelData.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": data == null
            ? []
            : List<dynamic>.from(data!.map((x) => x.toJson())),
      };
}

class CustomerListModelData {
  final int? id;
  final String? name;
  final String? email;
  final String? phone;
  final String? altPhone;
  final String? gender;
  final String? dob;
  final dynamic profileImage;
  final int? storeId;
  final int? userId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  // Loyalty card fields
  final String? cardNumber;
  final int? loyaltyPoints;
  final String? validFrom;
  final String? validUntil;
  final String? cardStatus;
  final String? membershipName;
  final String? membershipCode;
  final int? minRedeemablePoints;
  final double? pricePerPoint;

  // Financial fields
  final double? balance;

  // Related data
  final List<CustomerTransaction>? transactions;
  final List<CustomerOrder>? orders;

  CustomerListModelData({
    this.id,
    this.name,
    this.email,
    this.phone,
    this.altPhone,
    this.gender,
    this.dob,
    this.profileImage,
    this.storeId,
    this.userId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.cardNumber,
    this.loyaltyPoints,
    this.validFrom,
    this.validUntil,
    this.cardStatus,
    this.membershipName,
    this.membershipCode,
    this.minRedeemablePoints,
    this.pricePerPoint,
    this.balance,
    this.transactions,
    this.orders,
  });

  factory CustomerListModelData.fromJson(Map<String, dynamic> json) =>
      CustomerListModelData(
        id: json["id"],
        name: json["name"] ?? "No Name",
        email: json["email"],
        phone: json["phone"],
        altPhone: json["alt_phone"],
        gender: json["gender"],
        dob: json["dob"],
        profileImage: json["profile_image"],
        storeId: json["store_id"],
        userId: json["user_id"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
        deletedAt: json["deleted_at"] == null
            ? null
            : DateTime.parse(json["deleted_at"]),
        cardNumber: json["card_number"]?.toString(),
        loyaltyPoints: json["loyalty_points"],
        validFrom: json["valid_from"]?.toString(),
        validUntil: json["valid_until"]?.toString(),
        cardStatus: json["card_status"]?.toString(),
        membershipName: json["membership_name"]?.toString(),
        membershipCode: json["membership_code"]?.toString(),
        minRedeemablePoints: json["min_redeemable_points"],
        pricePerPoint: json["price_per_point"]?.toDouble(),
        balance: json["balance"]?.toDouble(),
        transactions: json["transactions"] == null
            ? []
            : List<CustomerTransaction>.from(json["transactions"]
                .map((x) => CustomerTransaction.fromJson(x))),
        orders: json["orders"] == null
            ? []
            : List<CustomerOrder>.from(
                json["orders"].map((x) => CustomerOrder.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "email": email,
        "phone": phone,
        "alt_phone": altPhone,
        "gender": gender,
        "dob": dob,
        "profile_image": profileImage,
        "store_id": storeId,
        "user_id": userId,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "deleted_at": deletedAt?.toIso8601String(),
        "card_number": cardNumber,
        "loyalty_points": loyaltyPoints,
        "valid_from": validFrom,
        "valid_until": validUntil,
        "card_status": cardStatus,
        "membership_name": membershipName,
        "membership_code": membershipCode,
        "min_redeemable_points": minRedeemablePoints,
        "price_per_point": pricePerPoint,
        "balance": balance,
        "transactions": transactions == null
            ? []
            : List<dynamic>.from(transactions!.map((x) => x.toJson())),
        "orders": orders == null
            ? []
            : List<dynamic>.from(orders!.map((x) => x.toJson())),
      };
}

class CustomerTransaction {
  final int? id;
  final int? orderId;
  final String? paymentMethod;
  final String? date;
  final String? type;
  final String? referenceId;
  final String? transactionType;
  final String? amount;
  final String? currency;
  final String? reference;
  final String? transactionComment;
  final String? status;

  CustomerTransaction({
    this.id,
    this.orderId,
    this.paymentMethod,
    this.date,
    this.type,
    this.referenceId,
    this.transactionType,
    this.amount,
    this.currency,
    this.reference,
    this.transactionComment,
    this.status,
  });

  factory CustomerTransaction.fromJson(Map<String, dynamic> json) =>
      CustomerTransaction(
        id: json["id"],
        orderId: json["order_id"],
        paymentMethod: json["payment_method"],
        date: json["date"],
        type: json["type"],
        referenceId: json["reference_id"],
        transactionType: json["transaction_type"],
        amount: json["amount"],
        currency: json["currency"],
        reference: json["reference"],
        transactionComment: json["transaction_comment"],
        status: json["status"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "order_id": orderId,
        "payment_method": paymentMethod,
        "date": date,
        "type": type,
        "reference_id": referenceId,
        "transaction_type": transactionType,
        "amount": amount,
        "currency": currency,
        "reference": reference,
        "transaction_comment": transactionComment,
        "status": status,
      };
}

class CustomerOrder {
  final int? id;
  final String? orderNumber;
  final int? cartId;
  final dynamic paymentMethod; // Can be String or List<String>
  final String? paymentStatus;
  final String? orderDate;
  final String? status;
  final String? subTotal;
  final String? discount;
  final String? grandTotal;
  final String? sourceType;
  final int? deliveryMethodId;
  final String? tax;
  final List<OrderItem>? items;
  // final DeliveryMethod? deliveryMethod;

  CustomerOrder({
    this.id,
    this.orderNumber,
    this.cartId,
    this.paymentMethod,
    this.paymentStatus,
    this.orderDate,
    this.status,
    this.subTotal,
    this.discount,
    this.grandTotal,
    this.sourceType,
    this.deliveryMethodId,
    this.tax,
    this.items,
    // this.deliveryMethod,
  });

  factory CustomerOrder.fromJson(Map<String, dynamic> json) => CustomerOrder(
        id: json["id"],
        orderNumber: json["order_number"],
        cartId: json["cart_id"],
        paymentMethod: json["payment_method"],
        paymentStatus: json["payment_status"],
        orderDate: json["order_date"],
        status: json["status"],
        subTotal: json["sub_total"],
        discount: json["discount"],
        grandTotal: json["grand_total"],
        sourceType: json["source_type"],
        deliveryMethodId: json["delivery_method_id"],
        tax: json["tax"],
        items: json["items"] == null
            ? []
            : List<OrderItem>.from(
                json["items"].map((x) => OrderItem.fromJson(x))),
        // deliveryMethod: json["delivery_method"] == null
        //     ? null
        //     : DeliveryMethod.fromJson(json["delivery_method"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "order_number": orderNumber,
        "cart_id": cartId,
        "payment_method": paymentMethod,
        "payment_status": paymentStatus,
        "order_date": orderDate,
        "status": status,
        "sub_total": subTotal,
        "discount": discount,
        "grand_total": grandTotal,
        "source_type": sourceType,
        "delivery_method_id": deliveryMethodId,
        "tax": tax,
        "items": items == null
            ? []
            : List<dynamic>.from(items!.map((x) => x.toJson())),
        // "delivery_method": deliveryMethod?.toJson(),
      };
}

class OrderItem {
  final int? id;
  final int? cartId;
  final int? categoryId;
  final int? productId;
  final int? productStockId;
  final String? quantity;
  final dynamic mrp; // Can be int or null
  final dynamic unitPrice; // Can be int or double
  final dynamic totalPrice; // Can be int or double
  final dynamic taxRate; // Can be int or double
  final dynamic taxAmount; // Can be int or double
  final DateTime? deletedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? laravelThroughKey;

  OrderItem({
    this.id,
    this.cartId,
    this.categoryId,
    this.productId,
    this.productStockId,
    this.quantity,
    this.mrp,
    this.unitPrice,
    this.totalPrice,
    this.taxRate,
    this.taxAmount,
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
    this.laravelThroughKey,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: json["id"],
        cartId: json["cart_id"],
        categoryId: json["category_id"],
        productId: json["product_id"],
        productStockId: json["product_stock_id"],
        quantity: json["quantity"],
        mrp: json["mrp"],
        unitPrice: json["unit_price"],
        totalPrice: json["total_price"],
        taxRate: json["tax_rate"],
        taxAmount: json["tax_amount"],
        deletedAt: json["deleted_at"] == null
            ? null
            : DateTime.parse(json["deleted_at"]),
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
        laravelThroughKey: json["laravel_through_key"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "cart_id": cartId,
        "category_id": categoryId,
        "product_id": productId,
        "product_stock_id": productStockId,
        "quantity": quantity,
        "mrp": mrp,
        "unit_price": unitPrice,
        "total_price": totalPrice,
        "tax_rate": taxRate,
        "tax_amount": taxAmount,
        "deleted_at": deletedAt?.toIso8601String(),
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "laravel_through_key": laravelThroughKey,
      };
}

// class DeliveryMethod {
//   final int? id;
//   final String? name;
//   final String? status;
//   final DateTime? createdAt;
//   final DateTime? updatedAt;

//   DeliveryMethod({
//     this.id,
//     this.name,
//     this.status,
//     this.createdAt,
//     this.updatedAt,
//   });

//   factory DeliveryMethod.fromJson(Map<String, dynamic> json) => DeliveryMethod(
//         id: json["id"],
//         name: json["name"],
//         status: json["status"],
//         createdAt: json["created_at"] == null
//             ? null
//             : DateTime.parse(json["created_at"]),
//         updatedAt: json["updated_at"] == null
//             ? null
//             : DateTime.parse(json["updated_at"]),
//       );

//   Map<String, dynamic> toJson() => {
//         "id": id,
//         "name": name,
//         "status": status,
//         "created_at": createdAt?.toIso8601String(),
//         "updated_at": updatedAt?.toIso8601String(),
//       };
// }
