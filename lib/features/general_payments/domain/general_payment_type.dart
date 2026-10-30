/// The kinds of general payment entry, with their API `entry_type` code.
enum GeneralPaymentType {
  expense('EXPENSE', 'EXP'),
  asset('ASSET', 'AST'),
  income('INCOME', 'INC'),
  loan('LOAN', 'LON');

  const GeneralPaymentType(this.code, this.referencePrefix);

  /// Value of `entry_type` in the API.
  final String code;

  /// Start of this type's reference numbers, e.g. EXP in EXP00120.
  final String referencePrefix;

  /// Translation key of the short label (Expense, Asset, Income, Loan).
  String get labelKey => 'general_payments.type_$name';

  /// Master data codes that may hold this type's categories, tried in order
  /// (the first with values wins).
  List<String> get categoryCodes => switch (this) {
        expense => const ['EXPENSE_CATEGORY', 'EXPENSE_CATEGORIES'],
        asset => const [
            'ASSET_CATEGORY',
            'ASSET_TYPE',
            'ASSET_CATEGORIES',
            'ASSET_TYPES'
          ],
        income => const [
            'INCOME_CATEGORY',
            'INCOME_CATEGORIES',
            'OTHER_INCOME_CATEGORY'
          ],
        loan => const [
            'LOAN_TYPE',
            'LOAN_TYPES',
            'LOAN_CATEGORY',
            'LOAN_CATEGORIES'
          ],
      };

  /// The type of an API code; null for codes this app does not know. A loan
  /// repayment is saved as its own `entry_type` (LOAN_REPAY) but is a loan,
  /// as the web's Total Loan counts it.
  static GeneralPaymentType? fromCode(String? code) {
    final clean = code?.trim().toUpperCase();
    if (clean == GeneralPaymentLoan.repaid.code) return loan;
    for (final type in values) {
      if (type.code == clean) return type;
    }
    return null;
  }
}

/// Which way a loan entry moves money, as the API's `loan_type`.
enum GeneralPaymentLoan {
  /// Loan money received into a bank or cash account.
  received('LOAN_IN', 'LON'),

  /// Paying the lender back; saved with this code as its `entry_type`.
  repaid('LOAN_REPAY', 'LRP');

  const GeneralPaymentLoan(this.code, this.referencePrefix);

  final String code;

  /// Start of the reference numbers it gets (LON00004, LRP00001).
  final String referencePrefix;

  String get labelKey => 'general_payments.loan_$name';
}

/// The reference series of an entry: one per type, and repayments have
/// their own (LRP).
String generalPaymentReferencePrefix(
        GeneralPaymentType type, GeneralPaymentLoan? loan) =>
    type == GeneralPaymentType.loan && loan != null
        ? loan.referencePrefix
        : type.referencePrefix;

/// Every reference series, for working out the next numbers: one per type,
/// plus loan repayments.
final generalPaymentReferencePrefixes = [
  for (final type in GeneralPaymentType.values) type.referencePrefix,
  GeneralPaymentLoan.repaid.referencePrefix,
];
