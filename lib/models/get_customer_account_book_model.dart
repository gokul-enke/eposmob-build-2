// get_customer_account_book_model.dart

class GetCustomerAccountBookResponse {
  final String status;
  final String message;
  final GetCustomerAccountBookData data;

  GetCustomerAccountBookResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory GetCustomerAccountBookResponse.fromJson(Map<String, dynamic> json) {
    return GetCustomerAccountBookResponse(
      status: json['status'],
      message: json['message'],
      data: GetCustomerAccountBookData.fromJson(json['data']),
    );
  }
}

class GetCustomerAccountBookData {
  final int currentPage;
  final List<CustomerAccountBookEntry> data;
  final String firstPageUrl;
  final int? from;
  final int lastPage;
  final String lastPageUrl;
  final List<Link> links;
  final String? nextPageUrl;
  final String path;
  final int perPage;
  final String? prevPageUrl;
  final int? to;
  final int total;

  GetCustomerAccountBookData({
    required this.currentPage,
    required this.data,
    required this.firstPageUrl,
    this.from,
    required this.lastPage,
    required this.lastPageUrl,
    required this.links,
    this.nextPageUrl,
    required this.path,
    required this.perPage,
    this.prevPageUrl,
    this.to,
    required this.total,
  });

  factory GetCustomerAccountBookData.fromJson(Map<String, dynamic> json) {
    return GetCustomerAccountBookData(
      currentPage: json['current_page'],
      data: (json['data'] as List)
          .map((entry) => CustomerAccountBookEntry.fromJson(entry))
          .toList(),
      firstPageUrl: json['first_page_url'],
      from: json['from'],
      lastPage: json['last_page'],
      lastPageUrl: json['last_page_url'],
      links:
          (json['links'] as List).map((link) => Link.fromJson(link)).toList(),
      nextPageUrl: json['next_page_url'],
      path: json['path'],
      perPage: json['per_page'],
      prevPageUrl: json['prev_page_url'],
      to: json['to'],
      total: json['total'],
    );
  }
}

class CustomerAccountBookEntry {
  final String customerName;
  final int userId;
  final String createdAt;
  final String totalDebit;
  final String totalCredit;
  final int balanceAmount;

  CustomerAccountBookEntry({
    required this.customerName,
    required this.userId,
    required this.createdAt,
    required this.totalDebit,
    required this.totalCredit,
    required this.balanceAmount,
  });

  factory CustomerAccountBookEntry.fromJson(Map<String, dynamic> json) {
    return CustomerAccountBookEntry(
      customerName: json['customer_name'],
      userId: json['user_id'],
      createdAt: json['created_at'],
      totalDebit: json['total_debit'],
      totalCredit: json['total_credit'],
      balanceAmount: json['balance_amount'],
    );
  }
}

class Link {
  final String? url;
  final String label;
  final bool active;

  Link({
    this.url,
    required this.label,
    required this.active,
  });

  factory Link.fromJson(Map<String, dynamic> json) {
    return Link(
      url: json['url'],
      label: json['label'],
      active: json['active'],
    );
  }
}
