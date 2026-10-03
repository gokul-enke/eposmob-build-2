/// Preserves the expense creation contract, including string master-data IDs
/// and the original account-ID types. Tenant store augmentation lives in API.
Map<String, dynamic> expenseCreatePayload(
        {required DateTime date,
        required Map<String, dynamic> category,
        required Map<String, dynamic> debitAccount,
        required Map<String, dynamic> creditAccount,
        required Map<String, dynamic> paymentMethod,
        required String description,
        required double amount,
        required String notes}) =>
    {
      'entry_type': 'EXPENSE',
      'payment_date':
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'category': category['id'].toString(),
      'description': description.trim(),
      'amount': amount,
      'payment_method': paymentMethod['id'].toString(),
      'expense_account_id': debitAccount['id'],
      'payment_account_id': creditAccount['id'],
      'status': 'SUCC',
      'notes': notes.trim(),
    };
