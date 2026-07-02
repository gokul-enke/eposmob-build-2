/// Shared payment validation for billing checkout and order confirmation.
///
/// Collected amounts (cash/card/upi/cod/extra) represent money taken at the
/// register. Debit / customer-credit fields represent change allocated to the
/// customer's account, not payment collected from them.
class PaymentValidation {
  PaymentValidation._();

  static const double _epsilon = 0.009;

  static double parseAmount(String? value) =>
      double.tryParse(value?.trim() ?? '') ?? 0.0;

  /// Sum of money collected at the register (excludes debit / store credit).
  static double sumCollected({
    required bool isCashSelected,
    required bool isCardSelected,
    required bool isUpiSelected,
    required bool isCodSelected,
    required String cashAmount,
    required String cardAmount,
    required String upiAmount,
    required String codAmount,
    Map<String, String>? extraAmounts,
  }) {
    var total = 0.0;

    if (isCashSelected) total += parseAmount(cashAmount);
    if (isCardSelected) total += parseAmount(cardAmount);
    if (isUpiSelected) total += parseAmount(upiAmount);
    if (isCodSelected) total += parseAmount(codAmount);

    for (final amountStr in (extraAmounts ?? const {}).values) {
      total += parseAmount(amountStr);
    }

    return total;
  }

  /// True when at least one collected method has a positive amount.
  static bool hasCollectedPayment({
    required bool isCashSelected,
    required bool isCardSelected,
    required bool isUpiSelected,
    required bool isCodSelected,
    required String cashAmount,
    required String cardAmount,
    required String upiAmount,
    required String codAmount,
    Map<String, String>? extraAmounts,
  }) {
    if (isCashSelected && parseAmount(cashAmount) > 0) return true;
    if (isCardSelected && parseAmount(cardAmount) > 0) return true;
    if (isUpiSelected && parseAmount(upiAmount) > 0) return true;
    if (isCodSelected && parseAmount(codAmount) > 0) return true;

    for (final amountStr in (extraAmounts ?? const {}).values) {
      if (parseAmount(amountStr) > 0) return true;
    }

    return false;
  }

  /// Net amount the customer must cover at checkout after applying store credit.
  static double computeNetDue({
    required double orderTotal,
    required bool toCustomerCreditEnabled,
    required bool isDefaultCustomer,
    required double customerPrevBalance,
  }) {
    if (orderTotal <= 0) return 0;

    if (!toCustomerCreditEnabled || isDefaultCustomer) {
      return orderTotal;
    }

    if (customerPrevBalance > 0) {
      return (orderTotal - customerPrevBalance).clamp(0.0, double.infinity);
    }

    return orderTotal;
  }

  /// Whether collected payments cover the net amount due (overpay allowed).
  static bool coversNetDue({
    required double orderTotal,
    required bool toCustomerCreditEnabled,
    required bool isDefaultCustomer,
    required double customerPrevBalance,
    required bool isCashSelected,
    required bool isCardSelected,
    required bool isUpiSelected,
    required bool isCodSelected,
    required String cashAmount,
    required String cardAmount,
    required String upiAmount,
    required String codAmount,
    Map<String, String>? extraAmounts,
  }) {
    if (orderTotal <= _epsilon) return true;

    final collected = sumCollected(
      isCashSelected: isCashSelected,
      isCardSelected: isCardSelected,
      isUpiSelected: isUpiSelected,
      isCodSelected: isCodSelected,
      cashAmount: cashAmount,
      cardAmount: cardAmount,
      upiAmount: upiAmount,
      codAmount: codAmount,
      extraAmounts: extraAmounts,
    );

    final netDue = computeNetDue(
      orderTotal: orderTotal,
      toCustomerCreditEnabled: toCustomerCreditEnabled,
      isDefaultCustomer: isDefaultCustomer,
      customerPrevBalance: customerPrevBalance,
    );

    return collected + _epsilon >= netDue;
  }

  static PaymentValidationResult validateForOrder({
    required double orderTotal,
    required bool toCustomerCreditEnabled,
    required bool isDefaultCustomer,
    required double customerPrevBalance,
    required bool isCashSelected,
    required bool isCardSelected,
    required bool isUpiSelected,
    required bool isCodSelected,
    required String cashAmount,
    required String cardAmount,
    required String upiAmount,
    required String codAmount,
    Map<String, String>? extraAmounts,
  }) {
    if (orderTotal <= _epsilon) {
      return const PaymentValidationResult.valid();
    }

    if (!hasCollectedPayment(
      isCashSelected: isCashSelected,
      isCardSelected: isCardSelected,
      isUpiSelected: isUpiSelected,
      isCodSelected: isCodSelected,
      cashAmount: cashAmount,
      cardAmount: cardAmount,
      upiAmount: upiAmount,
      codAmount: codAmount,
      extraAmounts: extraAmounts,
    )) {
      return const PaymentValidationResult.invalid(
        'Please enter at least one payment amount',
      );
    }

    if (!coversNetDue(
      orderTotal: orderTotal,
      toCustomerCreditEnabled: toCustomerCreditEnabled,
      isDefaultCustomer: isDefaultCustomer,
      customerPrevBalance: customerPrevBalance,
      isCashSelected: isCashSelected,
      isCardSelected: isCardSelected,
      isUpiSelected: isUpiSelected,
      isCodSelected: isCodSelected,
      cashAmount: cashAmount,
      cardAmount: cardAmount,
      upiAmount: upiAmount,
      codAmount: codAmount,
      extraAmounts: extraAmounts,
    )) {
      return const PaymentValidationResult.invalid(
        'Payment amount is less than the amount due',
      );
    }

    return const PaymentValidationResult.valid();
  }

  /// Mirrors checkout confirm/print gating: valid amounts plus payment UI reached.
  static bool isCheckoutPaymentComplete({
    required bool paymentStepVisited,
    required bool onPaymentStep,
    required double orderTotal,
    required bool toCustomerCreditEnabled,
    required bool isDefaultCustomer,
    required double customerPrevBalance,
    required bool isCashSelected,
    required bool isCardSelected,
    required bool isUpiSelected,
    required bool isCodSelected,
    required String cashAmount,
    required String cardAmount,
    required String upiAmount,
    required String codAmount,
    Map<String, String>? extraAmounts,
  }) {
    final validation = validateForOrder(
      orderTotal: orderTotal,
      toCustomerCreditEnabled: toCustomerCreditEnabled,
      isDefaultCustomer: isDefaultCustomer,
      customerPrevBalance: customerPrevBalance,
      isCashSelected: isCashSelected,
      isCardSelected: isCardSelected,
      isUpiSelected: isUpiSelected,
      isCodSelected: isCodSelected,
      cashAmount: cashAmount,
      cardAmount: cardAmount,
      upiAmount: upiAmount,
      codAmount: codAmount,
      extraAmounts: extraAmounts,
    );
    if (!validation.isValid) return false;
    return paymentStepVisited || onPaymentStep;
  }
}

class PaymentValidationResult {
  const PaymentValidationResult._({
    required this.isValid,
    this.message,
  });

  const PaymentValidationResult.valid() : this._(isValid: true);

  const PaymentValidationResult.invalid(String message)
      : this._(isValid: false, message: message);

  final bool isValid;
  final String? message;
}
