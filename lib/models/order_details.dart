import 'dart:convert';
import 'package:pos_machine/models/get_product.dart';

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
  final String? deliveryDate;
  final String? deliveryTime;
  final num? deliveryCharge;
  final OrderDetailsModelDataCart? cart;
  final String? orderNumber;
  final String? tokenNumber;
  final String? orderStatus;
  final OrderDetailsModelDataCustomerDetails? customerDetails;
  final OrderDetailsModelDataKycInfo? kycInfo;
  final OrderDetailsModelDataPriceSummary? priceSummary;
  final String? paymentStatus;
  final String? deliveryStatus;
  final OrderDetailsModelDataPaymentDetails? paymentDetails;
  final List<OrderDetailsModelDataOrderProp>? orderProps;
  final String? deliveryMethodId;
  final String? deliveryMethodName;
  final String? deliveryPhone;
  final OrderReturns? orderReturns;
  final dynamic points;
  final Map<String, dynamic>? payments;
  final String? invoiceHash;

  OrderDetailsModelData({
    this.ordersId,
    this.storeId,
    this.storeName,
    this.orderDate,
    this.deliveryDate,
    this.deliveryTime,
    this.deliveryCharge,
    this.cart,
    this.orderNumber,
    this.tokenNumber,
    this.orderStatus,
    this.customerDetails,
    this.kycInfo,
    this.priceSummary,
    this.paymentStatus,
    this.deliveryStatus,
    this.paymentDetails,
    this.orderProps,
    this.deliveryMethodId,
    this.deliveryMethodName,
    this.deliveryPhone,
    this.orderReturns,
    this.points,
    this.payments,
    this.invoiceHash,
  });

  factory OrderDetailsModelData.fromJson(Map<String, dynamic> json) =>
      OrderDetailsModelData(
        ordersId: json["orders_id"],
        storeId: json["store_id"],
        // Use cart store name as fallback when order store name is not available
        storeName: json["store_name"] ??
            (json["cart"] != null ? (json["cart"] as Map)["store_name"] : null),
        orderDate: json["order_date"],
        deliveryDate: json["delivery_date"],
        deliveryTime: json["delivery_time"],
        deliveryCharge: OrderDetailsModelDataPriceSummary._parseNum(
            json["delivery_charge"]),
        cart: json["cart"] == null
            ? null
            : OrderDetailsModelDataCart.fromJson(json["cart"]),
        orderNumber: json["order_number"],
        tokenNumber: json["token_number"]?.toString(),
        orderStatus: json["order_status"],
        customerDetails: json["customer_details"] == null
            ? null
            : OrderDetailsModelDataCustomerDetails.fromJson(
                json["customer_details"]),
        kycInfo: json["kyc_info"] == null
            ? null
            : OrderDetailsModelDataKycInfo.fromJson(json["kyc_info"]),
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
        deliveryMethodId: json["delivery_method_id"]?.toString(),
        deliveryMethodName: json["delivery_method_name"]?.toString(),
        deliveryPhone: (json["delivery_phone"] ??
                json["shipping_phone"] ??
                json["delivery_contact_phone"])
            ?.toString(),
        orderReturns: _parseOrderReturns(json["order_returns"]),
        points: json["points"],
        payments: json["payments"] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json["payments"])
            : null,
        invoiceHash: json["invoice_hash"]?.toString(),
      );

  // Helper method to handle order_returns which can be null, empty List, or Map
  static OrderReturns? _parseOrderReturns(dynamic orderReturns) {
    if (orderReturns == null) return null;
    // If it's an empty list [], return null (no returns)
    if (orderReturns is List && orderReturns.isEmpty) return null;
    // If it's a Map, parse it
    if (orderReturns is Map<String, dynamic>) {
      return OrderReturns.fromJson(orderReturns);
    }
    return null;
  }

  // Helper to extract customer address from order_props
  String? getCustomerAddressFromProps() {
    if (orderProps == null) return null;
    try {
      // Prioritize CUSTOMER_ADDRESS
      final addressProp = orderProps!.firstWhere(
        (prop) => prop.propsCode == "CUSTOMER_ADDRESS",
        orElse: () => OrderDetailsModelDataOrderProp(),
      );
      if (addressProp.propsValue != null &&
          addressProp.propsValue!.isNotEmpty) {
        return _formatAddress(addressProp.propsValue!);
      }

      // Fallback to DELIVERY_ADDRESS if needed
      final deliveryAddressProp = orderProps!.firstWhere(
        (prop) => prop.propsCode == "DELIVERY_ADDRESS",
        orElse: () => OrderDetailsModelDataOrderProp(),
      );
      if (deliveryAddressProp.propsValue != null &&
          deliveryAddressProp.propsValue!.isNotEmpty) {
        return _formatAddress(deliveryAddressProp.propsValue!);
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// Returns the phone number attached to the delivery, when the API supplies
  /// it either as a first-class order field or as an order property.
  String? getDeliveryPhoneForDisplay() {
    final direct = deliveryPhone?.trim();
    if (direct != null && direct.isNotEmpty) return direct;

    const supportedCodes = {
      'DELIVERY_PHONE',
      'DELIVERY_CONTACT_PHONE',
      'SHIPPING_PHONE',
    };
    for (final prop in orderProps ?? const <OrderDetailsModelDataOrderProp>[]) {
      if (!supportedCodes.contains(prop.propsCode?.trim().toUpperCase())) {
        continue;
      }
      final value = prop.propsValue?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  /// Returns a concise printable customer address.
  /// Priority: `order_props` address -> `customer_details.address` first entry.
  String? getCustomerAddressForDisplay() {
    final fromProps = getCustomerAddressFromProps();
    if (fromProps != null && fromProps.trim().isNotEmpty) {
      return fromProps;
    }

    final addressList = customerDetails?.address;
    if (addressList == null || addressList.isEmpty) {
      return null;
    }

    final first = addressList.first;

    if (first is Map) {
      return _buildCustomerDetailsAddress(first);
    }

    final raw = first.toString();
    if (raw.trim().isEmpty) {
      return null;
    }

    if (raw.trim().startsWith('{') || raw.trim().startsWith('[')) {
      final parsed = _formatAddress(raw);
      return parsed.trim().isEmpty ? null : parsed;
    }

    return raw;
  }

  String? _buildCustomerDetailsAddress(Map<dynamic, dynamic> map) {
    final parts = <String>[];

    void addPart(dynamic value) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty && !parts.contains(text)) {
        parts.add(text);
      }
    }

    addPart(map['address']);
    addPart(map['landmark']);
    addPart(map['city']);

    if (map['state'] != null) {
      if (map['state'] is Map && map['state']['name'] != null) {
        addPart(map['state']['name']);
      } else {
        addPart(map['state']);
      }
    }

    if (map['pincode'] != null) {
      if (map['pincode'] is Map && map['pincode']['pin_code'] != null) {
        addPart(map['pincode']['pin_code']);
      } else {
        addPart(map['pincode']);
      }
    }

    return parts.isEmpty ? null : parts.join(', ');
  }

  // Helper to format address string from JSON string or raw string
  String _formatAddress(String rawAddress) {
    try {
      // Check if it looks like a JSON object (starts with {)
      if (rawAddress.trim().startsWith('{')) {
        // It might be a raw string representation of a Map like "{city: thalassery, ...}"
        // which is not valid JSON. We need to parse it carefully or use regex.

        // If it's valid JSON, decode it
        try {
          final Map<String, dynamic> addressMap = json.decode(rawAddress);
          return _buildAddressString(addressMap);
        } catch (e) {
          // Not valid JSON, try to parse the raw string representation
          // Example: {city: thalassery, name: Athira, ...}

          String address = "";
          String city = "";
          String state = "";
          String pincode = "";

          // Extract address
          final addressMatch =
              RegExp(r'address:\s*([^,]+)').firstMatch(rawAddress);
          if (addressMatch != null)
            address = addressMatch.group(1)?.trim() ?? "";

          // Extract city
          final cityMatch = RegExp(r'city:\s*([^,]+)').firstMatch(rawAddress);
          if (cityMatch != null) city = cityMatch.group(1)?.trim() ?? "";

          // Extract state (might be nested or simple)
          final stateMatch = RegExp(r'state:\s*([^,]+)').firstMatch(rawAddress);
          if (stateMatch != null) {
            // If state is an object {id: 10, name: KERALA...}
            if (stateMatch.group(1)?.trim().startsWith('{') ?? false) {
              final stateNameMatch =
                  RegExp(r'name:\s*([^,]+)').firstMatch(stateMatch.group(1)!);
              if (stateNameMatch != null)
                state = stateNameMatch.group(1)?.trim() ?? "";
            } else {
              state = stateMatch.group(1)?.trim() ?? "";
            }
          }

          // Extract pincode
          final pincodeMatch =
              RegExp(r'pincode:\s*([^,]+)').firstMatch(rawAddress);
          if (pincodeMatch != null) {
            // If pincode is an object {id: 3382, pin_code: 670101...}
            if (pincodeMatch.group(1)?.trim().startsWith('{') ?? false) {
              final pinCodeValMatch = RegExp(r'pin_code:\s*([^,]+)')
                  .firstMatch(pincodeMatch.group(1)!);
              if (pinCodeValMatch != null)
                pincode = pinCodeValMatch.group(1)?.trim() ?? "";
            } else {
              pincode = pincodeMatch.group(1)?.trim() ?? "";
            }
          }

          List<String> parts = [];
          if (address.isNotEmpty) parts.add(address);
          if (city.isNotEmpty) parts.add(city);
          if (state.isNotEmpty) parts.add(state);
          if (pincode.isNotEmpty) parts.add(pincode);

          if (parts.isNotEmpty) return parts.join(', ');
        }
      }

      // If it's a list string "[{...}]"
      if (rawAddress.trim().startsWith('[')) {
        try {
          final List<dynamic> list = json.decode(rawAddress);
          if (list.isNotEmpty && list[0] is Map) {
            return _buildAddressString(list[0]);
          }
        } catch (e) {
          // Regex fallback for list string
          final addressMatch =
              RegExp(r'address:\s*([^,]+)').firstMatch(rawAddress);
          if (addressMatch != null)
            return addressMatch.group(1)?.trim() ?? rawAddress;
        }
      }

      return rawAddress;
    } catch (e) {
      return rawAddress;
    }
  }

  String _buildAddressString(Map<dynamic, dynamic> map) {
    List<String> parts = [];

    if (map['address'] != null) parts.add(map['address'].toString());
    if (map['city'] != null) parts.add(map['city'].toString());

    if (map['state'] != null) {
      if (map['state'] is Map) {
        if (map['state']['name'] != null)
          parts.add(map['state']['name'].toString());
      } else {
        parts.add(map['state'].toString());
      }
    }

    if (map['pincode'] != null) {
      if (map['pincode'] is Map) {
        if (map['pincode']['pin_code'] != null)
          parts.add(map['pincode']['pin_code'].toString());
      } else {
        parts.add(map['pincode'].toString());
      }
    }

    return parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
        "orders_id": ordersId,
        "store_id": storeId,
        "store_name": storeName,
        "order_date": orderDate,
        "delivery_date": deliveryDate,
        "delivery_time": deliveryTime,
        "delivery_charge": deliveryCharge,
        "cart": cart?.toJson(),
        "order_number": orderNumber,
        "token_number": tokenNumber,
        "order_status": orderStatus,
        "customer_details": customerDetails?.toJson(),
        "kyc_info": kycInfo?.toJson(),
        "order_price_summary": priceSummary?.toJson(),
        "payment_status": paymentStatus,
        "delivery_status": deliveryStatus,
        "payment_details": paymentDetails?.toJson(),
        "order_props": orderProps == null
            ? []
            : List<dynamic>.from(orderProps!.map((x) => x.toJson())),
        "delivery_method_id": deliveryMethodId,
        "delivery_method_name": deliveryMethodName,
        "delivery_phone": deliveryPhone,
        "order_returns": orderReturns?.toJson(),
        "points": points,
        "payments": payments,
        "invoice_hash": invoiceHash,
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
  final String? mrp;
  final String? totalPrice; // Changed to int
  final String? currency;
  final String? taxAmount; // Added tax_amount field
  final int? saleUnitId;
  final int? productSaleUnitId;
  final String? saleUnitName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Names? names; // Add bilingual names support
  final int? productVariantId; // Variant chosen for this order line (nullable)
  final Map<String, dynamic>?
      variantAttributes; // Snapshot map e.g. {"COLOR":"Red","SIZE":"L"}
  final bool warrantyEnabled;

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
    this.mrp,
    this.totalPrice,
    this.currency,
    this.taxAmount, // Added tax_amount field
    this.saleUnitId,
    this.productSaleUnitId,
    this.saleUnitName,
    this.createdAt,
    this.updatedAt,
    this.names, // Add to constructor
    this.productVariantId,
    this.variantAttributes,
    this.warrantyEnabled = false,
  });

  /// Formatted variant attribute line (values joined with " | "), matching
  /// ProductVariant.formattedAttributes style. Empty when there are no
  /// attributes to display.
  String get formattedVariantAttributes {
    final attrs = variantAttributes;
    if (attrs == null || attrs.isEmpty) return '';
    return attrs.values
        .map((value) => value?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .join(' | ');
  }

  String get displayName {
    final base = productName ?? '';
    final attrs = formattedVariantAttributes;
    return attrs.isEmpty ? base : '$base ($attrs)';
  }

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
        unitPrice: json["unit_price"].toString(),
        mrp: json["mrp"].toString(),
        totalPrice: json["total_price"].toString(),
        currency: json["currency"],
        taxAmount: json["tax_amount"]?.toString(), // Added tax_amount parsing
        saleUnitId: _parseNullableInt(json["sale_unit_id"]),
        productSaleUnitId: _parseNullableInt(json["product_sale_unit_id"]),
        saleUnitName: (json["sale_unit_name"] ??
                json["product_sale_unit_name"] ??
                json["product_sale_unit"]?["unit_name"] ??
                json["sale_unit"]?["unit_name"])
            ?.toString(),
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
        names: json["product_names"] ==
                null // Fix: Parse from "product_names" key (API returns this)
            ? null
            : json["product_names"] is List &&
                    (json["product_names"] as List).isEmpty
                ? null // Handle empty array case
                : Names.fromJson(json["product_names"]),
        productVariantId: _parseNullableInt(json["product_variant_id"]),
        variantAttributes: _parseVariantAttributes(json["variant_attributes"]),
        warrantyEnabled: _parseBool(
          json["warranty_enabled"] ?? json["warrantyEnabled"],
        ),
      );

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }

  // variant_attributes may arrive as a Map or as a JSON-encoded String; parse
  // defensively and return null when empty/unparseable.
  static Map<String, dynamic>? _parseVariantAttributes(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      if (raw.isEmpty) return null;
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      try {
        final decoded = json.decode(trimmed);
        if (decoded is Map && decoded.isNotEmpty) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Not valid JSON; ignore and fall through.
      }
    }
    return null;
  }

  OrderDetailsModelDataCartItem copyWith({
    num? quantity,
    String? totalPrice,
    String? taxAmount,
  }) =>
      OrderDetailsModelDataCartItem(
        id: id,
        productId: productId,
        productName: productName,
        productAttachment: productAttachment,
        categoryId: categoryId,
        categoryName: categoryName,
        quantity: quantity ?? this.quantity,
        productUnit: productUnit,
        unitPrice: unitPrice,
        mrp: mrp,
        totalPrice: totalPrice ?? this.totalPrice,
        currency: currency,
        taxAmount: taxAmount ?? this.taxAmount,
        saleUnitId: saleUnitId,
        productSaleUnitId: productSaleUnitId,
        saleUnitName: saleUnitName,
        createdAt: createdAt,
        updatedAt: updatedAt,
        names: names,
        productVariantId: productVariantId,
        variantAttributes: variantAttributes,
        warrantyEnabled: warrantyEnabled,
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
        "mrp": mrp,
        "total_price": totalPrice,
        "currency": currency,
        "tax_amount": taxAmount, // Added tax_amount serialization
        "sale_unit_id": saleUnitId,
        "product_sale_unit_id": productSaleUnitId,
        "sale_unit_name": saleUnitName,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "names": names?.toJson(), // Add names to serialization
        "product_variant_id": productVariantId,
        "variant_attributes": variantAttributes,
        "warranty_enabled": warrantyEnabled,
      };

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
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
  final num? savedTotal;
  final num? discount;
  final num? netPayable;
  final num? totalMrp;
  final num? netExcTax;

  OrderDetailsModelDataPriceSummary({
    this.subTotal,
    this.totalTax,
    this.netTotal,
    this.savedTotal,
    this.discount,
    this.netPayable,
    this.totalMrp,
    this.netExcTax,
  });

  factory OrderDetailsModelDataPriceSummary.fromJson(
          Map<String, dynamic> json) =>
      OrderDetailsModelDataPriceSummary(
        // Handle both num and String types for all numeric fields
        subTotal: _parseNum(json["sub_total"]),
        totalTax: _parseNum(json["total_tax"]),
        netTotal: _parseNum(json["net_total"]),
        savedTotal: _parseNum(json["total_saved"]),
        discount: _parseNum(json["discount"]),
        netPayable: _parseNum(json["net_payable"]),
        totalMrp: _parseNum(json["total_mrp"]),
        netExcTax: _parseNum(json["net_exc_tax"]),
      );

  // Helper method to parse num from either num or String
  static num? _parseNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() => {
        "sub_total": subTotal,
        "total_tax": totalTax,
        "net_total": netTotal,
        "total_saved": savedTotal,
        "discount": discount,
        "net_payable": netPayable,
        "total_mrp": totalMrp,
        "net_exc_tax": netExcTax,
      };
}

