// Main model for the API response
class ListInvoiceModel {
  final String status;
  final String message;
  final InvoiceData data;

  ListInvoiceModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory ListInvoiceModel.fromJson(Map<String, dynamic> json) {
    return ListInvoiceModel(
      status: json['status'] ?? 'unknown', // Use a default value
      message: json['message'] ?? 'No message', // Use a default value
      data: InvoiceData.fromJson(json['data'] ?? {}), // Handle null data
    );
  }
}

// Model to represent the data section in the response
class InvoiceData {
  final int currentPage;
  final List<Invoice> invoices;
  final String firstPageUrl;
  final String lastPageUrl;
  final int lastPage;
  final int total;

  InvoiceData({
    required this.currentPage,
    required this.invoices,
    required this.firstPageUrl,
    required this.lastPageUrl,
    required this.lastPage,
    required this.total,
  });

  factory InvoiceData.fromJson(Map<String, dynamic> json) {
    var invoiceList =
        json['data'] as List? ?? []; // Default to empty list if null
    List<Invoice> invoices =
        invoiceList.map((i) => Invoice.fromJson(i)).toList();

    return InvoiceData(
      currentPage: json['current_page'] ?? 1, // Default to 1 if null
      invoices: invoices,
      firstPageUrl: json['first_page_url'] ?? '', // Default to empty string
      lastPageUrl: json['last_page_url'] ?? '', // Default to empty string
      lastPage: json['last_page'] ?? 1, // Default to 1 if null
      total: json['total'] ?? 0, // Default to 0 if null
    );
  }
}

// Model for an individual invoice
class Invoice {
  final int id;
  final int? userId;
  final int customerId;
  final int? transactionId;
  final String invoiceNumber;
  final String type;
  final int companyId;
  final String amount;
  final String invoiceDate;
  final String dueDate;
  final String? totalDiscount;
  final String? discountType;
  final String? discountRemarks;
  final String? paymentMethod;
  final String? totalTax;
  final String status;
  final int createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? zatcaRequestStatus;
  final String? zatcaStatus;
  final String? paidAmount;
  final dynamic balanceAmount;
  final Customer customer;
  final List<dynamic>? zatcaInvoices;

  Invoice({
    required this.id,
    this.userId,
    required this.customerId,
    this.transactionId,
    required this.invoiceNumber,
    required this.type,
    required this.companyId,
    required this.amount,
    required this.invoiceDate,
    required this.dueDate,
    this.totalDiscount,
    this.discountType,
    this.discountRemarks,
    this.paymentMethod,
    this.totalTax,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.zatcaRequestStatus,
    this.zatcaStatus,
    this.paidAmount,
    this.balanceAmount,
    required this.customer,
    this.zatcaInvoices,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] ?? 0,
      userId: json['user_id'],
      customerId: json['customer_id'] ?? 0,
      transactionId: json['transaction_id'],
      invoiceNumber: json['invoice_number'] ?? '',
      type: json['type'] ?? '',
      companyId: json['company_id'] ?? 0,
      amount: json['amount'] ?? '0.00',
      invoiceDate: json['invoice_date'] ?? '',
      dueDate: json['due_date'] ?? '',
      totalDiscount: json['total_discount']?.toString(),
      discountType: json['discount_type']?.toString(),
      discountRemarks: json['discount_remarks']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      totalTax: json['total_tax']?.toString(),
      status: json['status'] ?? '',
      createdBy: json['created_by'] ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      zatcaRequestStatus: json['zatca_request_status']?.toString(),
      zatcaStatus: json['zatca_status']?.toString(),
      paidAmount: json['paid_amount']?.toString(),
      balanceAmount: json['balance_amount'],
      customer: Customer.fromJson(json['customer'] ?? {}),
      zatcaInvoices: json['zatca_invoices'] as List<dynamic>?,
    );
  }
}

// Model for customer details
class Customer {
  final int id;
  final int? userId;
  final String? dob;
  final String? gender;
  final String? altPhone;
  final String? profileImage;
  final String? balance;
  final String? paymentType;
  final int? storeId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final User user;

  Customer({
    required this.id,
    this.userId,
    this.dob,
    this.gender,
    this.altPhone,
    this.profileImage,
    this.balance,
    this.paymentType,
    this.storeId,
    required this.createdAt,
    required this.updatedAt,
    required this.user,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? 0, // Default to 0 if null
      userId: json['user_id'], // This can remain nullable
      dob: json['dob'] ?? '', // Default to empty string
      gender: json['gender'] ?? '', // Default to empty string
      altPhone: json['alt_phone'] ?? '', // Default to empty string
      profileImage: json['profile_image'] ?? '', // Default to empty string
      balance: json['balance']?.toString(), // Parse balance from API
      paymentType: json['payment_type']?.toString(), // Parse payment type from API
      storeId: json['store_id'] ?? 0, // Default to 0 if null
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      user: User.fromJson(json['user'] ?? {}), // Handle null user
    );
  }
}

// Model for user details
class User {
  final int id;
  final String name;
  final String email;
  final String phone;
  final int phoneVerified;
  final int? companyId;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.phoneVerified,
    this.companyId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0, // Default to 0 if null
      name: json['name'] ?? '', // Default to empty string
      email: json['email'] ?? '', // Default to empty string
      phone: json['phone'] ?? '', // Default to empty string
      phoneVerified: json['phone_verified'] ?? 0, // Default to 0 if null
      companyId: json['company_id'], // This can remain nullable
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }
}
