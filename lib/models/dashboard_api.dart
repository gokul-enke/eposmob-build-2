class DashboardOverview {
  final BankAccount bankAccount;
  final CashAccount cashAccount;
  final ProductsData products;
  final RevenueData revenue;
  final CustomersData customers;
  final OrdersData orders;

  DashboardOverview({
    required this.bankAccount,
    required this.cashAccount,
    required this.products,
    required this.revenue,
    required this.customers,
    required this.orders,
  });

  factory DashboardOverview.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};

    return DashboardOverview(
      bankAccount: data['bank_account'] != null
          ? BankAccount.fromJson(data['bank_account'] as Map<String, dynamic>)
          : BankAccount(receivedAmount: 0.0, sentAmount: 0.0),
      cashAccount: data['cash_account'] != null
          ? CashAccount.fromJson(data['cash_account'] as Map<String, dynamic>)
          : CashAccount(receivedAmount: 0.0, sentAmount: 0.0),
      products: data['products'] != null
          ? ProductsData.fromJson(data['products'] as Map<String, dynamic>)
          : ProductsData(total: 0, addedToday: 0, addedWeek: 0, addedMonth: 0),
      revenue: data['revenue'] != null
          ? RevenueData.fromJson(data['revenue'] as Map<String, dynamic>)
          : RevenueData(totalSales: 0.0),
      customers: data['customers'] != null
          ? CustomersData.fromJson(data['customers'] as Map<String, dynamic>)
          : CustomersData(newCustomers: 0, totalCustomers: 0),
      orders: data['orders'] != null
          ? OrdersData.fromJson(data['orders'] as Map<String, dynamic>)
          : OrdersData(newOrders: 0, totalOrders: 0),
    );
  }
}

class BankAccount {
  final double receivedAmount;
  final double sentAmount;

  BankAccount({
    required this.receivedAmount,
    required this.sentAmount,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};

    // Handle both int and double values
    double parseAmount(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return BankAccount(
      receivedAmount: parseAmount(data['received_amount']),
      sentAmount: parseAmount(data['sent_amount']),
    );
  }
}

class CashAccount {
  final double receivedAmount;
  final double sentAmount;

  CashAccount({
    required this.receivedAmount,
    required this.sentAmount,
  });

  factory CashAccount.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};

    // Handle both int and double values
    double parseAmount(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return CashAccount(
      receivedAmount: parseAmount(data['received_amount']),
      sentAmount: parseAmount(data['sent_amount']),
    );
  }
}

class ProductsData {
  final int total;
  final int addedToday;
  final int addedWeek;
  final int addedMonth;

  ProductsData({
    required this.total,
    required this.addedToday,
    required this.addedWeek,
    required this.addedMonth,
  });

  factory ProductsData.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};

    return ProductsData(
      total: data['total'] as int? ?? 0,
      addedToday: data['added_today'] as int? ?? 0,
      addedWeek: data['added_week'] as int? ?? 0,
      addedMonth: data['added_month'] as int? ?? 0,
    );
  }
}

class RevenueData {
  final double totalSales;

  RevenueData({
    required this.totalSales,
  });

  factory RevenueData.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};

    // Handle both int and double values
    double parseAmount(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return RevenueData(
      totalSales: parseAmount(data['total_sales']),
    );
  }
}

class CustomersData {
  final int newCustomers;
  final int totalCustomers;

  CustomersData({
    required this.newCustomers,
    required this.totalCustomers,
  });

  factory CustomersData.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};

    return CustomersData(
      newCustomers: data['new_customers'] as int? ?? 0,
      totalCustomers: data['total_customers'] as int? ?? 0,
    );
  }
}

class OrdersData {
  final int newOrders;
  final int totalOrders;

  OrdersData({
    required this.newOrders,
    required this.totalOrders,
  });

  factory OrdersData.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};

    return OrdersData(
      newOrders: data['new_orders'] as int? ?? 0,
      totalOrders: data['total_orders'] as int? ?? 0,
    );
  }
}

class OrdersPerMonth {
  final List<MonthlyData> ordersPerMonth;

  OrdersPerMonth({
    required this.ordersPerMonth,
  });

