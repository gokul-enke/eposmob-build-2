import 'models/expense.dart';

bool isMeaningfulExpenseFilterSelection(
  String? value, {
  required String allLabel,
}) {
  final normalizedValue = value?.trim().toLowerCase();
  if (normalizedValue == null || normalizedValue.isEmpty) return false;

  final normalizedAllLabel = allLabel.trim().toLowerCase();
  return normalizedValue != 'all' && normalizedValue != normalizedAllLabel;
}

List<Expense> applyExpenseFilters(Iterable<Expense> expenses,
        {required String reference,
        required String category,
        required String debitAccount,
        required String status}) =>
    expenses
        .where((expense) =>
            (reference.isEmpty ||
                expense.referenceNumber
                    .toLowerCase()
                    .contains(reference.toLowerCase())) &&
            (category == 'All' || expense.category == category) &&
            (debitAccount == 'All' || expense.debitAccount == debitAccount) &&
            (status == 'All' || expense.status == status))
        .toList();