class OrderDetailsModelDataCustomerDetails {
  final String? name;
  final String? email;
  final String? phone;
  final int? customerId; // Keep as int? if it's an int in JSON
  final List<dynamic>? address; // Changed to List<dynamic>
  final String? customerType;

  final String? alternatePhone; // Added alternate_phone

  OrderDetailsModelDataCustomerDetails({
    this.name,
    this.email,
    this.phone,
    this.customerId,
    this.address,
    this.customerType,
    this.alternatePhone,
  });

  factory OrderDetailsModelDataCustomerDetails.fromJson(
          Map<String, dynamic> json) =>
      OrderDetailsModelDataCustomerDetails(
        name: json["name"],
        email: json["email"],
        phone: json["phone"],
        customerId: json["customer_id"], // Keep as int? if it's an int
        address:
            json["address"] == null ? [] : List<dynamic>.from(json["address"]),
        customerType: json["customer_type"]?.toString(),
        alternatePhone: json["alternate_phone"],
      );

  Map<String, dynamic> toJson() => {
        "name": name,
        "email": email,
        "phone": phone,
        "customer_id": customerId,
        "address": address,
        "customer_type": customerType,
        "alternate_phone": alternatePhone,
      };
}

class OrderDetailsModelDataKycInfo {
  final String? crNumber;
  final String? vatNumber;

