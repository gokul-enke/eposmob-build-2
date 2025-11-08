class CustomerVoucherModel {
  final bool status;
  final String message;
  final List<CustomerVoucher> data;

  CustomerVoucherModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory CustomerVoucherModel.fromJson(Map<String, dynamic> json) {
    return CustomerVoucherModel(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
      data: (json['data'] as List?)
              ?.map((item) => CustomerVoucher.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class CustomerVoucher {
  final int id;
  final String voucherNumber;
  final String voucherDate;
  final String dueDate;
  final int? invoiceId;
  final int companyId;
  final int? transactionId;
  final String type;
  final String amount;
  final String status;
  final String paymentMethod;
  final int userId;
  final int customerId;
  final String createdAt;
  final String updatedAt;
  final VoucherCustomer customer;
  final List<VoucherItem> items;

  CustomerVoucher({
    required this.id,
    required this.voucherNumber,
    required this.voucherDate,
    required this.dueDate,
    this.invoiceId,
    required this.companyId,
    this.transactionId,
    required this.type,
    required this.amount,
    required this.status,
    required this.paymentMethod,
    required this.userId,
    required this.customerId,
    required this.createdAt,
    required this.updatedAt,
    required this.customer,
    required this.items,
  });

  factory CustomerVoucher.fromJson(Map<String, dynamic> json) {
    return CustomerVoucher(
      id: json['id'] ?? 0,
      voucherNumber: json['voucher_number'] ?? '',
      voucherDate: json['voucher_date'] ?? '',
      dueDate: json['due_date'] ?? '',
      invoiceId: json['invoice_id'],
      companyId: json['company_id'] ?? 0,
      transactionId: json['transaction_id'],
      type: json['type'] ?? '',
      amount: json['amount'] ?? '0',
      status: json['status'] ?? '',
      paymentMethod: json['payment_method'] ?? '',
      userId: json['user_id'] ?? 0,
      customerId: json['customer_id'] ?? 0,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      customer: VoucherCustomer.fromJson(json['customer'] ?? {}),
      items: (json['items'] as List?)
              ?.map((item) => VoucherItem.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class VoucherCustomer {
  final int id;
  final int userId;
  final String paymentType;
  final int storeId;
  final int companyId;
  final VoucherUser user;

  VoucherCustomer({
    required this.id,
    required this.userId,
    required this.paymentType,
    required this.storeId,
    required this.companyId,
    required this.user,
  });

  factory VoucherCustomer.fromJson(Map<String, dynamic> json) {
    return VoucherCustomer(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      paymentType: json['payment_type'] ?? '',
      storeId: json['store_id'] ?? 0,
      companyId: json['company_id'] ?? 0,
      user: VoucherUser.fromJson(json['user'] ?? {}),
    );
  }
}

class VoucherUser {
  final int id;
  final String name;
  final String? email;
  final String phone;
  final bool isAdmin;
  final String createdAt;
  final String updatedAt;

  VoucherUser({
    required this.id,
    required this.name,
    this.email,
    required this.phone,
    required this.isAdmin,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VoucherUser.fromJson(Map<String, dynamic> json) {
    return VoucherUser(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'],
      phone: json['phone'] ?? '',
      isAdmin: json['is_admin'] ?? false,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }
}

class VoucherItem {
  final int id;
  final int voucherId;
  final String itemName;
  final String quantity;
  final String unitAmount;
  final String tax;
  final String totalAmount;
  final String createdAt;
  final String updatedAt;

  VoucherItem({
    required this.id,
    required this.voucherId,
    required this.itemName,
    required this.quantity,
    required this.unitAmount,
    required this.tax,
    required this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VoucherItem.fromJson(Map<String, dynamic> json) {
    return VoucherItem(
      id: json['id'] ?? 0,
      voucherId: json['voucher_id'] ?? 0,
      itemName: json['item_name'] ?? '',
      quantity: json['quantity'] ?? '0',
      unitAmount: json['unit_amount'] ?? '0',
      tax: json['tax'] ?? '0',
      totalAmount: json['total_amount'] ?? '0',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }
}
