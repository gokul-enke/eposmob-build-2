class GetProductSalesReportResponse {
  const GetProductSalesReportResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  final String status;
  final String message;
  final ProductSalesReportData data;

  factory GetProductSalesReportResponse.fromJson(Map<String, dynamic> json) {
    return GetProductSalesReportResponse(
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      data: ProductSalesReportData.fromJson(
        Map<String, dynamic>.from(json['data'] as Map? ?? const {}),
      ),
    );
  }
}

class ProductSalesReportData {
  const ProductSalesReportData({
    required this.entries,
    required this.currency,
    required this.summary,
    required this.pagination,
  });

  final List<ProductSalesReportEntry> entries;
  final String currency;
  final ProductSalesReportSummary summary;
  final ProductSalesReportPagination pagination;

  factory ProductSalesReportData.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['data'];
    return ProductSalesReportData(
      entries: rawEntries is List
          ? rawEntries
              .whereType<Map>()
              .map((entry) => ProductSalesReportEntry.fromJson(
                    Map<String, dynamic>.from(entry),
                  ))
              .toList()
          : const [],
      currency: json['currency']?.toString() ?? '',
      summary: ProductSalesReportSummary.fromJson(
        Map<String, dynamic>.from(json['summary'] as Map? ?? const {}),
      ),
      pagination: ProductSalesReportPagination.fromJson(
        Map<String, dynamic>.from(json['pagination'] as Map? ?? const {}),
      ),
    );
  }
}

class ProductSalesReportEntry {
  const ProductSalesReportEntry({
    required this.productId,
    required this.productName,
    required this.category,
    required this.price,
    required this.salesCount,
    required this.totalPrice,
  });

  final int productId;
  final String productName;
  final String category;
  final double price;
  final double salesCount;
  final double totalPrice;

  factory ProductSalesReportEntry.fromJson(Map<String, dynamic> json) {
    return ProductSalesReportEntry(
      productId: _asInt(json['product_id']),
      productName: json['product_name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      price: _asDouble(json['price']),
      salesCount: _asDouble(json['sales_count']),
      totalPrice: _asDouble(json['total_price']),
    );
  }
}

class ProductSalesReportSummary {
  const ProductSalesReportSummary({
    required this.totalRevenue,
    required this.totalQuantity,
  });

  final double totalRevenue;
  final double totalQuantity;

  factory ProductSalesReportSummary.fromJson(Map<String, dynamic> json) {
    return ProductSalesReportSummary(
      totalRevenue: _asDouble(json['total_revenue']),
      totalQuantity: _asDouble(json['total_quantity']),
    );
  }
}

class ProductSalesReportPagination {
  const ProductSalesReportPagination({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  factory ProductSalesReportPagination.fromJson(Map<String, dynamic> json) {
    return ProductSalesReportPagination(
      currentPage: _asInt(json['current_page'], fallback: 1),
      lastPage: _asInt(json['last_page'], fallback: 1),
      perPage: _asInt(json['per_page'], fallback: 25),
      total: _asInt(json['total']),
    );
  }
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
