import 'package:pos_machine/models/pagination.dart';

class GetStockReportResponse {
  final String status;
  final String message;
  final List<StockReportData> data;
  final Pagination? pagination;
  final StockReportSummary? summary;

  GetStockReportResponse({
    required this.status,
    required this.message,
    required this.data,
    this.pagination,
    this.summary,
  });

  factory GetStockReportResponse.fromJson(Map<String, dynamic> json) {
    List<StockReportData> dataList = [];
    Pagination? paginationInfo;
    StockReportSummary? summaryInfo;

    // Parse summary
    if (json['summary'] is Map) {
      summaryInfo = StockReportSummary.fromJson(json['summary']);
    }

    if (json['data'] is Map) {
      final dataMap = json['data'] as Map<String, dynamic>;
      if (dataMap['data'] is List) {
        dataList = (dataMap['data'] as List)
            .map((item) => StockReportData.fromJson(item))
            .toList();
      }
      if (dataMap['pagination'] is Map) {
        paginationInfo = Pagination.fromJson(
            dataMap['pagination'] as Map<String, dynamic>);
      } else if (dataMap['current_page'] != null) {
        paginationInfo = Pagination.fromJson(dataMap);
      }
      
      // Fallback: check if summary is inside data map
      if (summaryInfo == null && dataMap['summary'] is Map) {
        summaryInfo = StockReportSummary.fromJson(dataMap['summary']);
      }
    } else if (json['data'] is List) {
      dataList = (json['data'] as List)
          .map((item) => StockReportData.fromJson(item))
          .toList();
    }

    return GetStockReportResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      data: dataList,
      pagination: paginationInfo,
      summary: summaryInfo,
    );
  }
}

class StockReportSummary {
  final dynamic totalUnits;
  final dynamic totalStockValue;
  final dynamic totalRetailValue;
  final String? snapshotDate;

  StockReportSummary({
    this.totalUnits,
    this.totalStockValue,
    this.totalRetailValue,
    this.snapshotDate,
  });

  factory StockReportSummary.fromJson(Map<String, dynamic> json) {
    return StockReportSummary(
      totalUnits: json['total_units'],
      totalStockValue: json['total_stock_value'],
      totalRetailValue: json['total_retail_value'],
      snapshotDate: json['snapshot_date']?.toString(),
    );
  }
}

class StockReportData {
  final int id;
  final String name;
  final String? barcode;
  final String? categoryName;
  final dynamic totalQuantity;
  final int? storeCount;
  final dynamic stockValue;
  final dynamic retailValue;
  final String? expiryDate;
  final String? unit;
  final dynamic retailPrice;
  final dynamic mrp;
  final dynamic purchasePrice;

  StockReportData({
    required this.id,
    required this.name,
    this.barcode,
    this.categoryName,
    this.totalQuantity,
    this.storeCount,
    this.stockValue,
    this.retailValue,
    this.expiryDate,
    this.unit,
    this.retailPrice,
    this.mrp,
    this.purchasePrice,
  });

  factory StockReportData.fromJson(Map<String, dynamic> json) {
    return StockReportData(
      id: json['id'] ?? json['product_id'] ?? 0,
      name: json['product'] ?? json['name'] ?? json['product_name'] ?? '',
      barcode: json['barcode']?.toString(),
      categoryName: json['category']?.toString() ?? json['category_name']?.toString(),
      totalQuantity: json['total_quantity'],
      storeCount: json['store_count'] is num ? (json['store_count'] as num).toInt() : null,
      stockValue: json['stock_value'],
      retailValue: json['retail_value'],
      expiryDate: json['earliest_expiry']?.toString() ?? json['expiry_date']?.toString(),
      unit: json['unit']?.toString(),
      retailPrice: json['retail_price'],
      mrp: json['mrp'],
      purchasePrice: json['purchase_price'],
    );
  }
}
