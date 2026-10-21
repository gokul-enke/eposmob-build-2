// Response models for the four independently loaded dashboard widgets.
// Malformed financial values fail visibly rather than appearing as zero.
double _number(dynamic value, String field) {
  final parsed = value is num
      ? value.toDouble()
      : value is String
          ? double.tryParse(value.trim())
          : null;
  if (parsed == null || !parsed.isFinite) {
    throw FormatException('Invalid dashboard field: $field');
  }
  return parsed;
}

int _count(dynamic value, String field) {
  final parsed = _number(value, field);
  if (parsed < 0 ||
      parsed > 9007199254740991 ||
      parsed != parsed.truncateToDouble()) {
    throw FormatException('Invalid dashboard count: $field');
  }
  return parsed.toInt();
}

class OrdersWidgetData {
  const OrdersWidgetData(
      {required this.todayCount, required this.averageAmount});
  final int todayCount;
  final double averageAmount;

  factory OrdersWidgetData.fromJson(Map<String, dynamic> json) =>
      OrdersWidgetData(
        todayCount: _count(json['total_orders_today'], 'total_orders_today'),
        averageAmount:
            _number(json['average_order_amount'], 'average_order_amount'),
      );
}

class LatestDashboardOrder {
  const LatestDashboardOrder({
    required this.id,
    required this.date,
    required this.customerName,
    required this.status,
    required this.grandTotal,
  });
  final String id;
  final String date;
  final String customerName;
  final String status;
  final double grandTotal;

  factory LatestDashboardOrder.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id == null || id.toString().trim().isEmpty) {
      throw const FormatException('Missing dashboard order ID');
    }
    return LatestDashboardOrder(
      id: id.toString(),
      date: json['order_date']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      grandTotal: _number(json['grand_total'], 'grand_total'),
    );
  }
}

class LatestOrdersData {
  LatestOrdersData(Iterable<LatestDashboardOrder> orders)
      : orders = List.unmodifiable(orders);
  final List<LatestDashboardOrder> orders;

  factory LatestOrdersData.fromJson(Map<String, dynamic> json) {
    final orders = json['orders'];
    if (orders is! List) {
      throw const FormatException('Invalid latest orders list');
    }
    return LatestOrdersData(orders.map((order) {
      if (order is! Map<String, dynamic>) {
        throw const FormatException('Invalid latest order');
      }
      return LatestDashboardOrder.fromJson(order);
    }));
  }
}

class CustomerTransactionsSummaryData {
  const CustomerTransactionsSummaryData({
    required this.customers,
    required this.credit,
    required this.debit,
    required this.balance,
  });
  final int customers;
  final double credit;
  final double debit;
  final double balance;

  factory CustomerTransactionsSummaryData.fromJson(Map<String, dynamic> json) =>
      CustomerTransactionsSummaryData(
        customers: _count(json['total_customers'], 'total_customers'),
        credit: _number(json['total_credit'], 'total_credit'),
        debit: _number(json['total_debit'], 'total_debit'),
        balance: _number(json['total_balance'], 'total_balance'),
      );
}

class RevenueStatsData {
  const RevenueStatsData({
    required this.totalOnOrder,
    required this.creditCollected,
    required this.creditSales,
    required this.totalInBank,
    required this.totalInCash,
  });
  final double totalOnOrder;
  final double creditCollected;
  final double creditSales;
  final double totalInBank;
  final double totalInCash;

  factory RevenueStatsData.fromJson(Map<String, dynamic> json) =>
      RevenueStatsData(
        totalOnOrder: _number(json['total_on_order'], 'total_on_order'),
        creditCollected: _number(json['credit_collected'], 'credit_collected'),
        creditSales: _number(json['credit_sales'], 'credit_sales'),
        totalInBank: _number(json['total_in_bank'], 'total_in_bank'),
        totalInCash: _number(json['total_in_cash'], 'total_in_cash'),
      );
}

class SuppliersGraphData {
  SuppliersGraphData(
      {required Iterable<String> labels, required Iterable<int> counts})
      : labels = List.unmodifiable(labels),
        counts = List.unmodifiable(counts);
  final List<String> labels;
  final List<int> counts;

  factory SuppliersGraphData.fromJson(Map<String, dynamic> json) {
    final labels = json['labels'];
    final counts = json['suppliers'];
    if (labels is! List || counts is! List || labels.length != counts.length) {
      throw const FormatException('Invalid suppliers graph arrays');
    }
    return SuppliersGraphData(
      labels: labels.map((label) {
        if (label is! String || label.trim().isEmpty) {
          throw const FormatException('Invalid suppliers graph label');
        }
        return label;
      }),
      counts: counts.map((value) => _count(value, 'suppliers')),
    );
  }
}
