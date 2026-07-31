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
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      data: (json['data'] as List<dynamic>?)
              ?.map((item) => Supplier.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class SupplierKyc {
  final String key;
  final String value;

  const SupplierKyc({
    required this.key,
    required this.value,
  });

  factory SupplierKyc.fromJson(Map<String, dynamic> json) {
    return SupplierKyc(
      key: json['key']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
      };
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
      date: json['date']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      transactionType: json['transaction_type']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0.000',
      currency: json['currency']?.toString() ?? 'INR',
      reference: json['reference']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
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
      productName: json['product_name']?.toString() ?? '',
      quantity: json['quantity']?.toString() ?? '0.00',
      unitPrice: json['unit_price']?.toString() ?? '0.000',
      totalPrice: json['total_price']?.toString() ?? '0.000',
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
      purchaseNumber: json['purchase_number']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      amountTotal: json['amount_total']?.toString() ?? '0.000',
      taxTotal: json['tax_total']?.toString(),
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
  final String? taxNumber;
  final String? crNumber;
  final String? vatNumber;
  final List<SupplierKyc> kyc;
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
    this.taxNumber,
    this.crNumber,
    this.vatNumber,
    this.kyc = const [],
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

    // Parse KYC entries returned by the supplier API.
    List<SupplierKyc> kycList = [];
    if (json['kyc'] is List) {
      kycList = (json['kyc'] as List)
          .whereType<Map>()
          .map((item) => SupplierKyc.fromJson(
                Map<String, dynamic>.from(item),
              ))
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
      name: json['name']?.toString() ?? userData['name']?.toString() ?? '',
      email: json['email']?.toString() ?? userData['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? userData['phone']?.toString() ?? '',
      altPhone: json['alt_phone']?.toString(),
      taxNumber: json['tax_number']?.toString(),
      crNumber: json['cr_number']?.toString(),
      vatNumber: json['vat_number']?.toString(),
      kyc: kycList,
      productCategories: productCategoriesStr,
      address: json['address']?.toString() ?? '',
      balance: parseBalance(json['balance']),
      paymentType: json['payment_type']?.toString() ?? 'to_pay',
      companyId: json['company_id'] ?? 0,
      currentBalance: parseBalance(json['current_balance']),
      balanceStatus: json['balance_status']?.toString() ?? '',
      userId: json['user_id'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      transactions: transactionsList,
      purchases: purchasesList,
    );
  }
}
