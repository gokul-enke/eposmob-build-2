import 'dart:convert';

BankListResponse bankListResponseFromJson(String str) =>
    BankListResponse.fromJson(json.decode(str) as Map<String, dynamic>);

class BankListResponse {
  final String? status;
  final String? message;
  final List<StoreBank> data;

  const BankListResponse({
    this.status,
    this.message,
    this.data = const [],
  });

  factory BankListResponse.fromJson(Map<String, dynamic> json) {
    return BankListResponse(
      status: json['status']?.toString(),
      message: json['message']?.toString(),
      data: (json['data'] as List<dynamic>? ?? const [])
          .map((item) => StoreBank.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'data': data.map((item) => item.toJson()).toList(),
    };
  }
}

class StoreBank {
  final int? id;
  final String? bankName;
  final String? bankCode;
  final String? headOffice;
  final String? phone;
  final int? status;
  final int? companyId;
  final String? createdAt;
  final String? updatedAt;
  final List<StoreBankAccount> bankAccounts;

  const StoreBank({
    this.id,
    this.bankName,
    this.bankCode,
    this.headOffice,
    this.phone,
    this.status,
    this.companyId,
    this.createdAt,
    this.updatedAt,
    this.bankAccounts = const [],
  });

  factory StoreBank.fromJson(Map<String, dynamic> json) {
    return StoreBank(
      id: json['id'] as int?,
      bankName: json['bank_name']?.toString(),
      bankCode: json['bank_code']?.toString(),
      headOffice: json['head_office']?.toString(),
      phone: json['phone']?.toString(),
      status: json['status'] as int?,
      companyId: json['company_id'] as int?,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      bankAccounts: (json['bank_accounts'] as List<dynamic>? ?? const [])
          .map((item) =>
              StoreBankAccount.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bank_name': bankName,
      'bank_code': bankCode,
      'head_office': headOffice,
      'phone': phone,
      'status': status,
      'company_id': companyId,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'bank_accounts': bankAccounts.map((item) => item.toJson()).toList(),
    };
  }

  bool get isActive => status == null || status == 1;

  StoreBankAccount? get primaryAccount {
    for (final account in bankAccounts) {
      if (account.isActive) {
        return account;
      }
    }
    if (bankAccounts.isEmpty) {
      return null;
    }
    return bankAccounts.first;
  }
}

class StoreBankAccount {
  final int? id;
  final int? companyId;
  final String? accountNumber;
  final int? bankId;
  final String? ifsc;
  final String? swiftCode;
  final String? accountHolderName;
  final String? iban;
  final String? createdDate;
  final String? phoneNumber;
  final String? emailId;
  final String? status;
  final String? createdAt;
  final String? updatedAt;

  const StoreBankAccount({
    this.id,
    this.companyId,
    this.accountNumber,
    this.bankId,
    this.ifsc,
    this.swiftCode,
    this.accountHolderName,
    this.iban,
    this.createdDate,
    this.phoneNumber,
    this.emailId,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory StoreBankAccount.fromJson(Map<String, dynamic> json) {
    return StoreBankAccount(
      id: json['id'] as int?,
      companyId: json['company_id'] as int?,
      accountNumber: json['account_number']?.toString(),
      bankId: json['bank_id'] as int?,
      ifsc: json['ifsc']?.toString(),
      swiftCode: json['swift_code']?.toString(),
      accountHolderName: json['account_holder_name']?.toString(),
      iban: json['iban']?.toString(),
      createdDate: json['created_date']?.toString(),
      phoneNumber: json['phone_number']?.toString(),
      emailId: json['email_id']?.toString(),
      status: json['status']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'account_number': accountNumber,
      'bank_id': bankId,
      'ifsc': ifsc,
      'swift_code': swiftCode,
      'account_holder_name': accountHolderName,
      'iban': iban,
      'created_date': createdDate,
      'phone_number': phoneNumber,
      'email_id': emailId,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  bool get isActive {
    final normalized = status?.trim().toLowerCase();
    return normalized == null || normalized.isEmpty || normalized == 'active';
  }
}