import 'daily_sales_close.dart';

class DailySalesCloseSummaryResponse {
  bool? success;
  String? message;
  DailySalesCloseSummary? data;

  DailySalesCloseSummaryResponse({this.success, this.message, this.data});

  DailySalesCloseSummaryResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    final responseData = json['data'];
    if (responseData is Map<String, dynamic>) {
      data = DailySalesCloseSummary.fromJson(responseData);
    } else if (responseData is Map) {
      data = DailySalesCloseSummary.fromJson(
        Map<String, dynamic>.from(responseData),
      );
    } else if (responseData is List && responseData.isNotEmpty) {
      final firstSummary = responseData.first;
      if (firstSummary is Map<String, dynamic>) {
        data = DailySalesCloseSummary.fromJson(firstSummary);
      } else if (firstSummary is Map) {
        data = DailySalesCloseSummary.fromJson(
          Map<String, dynamic>.from(firstSummary),
        );
      }
    }
  }
}

class DailySalesCloseSummary {
  String? userName;
  int? storeId;
  String? shiftName;
  String? businessDate;
  String? openingDate;
  String? openingTime;
  String? closingDate;
  String? closingTime;
  num? cashRefunds;
  num? cashExpenses;
  num? bankExpenses;
  num? totalExpenses;
  num? cashDropAmount;
  num? openingCashInHand;
  List<dynamic>? openingCashBreakdown;
  num? closingCashInHand;
  List<dynamic>? closingCashBreakdown;
  String? notes;
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
    this.shiftName,
    this.businessDate,
    this.openingDate,
    this.openingTime,
    this.closingDate,
    this.closingTime,
    this.cashRefunds,
    this.cashExpenses,
    this.bankExpenses,
    this.totalExpenses,
    this.cashDropAmount,
    this.openingCashInHand,
    this.openingCashBreakdown,
    this.closingCashInHand,
    this.closingCashBreakdown,
    this.notes,
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
    userName = _stringValue(json['user_name']);
    storeId = _intValue(json['store_id']);
    shiftName = _stringValue(json['shift_name']);
    businessDate = _stringValue(json['business_date']);
    openingDate = _stringValue(json['opening_date']);
    openingTime = _stringValue(json['opening_time']);
    closingDate = _stringValue(json['closing_date']);
    closingTime = _stringValue(json['closing_time']);
    cashRefunds = _numValue(json['cash_refunds']);
    cashExpenses = _numValue(json['cash_expenses']);
    bankExpenses = _numValue(json['bank_expenses']);
    totalExpenses = _numValue(json['total_expenses']);
    cashDropAmount = _numValue(json['cash_drop_amount']);
    openingCashInHand = _numValue(json['opening_cash_in_hand']);
    openingCashBreakdown = json['opening_cash_breakdown'] is List
        ? List<dynamic>.from(json['opening_cash_breakdown'] as List)
        : null;
    closingCashInHand = _numValue(json['closing_cash_in_hand']);
    closingCashBreakdown = json['closing_cash_breakdown'] is List
        ? List<dynamic>.from(json['closing_cash_breakdown'] as List)
        : null;
    notes = _stringValue(json['notes']);
    totalOrders = _intValue(json['total_orders']);
    totalSales = _stringValue(json['total_sales']);
    paymentReceived = _stringValue(json['payment_received']);
    collectedOnSale = _stringValue(
      json['collected_on_sales'] ?? json['collected_on_sale'],
    );
    cashSales = _stringValue(json['cash_sales']);
    onlineSales = _stringValue(json['online_sales']);
    creditAmount = _stringValue(json['credit_amount']);
    creditCollected = _stringValue(json['credit_collected']);
    totalReturns = _stringValue(json['total_returns']);
    totalRefunds = _stringValue(json['total_refunds']);
  }

  static String? _stringValue(dynamic value) => value?.toString();

  static int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static num? _numValue(dynamic value) {
    if (value is num) return value;
    final cleaned = value?.toString().replaceAll(',', '') ?? '';
    return num.tryParse(cleaned);
  }
}

class CashSummary {
  int? totalSalesCount;
  String? totalSalesAmount;
  String? cashCollected;
  String? onlineCollected;
  String? creditAmount;
  String? previousBalanceCollected;
  String? cashRefunds;
  String? cashExpenses;
  String? cashDropAmount;
  String? openingCashInHand;
  List<dynamic>? openingCashBreakdown;
  String? expectedClosingCash;
  String? todayCashCollection;
  String? closingCashInHand;
  List<dynamic>? closingCashBreakdown;
  String? shortCash;
  String? excessCash;
  String? notes;

  CashSummary({
    this.totalSalesCount,
    this.totalSalesAmount,
    this.cashCollected,
    this.onlineCollected,
    this.creditAmount,
    this.previousBalanceCollected,
    this.cashRefunds,
    this.cashExpenses,
    this.cashDropAmount,
    this.openingCashInHand,
    this.openingCashBreakdown,
    this.expectedClosingCash,
    this.todayCashCollection,
    this.closingCashInHand,
    this.closingCashBreakdown,
    this.shortCash,
    this.excessCash,
    this.notes,
  });

  CashSummary.fromJson(Map<String, dynamic> json) {
    totalSalesCount = json['total_sales_count'] is num
        ? (json['total_sales_count'] as num).toInt()
        : int.tryParse(json['total_sales_count']?.toString() ?? '');
    totalSalesAmount = json['total_sales_amount']?.toString();
    cashCollected = json['cash_collected']?.toString();
    onlineCollected = json['online_collected']?.toString();
    creditAmount = json['credit_amount']?.toString();
    previousBalanceCollected = json['previous_balance_collected']?.toString();
    cashRefunds = json['cash_refunds']?.toString();
    cashExpenses = json['cash_expenses']?.toString();
    cashDropAmount = json['cash_drop_amount']?.toString();
    openingCashInHand = json['opening_cash_in_hand']?.toString();
    openingCashBreakdown = json['opening_cash_breakdown'] is List
        ? List<dynamic>.from(json['opening_cash_breakdown'] as List)
        : null;
    expectedClosingCash = json['expected_closing_cash']?.toString();
    todayCashCollection = json['today_cash_collection']?.toString();
    closingCashInHand = json['closing_cash_in_hand']?.toString();
    closingCashBreakdown = json['closing_cash_breakdown'] is List
        ? List<dynamic>.from(json['closing_cash_breakdown'] as List)
        : null;
    shortCash = json['short_cash']?.toString();
    excessCash = json['excess_cash']?.toString();
    notes = json['notes']?.toString();
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
    grandTotalQty = json['grand_total_qty'] is num
        ? (json['grand_total_qty'] as num).toInt()
        : int.tryParse(json['grand_total_qty']?.toString() ?? '0');
    grandTotalAmount = json['grand_total_amount'] is num
        ? json['grand_total_amount']
        : num.tryParse(json['grand_total_amount']?.toString() ?? '0');
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
    productId = json['product_id'] is int
        ? json['product_id']
        : int.tryParse(json['product_id']?.toString() ?? '0');
    productName = json['product_name'];
    unitPrice = json['unit_price'] is num
        ? json['unit_price']
        : num.tryParse(json['unit_price']?.toString() ?? '0');
    totalQty = json['total_qty'] is int
        ? json['total_qty']
        : int.tryParse(json['total_qty']?.toString() ?? '0');
    totalAmount = json['total_amount'] is num
        ? json['total_amount']
        : num.tryParse(json['total_amount']?.toString() ?? '0');
  }
}
