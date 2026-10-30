import 'general_payment_type.dart';

/// One choice of a New Entry dropdown: an account, a category or a payment
/// method. [code] is the stable master data code where there is one (CASH).
class GeneralPaymentOption {
  const GeneralPaymentOption(this.id, this.label, {this.code});

  final String id;
  final String label;
  final String? code;

  @override
  bool operator ==(Object other) =>
      other is GeneralPaymentOption &&
      other.id == id &&
      other.label == label &&
      other.code == code;

  @override
  int get hashCode => Object.hash(id, label, code);
}

/// The accounts a kind of entry may debit and credit (account-options).
class GeneralPaymentAccounts {
  const GeneralPaymentAccounts({required this.debit, required this.credit});

  final List<GeneralPaymentOption> debit;
  final List<GeneralPaymentOption> credit;
}

/// What the server said to a new entry.
sealed class GeneralPaymentSaveResult {
  const GeneralPaymentSaveResult();
}

final class GeneralPaymentSaved extends GeneralPaymentSaveResult {
  const GeneralPaymentSaved({this.reference});

  /// The reference number the server gave the entry, when it says.
  final String? reference;
}

final class GeneralPaymentRejected extends GeneralPaymentSaveResult {
  const GeneralPaymentRejected([this.message]);

  /// The server's reason (its first field error when there is one); null
  /// when it gave none.
  final String? message;
}

/// A complete New Entry, ready to send.
class GeneralPaymentDraft {
  const GeneralPaymentDraft({
    required this.type,
    this.loan,
    required this.date,
    required this.categoryId,
    required this.debitAccountId,
    required this.creditAccountId,
    required this.amount,
    required this.paymentMethodId,
    this.description = '',
    this.notes = '',
    this.usefulLifeYears,
  });

  final GeneralPaymentType type;

  /// Only for loans.
  final GeneralPaymentLoan? loan;
  final DateTime date;
  final String categoryId;
  final String debitAccountId;
  final String creditAccountId;
  final double amount;
  final String paymentMethodId;
  final String description;
  final String notes;

  /// Only for assets; optional.
  final int? usefulLifeYears;

  /// The create-general-payment body. The debit account goes in
  /// `expense_account_id` and the credit account in `payment_account_id`
  /// for every type, as the list reports them. The active store is added by
  /// the API.
  Map<String, dynamic> toPayload() {
    String two(int n) => n.toString().padLeft(2, '0');
    Object id(String value) => int.tryParse(value) ?? value;
    return {
      'entry_type': type.code,
      if (type == GeneralPaymentType.loan)
        'loan_type': (loan ?? GeneralPaymentLoan.received).code,
      'payment_date': '${date.year.toString().padLeft(4, '0')}-'
          '${two(date.month)}-${two(date.day)}',
      'category': categoryId,
      'description': description.trim(),
      'amount': amount,
      'payment_method': paymentMethodId,
      'expense_account_id': id(debitAccountId),
      'payment_account_id': id(creditAccountId),
      'status': 'SUCC',
      'notes': notes.trim(),
      if (type == GeneralPaymentType.asset && usefulLifeYears != null)
        'useful_life_years': usefulLifeYears,
    };
  }
}

/// Why an amount cannot be saved, as a translation key; null when it is a
/// positive number.
String? generalPaymentAmountError(String? text) {
  final value = double.tryParse(text?.trim() ?? '');
  return value != null && value.isFinite && value > 0
      ? null
      : 'general_payments.error_amount';
}

/// Why a useful life cannot be saved; null when left empty (it is optional)
/// or whole years above zero.
String? generalPaymentUsefulLifeError(String? text) {
  final clean = text?.trim() ?? '';
  if (clean.isEmpty) return null;
  final years = int.tryParse(clean);
  return years != null && years > 0
      ? null
      : 'general_payments.error_useful_life';
}

/// The reference number after the highest of the [prefix] series among
/// [references] (EXP00119 → EXP00120), as the web shows it; the server
/// assigns the real one when saving. Null when there is none to count from.
String? nextGeneralPaymentReference(
    String prefix, Iterable<String> references) {
  final pattern = RegExp('^${RegExp.escape(prefix)}(\\d+)\$');
  int? highest;
  var digits = 5;
  for (final reference in references) {
    final match = pattern.firstMatch(reference.trim());
    final number = match == null ? null : int.tryParse(match[1]!);
    if (number != null && (highest == null || number > highest)) {
      highest = number;
      digits = match![1]!.length;
    }
  }
  if (highest == null) return null;
  return '$prefix${'${highest + 1}'.padLeft(digits, '0')}';
}

/// The reference number after [reference] (INC00008 → INC00009), or null
/// when it does not end in a number.
String? followingGeneralPaymentReference(String reference) {
  final match = RegExp(r'^(.*?)(\d+)$').firstMatch(reference.trim());
  if (match == null) return null;
  final number = int.parse(match[2]!) + 1;
  return '${match[1]}${'$number'.padLeft(match[2]!.length, '0')}';
}