  OrderDetailsModelDataKycInfo({
    this.crNumber,
    this.vatNumber,
  });

  factory OrderDetailsModelDataKycInfo.fromJson(Map<String, dynamic> json) =>
      OrderDetailsModelDataKycInfo(
        crNumber: json["cr_number"]?.toString(),
        vatNumber: json["vat_number"]?.toString(),
      );

  Map<String, dynamic> toJson() => {
        "cr_number": crNumber,
        "vat_number": vatNumber,
      };
}

class OrderDetailsModelDataOrderProp {
  final int? propsId;
  final String? propsCode;
  final String? propsValue; // Change this to String?

  OrderDetailsModelDataOrderProp({
    this.propsId,
    this.propsCode,
    this.propsValue,
  });

  factory OrderDetailsModelDataOrderProp.fromJson(Map<String, dynamic> json) =>
      OrderDetailsModelDataOrderProp(
        propsId: json["props_id"],
        propsCode: json["props_code"],
        propsValue:
            _parsePropsValue(json["props_value"]), // Handle different types
      );

  // Helper method to handle props_value which can be String, Map, or other types
  static String? _parsePropsValue(dynamic propsValue) {
    if (propsValue == null) return null;
    if (propsValue is String) return propsValue;
    if (propsValue is Map || propsValue is List) {
      // Convert complex objects to JSON string for storage
      return propsValue.toString();
    }
    return propsValue.toString();
  }

