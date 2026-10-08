/// Endpoint metadata; independent of shared UI pagination.
class NonStockReportPagination {
  const NonStockReportPagination(
      {this.currentPage, this.perPage, this.lastPage, this.total});
  final int? currentPage, perPage, lastPage, total;
  factory NonStockReportPagination.fromJson(Map<String, dynamic> json) =>
      NonStockReportPagination(
          currentPage: json['current_page'],
          perPage: json['per_page'],
          lastPage: json['last_page'],
          total: json['total']);
  Map<String, dynamic> toJson() => {
        'current_page': currentPage,
        'per_page': perPage,
        'last_page': lastPage,
        if (total != null) 'total': total
      };
}
