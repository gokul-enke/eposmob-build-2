// product_sales_report_model.dart

class GetProductSalesReportResponse {
  final String status;
  final String message;
  final List<ProductSalesReportEntry> data;

  GetProductSalesReportResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory GetProductSalesReportResponse.fromJson(Map<String, dynamic> json) {
    return GetProductSalesReportResponse(
      status: json['status'],
      message: json['message'],
      data: (json['data'] as List)
          .map((entry) => ProductSalesReportEntry.fromJson(entry))
          .toList(),
    );
  }
}

class ProductSalesReportEntry {
  final int productId;
  final String productName;
  final double unitPrice;
  final String categoryName;
  final int categoryId;
  final int parentCategoryId;
  final String? parentCategoryName;
  final String totalQuantity;
  final double totalAmount;

  ProductSalesReportEntry({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.categoryName,
    required this.categoryId,
    required this.parentCategoryId,
    this.parentCategoryName,
    required this.totalQuantity,
    required this.totalAmount,
  });

  factory ProductSalesReportEntry.fromJson(Map<String, dynamic> json) {
    return ProductSalesReportEntry(
      productId: json['product_id'],
      productName: json['product_name'],
      unitPrice: json['unit_price'].toDouble(),
      categoryName: json['category_name'],
      categoryId: json['category_id'],
      parentCategoryId: json['parent_category_id'],
      parentCategoryName: json['parent_category_name'],
      totalQuantity: json['total_quantity'],
      totalAmount: json['total_amount'].toDouble(),
    );
  }
}
