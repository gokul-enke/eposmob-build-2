/// Stock endpoint metadata. Independent of application/UI pagination.
class StockReportPagination {
  const StockReportPagination(
      {this.currentPage, this.perPage, this.lastPage, this.total});
  final int? currentPage, perPage, lastPage, total;
  Map<String, dynamic> toJson() => {
        'current_page': currentPage,
        'per_page': perPage,
        'last_page': lastPage,
        if (total != null) 'total': total
      };
  factory StockReportPagination.fromJson(Map<String, dynamic> json) =>
      StockReportPagination(
          currentPage: json['current_page'],
          perPage: json['per_page'],
          lastPage: json['last_page'],
          total: json['total']);
}
