class SupplierResponse {
  final String status;
  final String message;
  final List<Supplier> data;

  SupplierResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory SupplierResponse.fromJson(Map<String, dynamic> json) {
    return SupplierResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      data: (json['data'] as List<dynamic>?)
              ?.map((item) => Supplier.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class SupplierTransaction {
  final int id;
  final String date;
  final String paymentMethod;
  final String type; // Credit or Debit
  final String transactionType; // Invoice or Voucher
  final String amount;
  final String currency;
  final String reference;
  final String status;

  SupplierTransaction({
    required this.id,
    required this.date,
    required this.paymentMethod,
    required this.type,
    required this.transactionType,
    required this.amount,
    required this.currency,
    required this.reference,
    required this.status,
  });

  factory SupplierTransaction.fromJson(Map<String, dynamic> json) {
    return SupplierTransaction(
      id: json['id'] ?? 0,
      date: json['date'] ?? '',
      paymentMethod: json['payment_method'] ?? '',
      type: json['type'] ?? '',
      transactionType: json['transaction_type'] ?? '',
      amount: json['amount']?.toString() ?? '0.000',
      currency: json['currency'] ?? 'INR',
      reference: json['reference'] ?? '',
      status: json['status'] ?? '',
    );
  }
}

class PurchaseItem {
  final int id;
  final String productName;
  final String quantity; // Changed to String to match API
  final String unitPrice;
  final String totalPrice;

  PurchaseItem({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory PurchaseItem.fromJson(Map<String, dynamic> json) {
    return PurchaseItem(
      id: json['id'] ?? 0,
      productName: json['product_name'] ?? '',
      quantity: json['quantity']?.toString() ?? '0.00',
      unitPrice: json['unit_price'] ?? '0.000',
      totalPrice: json['total_price'] ?? '0.000',
    );
  }

  // Helper method to get quantity as double for calculations
  double get quantityAsDouble {
    return double.tryParse(quantity) ?? 0.0;
  }
}

class SupplierPurchase {
  final int id;
  final String purchaseNumber;
  final String status;
  final String amountTotal;
  final String? taxTotal;
  final List<PurchaseItem> items;

  SupplierPurchase({
    required this.id,
    required this.purchaseNumber,
    required this.status,
    required this.amountTotal,
    this.taxTotal,
    required this.items,
  });

  factory SupplierPurchase.fromJson(Map<String, dynamic> json) {
    List<PurchaseItem> itemsList = [];
    if (json['items'] != null && json['items'] is List) {
      itemsList = (json['items'] as List)
          .map((item) => PurchaseItem.fromJson(item))
          .toList();
    }

    return SupplierPurchase(
      id: json['id'] ?? 0,
      purchaseNumber: json['purchase_number'] ?? '',
      status: json['status'] ?? '',
      amountTotal: json['amount_total'] ?? '0.000',
      taxTotal: json['tax_total'],
      items: itemsList,
    );
  }
}

class Supplier {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String? altPhone;
  final String productCategories;
  final String address;
  final double balance;
  final String paymentType;
  final int companyId;
  final double currentBalance;
  final String balanceStatus;
  final DateTime? createdAt; // Made optional since API doesn't provide it
  final DateTime? updatedAt; // Made optional since API doesn't provide it
  final int userId;
  final List<SupplierTransaction> transactions;
  final List<SupplierPurchase> purchases;

  Supplier({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.altPhone,
    required this.productCategories,
    required this.address,
    required this.balance,
    required this.paymentType,
    required this.companyId,
    required this.currentBalance,
    required this.balanceStatus,
    this.createdAt, // Made optional
    this.updatedAt, // Made optional
    required this.userId,
    required this.transactions,
    required this.purchases,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    // Handle nested user data structure (fallback to top-level for new API)
    final Map<String, dynamic> userData = json['user'] ?? {};

    // Handle product_categories which might be a List or String
    String productCategoriesStr = '';
    var productCategories = json['product_categories'];
    if (productCategories is List) {
      productCategoriesStr = productCategories.join(', ');
    } else if (productCategories is String) {
      productCategoriesStr = productCategories;
    }

    // Parse transactions
    List<SupplierTransaction> transactionsList = [];
    if (json['transactions'] != null && json['transactions'] is List) {
      transactionsList = (json['transactions'] as List)
          .map((transaction) => SupplierTransaction.fromJson(transaction))
          .toList();
    }

    // Parse purchases
    List<SupplierPurchase> purchasesList = [];
    if (json['purchases'] != null && json['purchases'] is List) {
      purchasesList = (json['purchases'] as List)
          .map((purchase) => SupplierPurchase.fromJson(purchase))
          .toList();
    }

    // Helper function to convert balance to double
    double parseBalance(dynamic value) {
      if (value is num) {
        return value.toDouble();
      } else if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }

    return Supplier(
      id: json['id'] ?? 0,
      // Try top-level first, then fallback to nested user data
      name: json['name'] ?? userData['name'] ?? '',
      email: json['email'] ?? userData['email'] ?? '',
      phone: json['phone'] ?? userData['phone'] ?? '',
      altPhone: json['alt_phone'],
      productCategories: productCategoriesStr,
      address: json['address'] ?? '',
      balance: parseBalance(json['balance']),
      paymentType: json['payment_type'] ?? 'to_pay',
      companyId: json['company_id'] ?? 0,
      currentBalance: parseBalance(json['current_balance']),
      balanceStatus: json['balance_status'] ?? '',
      userId: json['user_id'] ?? 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      transactions: transactionsList,
      purchases: purchasesList,
    );
  }
}