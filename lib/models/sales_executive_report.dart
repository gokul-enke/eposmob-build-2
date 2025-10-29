import 'dart:convert';

SalesExecutiveReportModel salesExecutiveReportModelFromJson(String str) =>
    SalesExecutiveReportModel.fromJson(json.decode(str));

String salesExecutiveReportModelToJson(SalesExecutiveReportModel data) =>
    json.encode(data.toJson());

class SalesExecutiveReportModel {
  final String? status;
  final String? message;
  final List<SalesExecutiveReportData>? data;

  SalesExecutiveReportModel({
    this.status,
    this.message,
    this.data,
  });

  factory SalesExecutiveReportModel.fromJson(Map<String, dynamic> json) =>
      SalesExecutiveReportModel(
        status: json["status"],
        message: json["message"],
        data: json["data"] == null
            ? []
            : List<SalesExecutiveReportData>.from(
                json["data"].map((x) => SalesExecutiveReportData.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": data == null
            ? []
            : List<dynamic>.from(data!.map((x) => x.toJson())),
      };
}

class SalesExecutiveReportData {
  final String? name;
  final String? phone;
  final int? orderCount;
  final String? totalSales;
  final String? upiSales;
  final String? cashSales;
  final int? creditSales;
  final int? collectedSales;
  final String? totalPaymentReceived; // optional from API
  final String? creditCollectedPrev; // optional from API (prev balance collected)
  final String? totalCollectedOnSale; // optional from API

  SalesExecutiveReportData({
    this.name,
    this.phone,
    this.orderCount,
    this.totalSales,
    this.upiSales,
    this.cashSales,
    this.creditSales,
    this.collectedSales,
    this.totalPaymentReceived,
    this.creditCollectedPrev,
    this.totalCollectedOnSale,
  });

  factory SalesExecutiveReportData.fromJson(Map<String, dynamic> json) =>
      SalesExecutiveReportData(
        name: json["name"] ?? "No Name",
        phone: json["phone"] ?? "No Phone",
        // Prefer snake_case keys from API, fallback to camelCase for compatibility
        orderCount: (json["order_count"] ?? json["orderCount"]) is String
            ? int.tryParse((json["order_count"] ?? json["orderCount"]).toString()) ?? 0
            : (json["order_count"] ?? json["orderCount"] ?? 0),
        totalSales: (json["total_sales"] ?? json["totalSales"])?.toString() ?? "0.000",
        upiSales: (json["upi_sales"] ?? json["upiSales"])?.toString() ?? "0.000",
        cashSales: (json["cash_sales"] ?? json["cashSales"])?.toString() ?? "0.000",
        creditSales: (json["credit_sales"] ?? json["creditSales"]) is String
            ? int.tryParse((json["credit_sales"] ?? json["creditSales"]).toString()) ?? 0
            : (json["credit_sales"] ?? json["creditSales"] ?? 0),
        collectedSales: (json["collected_sales"] ?? json["collectedSales"]) is String
            ? int.tryParse((json["collected_sales"] ?? json["collectedSales"]).toString()) ?? 0
            : (json["collected_sales"] ?? json["collectedSales"] ?? 0),
        totalPaymentReceived: (json["total_payment_received"] ?? json["payment_received"] ?? json["totalPaymentReceived"])?.toString() ?? "0.000",
        creditCollectedPrev: (json["credit_collected_prev"] ?? json["prev_balance_collected"] ?? json["creditCollectedPrev"])?.toString() ?? "0.000",
        totalCollectedOnSale: (json["total_collected_on_sale"] ?? json["totalCollectedOnSale"])?.toString() ?? "0.000",
      );

  Map<String, dynamic> toJson() => {
        "name": name,
        "phone": phone,
        "orderCount": orderCount,
        "totalSales": totalSales,
        "upiSales": upiSales,
        "cashSales": cashSales,
        "creditSales": creditSales,
        "collectedSales": collectedSales,
        "totalPaymentReceived": totalPaymentReceived,
        "creditCollectedPrev": creditCollectedPrev,
        "totalCollectedOnSale": totalCollectedOnSale,
      };

  // Helper methods for calculations
  double get totalSalesAmount {
    return double.tryParse(totalSales ?? "0") ?? 0.0;
  }

  double get upiSalesAmount {
    return double.tryParse(upiSales ?? "0") ?? 0.0;
  }

  double get cashSalesAmount {
    return double.tryParse(cashSales ?? "0") ?? 0.0;
  }

  double get creditSalesAmount {
    return (creditSales ?? 0).toDouble();
  }

  double get collectedSalesAmount {
    return (collectedSales ?? 0).toDouble();
  }

  double get totalPaymentReceivedAmount {
    return double.tryParse(totalPaymentReceived ?? "0") ?? 0.0;
  }

  double get creditCollectedPrevAmount {
    return double.tryParse(creditCollectedPrev ?? "0") ?? 0.0;
  }

  double get totalCollectedOnSaleAmount {
    return double.tryParse(totalCollectedOnSale ?? "0") ?? 0.0;
  }

  // Formatted getters for display
  String get formattedTotalSales {
    return totalSalesAmount.toStringAsFixed(2);
  }

  String get formattedUpiSales {
    return upiSalesAmount.toStringAsFixed(2);
  }

  String get formattedCashSales {
    return cashSalesAmount.toStringAsFixed(2);
  }

  String get formattedCreditSales {
    return creditSalesAmount.toStringAsFixed(2);
  }

  String get formattedCollectedSales {
    return collectedSalesAmount.toStringAsFixed(2);
  }

  String get formattedTotalPaymentReceived {
    return totalPaymentReceivedAmount.toStringAsFixed(2);
  }

  String get formattedCreditCollectedPrev {
    return creditCollectedPrevAmount.toStringAsFixed(2);
  }

  String get formattedTotalCollectedOnSale {
    return totalCollectedOnSaleAmount.toStringAsFixed(2);
  }

  // Calculate percentage of UPI vs Cash sales
  double get upiPercentage {
    if (totalSalesAmount == 0) return 0.0;
    return (upiSalesAmount / totalSalesAmount) * 100;
  }

  double get cashPercentage {
    if (totalSalesAmount == 0) return 0.0;
    return (cashSalesAmount / totalSalesAmount) * 100;
  }

  double get creditPercentage {
    if (totalSalesAmount == 0) return 0.0;
    return (creditSalesAmount / totalSalesAmount) * 100;
  }

  double get collectedPercentage {
    if (totalSalesAmount == 0) return 0.0;
    return (collectedSalesAmount / totalSalesAmount) * 100;
  }

  // Average sales per order
  double get averageSalesPerOrder {
    if (orderCount == null || orderCount! <= 0) return 0.0;
    return totalSalesAmount / orderCount!;
  }

  String get formattedAverageSalesPerOrder {
    return averageSalesPerOrder.toStringAsFixed(2);
  }
}
