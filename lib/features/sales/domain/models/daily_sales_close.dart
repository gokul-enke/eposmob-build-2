import 'daily_sales_close_summary.dart';

export 'daily_sales_close_summary.dart';

class DailySalesCloseModel {
  bool? success;
  String? message;
  List<DailySalesCloseData>? data;
  Pagination? pagination;

  DailySalesCloseModel(
      {this.success, this.message, this.data, this.pagination});

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
  String? shiftName;
  String? businessDate;
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
  String? totalReturns;
  String? totalRefunds;
  String? totalExpenses;
  String? cashExpenses;
  String? bankExpenses;
  CashSummary? cashSummary;
  List<DailySalesTransaction>? transactions;
  ProductSummary? productSummary;
  String? createdAt;
  String? updatedAt;
  String? status;
  String? refundCash;
  String? refundOnline;
  Map<String, dynamic>? paymentMethodBreakdown;

  DailySalesCloseData(
      {this.id,
      this.salesExecutive,
      this.store,
      this.closingPeriod,
      this.openingDate,
      this.openingTime,
      this.closingDate,
      this.closingTime,
      this.shiftName,
      this.businessDate,
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
      this.totalReturns,
      this.totalRefunds,
      this.totalExpenses,
      this.cashExpenses,
      this.bankExpenses,
      this.cashSummary,
      this.transactions,
      this.productSummary,
      this.createdAt,
      this.updatedAt,
      this.status,
      this.refundCash,
      this.refundOnline,
      this.paymentMethodBreakdown});

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
    shiftName = json['shift_name'];
    businessDate = json['business_date'];
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
    totalReturns = json['total_returns'];
    totalRefunds = json['total_refunds'];
    totalExpenses = json['total_expenses']?.toString();
    cashExpenses = json['cash_expenses']?.toString();
    bankExpenses = json['bank_expenses']?.toString();
    refundCash = json['refund_cash']?.toString();
    refundOnline = json['refund_online']?.toString();
    paymentMethodBreakdown = json['payment_method_breakdown'] != null
        ? Map<String, dynamic>.from(json['payment_method_breakdown'])
        : null;
    if (json['cash_summary'] != null) {
      cashSummary = CashSummary.fromJson(
        Map<String, dynamic>.from(json['cash_summary']),
      );
    }
    if (json['transactions'] != null) {
      transactions = <DailySalesTransaction>[];
      json['transactions'].forEach((v) {
        transactions!.add(DailySalesTransaction.fromJson(v));
      });
    }
    if (json['product_summary'] != null) {
      productSummary = ProductSummary.fromJson(json['product_summary']);
    }
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    status = json['status'];
  }
}

class DailySalesTransaction {
  int? id;
  String? customerName;
  String? orderNumber;
  num? orderAmount;
  num? paidAmount;
  String? paymentType;
  String? date;
  String? time;

  DailySalesTransaction(
      {this.id,
      this.customerName,
      this.orderNumber,
      this.orderAmount,
      this.paidAmount,
      this.paymentType,
      this.date,
      this.time});

  DailySalesTransaction.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    customerName = json['customer_name'];
    orderNumber = json['order_number'];
    orderAmount = json['order_amount'];
    paidAmount = json['paid_amount'];
    paymentType = json['payment_type'];
    date = json['date'];
    time = json['time'];
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
