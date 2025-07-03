// supplier_sales_report_model.dart

class GetSupplierSalesReportResponse {
  final String status;
  final String message;
  final List<SupplierSalesReportEntry> data;

  GetSupplierSalesReportResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory GetSupplierSalesReportResponse.fromJson(Map<String, dynamic> json) {
    return GetSupplierSalesReportResponse(
      status: json['status'],
      message: json['message'],
      data: (json['data'] as List)
          .map((entry) => SupplierSalesReportEntry.fromJson(entry))
          .toList(),
    );
  }
}

class SupplierSalesReportEntry {
  final String supplierName;
  final String date;
  final double totalAmount;

  SupplierSalesReportEntry({
    required this.supplierName,
    required this.date,
    required this.totalAmount,
  });

  factory SupplierSalesReportEntry.fromJson(Map<String, dynamic> json) {
    return SupplierSalesReportEntry(
      supplierName: json['supplier_name'],
      date: json['date'],
      totalAmount: json['total_amount'].toDouble(),
    );
  }
}
