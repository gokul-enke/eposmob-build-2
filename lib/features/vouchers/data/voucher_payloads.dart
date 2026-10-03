/// Preserve the original create contracts, including nullable payment methods.
Map<String, dynamic> customerVoucherPayload(
        {required int customerId,
        required String type,
        required double amount,
        required String voucherDate,
        required String dueDate,
        required String status,
        required int? paymentMethodId,
        required List<Map<String, dynamic>> voucherItems}) =>
    {
      'type': type,
      'amount': amount,
      'voucher_date': voucherDate,
      'due_date': dueDate,
      'status': status,
      'payment_method': paymentMethodId,
      'customer_id': customerId,
      'voucher_items': voucherItems,
    };

Map<String, dynamic> supplierVoucherPayload(
        {required int supplierId,
        required String type,
        required double amount,
        required String voucherDate,
        required String dueDate,
        required String status,
        required int? paymentMethodId,
        required List<Map<String, dynamic>> voucherItems}) =>
    {
      'supplier_id': supplierId,
      'type': type,
      'amount': amount,
      'voucher_date': voucherDate,
      'due_date': dueDate,
      'status': status,
      'payment_method': paymentMethodId,
      'voucher_items': voucherItems,
    };
