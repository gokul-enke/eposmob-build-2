import 'dart:convert';

import '../sales_payment_codes.dart';
import 'sales_order_cart.dart';

class ListOrderModelData {
  final int? id;
  final int? cartId;
  final DateTime? orderDate;
  final String? orderNumber;
  final String? clientSaleId;
  final String? receiptNumber;
  final String? issuedAt;
  final String? grantTotal;
  final String? paymentStatus;
  final List<String> paymentMethods;
  final String? status;
  final CustomerDetails? customerDetails;
  final PriceSummary? priceSummary;
  final List<OrderProp>? orderProps;
  final List<CartItem>? cartItems;
  final String? customerName;
  final String? invoiceHash;
  final bool? isOnline;

  ListOrderModelData({
    this.id,
    this.cartId,
    this.orderDate,
    this.orderNumber,
    this.clientSaleId,
    this.receiptNumber,
    this.issuedAt,
    this.grantTotal,
    this.paymentStatus,
    this.paymentMethods = const [],
    this.status,
    this.customerDetails,
    this.priceSummary,
    this.orderProps,
    this.cartItems,
    this.customerName,
    this.invoiceHash,
    this.isOnline,
  });

  factory ListOrderModelData.fromJson(Map<String, dynamic> json) {
    try {
      if (json["cart_items"] != null) {
        if (json["cart_items"] is Map &&
            json["cart_items"]["cart_items"] != null) {}
      }

      return ListOrderModelData(
        id: _asInt(json["id"]),
        cartId: _asInt(json["cart_id"]),
        orderDate: json["order_date"] is String
            ? DateTime.tryParse(json["order_date"])
            : null,
        orderNumber: _asString(json["order_number"]),
        clientSaleId: json["client_sale_id"]?.toString(),
        receiptNumber: json["receipt_number"]?.toString(),
        issuedAt: json["issued_at"]?.toString(),
        grantTotal: _asString(json["grand_total"]),
        paymentStatus: _asString(json["payment_status"]),
        paymentMethods: _asStringList(json["payment_method"]),
        status: _asString(json["status"]),
        customerName: _asString(json["customer_name"]),
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
        invoiceHash: _asString(json["invoice_hash"]),
        isOnline: json["is_online"] == true ||
            json["is_online"] == 1 ||
            json["is_online"] == "1",
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Accepts int, num or numeric String ids without throwing on type variance.
  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  /// These fields arrive as strings today, but a numeric value used to make the
  /// implicit cast throw and take the whole order list down with it.
  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static List<String> _asStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .where((item) => item != null)
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return const [];
      if (trimmed.startsWith('[')) {
        try {
          return _asStringList(jsonDecode(trimmed));
        } catch (_) {
          // Fall back to treating malformed JSON as a single method value.
        }
      }
      return [trimmed];
    }
    return [value.toString()];
  }

  bool get isUnpaidCod {
    // Only a purely COD order can skip refund details. If COD appears alongside
    // another method, that paid portion may still need to be refunded.
    final isCodOnly = paymentMethods.length == 1 &&
        _isCodPaymentMethod(paymentMethods.single);
    final normalizedStatus = paymentStatus?.trim().toLowerCase();
    return isCodOnly &&
        (normalizedStatus == 'pending' || normalizedStatus == 'unpaid');
  }

  static bool _isCodPaymentMethod(String method) {
    final resolvedCode = SalesPaymentCodes.resolve(method);
    final candidate = resolvedCode ?? method;
    final normalized =
        candidate.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    return normalized == 'COD' || normalized == 'CASHONDELIVERY';
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "cart_id": cartId,
        "order_date": orderDate?.toIso8601String(),
        "order_number": orderNumber,
        "client_sale_id": clientSaleId,
        "receipt_number": receiptNumber,
        "issued_at": issuedAt,
        "grant_total": grantTotal,
        "payment_status": paymentStatus,
        "payment_method": paymentMethods,
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
        "invoice_hash": invoiceHash,
        "is_online": isOnline,
      };

  String? get customerReceiptNumber {
    final receipt = receiptNumber?.trim();
    if (receipt != null && receipt.isNotEmpty) return receipt;
    final server = orderNumber?.trim();
    return server == null || server.isEmpty ? null : server;
  }
}
