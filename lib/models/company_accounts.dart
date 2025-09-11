import 'dart:convert';

CompanyAccountsModel companyAccountsModelFromJson(String str) =>
    CompanyAccountsModel.fromJson(json.decode(str));

String companyAccountsModelToJson(CompanyAccountsModel data) =>
    json.encode(data.toJson());

class CompanyAccountsModel {
  final String? status;
  final String? message;
  final List<CompanyAccountsData>? data;

  CompanyAccountsModel({
    this.status,
    this.message,
    this.data,
  });

  factory CompanyAccountsModel.fromJson(Map<String, dynamic> json) {
    print('🔍 CompanyAccountsModel.fromJson called with: ${json.toString()}');
    print('🔍 Status: ${json["status"]}');
    print('🔍 Message: ${json["message"]}');
    print('🔍 Data type: ${json["data"].runtimeType}');
    if (json["data"] is List) {
      print('🔍 Data length: ${(json["data"] as List).length}');
    }

    return CompanyAccountsModel(
      status: json["status"],
      message: json["message"],
      data: json["data"] == null
          ? []
          : List<CompanyAccountsData>.from(json["data"].map((x) {
              print('🔍 Parsing account data: ${x.toString()}');
              return CompanyAccountsData.fromJson(x);
            })),
    );
  }

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": data == null
            ? []
            : List<dynamic>.from(data!.map((x) => x.toJson())),
      };
}

class CompanyAccountsData {
  final String? name;
  final List<String>? paymentMethod;
  final String? type;
  final String? received;
  final dynamic sent; // Can be int or string
  final List<AccountTransaction>? accountTransaction;

  CompanyAccountsData({
    this.name,
    this.paymentMethod,
    this.type,
    this.received,
    this.sent,
    this.accountTransaction,
  });

  factory CompanyAccountsData.fromJson(Map<String, dynamic> json) {
    print('💰 CompanyAccountsData.fromJson called with: ${json.toString()}');
    print('💰 Name: ${json["name"]}');
    print('💰 Payment methods: ${json["paymentMethod"]}');
    print('💰 Type: ${json["type"]}');
    print('💰 Received: ${json["received"]}');
    print('💰 Sent: ${json["sent"]}');

    return CompanyAccountsData(
      name: json["name"] ?? "No Name",
      paymentMethod: json["paymentMethod"] == null
          ? []
          : List<String>.from(json["paymentMethod"]),
      type: json["type"] ?? "Unknown",
      received: json["received"]?.toString() ?? "0.000",
      sent: json["sent"], // Keep as dynamic to handle both int and string
      accountTransaction: json["accountTransaction"] == null
          ? []
          : List<AccountTransaction>.from(json["accountTransaction"]
              .map((x) => AccountTransaction.fromJson(x))),
    );
  }

  Map<String, dynamic> toJson() => {
        "name": name,
        "paymentMethod": paymentMethod == null
            ? []
            : List<dynamic>.from(paymentMethod!.map((x) => x)),
        "type": type,
        "received": received,
        "sent": sent,
        "accountTransaction": accountTransaction == null
            ? []
            : List<dynamic>.from(accountTransaction!.map((x) => x.toJson())),
      };

  // Helper methods for calculations and display
  double get receivedAmount {
    return double.tryParse(received ?? "0") ?? 0.0;
  }

  double get sentAmount {
    if (sent == null) return 0.0;
    if (sent is String) {
      return double.tryParse(sent) ?? 0.0;
    }
    if (sent is num) {
      return sent.toDouble();
    }
    return 0.0;
  }

  // Formatted getters for display
  String get formattedReceived {
    return receivedAmount.toStringAsFixed(2);
  }

  String get formattedSent {
    return sentAmount.toStringAsFixed(2);
  }

  // Calculate balance (received - sent)
  double get balance {
    return receivedAmount - sentAmount;
  }

  String get formattedBalance {
    return balance.toStringAsFixed(2);
  }

  // Payment methods as comma-separated string for display
  String get paymentMethodsString {
    if (paymentMethod == null || paymentMethod!.isEmpty) {
      return "No Payment Methods";
    }
    return paymentMethod!.join(", ");
  }

  // Check if account has specific payment method
  bool hasPaymentMethod(String method) {
    return paymentMethod?.contains(method) ?? false;
  }

  // Get transaction count
  int get transactionCount {
    return accountTransaction?.length ?? 0;
  }

  // Check if account type is cash or bank
  bool get isCashAccount {
    return type?.toLowerCase() == "cash";
  }

  bool get isBankAccount {
    return type?.toLowerCase() == "bank";
  }

  // Status based on balance
  String get accountStatus {
    if (balance > 0) return "Credit";
    if (balance < 0) return "Debit";
    return "Balanced";
  }
}

class AccountTransaction {
  final int? id;
  final String? transactionType;
  final String? amount;
  final String? description;
  final String? date;
  final String? reference;

  AccountTransaction({
    this.id,
    this.transactionType,
    this.amount,
    this.description,
    this.date,
    this.reference,
  });

  factory AccountTransaction.fromJson(Map<String, dynamic> json) =>
      AccountTransaction(
        id: json["id"],
        transactionType: json["transaction_type"] ?? json["transactionType"],
        amount: json["amount"]?.toString() ?? "0.00",
        description: json["description"] ?? "No Description",
        date: json["date"] ?? json["created_at"],
        reference: json["reference"] ?? json["transaction_reference"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "transaction_type": transactionType,
        "amount": amount,
        "description": description,
        "date": date,
        "reference": reference,
      };

  // Helper methods
  double get transactionAmount {
    return double.tryParse(amount ?? "0") ?? 0.0;
  }

  String get formattedAmount {
    return transactionAmount.toStringAsFixed(2);
  }

  bool get isCredit {
    return transactionType?.toLowerCase() == "credit" ||
        transactionType?.toLowerCase() == "received";
  }

  bool get isDebit {
    return transactionType?.toLowerCase() == "debit" ||
        transactionType?.toLowerCase() == "sent";
  }
}
