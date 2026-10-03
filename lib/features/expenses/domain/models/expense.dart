import 'dart:convert';

class Expense {
  final String referenceNumber;
  final DateTime paymentDate;
  final String category;
  final String? categoryId;
  final String debitAccount;
  final String? debitAccountId;
  final String creditAccount;
  final String? creditAccountId;
  final double amount;
  final String status;
  final String paymentMethod;
  final String? paymentMethodId;
  final String description;
  final String notes;

  Expense({
    required this.referenceNumber,
    required this.paymentDate,
    required this.category,
    this.categoryId,
    required this.debitAccount,
    this.debitAccountId,
    required this.creditAccount,
    this.creditAccountId,
    required this.amount,
    this.status = 'SUCC',
    required this.paymentMethod,
    this.paymentMethodId,
    required this.description,
    this.notes = '',
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    final categoryId = _readString(
      json,
      const ['category_id', 'category', 'category_code'],
    );
    final debitAccountId = _readString(
      json,
      const ['expense_account_id', 'debit_account_id', 'debit_account'],
    );
    final creditAccountId = _readString(
      json,
      const ['payment_account_id', 'credit_account_id', 'credit_account'],
    );
    final paymentMethodId = _readString(
      json,
      const ['payment_method_id', 'payment_method', 'payment_method_code'],
    );

    return Expense(
      referenceNumber: json['reference_number'] ?? json['reference_no'] ?? '',
      paymentDate: json['payment_date'] != null
          ? DateTime.parse(json['payment_date'])
          : DateTime.now(),
      category: _readString(
            json,
            const ['category_name', 'category_description', 'category_label'],
          ) ??
          categoryId ??
          '',
      categoryId: categoryId,
      debitAccount: _readString(
            json,
            const [
              'expense_account_name',
              'debit_account_name',
              'expense_account_description'
            ],
          ) ??
          debitAccountId ??
          '',
      debitAccountId: debitAccountId,
      creditAccount: _readString(
            json,
            const [
              'payment_account_name',
              'credit_account_name',
              'payment_account_description'
            ],
          ) ??
          creditAccountId ??
          '',
      creditAccountId: creditAccountId,
      amount: (json['amount'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'SUCC',
      paymentMethod: _readString(
            json,
            const [
              'payment_method_name',
              'payment_method_description',
              'payment_method_label'
            ],
          ) ??
          paymentMethodId ??
          '',
      paymentMethodId: paymentMethodId,
      description: json['description'] ?? '',
      notes: json['notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reference_number': referenceNumber,
      'payment_date': paymentDate.toIso8601String(),
      'category': category,
      'category_id': categoryId,
      'debit_account': debitAccount,
      'debit_account_id': debitAccountId,
      'credit_account': creditAccount,
      'credit_account_id': creditAccountId,
      'amount': amount,
      'status': status,
      'payment_method': paymentMethod,
      'payment_method_id': paymentMethodId,
      'description': description,
      'notes': notes,
    };
  }

  Expense copyWith({
    String? referenceNumber,
    DateTime? paymentDate,
    String? category,
    String? categoryId,
    String? debitAccount,
    String? debitAccountId,
    String? creditAccount,
    String? creditAccountId,
    double? amount,
    String? status,
    String? paymentMethod,
    String? paymentMethodId,
    String? description,
    String? notes,
  }) {
    return Expense(
      referenceNumber: referenceNumber ?? this.referenceNumber,
      paymentDate: paymentDate ?? this.paymentDate,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      debitAccount: debitAccount ?? this.debitAccount,
      debitAccountId: debitAccountId ?? this.debitAccountId,
      creditAccount: creditAccount ?? this.creditAccount,
      creditAccountId: creditAccountId ?? this.creditAccountId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
      description: description ?? this.description,
      notes: notes ?? this.notes,
    );
  }
}

String? _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null) {
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
  }
  return null;
}
