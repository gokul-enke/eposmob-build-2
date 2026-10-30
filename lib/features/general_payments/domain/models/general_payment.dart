import '../general_payment_type.dart';

/// One entry of the General Payments list: an expense, asset, income or loan
/// with the account it debits and the account it credits.
class GeneralPayment {
  const GeneralPayment({
    this.id,
    required this.referenceNumber,
    required this.typeCode,
    this.typeLabel,
    required this.paymentDate,
    this.categoryId,
    required this.category,
    this.debitAccountId,
    required this.debitAccount,
    this.creditAccountId,
    required this.creditAccount,
    required this.amount,
    this.paymentMethod,
    this.status = '',
    this.description,
    this.notes,
    this.createdBy,
    this.usefulLifeYears,
  });

  final int? id;
  final String referenceNumber;

  /// `entry_type` as sent, e.g. EXPENSE; see [type].
  final String typeCode;

  /// `entry_type_label` as sent, shown for a type this app does not know.
  final String? typeLabel;

  /// The day of the payment, without a time.
  final DateTime paymentDate;
  final String? categoryId;
  final String category;
  final String? debitAccountId;
  final String debitAccount;
  final String? creditAccountId;
  final String creditAccount;
  final double amount;
  final String? paymentMethod;

  /// Status code as sent, e.g. SUCC; empty when missing.
  final String status;
  final String? description;
  final String? notes;
  final String? createdBy;

  /// Assets only, when given.
  final int? usefulLifeYears;

  GeneralPaymentType? get type => GeneralPaymentType.fromCode(typeCode);

  /// For loans, which way the money moved: repayments are saved as
  /// LOAN_REPAY entries, everything else as received.
  GeneralPaymentLoan? get loan => type != GeneralPaymentType.loan
      ? null
      : typeCode == GeneralPaymentLoan.repaid.code
          ? GeneralPaymentLoan.repaid
          : GeneralPaymentLoan.received;

  /// Reads one API row. The reference number, payment date and amount are
  /// required; everything else may be missing.
  factory GeneralPayment.fromJson(Map<String, dynamic> json) {
    final reference = _text(json['reference_number'] ?? json['reference_no']);
    final date = DateTime.tryParse(_text(json['payment_date']) ?? '');
    final amount = _amount(json['amount']);
    if (reference == null || date == null || amount == null) {
      throw const FormatException('Invalid general payment row.');
    }
    final categoryId = _text(json['category']);
    final debitAccountId = _text(json['expense_account_id']);
    final creditAccountId = _text(json['payment_account_id']);
    return GeneralPayment(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}'),
      referenceNumber: reference,
      typeCode: _text(json['entry_type'])?.toUpperCase() ?? '',
      typeLabel: _text(json['entry_type_label']),
      paymentDate: DateTime(date.year, date.month, date.day),
      categoryId: categoryId,
      category: _text(json['category_label']) ?? categoryId ?? '',
      debitAccountId: debitAccountId,
      debitAccount: _text(json['expense_account_name']) ?? debitAccountId ?? '',
      creditAccountId: creditAccountId,
      creditAccount:
          _text(json['payment_account_name']) ?? creditAccountId ?? '',
      amount: amount,
      paymentMethod:
          _text(json['payment_method_label']) ?? _text(json['payment_method']),
      status: _text(json['status'])?.toUpperCase() ?? '',
      description: _text(json['description']),
      notes: _text(json['notes']),
      createdBy: _text(json['created_by_name']),
      usefulLifeYears: _amount(json['useful_life_years'])?.round(),
    );
  }
}

/// Trimmed text, or null when missing or empty.
String? _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text == 'null' ? null : text;
}

/// A finite amount from a number or numeric string; null when missing or bad.
double? _amount(Object? value) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse('${value ?? ''}'.replaceAll(',', '').trim());
  return parsed != null && parsed.isFinite ? parsed : null;
}