  Map<String, dynamic> toJson() => {
        "props_id": propsId,
        "props_code": propsCode,
        "props_value": propsValue,
      };
}

class OrderDetailsModelDataPaymentDetails {
  final String? paymentId; // Changed to String to handle List of IDs joined
  final String? paymentStatus; // String for payment_status
  final int? transactionId; // Nullable int for transaction_id
  final String? paymentMethod; // String for payment_method

  OrderDetailsModelDataPaymentDetails({
    this.paymentId,
    this.paymentStatus,
    this.transactionId,
    this.paymentMethod,
  });

  factory OrderDetailsModelDataPaymentDetails.fromJson(
          Map<String, dynamic> json) =>
      OrderDetailsModelDataPaymentDetails(
        paymentId:
            _parsePaymentId(json["payment_id"]), // Handle int, String, or List
        paymentStatus: json["payment_status"], // This is a String
        transactionId: json["transaction_id"] is int
            ? json["transaction_id"]
            : int.tryParse(json["transaction_id"]?.toString() ??
                ''), // Handle both int and String
        paymentMethod: _parsePaymentMethod(
            json["payment_method"]), // Handle both String and List
      );

  // Helper method to handle payment_id which can be int, String, or List
  static String? _parsePaymentId(dynamic paymentId) {
    if (paymentId == null) return null;
    if (paymentId is int) return paymentId.toString();
    if (paymentId is String) return paymentId;
    if (paymentId is List && paymentId.isNotEmpty) {
      // Join all payment IDs with commas for multiple payments
      return paymentId.map((id) => id.toString()).join(', ');
    }
    return null;
  }

