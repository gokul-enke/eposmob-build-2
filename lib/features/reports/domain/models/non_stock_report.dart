import 'non_stock_report_pagination.dart';

class GetNonStockReportResponse {
  final String status;
  final String message;
  final List<NonStockReportData> data;
  final NonStockReportPagination? pagination;

  GetNonStockReportResponse({
    required this.status,
    required this.message,
    required this.data,
    this.pagination,
  });

  factory GetNonStockReportResponse.fromJson(Map<String, dynamic> json) {
    // Some APIs return data as a Map containing 'data' (the list) and pagination info,
    // others return data directly as a List.
    List<NonStockReportData> dataList = [];
    NonStockReportPagination? paginationInfo;

    if (json['data'] is Map) {
      final dataMap = json['data'] as Map<String, dynamic>;
      if (dataMap['data'] is List) {
        dataList = (dataMap['data'] as List)
            .map((item) => NonStockReportData.fromJson(item))
            .toList();
      }
      if (dataMap.containsKey('current_page') ||
          dataMap.containsKey('last_page')) {
        paginationInfo = NonStockReportPagination.fromJson(dataMap);
      }
    } else if (json['data'] is List) {
      dataList = (json['data'] as List)
          .map((item) => NonStockReportData.fromJson(item))
          .toList();
    }

    return GetNonStockReportResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      data: dataList,
      pagination: paginationInfo,
    );
  }
}

class NonStockReportData {
  final int id;
  final String name;
  final String? barcode;
  final dynamic reorderLevel;
  final String? unit;
  final String? categoryName;
  final dynamic totalQuantity;
  final String? store;
  final String? status;

  NonStockReportData({
    required this.id,
    required this.name,
    this.barcode,
    this.reorderLevel,
    this.unit,
    this.categoryName,
    this.totalQuantity,
    this.store,
    this.status,
  });

  factory NonStockReportData.fromJson(Map<String, dynamic> json) {
    return NonStockReportData(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      barcode: json['barcode'],
      reorderLevel: json['reorder_level'],
      unit: json['unit'],
      categoryName: json['category_name'],
      totalQuantity: json['total_quantity'],
      store: json['store'],
      status: json['status'],
    );
  }
}
