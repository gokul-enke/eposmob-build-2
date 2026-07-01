/// Customer balance fields shown on printed receipts after checkout.
///
/// Mirrors desktop `_createOrderAndPrint` balance math in
/// `billing_page.dart`.
class ReceiptCustomerBalance {
  const ReceiptCustomerBalance({
    this.oldBalance,
    this.currentBalance,
  });

  final double? oldBalance;
  final double? currentBalance;

  /// Computes old/current balance for a receipt using the customer's
  /// pre-sale balance, cart total, and amount collected at checkout.
  static ReceiptCustomerBalance compute({
    required bool isDefaultCustomer,
    required double? customerBalance,
    required double cartTotal,
    required double totalPaid,
  }) {
    final oldBalance = isDefaultCustomer ? null : customerBalance;
    if (oldBalance == null) {
      return const ReceiptCustomerBalance();
    }

    // Current balance = old balance - (cart total - amount paid)
    final currentBalance = oldBalance - (cartTotal - totalPaid);
    return ReceiptCustomerBalance(
      oldBalance: oldBalance,
      currentBalance: currentBalance,
    );
  }
}
