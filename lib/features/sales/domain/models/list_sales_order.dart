import 'sales_order_row.dart';

export 'sales_order_row.dart';
export 'sales_order_cart.dart';

class ListSalesOrderModel {
  final String? status;
  final String? message;
  final List<ListOrderModelData>? data;
  final PaginationInfo? pagination;

  ListSalesOrderModel({
    this.status,
    this.message,
    this.data,
    this.pagination,
  });

  factory ListSalesOrderModel.fromJson(Map<String, dynamic> json) {
    try {
      return ListSalesOrderModel(
        status: json["status"],
        message: json["message"],
        data: json["data"]?["data"] == null
            ? []
            : _parseOrders(json["data"]["data"]),
        pagination:
            json["data"] != null ? PaginationInfo.fromJson(json["data"]) : null,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Parses the order rows one by one so a single malformed row (an unexpected
  /// field type, for instance) drops only that row instead of throwing away the
  /// whole page and leaving the list empty.
  static List<ListOrderModelData> _parseOrders(dynamic rows) {
    if (rows is! List) return [];

    final parsed = <ListOrderModelData>[];
    for (final row in rows) {
      try {
        parsed.add(ListOrderModelData.fromJson(row));
      } catch (e) {}
    }
    return parsed;
  }

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": data == null
            ? []
            : List<dynamic>.from(data!.map((x) => x.toJson())),
        "pagination": pagination?.toJson(),
      };
}

class PaginationInfo {
  final int? currentPage;
  final int? from;
  final int? to;
  final int? totalPages;
  final String? firstPageUrl;
  final String? nextPageUrl;
  final String? prevPageUrl;

  PaginationInfo({
    this.currentPage,
    this.from,
    this.to,
    this.totalPages,
    this.firstPageUrl,
    this.nextPageUrl,
    this.prevPageUrl,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      currentPage: json["current_page"],
      from: json["from"],
      to: json["to"],
      totalPages: (json["last_page"] != null) ? json["last_page"] : null,
      firstPageUrl: json["first_page_url"],
      nextPageUrl: json["next_page_url"],
      prevPageUrl: json["prev_page_url"],
    );
  }

  Map<String, dynamic> toJson() => {
        "current_page": currentPage,
        "from": from,
        "to": to,
        "total_pages": totalPages,
        "first_page_url": firstPageUrl,
        "next_page_url": nextPageUrl,
        "prev_page_url": prevPageUrl,
      };
}
