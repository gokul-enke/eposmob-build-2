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
    var itemsJson = json['invoice_items'] as List;
    List<InvoiceItem> itemsList =
        itemsJson.map((item) => InvoiceItem.fromJson(item)).toList();

    return InvoiceDetails(
      id: json['id'],
      userId: json['user_id'],
      customerId: json['customer_id'],
      invoiceNumber: json['invoice_number'],
      type: json['type'],
      companyId: json['company_id'],
      amount: json['amount'],
      invoiceDate: json['invoice_date'],
      dueDate: json['due_date'],
      status: json['status'],
      createdBy: json['created_by'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
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

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      userId: json['user_id'],
      name: json['user']['name'],
      email: json['user']['email'],
      phone: json['user']['phone'],
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
      id: json['id'],
      invoiceId: json['invoice_id'],
      itemName: json['item_name'],
      quantity: json['quantity'],
      unitAmount: json['unit_amount'],
      tax: json['tax'],
      totalAmount: json['total_amount'],
    );
  }
}
