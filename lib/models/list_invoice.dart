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
    final dynamic rawZatcaStatus = json['zatca_status'];
    final Map<String, dynamic>? zatcaStatusMap =
        rawZatcaStatus is Map<String, dynamic>
            ? rawZatcaStatus
            : rawZatcaStatus is Map
                ? Map<String, dynamic>.from(rawZatcaStatus)
                : null;

    final dynamic rawCustomer = json['customer'];
    final Map<String, dynamic> customerJson =
        rawCustomer is Map<String, dynamic>
            ? rawCustomer
            : rawCustomer is Map
                ? Map<String, dynamic>.from(rawCustomer)
                : {
                    'id': json['customer_id'] ?? 0,
                    'user_id': null,
                    'user': {
                      'id': json['customer_id'] ?? 0,
                      'name': json['customer_name']?.toString() ?? '',
                      'email': '',
                      'phone': '',
                    },
                  };

    final String? nestedStatus = zatcaStatusMap?['status']?.toString();
    final String? nestedZatcaStatus =
        zatcaStatusMap?['zatca_status']?.toString();

    String? resolvedRequestStatus = json['zatca_request_status']?.toString();
    String? resolvedZatcaStatus;

    String? normalizeZatcaStatus(String? value) {
      final normalized = value?.trim().toLowerCase();
      switch (normalized) {
        case 'pass':
        case 'success':
        case 'sent':
        case 'reported':
        case 'cleared':
          return 'success';
        case 'failed':
        case 'fail':
          return 'failed';
        case 'pending':
        case 'processing':
          return 'pending';
        default:
          return value;
      }
    }

    if (rawZatcaStatus is String || rawZatcaStatus is num || rawZatcaStatus is bool) {
      resolvedZatcaStatus = normalizeZatcaStatus(rawZatcaStatus.toString());
    } else {
      resolvedZatcaStatus = normalizeZatcaStatus(nestedZatcaStatus);
    }

    if (resolvedRequestStatus == null || resolvedRequestStatus.isEmpty) {
      if (nestedStatus == 'failed' ||
          nestedStatus == 'pending' ||
          nestedStatus == 'processing' ||
          nestedStatus == 'success' ||
          nestedStatus == 'sent') {
        resolvedRequestStatus = nestedStatus;
      }
    }

    if ((resolvedZatcaStatus == null || resolvedZatcaStatus.isEmpty) &&
        (nestedStatus == 'sent' || nestedStatus == 'success')) {
      resolvedZatcaStatus = 'success';
    }

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
      zatcaRequestStatus: resolvedRequestStatus,
      zatcaStatus: resolvedZatcaStatus,
      paidAmount: json['paid_amount']?.toString(),
      balanceAmount: json['balance_amount'],
      customer: Customer.fromJson(customerJson),
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
  final String? customerType;
  final int? storeId;
  final int? companyId;
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
    this.customerType,
    this.storeId,
    this.companyId,
    required this.createdAt,
    required this.updatedAt,
    required this.user,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? 0,
      userId: json['user_id'],
      dob: json['dob']?.toString(),
      gender: json['gender']?.toString(),
      altPhone: json['alt_phone']?.toString(),
      profileImage: json['profile_image']?.toString(),
      balance: json['balance']?.toString(),
      paymentType: json['payment_type']?.toString(),
      customerType: json['customer_type']?.toString(),
      storeId: json['store_id'],
      companyId: json['company_id'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      user: User.fromJson(json['user'] ?? {}),
    );
  }
}

// Model for user details
class User {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String? emailVerifiedAt;
  final int phoneVerified;
  final bool isAdmin;
  final int? companyId;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.emailVerifiedAt,
    required this.phoneVerified,
    required this.isAdmin,
    this.companyId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      emailVerifiedAt: json['email_verified_at']?.toString(),
      phoneVerified: json['phone_verified'] ?? 0,
      isAdmin: json['is_admin'] ?? false,
      companyId: json['company_id'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }
}
