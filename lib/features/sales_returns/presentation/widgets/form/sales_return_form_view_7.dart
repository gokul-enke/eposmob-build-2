part of 'sales_return_form_view.dart';

extension _FormSection7 on SalesReturnFormSections {
  IconData _getPaymentMethodIcon(String method) {
    switch (method) {
      case 'CASH':
        return Icons.money;
      case 'CARD':
        return Icons.credit_card;
      case 'UPI':
        return Icons.qr_code;
      default:
        return Icons.payment;
    }
  }
}
