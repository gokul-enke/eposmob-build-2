/// Snapshot of a saved form row, preserving the existing receipt API mapping.
class ReceiptFormItem {
  const ReceiptFormItem({
    required this.selectedItemType,
    required this.invoiceId,
    required this.amount,
    required this.paymentDate,
    required this.description,
  });

  final String? selectedItemType;
  final String? invoiceId;
  final String amount;
  final String paymentDate;
  final String description;

  Map<String, dynamic> toApi({required int? paymentMethodId}) {
    final type =
        (selectedItemType?.toLowerCase() ?? 'general').contains('invoice')
            ? 'invoice'
            : 'general';
    return {
      'item_type': type,
      'paid_amount': double.tryParse(amount) ?? 0.0,
      'status': 'paid',
      'payment_date': paymentDate,
      'payment_method': paymentMethodId,
      'description': description.isNotEmpty ? description : 'General Payment',
      if (type == 'invoice' && invoiceId != null && invoiceId!.isNotEmpty)
        'invoice_id': invoiceId,
    };
  }
}
