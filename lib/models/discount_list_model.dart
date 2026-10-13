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
  final int? storeId;
  final int? categoryId;
  final int? productId;
  final String discountType;
  final String validFromDate;
  final String validToDate;
  final int discountCouponLimitCount;
  final double discountCouponLimitAmount;
  final double? discountCouponMinAmount;
  final double? discountCouponMaxAmount;
  final num discountValue;
  final int? usageCount;
  final int? remainingUses;
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
    this.usageCount,
    this.remainingUses,
    required this.companyId,
    this.createdAt,
    this.updatedAt,
  });

  factory DiscountData.fromJson(Map<String, dynamic> json) => DiscountData(
        id: _int(json["id"]) ?? 0,
        couponCode: json["coupon_code"]?.toString() ?? '',
        discountCategoryId: _int(json["discount_category_id"]) ?? 0,
        couponName: json["coupon_name"]?.toString() ?? '',
        storeId: _int(json["store_id"]),
        categoryId: _int(json["category_id"]),
        productId: _int(json["product_id"]),
        discountType: json["discount_type"]?.toString() ?? '',
        validFromDate: json["valid_from_date"]?.toString() ?? '',
        validToDate: json["valid_to_date"]?.toString() ?? '',
        discountCouponLimitCount:
            _int(json["discount_coupon_limit_count"]) ?? 0,
        discountCouponLimitAmount: json["discount_coupon_limit_amount"] != null
            ? double.tryParse(
                    json["discount_coupon_limit_amount"].toString()) ??
                0.0
            : 0.0,
        discountCouponMinAmount: json["discount_coupon_min_amount"] != null
            ? double.tryParse(json["discount_coupon_min_amount"].toString())
            : null,
        discountCouponMaxAmount: json["discount_coupon_max_amount"] != null
            ? double.tryParse(json["discount_coupon_max_amount"].toString())
            : null,
        discountValue:
            num.tryParse(json["discount_value"]?.toString() ?? '') ?? 0,
        usageCount: _int(json['usage_count']),
        remainingUses: _int(json['remaining_uses']),
        companyId: _int(json["company_id"]) ?? 0,
        createdAt: json["created_at"] == null
            ? null
            : DateTime.tryParse(json["created_at"].toString()),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.tryParse(json["updated_at"].toString()),
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
        if (usageCount != null) 'usage_count': usageCount,
        if (remainingUses != null) 'remaining_uses': remainingUses,
        "company_id": companyId,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };

  static int? _int(dynamic value) => int.tryParse(value?.toString() ?? '');

  DiscountValidity checkValidity(double cartTotal, DateTime now) {
    // Coupon boundaries are business calendar dates, independent of the
    // device's timezone and of TZDateTime's UTC offset.
    now = DateTime(
        now.year, now.month, now.day, now.hour, now.minute, now.second);
    final validFrom = DateTime.tryParse(validFromDate);
    final validTo = DateTime.tryParse(validToDate);
    if ((validFromDate.isNotEmpty && validFrom == null) ||
        (validToDate.isNotEmpty && validTo == null)) {
      return DiscountValidity.invalid;
    }

    // Check if before start date
    if (validFrom != null && now.isBefore(validFrom)) {
      return DiscountValidity.notStarted;
    }

    // Check if after valid to date (inclusive - treat valid_to as end of day)
    // Convert validTo to end of day (23:59:59) for inclusive comparison
    if (validTo != null) {
      final nextDay = DateTime(validTo.year, validTo.month, validTo.day + 1);
      if (!now.isBefore(nextDay)) return DiscountValidity.expired;
    }

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
  invalid,
}
