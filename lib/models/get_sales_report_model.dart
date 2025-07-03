// sales_report_model.dart

class GetSalesReportResponse {
  final String status;
  final String message;
  final List<SalesReportEntry> data;

  GetSalesReportResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory GetSalesReportResponse.fromJson(Map<String, dynamic> json) {
    return GetSalesReportResponse(
      status: json['status'],
      message: json['message'],
      data: (json['data'] as List)
          .map((entry) => SalesReportEntry.fromJson(entry))
          .toList(),
    );
  }
}

class SalesReportEntry {
  final String customerName;
  final String createdBy;
  final String date;
  final double totalPrice;

  SalesReportEntry({
    required this.customerName,
    required this.createdBy,
    required this.date,
    required this.totalPrice,
  });

  factory SalesReportEntry.fromJson(Map<String, dynamic> json) {
    return SalesReportEntry(
      customerName: json['customer_name'],
      createdBy: json['created_by'],
      date: json['date'],
      totalPrice: json['total_price'].toDouble(),
    );
  }
}
