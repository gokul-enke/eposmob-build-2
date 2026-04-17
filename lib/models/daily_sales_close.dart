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
  String? totalReturns;
  String? totalRefunds;
  List<DailySalesTransaction>? transactions;
  ProductSummary? productSummary;
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
      this.totalReturns,
      this.totalRefunds,
      this.transactions,
      this.productSummary,
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
    totalReturns = json['total_returns'];
    totalRefunds = json['total_refunds'];
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

class DailySalesCloseSummaryResponse {
  bool? success;
  String? message;
  DailySalesCloseSummary? data;

  DailySalesCloseSummaryResponse({this.success, this.message, this.data});

  DailySalesCloseSummaryResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    data = json['data'] != null
        ? DailySalesCloseSummary.fromJson(json['data'])
        : null;
  }
}

class DailySalesCloseSummary {
  String? userName;
  int? storeId;
  String? openingDate;
  String? openingTime;
  String? closingDate;
  String? closingTime;
  int? totalOrders;
  String? totalSales;
  String? paymentReceived;
  String? collectedOnSale;
  String? cashSales;
  String? onlineSales;
  String? creditAmount;
  String? creditCollected;
  String? totalReturns;
  String? totalRefunds;

  DailySalesCloseSummary({
    this.userName,
    this.storeId,
    this.openingDate,
    this.openingTime,
    this.closingDate,
    this.closingTime,
    this.totalOrders,
    this.totalSales,
    this.paymentReceived,
    this.collectedOnSale,
    this.cashSales,
    this.onlineSales,
    this.creditAmount,
    this.creditCollected,
    this.totalReturns,
    this.totalRefunds,
  });

  DailySalesCloseSummary.fromJson(Map<String, dynamic> json) {
    userName = json['user_name'];
    storeId = json['store_id'];
    openingDate = json['opening_date'];
    openingTime = json['opening_time'];
    closingDate = json['closing_date'];
    closingTime = json['closing_time'];
    totalOrders = json['total_orders'];
    totalSales = json['total_sales'];
    paymentReceived = json['payment_received'];
    collectedOnSale = json['collected_on_sale'];
    cashSales = json['cash_sales'];
    onlineSales = json['online_sales'];
    creditAmount = json['credit_amount'];
    creditCollected = json['credit_collected'];
    totalReturns = json['total_returns'];
    totalRefunds = json['total_refunds'];
  }
}

class DailySalesCloseCreateResponse {
  bool? success;
  String? message;
  DailySalesCloseData? data;

  DailySalesCloseCreateResponse({this.success, this.message, this.data});

  DailySalesCloseCreateResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    data = json['data'] != null
        ? DailySalesCloseData.fromJson(json['data'])
        : null;
  }
}

class ProductSummary {
  List<ProductSummaryItem>? items;
  int? grandTotalQty;
  num? grandTotalAmount;

  ProductSummary({this.items, this.grandTotalQty, this.grandTotalAmount});

  ProductSummary.fromJson(Map<String, dynamic> json) {
    if (json['items'] != null) {
      items = <ProductSummaryItem>[];
      json['items'].forEach((v) {
        items!.add(ProductSummaryItem.fromJson(v));
      });
    }
    grandTotalQty = json['grand_total_qty'] is num ? (json['grand_total_qty'] as num).toInt() : int.tryParse(json['grand_total_qty']?.toString() ?? '0');
    grandTotalAmount = json['grand_total_amount'] is num ? json['grand_total_amount'] : num.tryParse(json['grand_total_amount']?.toString() ?? '0');
  }
}

class ProductSummaryItem {
  int? productId;
  String? productName;
  num? unitPrice;
  int? totalQty;
  num? totalAmount;

  ProductSummaryItem({
    this.productId,
    this.productName,
    this.unitPrice,
    this.totalQty,
    this.totalAmount,
  });

  ProductSummaryItem.fromJson(Map<String, dynamic> json) {
    productId = json['product_id'] is int ? json['product_id'] : int.tryParse(json['product_id']?.toString() ?? '0');
    productName = json['product_name'];
    unitPrice = json['unit_price'] is num ? json['unit_price'] : num.tryParse(json['unit_price']?.toString() ?? '0');
    totalQty = json['total_qty'] is int ? json['total_qty'] : int.tryParse(json['total_qty']?.toString() ?? '0');
    totalAmount = json['total_amount'] is num ? json['total_amount'] : num.tryParse(json['total_amount']?.toString() ?? '0');
  }
}
