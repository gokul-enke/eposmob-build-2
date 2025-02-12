import 'dart:convert';

OrderDetailsModel orderDetailsModelFromJson(String str) =>
    OrderDetailsModel.fromJson(json.decode(str));

String orderDetailsModelToJson(OrderDetailsModel data) =>
    json.encode(data.toJson());

class OrderDetailsModel {
  final String? status;
  final OrderDetailsModelData? data;

  OrderDetailsModel({
    this.status,
    this.data,
  });

  factory OrderDetailsModel.fromJson(Map<String, dynamic> json) =>
      OrderDetailsModel(
        status: json["status"],
        data: json["data"] == null
            ? null
            : OrderDetailsModelData.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "data": data?.toJson(),
      };
}

class OrderDetailsModelData {
  final int? ordersId;
  final int? storeId;
  final String? storeName;
  final String? orderDate;
  final OrderDetailsModelDataCart? cart;
  final String? orderNumber;
  final String? orderStatus;
  final OrderDetailsModelDataCustomerDetails? customerDetails;
  final OrderDetailsModelDataPriceSummary? priceSummary;
  final String? paymentStatus;
  final String? deliveryStatus;
  final OrderDetailsModelDataPaymentDetails? paymentDetails;
  final List<OrderDetailsModelDataOrderProp>? orderProps;

  OrderDetailsModelData({
    this.ordersId,
    this.storeId,
    this.storeName,
    this.orderDate,
    this.cart,
    this.orderNumber,
    this.orderStatus,
    this.customerDetails,
    this.priceSummary,
    this.paymentStatus,
    this.deliveryStatus,
    this.paymentDetails,
    this.orderProps,
  });

