class PaymentAutoFillResult {
  final String cash;
  final String card;
  final String upi;
  final String cod;

  const PaymentAutoFillResult({
    required this.cash,
    required this.card,
    required this.upi,
    required this.cod,
  });
}

class PaymentAutoFillHelper {
  static PaymentAutoFillResult remapAmountsAfterDiscount({
    required bool isCashSelected,
    required bool isCardSelected,
    required bool isUpiSelected,
    required bool isCodSelected,
    required String cashAmount,
    required String cardAmount,
    required String upiAmount,
    required String codAmount,
    required double oldEffectiveTotal,
    required double newEffectiveTotal,
  }) {
    var nextCash = cashAmount;
    var nextCard = cardAmount;
    var nextUpi = upiAmount;
    var nextCod = codAmount;

    final anySelected =
        isCashSelected || isCardSelected || isUpiSelected || isCodSelected;
    final selectedCount = (isCashSelected ? 1 : 0) +
        (isCardSelected ? 1 : 0) +
        (isUpiSelected ? 1 : 0) +
        (isCodSelected ? 1 : 0);

    final cashVal = double.tryParse(cashAmount) ?? 0.0;
    final cardVal = double.tryParse(cardAmount) ?? 0.0;
    final upiVal = double.tryParse(upiAmount) ?? 0.0;
    final codVal = double.tryParse(codAmount) ?? 0.0;
    final totalPaid = cashVal + cardVal + upiVal + codVal;

    if (!anySelected) {
      return const PaymentAutoFillResult(cash: '', card: '', upi: '', cod: '');
    }

    if (selectedCount == 1 && (totalPaid - oldEffectiveTotal).abs() < 0.01) {
      final remapped = newEffectiveTotal.toStringAsFixed(2);
      if (isCashSelected) {
        nextCash = remapped;
        nextCard = '';
        nextUpi = '';
        nextCod = '';
      } else if (isCardSelected) {
        nextCash = '';
        nextCard = remapped;
        nextUpi = '';
        nextCod = '';
      } else if (isUpiSelected) {
        nextCash = '';
        nextCard = '';
        nextUpi = remapped;
        nextCod = '';
      } else if (isCodSelected) {
        nextCash = '';
        nextCard = '';
        nextUpi = '';
        nextCod = remapped;
      }
    }

    return PaymentAutoFillResult(
      cash: nextCash,
      card: nextCard,
      upi: nextUpi,
      cod: nextCod,
    );
  }

  static String autoFillSingleMethod({
    required String paymentType,
    required String currentTargetAmount,
    required String cashAmount,
    required String cardAmount,
    required String upiAmount,
    required String codAmount,
    required double cartTotal,
  }) {
    if (currentTargetAmount.isNotEmpty) {
      return currentTargetAmount;
    }

    final cash = paymentType == 'cash' ? 0.0 : (double.tryParse(cashAmount) ?? 0.0);
    final card = paymentType == 'card' ? 0.0 : (double.tryParse(cardAmount) ?? 0.0);
    final upi = paymentType == 'upi' ? 0.0 : (double.tryParse(upiAmount) ?? 0.0);
    final cod = paymentType == 'cod' ? 0.0 : (double.tryParse(codAmount) ?? 0.0);

    final remaining = cartTotal - (cash + card + upi + cod);
    if (remaining <= 0) {
      return currentTargetAmount;
    }
    return remaining.toStringAsFixed(2);
  }
}
