import 'package:flutter/material.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/screens/billing/widgets/payment_method_modal.dart';
import 'package:provider/provider.dart';

class PaymentMethodModalWrapper extends StatelessWidget {
  const PaymentMethodModalWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BillingProvider>(
      builder: (context, billingProvider, child) {
        return PaymentMethodModal(
          initialIsCashSelected: billingProvider.isCashSelected,
          initialIsCardSelected: billingProvider.isCardSelected,
          initialIsUpiSelected: billingProvider.isUpiSelected,
          initialIsDebitSelected: billingProvider.isDebitSelected,
          initialCashAmount: billingProvider.cashAmountController.text,
          initialCardAmount: billingProvider.cardAmountController.text,
          initialUpiAmount: billingProvider.upiAmountController.text,
          initialDebitAmount: billingProvider.debitAmountController.text,
          initialTransactionNumber:
              billingProvider.transactionNumberController.text,
          cartTotal: billingProvider.totalOrderAmount,
          customerPrevBalance: billingProvider.customerBalance,
          onPaymentMethodSelected: (
            isCash,
            isCard,
            isUpi,
            isDebit,
            cashAmt,
            cardAmt,
            upiAmt,
            debitAmt,
            transNum,
            toCustomerCredit, {
            String? cashMethodId,
            String? cardMethodId,
            String? upiMethodId,
          }) {
            billingProvider.updatePaymentFromModal(
              isCash: isCash,
              isCard: isCard,
              isUpi: isUpi,
              isDebit: isDebit,
              cashAmount: cashAmt,
              cardAmount: cardAmt,
              upiAmount: upiAmt,
              debitAmount: debitAmt,
              transactionNumber: transNum,
              toCustomerCredit: toCustomerCredit,
              cashMethodId: cashMethodId,
              cardMethodId: cardMethodId,
              upiMethodId: upiMethodId,
            );
          },
        );
      },
    );
  }
}