  factory OrderDetailsModelData.fromJson(Map<String, dynamic> json) =>
      OrderDetailsModelData(
        ordersId: json["orders_id"],
        storeId: json["store_id"],
        storeName: json["store_name"],
        orderDate: json["order_date"],
        cart: json["cart"] == null
            ? null
            : OrderDetailsModelDataCart.fromJson(json["cart"]),
        orderNumber: json["order_number"],
        orderStatus: json["order_status"],
        customerDetails: json["customer_details"] == null
            ? null
            : OrderDetailsModelDataCustomerDetails.fromJson(
                json["customer_details"]),
        priceSummary: json["order_price_summary"] == null
            ? null
            : OrderDetailsModelDataPriceSummary.fromJson(
                json["order_price_summary"]),
        paymentStatus: json["payment_status"],
        deliveryStatus: json["delivery_status"],
        paymentDetails: json["payment_details"] == null
            ? null
            : OrderDetailsModelDataPaymentDetails.fromJson(
                json["payment_details"]),
        orderProps: json["order_props"] == null
            ? []
            : List<OrderDetailsModelDataOrderProp>.from(json["order_props"]!
                .map((x) => OrderDetailsModelDataOrderProp.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "orders_id": ordersId,
        "store_id": storeId,
        "store_name": storeName,
        "order_date": orderDate,
        "cart": cart?.toJson(),
        "order_number": orderNumber,
        "order_status": orderStatus,
        "customer_details": customerDetails?.toJson(),
        "order_price_summary": priceSummary?.toJson(),
        "payment_status": paymentStatus,
        "delivery_status": deliveryStatus,
        "payment_details": paymentDetails?.toJson(),
        "order_props": orderProps == null
            ? []
            : List<dynamic>.from(orderProps!.map((x) => x.toJson())),
      };
}

class OrderDetailsModelDataCart {
  final int? id;
  final int? customerId;
  final int? userId;
  final int? itemCount;
  final int? storeId;
  final String? storeName;
  final List<OrderDetailsModelDataCartItem>? cartItems;
  final OrderDetailsModelDataPriceSummary? priceSummary;

  OrderDetailsModelDataCart({
    this.id,
    this.customerId,
    this.userId,
    this.itemCount,
    this.storeId,
    this.storeName,
    this.cartItems,
    this.priceSummary,
  });

  factory OrderDetailsModelDataCart.fromJson(Map<String, dynamic> json) =>
      OrderDetailsModelDataCart(
        id: json["id"],
        customerId: json["customer_id"],
        userId: json["user_id"],
        itemCount: json["item_count"],
        storeId: json["store_id"],
        storeName: json["store_name"],
        cartItems: json["cart_items"] == null
            ? []
            : List<OrderDetailsModelDataCartItem>.from(json["cart_items"]!
                .map((x) => OrderDetailsModelDataCartItem.fromJson(x))),
        priceSummary: json["price_summary"] == null
            ? null
            : OrderDetailsModelDataPriceSummary.fromJson(json["price_summary"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "customer_id": customerId,
        "user_id": userId,
        "item_count": itemCount,
        "store_id": storeId,
        "store_name": storeName,
        "cart_items": cartItems == null
            ? []
            : List<dynamic>.from(cartItems!.map((x) => x.toJson())),
        "price_summary": priceSummary?.toJson(),
      };
}

class OrderDetailsModelDataCartItem {
  final int? id;
  final int? productId;
  final String? productName;
  final List<OrderDetailsModelDataProductAttachment>?
      productAttachment; // Corrected spelling
  final int? categoryId;
  final String? categoryName; // Added category name
  final num? quantity;
  final String? productUnit;
  final String? unitPrice;
  final String? totalPrice; // Changed to int
  final String? currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OrderDetailsModelDataCartItem({
    this.id,
    this.productId,
    this.productName,
    this.productAttachment,
    this.categoryId,
    this.categoryName,
    this.quantity,
    this.productUnit,
    this.unitPrice,
    this.totalPrice,
    this.currency,
    this.createdAt,
    this.updatedAt,
  });

  factory OrderDetailsModelDataCartItem.fromJson(Map<String, dynamic> json) =>
      OrderDetailsModelDataCartItem(
        id: json["id"],
        productId: json["product_id"],
        productName: json["product_name"],
        productAttachment: json["product_attachment"] == null
            ? []
            : List<OrderDetailsModelDataProductAttachment>.from(
                json["product_attachment"]!.map(
                    (x) => OrderDetailsModelDataProductAttachment.fromJson(x))),
        categoryId: json["category_id"],
        categoryName: json["category_name"], // Added category name
        quantity: num.tryParse(json["quantity"]),
        productUnit: json["product_unit"],
        unitPrice: json["unit_price"],
        totalPrice: json["total_price"],
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
        "product_attachment": productAttachment == null
            ? []
            : List<dynamic>.from(productAttachment!.map((x) => x.toJson())),
        "category_id": categoryId,
        "category_name": categoryName, // Added category name
        "quantity": quantity,
        "product_unit": productUnit,
        "unit_price": unitPrice,
        "total_price": totalPrice,
        "currency": currency,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}

class OrderDetailsModelDataProductAttachment {
  final int? id;
  final int? productId;
  final int? userId;
  final String? title;
  final int? isPrimary;
  final String? fileType;
  final String? filePath;
  final String? status;
  final String? alt;
  final String? description;

  OrderDetailsModelDataProductAttachment({
    this.id,
    this.productId,
    this.userId,
    this.title,
    this.isPrimary,
    this.fileType,
    this.filePath,
    this.status,
    this.alt,
    this.description,
  });

  factory OrderDetailsModelDataProductAttachment.fromJson(
          Map<String, dynamic> json) =>
      OrderDetailsModelDataProductAttachment(
        id: json["id"],
        productId: json["product_id"],
        userId: json["user_id"],
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
        "user_id": userId,
        "title": title,
        "is_primary": isPrimary,
        "file_type": fileType,
        "file_path": filePath,
        "status": status,
        "alt": alt,
        "description": description,
      };
}

class OrderDetailsModelDataPriceSummary {
  final num? subTotal;
  final num? totalTax;
  final num? netTotal;
  final num? discount;
  final num? netPayable;

  OrderDetailsModelDataPriceSummary({
    this.subTotal,
    this.totalTax,
    this.netTotal,
    this.discount,
    this.netPayable,
  });

  factory OrderDetailsModelDataPriceSummary.fromJson(
          Map<String, dynamic> json) =>
      OrderDetailsModelDataPriceSummary(
        subTotal: json["sub_total"],
        totalTax: json["total_tax"],
        netTotal: json["net_total"],
        discount: json["discount"],
        netPayable: json["net_payable"],
      );

  Map<String, dynamic> toJson() => {
        "sub_total": subTotal,
        "total_tax": totalTax,
        "net_total": netTotal,
        "discount": discount,
        "net_payable": netPayable,
      };
}

class OrderDetailsModelDataCustomerDetails {
  final String? name;
  final String? email;
  final String? phone;
  final int? customerId;
  final String? address; // Added address

  OrderDetailsModelDataCustomerDetails({
    this.name,
    this.email,
    this.phone,
    this.customerId,
    this.address,
  });

  factory OrderDetailsModelDataCustomerDetails.fromJson(
          Map<String, dynamic> json) =>
      OrderDetailsModelDataCustomerDetails(
        name: json["name"],
        email: json["email"],
        phone: json["phone"],
        customerId: json["customer_id"],
        address: json["address"],
      );

  Map<String, dynamic> toJson() => {
        "name": name,
        "email": email,
        "phone": phone,
        "customer_id": customerId,
        "address": address,
      };
}

class OrderDetailsModelDataOrderProp {
  final int? propsId; // Changed to int
  final String? propsCode;
  final String? propsValue;

  OrderDetailsModelDataOrderProp({
    this.propsId,
    this.propsCode,
    this.propsValue,
  });

  factory OrderDetailsModelDataOrderProp.fromJson(Map<String, dynamic> json) =>
      OrderDetailsModelDataOrderProp(
        propsId: json["props_id"],
        propsCode: json["props_code"],
        propsValue: json["props_value"],
      );

  Map<String, dynamic> toJson() => {
        "props_id": propsId,
        "props_code": propsCode,
        "props_value": propsValue,
      };
}

class OrderDetailsModelDataPaymentDetails {
  final int? paymentId;
  final String? paymentStatus;
  final String? transactionId;
  final String? paymentMethod;

  OrderDetailsModelDataPaymentDetails({
    this.paymentId,
    this.paymentStatus,
    this.transactionId,
    this.paymentMethod,
  });

  factory OrderDetailsModelDataPaymentDetails.fromJson(
          Map<String, dynamic> json) =>
      OrderDetailsModelDataPaymentDetails(
        paymentId: json["payment_id"],
        paymentStatus: json["payment_status"],
        transactionId: json["transaction_id"],
        paymentMethod: json["payment_method"],
      );

  Map<String, dynamic> toJson() => {
        "payment_id": paymentId,
        "payment_status": paymentStatus,
        "transaction_id": transactionId,
        "payment_method": paymentMethod,
      };
}
