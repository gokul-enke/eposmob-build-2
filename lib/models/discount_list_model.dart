import 'package:flutter/material.dart';

class DiscountListModel {
  final String? status;
  final String? message;
  final DiscountListData? data;

  DiscountListModel({
    this.status,
    this.message,
    this.data,
  });

  factory DiscountListModel.fromJson(Map<String, dynamic> json) =>
      DiscountListModel(
        status: json["status"],
        message: json["message"],
        data: json["data"] == null
            ? null
            : DiscountListData.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": data?.toJson(),
      };
}

class DiscountListData {
  final List<DiscountData> data;

  DiscountListData({
    required this.data,
  });

  factory DiscountListData.fromJson(Map<String, dynamic> json) =>
      DiscountListData(
        data: json["data"] == null
            ? []
            : List<DiscountData>.from(
                json["data"].map((x) => DiscountData.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class DiscountData {
  final int id;
  final String couponCode;
  final int discountCategoryId;
  final String couponName;
  final int storeId;
  final int? categoryId;
  final int? productId;
  final String discountType;
  final String validFromDate;
  final String validToDate;
  final int discountCouponLimitCount;
  final double discountCouponLimitAmount;
  final double? discountCouponMinAmount;
  final double? discountCouponMaxAmount;
  final int discountValue;
  final int companyId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DiscountData({
    required this.id,
    required this.couponCode,
    required this.discountCategoryId,
    required this.couponName,
    required this.storeId,
    this.categoryId,
    this.productId,
    required this.discountType,
    required this.validFromDate,
    required this.validToDate,
    required this.discountCouponLimitCount,
    required this.discountCouponLimitAmount,
    this.discountCouponMinAmount,
    this.discountCouponMaxAmount,
    required this.discountValue,
    required this.companyId,
    this.createdAt,
    this.updatedAt,
  });

  factory DiscountData.fromJson(Map<String, dynamic> json) => DiscountData(
        id: json["id"],
        couponCode: json["coupon_code"],
        discountCategoryId: json["discount_category_id"],
        couponName: json["coupon_name"],
        storeId: json["store_id"],
        categoryId: json["category_id"],
        productId: json["product_id"],
        discountType: json["discount_type"],
        validFromDate: json["valid_from_date"],
        validToDate: json["valid_to_date"],
        discountCouponLimitCount: json["discount_coupon_limit_count"],
        discountCouponLimitAmount: json["discount_coupon_limit_amount"] != null
            ? double.tryParse(json["discount_coupon_limit_amount"].toString()) ?? 0.0
            : 0.0,
        discountCouponMinAmount: json["discount_coupon_min_amount"] != null
            ? double.tryParse(json["discount_coupon_min_amount"].toString())
            : null,
        discountCouponMaxAmount: json["discount_coupon_max_amount"] != null
            ? double.tryParse(json["discount_coupon_max_amount"].toString())
            : null,
        discountValue: json["discount_value"],
        companyId: json["company_id"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "coupon_code": couponCode,
        "discount_category_id": discountCategoryId,
        "coupon_name": couponName,
        "store_id": storeId,
        "category_id": categoryId,
        "product_id": productId,
        "discount_type": discountType,
        "valid_from_date": validFromDate,
        "valid_to_date": validToDate,
        "discount_coupon_limit_count": discountCouponLimitCount,
        "discount_coupon_limit_amount": discountCouponLimitAmount,
        "discount_coupon_min_amount": discountCouponMinAmount,
        "discount_coupon_max_amount": discountCouponMaxAmount,
        "discount_value": discountValue,
        "company_id": companyId,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };

  DateTime? _safeParseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      debugPrint('⚠️ Failed to parse date: $dateStr, error: $e');
      return null;
    }
  }

  DiscountValidity checkValidity(double cartTotal, DateTime now) {
    // Use safe date parsing - if dates are invalid, assume valid (API sends only valid coupons)
    final validFrom = _safeParseDate(validFromDate);
    final validTo = _safeParseDate(validToDate);

    // If dates are null or invalid, assume valid as per requirement
    if (validFrom == null || validTo == null) {
      return DiscountValidity.valid;
    }

    if (now.isBefore(validFrom)) return DiscountValidity.notStarted;
    if (now.isAfter(validTo)) return DiscountValidity.expired;

    if (discountCouponMinAmount != null &&
        discountCouponMinAmount! > 0 &&
        cartTotal < discountCouponMinAmount!) {
      return DiscountValidity.belowMin;
    }

    if (discountCouponMaxAmount != null &&
        discountCouponMaxAmount! > 0 &&
        cartTotal > discountCouponMaxAmount!) {
      return DiscountValidity.aboveMax;
    }

    return DiscountValidity.valid;
  }
}

enum DiscountValidity {
  valid,
  belowMin,
  aboveMax,
  expired,
  notStarted,
}
