import 'package:flutter/foundation.dart';

// Main Response Class
class ReceiptResponse {
  String status;
  String message;
  ReceiptData data;

  ReceiptResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory ReceiptResponse.fromJson(Map<String, dynamic> json) {
    debugPrint("🔍 ReceiptResponse.fromJson called with: ${json.toString()}");
    debugPrint("🔍 Status: ${json['status']}");
    debugPrint("🔍 Message: ${json['message']}");
    debugPrint("🔍 Data: ${json['data']}");
    
    return ReceiptResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      data: ReceiptData.fromJson(json['data']),
    );
  }
}

class ReceiptPayment {
  int id;
  int receiptId;
  int? invoiceId;
  int? transactionId;
  String paymentMethod;
  String paidAmount;
  String status;
  String paymentDate;
  String? description;
  int? updatedBy;
  DateTime createdAt;
  DateTime updatedAt;

  ReceiptPayment({
    required this.id,
    required this.receiptId,
    this.invoiceId,
    this.transactionId,
    required this.paymentMethod,
    required this.paidAmount,
    required this.status,
    required this.paymentDate,
    this.description,
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReceiptPayment.fromJson(Map<String, dynamic> json) {
    return ReceiptPayment(
      id: json['id'] ?? 0,
      receiptId: json['receipt_id'] ?? 0,
      invoiceId: json['invoice_id'],
      transactionId: json['transaction_id'],
      paymentMethod: json['payment_method']?.toString() ?? '',
      paidAmount: json['paid_amount']?.toString() ?? '0',
      status: json['status']?.toString() ?? '',
      paymentDate: json['payment_date']?.toString() ?? '',
      description: json['description']?.toString(),
      updatedBy: json['updated_by'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

// Data Class for Pagination and Receipts
class ReceiptData {
  int currentPage;
  List<Receipt> data;
  String firstPageUrl;
  int from;
  int lastPage;
  String lastPageUrl;
  List<PageLink> links;
  String? nextPageUrl;
  String path;
  int perPage;
  String? prevPageUrl;
  int to;
  int total;

  ReceiptData({
    required this.currentPage,
    required this.data,
    required this.firstPageUrl,
    required this.from,
    required this.lastPage,
    required this.lastPageUrl,
    required this.links,
    this.nextPageUrl,
    required this.path,
    required this.perPage,
    this.prevPageUrl,
    required this.to,
    required this.total,
  });

  factory ReceiptData.fromJson(Map<String, dynamic> json) {
    debugPrint("🔍 ReceiptData.fromJson called with: ${json.toString()}");
    var list = json['data'] as List;
    List<Receipt> receiptsList =
        list.map((receipt) => Receipt.fromJson(receipt)).toList();

    var linksList = json['links'] as List;
    List<PageLink> links =
        linksList.map((link) => PageLink.fromJson(link)).toList();

    return ReceiptData(
      currentPage: json['current_page'] ?? 1,
      data: receiptsList,
      firstPageUrl: json['first_page_url'] ?? '',
      from: json['from'] ?? 1,
      lastPage: json['last_page'] ?? 1,
      lastPageUrl: json['last_page_url'] ?? '',
      links: links,
      nextPageUrl: json['next_page_url'],
      path: json['path'] ?? '',
      perPage: json['per_page'] ?? 20,
      prevPageUrl: json['prev_page_url'],
      to: json['to'] ?? 0,
      total: json['total'] ?? 0,
    );
  }
}

// Receipt Class
class Receipt {
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

  Receipt({
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

  factory Receipt.fromJson(Map<String, dynamic> json) {
    debugPrint("🔍 Receipt.fromJson called with: ${json.toString()}");
    final paymentsJson = (json['receipt_payments'] as List?) ?? [];
    final payments = paymentsJson
        .map((e) => ReceiptPayment.fromJson(e as Map<String, dynamic>))
        .toList();
    return Receipt(
      id: json['id'] ?? 0,
      receiptNumber: json['receipt_number'] ?? '',
      amount: json['amount'] ?? '0',
      receiptStatus: json['receipt_status'] ?? '',
      paymentReference: json['payment_reference'] ?? '',
      paymentMethod: _parsePaymentMethod(json['payment_method']),
      userId: json['user_id'],
      customerId: json['customer_id'] ?? 0,
      companyId: json['company_id'] ?? 0,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      company: Company.fromJson(json['company'] ?? {}),
      customer: Customer.fromJson(json['customer'] ?? {}),
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
    debugPrint("🔍 Company.fromJson called with: ${json.toString()}");
    return Company(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      webUrl: json['web_url'] ?? '',
      verified: json['verified'] ?? 0,
      status: json['status'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      deletedAt: json['deleted_at'],
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
  String? balance;
  String? paymentType;
  String? customerType;
  int? storeId;
  int? companyId;
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
    this.balance,
    this.paymentType,
    this.customerType,
    this.storeId,
    this.companyId,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.user,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    debugPrint("🔍 Customer.fromJson called with: ${json.toString()}");
    return Customer(
      id: json['id'] ?? 0,
      dob: json['dob'],
      gender: json['gender'],
      userId: json['user_id'],
      altPhone: json['alt_phone'],
      profileImage: json['profile_image'],
      balance: json['balance'],
      paymentType: json['payment_type'],
      customerType: json['customer_type'],
      storeId: json['store_id'],
      companyId: json['company_id'],
      deletedAt: json['deleted_at'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      user: User.fromJson(json['user'] ?? {}),
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
  int? companyId;
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
    debugPrint("🔍 User.fromJson called with: ${json.toString()}");
    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      emailVerifiedAt: json['email_verified_at'],
      phoneVerified: json['phone_verified'] ?? 0,
      companyId: json['company_id'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

// PageLink Class for Pagination Links
class PageLink {
  String? url;
  String label;
  bool active;

  PageLink({
    this.url,
    required this.label,
    required this.active,
  });

  factory PageLink.fromJson(Map<String, dynamic> json) {
    return PageLink(
      url: json['url'],
      label: json['label'],
      active: json['active'],
    );
  }
}
