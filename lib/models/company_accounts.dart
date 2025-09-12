import 'dart:convert';

import 'package:flutter/material.dart';

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
    debugPrint(
        '=================== COMPANY ACCOUNTS MODEL DEBUG ===================');
    debugPrint(
        '🔍 CompanyAccountsModel.fromJson called with: ${json.toString()}');
    debugPrint('🔍 Status: ${json["status"]}');
    debugPrint('🔍 Message: ${json["message"]}');
    debugPrint('🔍 Data type: ${json["data"].runtimeType}');
    if (json["data"] is List) {
      debugPrint('🔍 Data length: ${(json["data"] as List).length}');
      if ((json["data"] as List).isNotEmpty) {
        debugPrint('🔍 First account data: ${(json["data"] as List)[0]}');
        // Let's also check if the first account has transaction data
        final firstAccount = (json["data"] as List)[0];
        if (firstAccount is Map<String, dynamic>) {
          debugPrint('🔍 First account keys: ${firstAccount.keys.toList()}');
          debugPrint(
              '🔍 First account accountTransaction: ${firstAccount["accountTransaction"]}');
          if (firstAccount["accountTransaction"] is List) {
            debugPrint(
                '🔍 First account transaction count: ${(firstAccount["accountTransaction"] as List).length}');
            if ((firstAccount["accountTransaction"] as List).isNotEmpty) {
              debugPrint(
                  '🔍 First transaction data: ${(firstAccount["accountTransaction"] as List)[0]}');
            }
          }
        }
      }
    }

    final model = CompanyAccountsModel(
      status: json["status"],
      message: json["message"],
      data: json["data"] == null
          ? []
          : List<CompanyAccountsData>.from(json["data"].map((x) {
              debugPrint('🔍 Parsing account data: ${x.toString()}');
              return CompanyAccountsData.fromJson(x);
            })),
    );

    debugPrint(
        '🔍 Parsed model: status=${model.status}, message=${model.message}, data length=${model.data?.length ?? 0}');
    debugPrint(
        '====================================================================');

    return model;
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
    debugPrint(
        '💰 CompanyAccountsData.fromJson called with: ${json.toString()}');
    debugPrint('💰 Name: ${json["name"]}');
    debugPrint('💰 Payment methods: ${json["payment_method"]}');
    debugPrint('💰 Type: ${json["type"]}');
    debugPrint('💰 Received: ${json["received"]}');
    debugPrint('💰 Sent: ${json["sent"]}');
    debugPrint('💰 Account transactions: ${json["account_transaction"]}');
    debugPrint(
        '💰 Account transactions type: ${json["account_transaction"].runtimeType}');
    if (json["account_transaction"] is List) {
      debugPrint(
          '💰 Account transactions length: ${(json["account_transaction"] as List).length}');
      if ((json["account_transaction"] as List).isNotEmpty) {
        debugPrint(
            '💰 First transaction: ${(json["account_transaction"] as List)[0]}');
      }
    }

    final account = CompanyAccountsData(
      name: json["name"] ?? "No Name",
      paymentMethod: json["payment_method"] == null
          ? []
          : List<String>.from(json["payment_method"]),
      type: json["type"] ?? "Unknown",
      received: json["received"]?.toString() ?? "0.000",
      sent: json["sent"], // Keep as dynamic to handle both int and string
      accountTransaction: json["account_transaction"] == null
          ? []
          : List<AccountTransaction>.from(json["account_transaction"]
              .map((x) => AccountTransaction.fromJson(x))),
    );

    debugPrint(
        '💰 Parsed account: name=${account.name}, transactions count=${account.accountTransaction?.length ?? 0}');

    return account;
  }

  Map<String, dynamic> toJson() => {
        "name": name,
        "payment_method": paymentMethod == null
            ? []
            : List<dynamic>.from(paymentMethod!.map((x) => x)),
        "type": type,
        "received": received,
        "sent": sent,
        "account_transaction": accountTransaction == null
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
  final String? transferFrom;
  final String? transferTo;
  final String? transferBy;
  final String? receivedBy;
  final String? status;

  AccountTransaction({
    this.id,
    this.transactionType,
    this.amount,
    this.description,
    this.date,
    this.reference,
    this.transferFrom,
    this.transferTo,
    this.transferBy,
    this.receivedBy,
    this.status,
  });

  factory AccountTransaction.fromJson(Map<String, dynamic> json) {
    // Debug print to see what data we're receiving
    debugPrint(
        '🧾 AccountTransaction.fromJson called with: ${json.toString()}');
    debugPrint('🧾 transfer_from: ${json["transfer_from"]}');
    debugPrint('🧾 transfer_to: ${json["transfer_to"]}');
    debugPrint('🧾 amount: ${json["amount"]}');
    debugPrint('🧾 transfer_type: ${json["transfer_type"]}');
    debugPrint('🧾 transaction_type: ${json["transaction_type"]}');
    debugPrint('🧾 transactionType: ${json["transactionType"]}');
    debugPrint('🧾 status: ${json["status"]}');
    debugPrint('🧾 date: ${json["date"]}');
    debugPrint('🧾 created_at: ${json["created_at"]}');

    final transaction = AccountTransaction(
      id: json["id"],
      transactionType: json["transaction_type"] ??
          json["transactionType"] ??
          json["transfer_type"] ??
          json["type"],
      amount: json["amount"]?.toString() ?? "0.00",
      description: json["description"] ?? "No Description",
      date: json["date"] ?? json["created_at"],
      reference: json["reference"] ?? json["transaction_reference"],
      transferFrom: json["transfer_from"],
      transferTo: json["transfer_to"],
      transferBy: json["transfer_by"],
      receivedBy: json["received_by"],
      status: json["status"],
    );

    debugPrint(
        '🧾 Parsed transaction: transferFrom=${transaction.transferFrom}, transferTo=${transaction.transferTo}, amount=${transaction.amount}, type=${transaction.transactionType}, status=${transaction.status}, date=${transaction.date}');

    return transaction;
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "transaction_type": transactionType,
        "amount": amount,
        "description": description,
        "date": date,
        "reference": reference,
        "transfer_from": transferFrom,
        "transfer_to": transferTo,
        "transfer_by": transferBy,
        "received_by": receivedBy,
        "status": status,
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
