class DailySalesCloseModel {
  bool? success;
  String? message;
  List<DailySalesCloseData>? data;
  Pagination? pagination;

  DailySalesCloseModel({this.success, this.message, this.data, this.pagination});

  DailySalesCloseModel.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    if (json['data'] != null) {
      data = <DailySalesCloseData>[];
      json['data'].forEach((v) {
        data!.add(DailySalesCloseData.fromJson(v));
      });
    }
    pagination = json['pagination'] != null
        ? Pagination.fromJson(json['pagination'])
        : null;
  }
}

class DailySalesCloseData {
  int? id;
  SalesExecutive? salesExecutive;
  Store? store;
  String? closingPeriod;
  String? openingDate;
  String? openingTime;
  String? closingDate;
  String? closingTime;
  int? openingTransactionId;
  int? closingTransactionId;
  int? totalOrders;
  String? totalSales;
  String? totalOnline;
  String? totalCash;
  String? totalCredit;
  String? totalPaymentReceived;
  String? totalAmountCollectedOnSale;
  String? totalCreditCollected;
  String? createdAt;
  String? updatedAt;

  DailySalesCloseData(
      {this.id,
      this.salesExecutive,
      this.store,
      this.closingPeriod,
      this.openingDate,
      this.openingTime,
      this.closingDate,
      this.closingTime,
      this.openingTransactionId,
      this.closingTransactionId,
      this.totalOrders,
      this.totalSales,
      this.totalOnline,
      this.totalCash,
      this.totalCredit,
      this.totalPaymentReceived,
      this.totalAmountCollectedOnSale,
      this.totalCreditCollected,
      this.createdAt,
      this.updatedAt});

  DailySalesCloseData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    salesExecutive = json['sales_executive'] != null
        ? SalesExecutive.fromJson(json['sales_executive'])
        : null;
    store = json['store'] != null ? Store.fromJson(json['store']) : null;
    closingPeriod = json['closing_period'];
    openingDate = json['opening_date'];
    openingTime = json['opening_time'];
    closingDate = json['closing_date'];
    closingTime = json['closing_time'];
    openingTransactionId = json['opening_transaction_id'];
    closingTransactionId = json['closing_transaction_id'];
    totalOrders = json['total_orders'];
    totalSales = json['total_sales'];
    totalOnline = json['total_online'];
    totalCash = json['total_cash'];
    totalCredit = json['total_credit'];
    totalPaymentReceived = json['total_payment_received'];
    totalAmountCollectedOnSale = json['total_amount_collected_on_sale'];
    totalCreditCollected = json['total_credit_collected'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }
}

class SalesExecutive {
  int? id;
  String? name;
  String? phone;

  SalesExecutive({this.id, this.name, this.phone});

  SalesExecutive.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    phone = json['phone'];
  }
}

class Store {
  int? id;
  String? name;

  Store({this.id, this.name});

  Store.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
  }
}

class Pagination {
  int? total;
  int? perPage;
  int? currentPage;
  int? lastPage;

  Pagination({this.total, this.perPage, this.currentPage, this.lastPage});

  Pagination.fromJson(Map<String, dynamic> json) {
    total = json['total'];
    perPage = json['per_page'];
    currentPage = json['current_page'];
    lastPage = json['last_page'];
  }
}