  factory OrdersPerMonth.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};
    final ordersData = data['orders_per_month'] as List? ?? [];

    return OrdersPerMonth(
      ordersPerMonth: ordersData
          .map((item) => MonthlyData.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CustomersPerMonth {
  final List<MonthlyData> customersPerMonth;

  CustomersPerMonth({
    required this.customersPerMonth,
  });

  factory CustomersPerMonth.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};
    final customersData = data['customers_per_month'] as List? ?? [];

    return CustomersPerMonth(
      customersPerMonth: customersData
          .map((item) => MonthlyData.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MonthlyData {
  final String month;
  final int count;

  MonthlyData({
    required this.month,
    required this.count,
  });

  factory MonthlyData.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};

    return MonthlyData(
      month: data['month'] as String? ?? '',
      count: data['count'] as int? ?? 0,
    );
  }
}

class ExecutivesOverview {
  final int totalExecutives;
  final List<SalesExecutiveGraph> salesExecutivesGraph;

  ExecutivesOverview({
    required this.totalExecutives,
    required this.salesExecutivesGraph,
  });

  factory ExecutivesOverview.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};
    final executivesData = data['sales_executives_graph'] as List? ?? [];

    return ExecutivesOverview(
      totalExecutives: data['total_executives'] as int? ?? 0,
      salesExecutivesGraph: executivesData
          .map((item) =>
              SalesExecutiveGraph.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SalesExecutiveGraph {
  final int executiveId;
  final String executiveName;
  final List<SalesData> sales;

  SalesExecutiveGraph({
    required this.executiveId,
    required this.executiveName,
    required this.sales,
  });

  factory SalesExecutiveGraph.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};
    final salesData = data['sales'] as List? ?? [];

    return SalesExecutiveGraph(
      executiveId: data['executive_id'] as int? ?? 0,
      executiveName: data['executive_name'] as String? ?? '',
      sales: salesData
          .map((item) => SalesData.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SalesData {
  final String date;
  final int amount;

  SalesData({
    required this.date,
    required this.amount,
  });

  factory SalesData.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};

    return SalesData(
      date: data['date'] as String? ?? '',
      amount: data['amount'] as int? ?? 0,
    );
  }
}

class SalesGraph {
  final String period;
  final List<GraphDataPoint> salesGraph;
  final int totalSales;

  SalesGraph({
    required this.period,
    required this.salesGraph,
    required this.totalSales,
  });

  factory SalesGraph.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};
    final graphData = data['sales_graph'] as List? ?? [];

    return SalesGraph(
      period: data['period'] as String? ?? '',
      salesGraph: graphData
          .map((item) => GraphDataPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalSales: data['total_sales'] as int? ?? 0,
    );
  }
}

class GraphDataPoint {
  final String? time;
  final String? day;
  final String? date;
  final int amount;

  GraphDataPoint({
    this.time,
    this.day,
    this.date,
    required this.amount,
  });

  factory GraphDataPoint.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};

    return GraphDataPoint(
      time: data['time'] as String?,
      day: data['day'] as String?,
      date: data['date'] as String?,
      amount: data['amount'] as int? ?? 0,
    );
  }
}

// Supplier Dashboard Models

class SuppliersOverview {
  final String period;
  final SupplierData suppliers;
  final PurchaseData purchases;

  SuppliersOverview({
    required this.period,
    required this.suppliers,
    required this.purchases,
  });

  factory SuppliersOverview.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};

    return SuppliersOverview(
      period: data['period'] as String? ?? '',
      suppliers: data['suppliers'] != null
          ? SupplierData.fromJson(data['suppliers'] as Map<String, dynamic>)
          : SupplierData(totalSuppliers: 0, newSuppliers: 0),
      purchases: data['purchases'] != null
          ? PurchaseData.fromJson(data['purchases'] as Map<String, dynamic>)
          : PurchaseData(totalPurchaseAmount: 0.0),
    );
  }
}

class SupplierData {
  final int totalSuppliers;
  final int newSuppliers;

  SupplierData({
    required this.totalSuppliers,
    required this.newSuppliers,
  });

  factory SupplierData.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};

    return SupplierData(
      totalSuppliers: data['total_suppliers'] as int? ?? 0,
      newSuppliers: data['new_suppliers'] as int? ?? 0,
    );
  }
}

class PurchaseData {
  final double totalPurchaseAmount;

  PurchaseData({
    required this.totalPurchaseAmount,
  });

