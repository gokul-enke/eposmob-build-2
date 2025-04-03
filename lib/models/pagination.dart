class Pagination {
  final int? currentPage;
  final int? perPage;
  final int? lastPage;

  Pagination({
    this.currentPage,
    this.perPage,
    this.lastPage,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
        currentPage: json["current_page"],
        perPage: json["per_page"],
        lastPage: json["last_page"],
      );

  Map<String, dynamic> toJson() => {
        "current_page": currentPage,
        "per_page": perPage,
        "last_page": lastPage,
      };
}
