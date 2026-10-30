import 'general_payment_entry.dart';
import 'general_payment_type.dart';

/// Which payment methods go with which cash or bank account, from the
/// Company Accounts setup (an account's `payment_method` list), as Create
/// Expense applies it: UPI is not paid from the Cash Account. Names are
/// compared without case, against a method's label or code.
class GeneralPaymentMethodRules {
  GeneralPaymentMethodRules(Map<String, List<String>> rules)
      : _rules = {
          for (final MapEntry(:key, :value) in rules.entries)
            if (value.isNotEmpty)
              key.trim().toUpperCase(): {
                for (final method in value) method.trim().toUpperCase()
              }
        };

  static final none = GeneralPaymentMethodRules(const {});

  final Map<String, Set<String>> _rules;

  /// Whether [account] (by name) limits its payment methods.
  bool limits(String? account) =>
      account != null && _rules.containsKey(account.trim().toUpperCase());

  /// The [methods] that [account] allows: all of them when it has no rule,
  /// or when none of its names match (a setup that would leave no choice).
  List<GeneralPaymentOption> methodsFor(
      String? account, List<GeneralPaymentOption> methods) {
    final allowed =
        account == null ? null : _rules[account.trim().toUpperCase()];
    if (allowed == null) return methods;
    final fitting = [
      for (final method in methods)
        if (allowed.contains(method.label.trim().toUpperCase()) ||
            allowed.contains(method.code?.trim().toUpperCase()))
          method
    ];
    return fitting.isEmpty ? methods : fitting;
  }

  /// Whether the money comes in through the debit account (Income, Loan
  /// received) rather than going out of the credit one (Expense, Asset,
  /// Loan repaid) — the account whose rule applies.
  static bool receivesOnDebit(
          GeneralPaymentType type, GeneralPaymentLoan? loan) =>
      type == GeneralPaymentType.income ||
      (type == GeneralPaymentType.loan && loan == GeneralPaymentLoan.received);
}
