import 'dart:convert';

DashBoardModel dashBoardModelFromJson(String str) =>
    DashBoardModel.fromJson(json.decode(str));

String dashBoardModelToJson(DashBoardModel data) => json.encode(data.toJson());

class DashBoardModel {
  final String? status;
  final String? message;
  final DashBoardModelData? data;

  DashBoardModel({
    this.status,
    this.message,
    this.data,
  });

  factory DashBoardModel.fromJson(Map<String, dynamic> json) => DashBoardModel(
        status: json["status"],
        message: json["message"],
        data: json["data"] == null
            ? null
            : DashBoardModelData.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": data?.toJson(),
      };
}

class DashBoardModelData {
  final List<ProfileDetail>? profileDetails;
  final TotalSales? totalSales;
  final int? totalProducts;

  DashBoardModelData({
    this.profileDetails,
    this.totalSales,
    this.totalProducts,
  });

  factory DashBoardModelData.fromJson(Map<String, dynamic> json) =>
      DashBoardModelData(
        profileDetails: json["profile_details"] == null
            ? []
            : List<ProfileDetail>.from(
                json["profile_details"].map((x) => ProfileDetail.fromJson(x))),
        totalSales: json["total_sales"] == null
            ? null
            : TotalSales.fromJson(json["total_sales"]),
        totalProducts: json["total_products"],
      );

  Map<String, dynamic> toJson() => {
        "profile_details": profileDetails == null
            ? []
            : List<dynamic>.from(profileDetails!.map((x) => x.toJson())),
        "total_sales": totalSales?.toJson(),
        "total_products": totalProducts,
      };
}

class ProfileDetail {
  final int? id;
  final String? name;
  final String? email;
  final String? phone;

  ProfileDetail({
    this.id,
    this.name,
    this.email,
    this.phone,
  });

  factory ProfileDetail.fromJson(Map<String, dynamic> json) => ProfileDetail(
        id: json["id"],
        name: json["name"],
        email: json["email"],
        phone: json["phone"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "email": email,
        "phone": phone,
      };
}

class TotalSales {
  final PeriodStats? today;
  final PeriodStats? week;
  final PeriodStats? month;
  final PeriodStats? year;
  final int? count;
  final double? total;

  TotalSales({
    this.today,
    this.week,
    this.month,
    this.year,
    this.count,
    this.total,
  });

  factory TotalSales.fromJson(Map<String, dynamic> json) => TotalSales(
        today:
            json["today"] == null ? null : PeriodStats.fromJson(json["today"]),
        week: json["week"] == null ? null : PeriodStats.fromJson(json["week"]),
        month:
            json["month"] == null ? null : PeriodStats.fromJson(json["month"]),
        year: json["year"] == null ? null : PeriodStats.fromJson(json["year"]),
        count: json["count"] ?? 0,
        total: json["total"] == null
            ? 0.0
            : (json["total"] is String
                ? double.parse(json["total"])
                : json["total"].toDouble()),
      );

  Map<String, dynamic> toJson() => {
        "today": today?.toJson(),
        "week": week?.toJson(),
        "month": month?.toJson(),
        "year": year?.toJson(),
        "count": count,
        "total": total,
      };
}

class PeriodStats {
  final double? totalSales;
  final int? totalCustomers;
  final double? totalAmount;

  PeriodStats({
    this.totalSales,
    this.totalCustomers,
    this.totalAmount,
  });

  factory PeriodStats.fromJson(Map<String, dynamic> json) => PeriodStats(
        totalSales: json["total_sales"] == null
            ? 0.0
            : (json["total_sales"] is String
                ? double.parse(json["total_sales"])
                : json["total_sales"].toDouble()),
        totalCustomers: json["total_customers"] ?? 0,
        totalAmount: json["total_amount"] == null
            ? 0.0
            : (json["total_amount"] is String
                ? double.parse(json["total_amount"])
                : json["total_amount"].toDouble()),
      );

  Map<String, dynamic> toJson() => {
        "total_sales": totalSales?.toStringAsFixed(2),
        "total_customers": totalCustomers,
        "total_amount": totalAmount?.toStringAsFixed(2),
      };
}
