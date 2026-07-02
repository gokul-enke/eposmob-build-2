class InvoiceDetails {
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
  final String createdAt;
  final String updatedAt;
  
  final Customer customer;
  final Company company;
  final List<InvoiceItem> invoiceItems;

  InvoiceDetails({
    required this.id,
    required this.userId,
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
     required this.company,
    required this.invoiceItems,
  });

  factory InvoiceDetails.fromJson(Map<String, dynamic> json) {
    var itemsJson = json['invoice_items'] as List? ?? [];
    List<InvoiceItem> itemsList =
        itemsJson.map((item) => InvoiceItem.fromJson(item)).toList();

    return InvoiceDetails(
      id: json['id'] ?? 0,
      userId: json['user_id'],
      customerId: json['customer_id'] ?? 0,
      invoiceNumber: json['invoice_number']?.toString() ?? "",
      type: json['type']?.toString() ?? "",
      companyId: json['company_id'] ?? 0,
      amount: json['amount']?.toString() ?? "0.00",
      invoiceDate: json['invoice_date']?.toString() ?? "",
      dueDate: json['due_date']?.toString() ?? "",
      status: json['status']?.toString() ?? "",
      createdBy: json['created_by'] ?? 0,
      createdAt: json['created_at']?.toString() ?? "",
      updatedAt: json['updated_at']?.toString() ?? "",
      company: Company.fromJson(json['company'] ?? {}),
      customer: Customer.fromJson(json['customer']),
      invoiceItems: itemsList,
    );
  }
}


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



class Customer {
  final int id;
  final int? userId;
  final String name;
  final String email;
  final String phone;

  Customer({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
  });

  factory Customer.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return Customer(
        id: 0,
        userId: null,
        name: "Walk-in Customer",
        email: "",
        phone: "",
      );
    }
    final userMap = json['user'] as Map<String, dynamic>?;
    return Customer(
      id: json['id'] ?? 0,
      userId: json['user_id'],
      name: userMap != null ? (userMap['name']?.toString() ?? "Walk-in Customer") : "Walk-in Customer",
      email: userMap != null ? (userMap['email']?.toString() ?? "") : "",
      phone: userMap != null ? (userMap['phone']?.toString() ?? "") : "",
    );
  }
}

class InvoiceItem {
  final int id;
  final int invoiceId;
  final String itemName;
  final int quantity;
  final String unitAmount;
  final String tax;
  final String totalAmount;

  InvoiceItem({
    required this.id,
    required this.invoiceId,
    required this.itemName,
    required this.quantity,
    required this.unitAmount,
    required this.tax,
    required this.totalAmount,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      id: json['id'] ?? 0,
      invoiceId: json['invoice_id'] ?? 0,
      itemName: json['item_name']?.toString() ?? "",
      quantity: json['quantity'] ?? 0,
      unitAmount: json['unit_amount']?.toString() ?? "0.00",
      tax: json['tax']?.toString() ?? "0.00",
      totalAmount: json['total_amount']?.toString() ?? "0.00",
    );
  }
}