  // Helper method to handle payment_method which can be String or List<String>
  static String? _parsePaymentMethod(dynamic paymentMethod) {
    if (paymentMethod == null) return null;
    if (paymentMethod is String) return paymentMethod;
    if (paymentMethod is List && paymentMethod.isNotEmpty) {
      // Join all payment methods with commas for multiple payment methods
      return paymentMethod.map((method) => method.toString()).join(', ');
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        "payment_id": paymentId,
        "payment_status": paymentStatus,
        "transaction_id": transactionId,
        "payment_method": paymentMethod,
      };
}

class OrderReturns {
  final int? id;
  final String? returnTotalAmount;
  final List<OrderReturnItem>? returnItems; // This can be an empty list

  OrderReturns({
    this.id,
    this.returnTotalAmount,
    this.returnItems,
  });

  factory OrderReturns.fromJson(Map<String, dynamic> json) {
    // Check if return_items is a List
    return OrderReturns(
      id: json["id"],
      returnTotalAmount: json["return_total_amount"],
      returnItems: json["return_items"] is List
          ? List<OrderReturnItem>.from(
              json["return_items"].map((x) => OrderReturnItem.fromJson(x)))
          : [], // Default to empty list if not a List
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "return_total_amount": returnTotalAmount,
        "return_items": returnItems == null
            ? []
            : List<dynamic>.from(returnItems!.map((x) => x.toJson())),
      };
}

class OrderReturnItem {
  final int? id;
  final String? productName;
  final num? quantity;
  final String? reason;
  final int? productVariantId;
  final Map<String, dynamic>? variantAttributes;

