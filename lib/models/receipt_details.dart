// ReceiptDetails Model
class ReceiptDetails {
  String status;
  String message;
  ReceiptData data;

  ReceiptDetails({
    required this.status,
    required this.message,
    required this.data,
  });

  factory ReceiptDetails.fromJson(Map<String, dynamic> json) {
    return ReceiptDetails(
      status: json['status'] ?? "", // Default to empty string
      message: json['message'] ?? "", // Default to empty string
      data: ReceiptData.fromJson(json['data'] ?? {}), // Handle null case
    );
  }
}

// ReceiptData Class
class ReceiptData {
  int id;
  String receiptNumber;
  String amount;
  String receiptStatus;
  String paymentReference;
  String paymentMethod;
  int? userId;
  int customerId;
  int companyId;
  DateTime createdAt;
  DateTime updatedAt;
  Company company;
  Customer customer;
  List<ReceiptPayment> receiptPayments;

  ReceiptData({
    required this.id,
    required this.receiptNumber,
    required this.amount,
    required this.receiptStatus,
    required this.paymentReference,
    required this.paymentMethod,
    this.userId,
    required this.customerId,
    required this.companyId,
    required this.createdAt,
    required this.updatedAt,
    required this.company,
    required this.customer,
    required this.receiptPayments,
  });

  factory ReceiptData.fromJson(Map<String, dynamic> json) {
    var paymentsList =
        json['receipt_payments'] as List? ?? []; // Default to empty list
    List<ReceiptPayment> payments = paymentsList
        .map((payment) => ReceiptPayment.fromJson(payment))
        .toList();

    return ReceiptData(
      id: json['id'] ?? 0, // Default to 0 if null
      receiptNumber: json['receipt_number'] ?? "", // Default to empty string
      amount: json['amount'] ?? "0.0", // Default to "0.0"
      receiptStatus: json['receipt_status'] ?? "", // Default to empty string
      paymentReference:
          json['payment_reference'] ?? "", // Default to empty string
      paymentMethod: _parsePaymentMethod(json['payment_method']), // Handle both String and List
      userId: json['user_id'], // Keep as nullable
      customerId: json['customer_id'] ?? 0, // Default to 0 if null
      companyId: json['company_id'] ?? 0, // Default to 0 if null
      createdAt: DateTime.parse(json['created_at'] ??
          DateTime.now().toIso8601String()), // Default to current time
      updatedAt: DateTime.parse(json['updated_at'] ??
          DateTime.now().toIso8601String()), // Default to current time
      company: Company.fromJson(json['company'] ?? {}), // Handle null case
      customer: Customer.fromJson(json['customer'] ?? {}), // Handle null case
      receiptPayments: payments,
    );
  }

  // Helper method to handle payment_method which can be String or List<String>
  static String _parsePaymentMethod(dynamic paymentMethod) {
    if (paymentMethod == null) return "";
    if (paymentMethod is String) return paymentMethod;
    if (paymentMethod is List && paymentMethod.isNotEmpty) {
      return paymentMethod.join(', ');
    }
    return "";
  }
}

// Company Class
class Company {
  int id;
  String name;
  String code;
  String webUrl;
  int verified;
  String status;
  DateTime createdAt;
  DateTime updatedAt;
  dynamic deletedAt;

  Company({
    required this.id,
    required this.name,
    required this.code,
    required this.webUrl,
    required this.verified,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] ?? 0, // Default to 0 if null
      name: json['name'] ?? "", // Default to empty string
      code: json['code'] ?? "", // Default to empty string
      webUrl: json['web_url'] ?? "", // Default to empty string
      verified: json['verified'] ?? 0, // Default to 0 if null
      status: json['status'] ?? "", // Default to empty string
      createdAt: DateTime.parse(json['created_at'] ??
          DateTime.now().toIso8601String()), // Default to current time
      updatedAt: DateTime.parse(json['updated_at'] ??
          DateTime.now().toIso8601String()), // Default to current time
      deletedAt: json['deleted_at'], // Keep as nullable
    );
  }
}

// Customer Class
class Customer {
  int id;
  dynamic dob;
  dynamic gender;
  int? userId;
  dynamic altPhone;
  dynamic profileImage;
  int? storeId;
  dynamic deletedAt;
  DateTime createdAt;
  DateTime updatedAt;
  User user;

  Customer({
    required this.id,
    this.dob,
    this.gender,
    this.userId,
    this.altPhone,
    this.profileImage,
    this.storeId,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.user,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? 0, // Default to 0 if null
      dob: json['dob'], // Keep as nullable
      gender: json['gender'], // Keep as nullable
      userId: json['user_id'], // Keep as nullable
      altPhone: json['alt_phone'], // Keep as nullable
      profileImage: json['profile_image'], // Keep as nullable
      storeId: json['store_id'], // Keep as nullable
      deletedAt: json['deleted_at'], // Keep as nullable
      createdAt: DateTime.parse(json['created_at'] ??
          DateTime.now().toIso8601String()), // Default to current time
      updatedAt: DateTime.parse(json['updated_at'] ??
          DateTime.now().toIso8601String()), // Default to current time
      user: User.fromJson(json['user'] ?? {}), // Handle null case
    );
  }
}

// User Class
class User {
  int id;
  String name;
  String email;
  String phone;
  dynamic emailVerifiedAt;
  int phoneVerified;
  dynamic companyId;
  DateTime createdAt;
  DateTime updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.emailVerifiedAt,
    required this.phoneVerified,
    this.companyId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0, // Default to 0 if null
      name: json['name'] ?? "", // Default to empty string
      email: json['email'] ?? "", // Default to empty string
      phone: json['phone'] ?? "", // Default to empty string
      emailVerifiedAt: json['email_verified_at'], // Keep as nullable
      phoneVerified: json['phone_verified'] ?? 0, // Default to 0 if null
      companyId: json['company_id'], // Keep as nullable
      createdAt: DateTime.parse(json['created_at'] ??
          DateTime.now().toIso8601String()), // Default to current time
      updatedAt: DateTime.parse(json['updated_at'] ??
          DateTime.now().toIso8601String()), // Default to current time
    );
  }
}

// ReceiptPayment Class
class ReceiptPayment {
  int id;
  int receiptId;
  int invoiceId; // Assuming you still need this field
  String paidAmount;
  String status;
  String paymentDate;
  int updatedBy;
  DateTime createdAt;
  DateTime updatedAt;

  ReceiptPayment({
    required this.id,
    required this.receiptId,
    required this.invoiceId,
    required this.paidAmount,
    required this.status,
    required this.paymentDate,
    required this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReceiptPayment.fromJson(Map<String, dynamic> json) {
    return ReceiptPayment(
      id: json['id'] ?? 0, // Default to 0 if null
      receiptId: json['receipt_id'] ?? 0, // Default to 0 if null
      invoiceId: json['invoice_id'] ?? 0, // Default to 0 if null
      paidAmount: json['paid_amount'] ?? "0.0", // Default to "0.0"
      status: json['status'] ?? "", // Default to empty string
      paymentDate: json['payment_date'] ?? "", // Default to empty string
      updatedBy: json['updated_by'] ?? 0, // Default to 0 if null
      createdAt: DateTime.parse(json['created_at'] ??
          DateTime.now().toIso8601String()), // Default to current time
      updatedAt: DateTime.parse(json['updated_at'] ??
          DateTime.now().toIso8601String()), // Default to current time
    );
  }
}
