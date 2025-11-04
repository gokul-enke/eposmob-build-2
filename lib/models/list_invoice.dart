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
  final String invoiceNumber;
  final String type;
  final int companyId;
  final String amount;
  final String invoiceDate;
  final String dueDate;
  final String status;
  final int createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Customer customer;
  final String? zatcaStatus;

  Invoice({
    required this.id,
    this.userId,
    required this.customerId,
    required this.invoiceNumber,
    required this.type,
    required this.companyId,
    required this.amount,
    required this.invoiceDate,
    required this.dueDate,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.customer,
    this.zatcaStatus,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] ?? 0, // Default to 0 if null
      userId: json['user_id'], // This can remain nullable
      customerId: json['customer_id'] ?? 0, // Default to 0 if null
      invoiceNumber: json['invoice_number'] ?? '',
      type: json['type'] ?? '',
      companyId: json['company_id'] ?? 0, // Default to 0 if null
      amount: json['amount'] ?? '0.00', // Default to '0.00' if null
      invoiceDate: json['invoice_date'] ?? '',
      dueDate: json['due_date'] ?? '',
      status: json['status'] ?? '',
      createdBy: json['created_by'] ?? 0, // Default to 0 if null
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      customer:
          Customer.fromJson(json['customer'] ?? {}), // Handle null customer
      zatcaStatus: json['zatca_status']?.toString(),
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