  OrderReturnItem({
    this.id,
    this.productName,
    this.quantity,
    this.reason,
    this.productVariantId,
    this.variantAttributes,
  });

  /// Formatted variant attribute line (values joined with " | "). Empty when
  /// there are no attributes to display.
  String get formattedVariantAttributes {
    final attrs = variantAttributes;
    if (attrs == null || attrs.isEmpty) return '';
    return attrs.values
        .map((value) => value?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .join(' | ');
  }

  String get displayName {
    final base = productName ?? '';
    final attrs = formattedVariantAttributes;
    return attrs.isEmpty ? base : '$base ($attrs)';
  }

  factory OrderReturnItem.fromJson(Map<String, dynamic> json) =>
      OrderReturnItem(
        id: json["id"],
        productName: json["product_name"],
        quantity: json["quantity"] is num
            ? json["quantity"]
            : num.tryParse(json["quantity"]?.toString() ?? ''),
        reason: json["reason"],
        productVariantId: OrderDetailsModelDataCartItem._parseNullableInt(
            json["product_variant_id"]),
        variantAttributes:
            OrderDetailsModelDataCartItem._parseVariantAttributes(
                json["variant_attributes"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "product_name": productName,
        "quantity": quantity,
        "reason": reason,
        "product_variant_id": productVariantId,
        "variant_attributes": variantAttributes,
      };
}