  factory PurchaseData.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};

    // Handle both int and double values
    double parseAmount(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return PurchaseData(
      totalPurchaseAmount: parseAmount(data['total_purchase_amount']),
    );
  }
}

class SuppliersPurchaseGraph {
  final String period;
  final List<PurchaseGraphData> purchaseGraph;
  final double totalPurchase;

  SuppliersPurchaseGraph({
    required this.period,
    required this.purchaseGraph,
    required this.totalPurchase,
  });

  factory SuppliersPurchaseGraph.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};
    final graphData = data['purchase_graph'] as List? ?? [];

    // Handle both int and double values for total_purchase
    double parseAmount(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return SuppliersPurchaseGraph(
      period: data['period'] as String? ?? '',
      purchaseGraph: graphData
          .map((item) =>
              PurchaseGraphData.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalPurchase: parseAmount(data['total_purchase']),
    );
  }
}

class PurchaseGraphData {
  final String supplierName;
  final double amount;

  PurchaseGraphData({
    required this.supplierName,
    required this.amount,
  });

  factory PurchaseGraphData.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};

    // Handle both int and double values
    double parseAmount(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return PurchaseGraphData(
      supplierName: data['supplier_name'] as String? ?? '',
      amount: parseAmount(data['amount']),
    );
  }
}

class SupplierTransactionsGraph {
  final String period;
  final List<TransactionGraphData> transactionsGraph;
  final double totalReceived;
  final double totalPaid;

  SupplierTransactionsGraph({
    required this.period,
    required this.transactionsGraph,
    required this.totalReceived,
    required this.totalPaid,
  });

  factory SupplierTransactionsGraph.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};
    final graphData = data['transactions_graph'] as List? ?? [];

    // Handle both int and double values
    double parseAmount(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return SupplierTransactionsGraph(
      period: data['period'] as String? ?? '',
      transactionsGraph: graphData
          .map((item) =>
              TransactionGraphData.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalReceived: parseAmount(data['total_received']),
      totalPaid: parseAmount(data['total_paid']),
    );
  }
}

class TransactionGraphData {
  final String? date;
  final String? day;
  final String? time;
  final double receivedAmount;
  final double paidAmount;

  TransactionGraphData({
    this.date,
    this.day,
    this.time,
    required this.receivedAmount,
    required this.paidAmount,
  });

  factory TransactionGraphData.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};

    // Handle both int and double values
    double parseAmount(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return TransactionGraphData(
      date: data['date'] as String?,
      day: data['day'] as String?,
      time: data['time'] as String?,
      receivedAmount: parseAmount(data['received_amount']),
      paidAmount: parseAmount(data['paid_amount']),
    );
  }
}

class SupplierCreditBalanceGraph {
  final String period;
  final List<CreditBalanceGraphData> creditBalanceGraph;
  final double totalCredit;
  final double totalBalance;

  SupplierCreditBalanceGraph({
    required this.period,
    required this.creditBalanceGraph,
    required this.totalCredit,
    required this.totalBalance,
  });

  factory SupplierCreditBalanceGraph.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};
    final graphData = data['credit_balance_graph'] as List? ?? [];

    // Handle both int and double values
    double parseAmount(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return SupplierCreditBalanceGraph(
      period: data['period'] as String? ?? '',
      creditBalanceGraph: graphData
          .map((item) =>
              CreditBalanceGraphData.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalCredit: parseAmount(data['total_credit']),
      totalBalance: parseAmount(data['total_balance']),
    );
  }
}

class CreditBalanceGraphData {
  final String? time;
  final String? day;
  final String? date;
  final double creditAmount;
  final double balanceAmount;

  CreditBalanceGraphData({
    this.time,
    this.day,
    this.date,
    required this.creditAmount,
    required this.balanceAmount,
  });

  factory CreditBalanceGraphData.fromJson(Map<String, dynamic> json) {
    // Add null safety checks
    final data = json as Map<String, dynamic>? ?? {};

    // Handle both int and double values
    double parseAmount(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return CreditBalanceGraphData(
      time: data['time'] as String?,
      day: data['day'] as String?,
      date: data['date'] as String?,
      creditAmount: parseAmount(data['credit_amount']),
      balanceAmount: parseAmount(data['balance_amount']),
    );
  }
}
