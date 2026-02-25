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
  final String? onlineSales;
  final String? upiSales;
  final String? cardSales;
  final String? cashSales;
  final String? creditSales;
  final String? collectedSales;
  final String? totalPaymentReceived; // optional from API
  final String?
      creditCollectedPrev; // optional from API (prev balance collected)
  final String? totalCollectedOnSale; // optional from API

  SalesExecutiveReportData({
    this.name,
    this.phone,
    this.orderCount,
    this.totalSales,
    this.onlineSales,
    this.upiSales,
    this.cardSales,
    this.cashSales,
    this.creditSales,
    this.collectedSales,
    this.totalPaymentReceived,
    this.creditCollectedPrev,
    this.totalCollectedOnSale,
  });

  factory SalesExecutiveReportData.fromJson(Map<String, dynamic> json) {
    // Helper function to safely convert values to string representation
    String _toString(dynamic value) {
      if (value == null) return "0.000";
      if (value is String) return value;
      if (value is int || value is double) return value.toString();
      return "0.000";
    }

    // Helper function to safely extract from payment_breakdown
    String _getPaymentBreakdownValue(
        dynamic paymentBreakdown, String key, dynamic fallback) {
      try {
        // Check if payment_breakdown is a Map (object)
        if (paymentBreakdown is Map<String, dynamic>) {
          return _toString(paymentBreakdown[key] ?? fallback);
        }
        // If it's an empty list or other type, use fallback
        return _toString(fallback);
      } catch (e) {
        return _toString(fallback);
      }
    }

    return SalesExecutiveReportData(
      name: json["name"]?.toString() ?? "No Name",
      phone: json["phone"]?.toString() ?? "No Phone",
      // Prefer snake_case keys from API, fallback to camelCase for compatibility
      orderCount: (json["order_count"] ?? json["orderCount"]) is String
          ? int.tryParse(
                  (json["order_count"] ?? json["orderCount"]).toString()) ??
              0
          : (json["order_count"] ?? json["orderCount"] ?? 0),
      totalSales: _toString(json["total_sales"] ?? json["totalSales"]),
      onlineSales: _toString(json["online_sales"] ?? json["onlineSales"]),
      upiSales: _getPaymentBreakdownValue(json["payment_breakdown"], "UPI",
          json["upi_sales"] ?? json["upiSales"]),
      cardSales: _getPaymentBreakdownValue(
          json["payment_breakdown"],
          "CARD",
          json["card_sales"] ?? json["cardSales"]),
      cashSales: _toString(json["cash_sales"] ?? json["cashSales"]),
      creditSales: _toString(json["credit_sales"] ?? json["creditSales"]),
      collectedSales:
          _toString(json["collected_sales"] ?? json["collectedSales"]),
      totalPaymentReceived: _toString(json["total_payment_received"] ??
          json["payment_received"] ??
          json["totalPaymentReceived"]),
      creditCollectedPrev: _toString(json["credit_collected_prev"] ??
          json["prev_balance_collected"] ??
          json["creditCollectedPrev"]),
      totalCollectedOnSale:
          _toString(json["total_collected_on_sale"] ?? json["totalCollectedOnSale"]),
    );
  }

  Map<String, dynamic> toJson() => {
        "name": name,
        "phone": phone,
        "orderCount": orderCount,
        "totalSales": totalSales,
        "onlineSales": onlineSales,
        "upiSales": upiSales,
        "cardSales": cardSales,
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

  double get onlineSalesAmount {
    return double.tryParse(onlineSales ?? "0") ?? 0.0;
  }

  double get upiSalesAmount {
    return double.tryParse(upiSales ?? "0") ?? 0.0;
  }

  double get cardSalesAmount {
    return double.tryParse(cardSales ?? "0") ?? 0.0;
  }

  double get cashSalesAmount {
    return double.tryParse(cashSales ?? "0") ?? 0.0;
  }

  double get creditSalesAmount {
    return double.tryParse(creditSales ?? "0") ?? 0.0;
  }

  double get collectedSalesAmount {
    return double.tryParse(collectedSales ?? "0") ?? 0.0;
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

  String get formattedOnlineSales {
    return onlineSalesAmount.toStringAsFixed(2);
  }

  String get formattedUpiSales {
    return upiSalesAmount.toStringAsFixed(2);
  }

  String get formattedCardSales {
    return cardSalesAmount.toStringAsFixed(2);
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
